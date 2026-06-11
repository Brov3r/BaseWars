AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
AddCSLuaFile("include.lua")

include("shared.lua")
include("include.lua")

function GM:GetFallDamage(ply, speed)
    return math.max( 0, math.ceil( 0.2418 * speed - 141.75 ) )
end

function GM:PlayerSpawn(ply)
    self.BaseClass.PlayerSpawn(self, ply)
    ply:SetWalkSpeed(BW.Config.Motion.WalkSpeed)
    ply:SetRunSpeed(BW.Config.Motion.RunSpeed)
    ply:SetJumpPower(BW.Config.Motion.JumpPower)  
end

function GM:PlayerLoadout( ply )
	for _, class in ipairs(BW.Config.PlayerLoadout) do
        if not ply:HasWeapon(class) then
            ply:Give(class)
        end
    end

    timer.Simple(0.1, function()
        if IsValid(ply) then
            ply:SelectWeapon("hands")
        end
    end)
    
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
        
        local dropAmount = math.floor((money - safeMoney) * multiplier)
        
        if dropAmount > 0 then
            victim:TakeMoney(dropAmount)
            victim:Notify(NOTIFY_WARNING, string.format(Translate("MoneyDropOnDeath", "Oops... You've lost %s%s!"), BW.Config.Economy.Currency, dropAmount), 5)
            local ent = ents.Create("spawned_money")
            if IsValid(ent) then
                ent:SetPos(victim:GetPos() + Vector(0, 0, 20))
                ent:Spawn()
                ent:SetAmount(dropAmount)
                
                local phys = ent:GetPhysicsObject()
                if IsValid(phys) then
                    phys:ApplyForceCenter(Vector(math.random(-200, 200), math.random(-200, 200), 300))
                end
            end
        end
    end

    -- Drop Weapon
    for _, wep in ipairs(victim:GetWeapons()) do
        local wepClass = wep:GetClass()

        local isProtected = false
        for _, class in ipairs(BW.Config.PlayerLoadout) do
            if class == wepClass then
                isProtected = true
                break
            end
        end

        if not isProtected then
            local ammo = victim:GetAmmoCount(wep:GetPrimaryAmmoType()) + wep:Clip1()
            
            local ent = ents.Create("spawned_weapon")
            if IsValid(ent) then
                ent:SetPos(victim:GetPos() + Vector(0, 0, 20))
                ent:Spawn()
                
                ent:SetWeaponClass(wepClass)
                ent:SetAmmoCount(ammo)

                local phys = ent:GetPhysicsObject()
                if IsValid(phys) then
                    phys:ApplyForceCenter(Vector(math.random(-100, 100), math.random(-100, 100), 200))
                end
            end
        end
    end
end

function GM:SetupMove(ply, mv, cmd)
    self.BaseClass:SetupMove(ply, mv, cmd)
    
    if BW.Config.Motion.EnableBHop and ply:IsOnGround() and cmd:KeyDown(IN_JUMP) then
        local vel = ply:GetVelocity()
        local jumpPower = BW.Config.Motion.JumpPower or 200

        mv:SetVelocity(Vector(vel.x, vel.y, jumpPower))
        ply:SetGroundEntity(NULL)
        cmd:RemoveKey(IN_JUMP)
    end
end