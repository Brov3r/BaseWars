if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Prop Physics"
ENT.Author = "Brov3r"
ENT.Spawnable = false

ENT.MaxHealthValue = 100
ENT.AllowedWeapon = "bw_weapon_blowtorch"
ENT.DamageChance  = 0.2
ENT.MinDamage     = 1

if SERVER then

    function ENT:Initialize()
        local mdl = self:GetModel()
    
        if not util.IsValidModel(mdl) then
            self:SetModel("models/props_junk/wood_crate001a.mdl")
        end
        
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        
        self:SetMaxHealth(self.MaxHealthValue)
        self:SetHealth(self.MaxHealthValue)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
        end
    end

    function ENT:OnTakeDamage(dmginfo)
        local currentHP = self:Health()
        if currentHP <= 0 then return end

        local damage = dmginfo:GetDamage()
        local attacker = dmginfo:GetAttacker()

        local isSpecial = false
        if IsValid(attacker) and attacker:IsPlayer() then
            local wep = attacker:GetActiveWeapon()
            if IsValid(wep) and wep:GetClass() == self.AllowedWeapon then
                isSpecial = true
            end
        end

        if not isSpecial and (dmginfo:IsDamageType(DMG_BULLET) or dmginfo:IsDamageType(DMG_CLUB)) then
            if math.random() > self.DamageChance then
                return
            end
            damage = self.MinDamage
        end

        if damage <= 0 then return end

        local newHP = math.max(0, currentHP - damage)
        self:SetHealth(newHP)

        if newHP <= 0 then
            self:Destruct(dmginfo)
        end
    end

    function ENT:Destruct(dmginfo)
        local spawnPos = self:GetPos()

        local effectSmoke = EffectData()
        effectSmoke:SetOrigin(spawnPos)
        util.Effect("Explosion", effectSmoke, true, true)

        self:GibBreakServer(dmginfo:GetDamageForce())

        self:Remove()
    end

end

if CLIENT then

    function ENT:Draw()
        self:DrawModel()
    end

end