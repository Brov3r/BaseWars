AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
AddCSLuaFile("include.lua")

include("shared.lua")
include("include.lua")

function GM:PlayerInitialSpawn(ply, transition)
    self.BaseClass.PlayerInitialSpawn(self, ply, transition)
    -- The base method assigns TEAM_UNASSIGNED after PlayerInitialSpawn hooks.
    ply:SetTeam(BW.TEAM_DEFAULT or 1000)
end

function GM:GetFallDamage(ply, speed)
    return math.max( 0, math.ceil( 0.2418 * speed - 141.75 ) )
end

function GM:PlayerSpawn(ply, transition)
    self.BaseClass.PlayerSpawn(self, ply, transition)
    
    -- Validate motion config values
    local walkSpeed = math.max(1, BW.Config.Motion.WalkSpeed or 200)
    local runSpeed = math.max(1, BW.Config.Motion.RunSpeed or 400)
    local jumpPower = math.Clamp(BW.Config.Motion.JumpPower or 200, 0, 1000)
    
    ply:SetWalkSpeed(walkSpeed)
    ply:SetRunSpeed(runSpeed)
    ply:SetJumpPower(jumpPower)  
end

function GM:PlayerLoadout( ply )
	for _, class in ipairs(BW.Config.PlayerLoadout) do
        if not ply:HasWeapon(class) then
            ply:Give(class)
        end
    end

    -- Ensure player has hands weapon selected
    if IsValid(ply) then
        ply:SelectWeapon("hands")
    end
    
    return true
end

function GM:PlayerDeath(victim, inflictor, attacker)
    self.BaseClass.PlayerDeath(self, victim, inflictor, attacker)

    if IsValid(attacker) and attacker:IsPlayer() and attacker ~= victim then
        attacker:AddKills(1)
    end

    -- Drop Money
    local money = victim:GetMoney()
    local safeMoney = BW.Config.Economy.SafeMoneyAmountOnDeath
    
    if money > safeMoney then
        local userGroup = victim:GetUserGroup()
        local groupConfig = BW.Config.PlayerGroups[userGroup]
        
        local multiplier = (groupConfig and groupConfig.DropMoneyMultiplier) 
                           or BW.Config.Economy.DropMoneyMultiplierDefault
        
        local dropAmount = math.floor((money - safeMoney) * math.Clamp(multiplier, 0, 1))
        
        if dropAmount > 0 then
            local ent = ents.Create("spawned_money")
            if IsValid(ent) then
                ent:SetPos(victim:GetPos() + Vector(0, 0, 20))
                ent:Spawn()
                if not IsValid(ent) then return end
                ent:SetAmount(dropAmount)
                victim:TakeMoney(dropAmount)
                victim:Notify(NOTIFY_WARNING, string.format(Translate("MoneyDropOnDeath", "Oops... You've lost %s%s!"), BW.Config.Economy.Currency, BW.Utils.NumWithSep(dropAmount)), 5)
                
                local phys = ent:GetPhysicsObject()
                if IsValid(phys) then
                    phys:ApplyForceCenter(Vector(math.random(-200, 200), math.random(-200, 200), 300))
                end
            end
        end
    end

    -- Drop Weapon
    local distributedAmmo = {}
    local protected = {}
    for _, class in ipairs(BW.Config.PlayerLoadout) do protected[class] = true end
    for _, wep in ipairs(victim:GetWeapons()) do
        local wepClass = wep:GetClass()

        local isProtected = protected[wepClass]

        if not isProtected then
            local ammoType = wep:GetPrimaryAmmoType()
            local reserve = ammoType >= 0 and not distributedAmmo[ammoType] and victim:GetAmmoCount(ammoType) or 0
            local ammo = reserve + math.max(0, wep:Clip1())
            
            local ent = ents.Create("spawned_weapon")
            if IsValid(ent) then
                ent:SetPos(victim:GetPos() + Vector(0, 0, 20))
                ent:Spawn()
                if not IsValid(ent) then continue end
                
                ent:SetWeaponClass(wepClass)
                ent:SetAmmoCount(ammo)
                if ammoType >= 0 then
                    distributedAmmo[ammoType] = true
                    victim:RemoveAmmo(reserve, ammoType)
                end

                local phys = ent:GetPhysicsObject()
                if IsValid(phys) then
                    phys:ApplyForceCenter(Vector(math.random(-100, 100), math.random(-100, 100), 200))
                end
            end
        end
    end
end
