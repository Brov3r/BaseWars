if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "C4"
ENT.Spawnable = false
ENT.BlockPhysGun = true 
ENT.UseType = SIMPLE_USE
ENT.DetonateTime = 0

function ENT:Initialize()
    self:SetModel("models/weapons/w_c4.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    
    if SERVER then
        self:SetNWFloat("DetonateTime", self.DetonateTime)
        self:SetNWFloat("DefuseProgress", 0)
        self:SetNWFloat("DefuseDuration", 0)
        self:SetNWEntity("Defuser", nil)
    end
end

function ENT:Think()
    if SERVER then
        if CurTime() >= self.DetonateTime then
            self:Explode()
            return
        end

        if not self.LastBeep or CurTime() >= self.LastBeep + 1 then
            self:EmitSound("weapons/c4/c4_beep1.wav", 60, 100)
            self.LastBeep = CurTime()
        end

        if self.DefuseStart and self.Defuser and IsValid(self.Defuser) then
            local dist = self.Defuser:GetPos():Distance(self:GetPos())
            if not self.Defuser:Alive() or not self.Defuser:KeyDown(IN_USE) or dist > 120 then
                self:CancelDefuse()
                return
            end

            local elapsed = CurTime() - self.DefuseStart
            self:SetNWFloat("DefuseProgress", elapsed)

            if elapsed >= self.DefuseDuration then
                self:DefuseSuccess()
            end
        end
    end
end

function ENT:Use(activator, caller, type, value)
    if SERVER and type == USE_ON and activator:IsPlayer() and not self.DefuseStart then
        self:StartDefuse(activator)
    end
end

function ENT:StartDefuse(player)
    local timeLeft = self.DetonateTime - CurTime()
    self.DefuseDuration = math.min(30, math.max(2, timeLeft / 2))
    self.Defuser = player
    self.DefuseStart = CurTime()
    
    self:SetNWEntity("Defuser", player)
    self:SetNWFloat("DefuseDuration", self.DefuseDuration)
end

function ENT:CancelDefuse()
    self.Defuser = nil
    self.DefuseStart = nil
    self.DefuseDuration = nil
    
    self:SetNWEntity("Defuser", nil)
    self:SetNWFloat("DefuseProgress", 0)
    self:SetNWFloat("DefuseDuration", 0)
end

function ENT:DefuseSuccess()
    self:Remove()
end

function ENT:Explode()
    local pos = self:GetPos()
    local attacker = IsValid(self:GetOwner()) and self:GetOwner() or self

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

    util.BlastDamage(self, attacker, pos, 600, 1500)
    util.Decal("Scorch", pos + Vector(0,0,50), pos - Vector(0,0,50))
    self:EmitSound("ambient/explosions/explode_" .. math.random(1, 9) .. ".wav", 100, 100)
    self:Remove()
end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()

        local detonateTime = self:GetNWFloat("DetonateTime", 0)
        if detonateTime == 0 then return end

        local offset = Vector(1.5, -0.5, 4.3)
        local pos = self:GetPos()
            + self:GetForward() * offset.x
            + self:GetRight() * offset.y
            + self:GetUp() * offset.z

        local ang = self:GetAngles()
        ang:RotateAroundAxis(ang:Up(), -90)

        local timeLeft = math.max(0, detonateTime - CurTime())
        local text = string.format("%.1f", timeLeft)

        local progress = self:GetNWFloat("DefuseProgress", 0)
        local duration = self:GetNWFloat("DefuseDuration", 0)
        local isDefusing = duration > 0 and progress > 0

        cam.Start3D2D(pos, ang, 0.1)
            draw.SimpleText(text, "DermaDefault", 0, 0, Color(255, 0, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            if isDefusing then
                local pct = math.min(1, progress / duration)
                draw.RoundedBox(2, -25, -15, 50, 8, Color(40, 40, 40))
                draw.RoundedBox(2, -25, -15, 50 * pct, 8, Color(50, 200, 50))
            end
        cam.End3D2D()
    end
end