if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Planted C4"
ENT.Spawnable = false
ENT.BlockPhysGun = true 
ENT.DetonateTime = 0

function ENT:Initialize()
    self:SetModel("models/weapons/w_c4.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    
    if SERVER then
        self:SetNWFloat("DetonateTime", self.DetonateTime)
    end
end

function ENT:Think()
    if SERVER and CurTime() >= self.DetonateTime then
        self:Explode()
    end
    
    if CurTime() % 1 < 0.1 then
        self:EmitSound("weapons/c4/c4_beep1.wav", 60, 100)
    end
end

function ENT:Explode()
    local pos = self:GetPos()

    local explosion = EffectData()
    explosion:SetOrigin(pos)
    explosion:SetScale(100)
    util.Effect("Explosion", explosion)

    local smoke = EffectData()
    smoke:SetOrigin(pos)
    smoke:SetScale(50)
    util.Effect("HelicopterMegaBomb", smoke)

    local sparks = EffectData()
    sparks:SetOrigin(pos)
    sparks:SetMagnitude(20)
    sparks:SetScale(20)
    util.Effect("Sparks", sparks)

    local shaker = ents.Create("env_shake")
    shaker:SetPos(pos)
    shaker:SetKeyValue("amplitude", "500")
    shaker:SetKeyValue("radius", "4000")
    shaker:SetKeyValue("duration", "4")
    shaker:SetKeyValue("frequency", "255")
    shaker:Spawn()
    shaker:Activate()
    shaker:Fire("StartShake")
    shaker:Fire("Kill", "", 4)


    local attacker = IsValid(self:GetOwner()) and self:GetOwner() or self
    util.BlastDamage(self, attacker, pos, 600, 5000)

    util.Decal("Scorch", pos + Vector(0,0,50), pos - Vector(0,0,50))

    self:EmitSound("ambient/explosions/explode_" .. math.random(1, 9) .. ".wav", 100, 100)

    self:Remove()
end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()

        local detonateTime = self:GetNWFloat("DetonateTime", 0)
        
        if detonateTime == 0 then return end

        local pos = self:GetPos() + self:GetUp() * 4.08 + Vector(-0.5, 0, 1.5)
        local ang = self:GetAngles()
        
        ang:RotateAroundAxis(ang:Up(), -90)

        local timeLeft = math.max(0, detonateTime - CurTime())
        local text = string.format("%.1f", timeLeft)

        cam.Start3D2D(pos, ang, 0.1)
            draw.RoundedBox(0, -25, -10, 50, 20, Color(0, 0, 0, 200))
            draw.SimpleText(text, "DermaDefault", 0, 0, Color(255, 0, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        cam.End3D2D()
    end
end