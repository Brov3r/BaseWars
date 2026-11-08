if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_consumer"
ENT.PrintName = "Power Turret"
ENT.ID = "power_turret"
ENT.Author = "Brov3r"
ENT.Spawnable = false
ENT.BlockPhysGun = false

ENT.Model = "models/props_lab/labturret.mdl"
ENT.DefaultMaxHealth = 250

ENT.PowerConsumer = true
ENT.PowerGenerator = false

ENT.TurretRange = 800
ENT.TurretDamage = 8
ENT.TurretFireRate = 0.5
ENT.TurretSpread = 0.03
ENT.TurretScanInterval = 0.2
ENT.TurretSound = "Weapon_SMG1.Single"
ENT.TurretAim = true
ENT.TurretMuzzleOffset = Vector(0, 0, 40)
ENT.TurretIgnoreSameTeam = true

DEFINE_BASECLASS("bw_power_consumer")

if SERVER then

    function ENT:Initialize()
        BaseClass.Initialize(self)

        self.NextTargetScan = 0
        self.NextShot = 0
        self.CurrentTarget = nil

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false)
            phys:Sleep()
        end
    end

    function ENT:GetTurretRange()
        return math.max(0, tonumber(self.TurretRange) or 800)
    end

    function ENT:GetTurretDamage()
        return math.max(0, tonumber(self.TurretDamage) or 8)
    end

    function ENT:GetTurretFireRate()
        return math.max(0.05, tonumber(self.TurretFireRate) or 0.5)
    end

    function ENT:GetTurretSpread()
        return math.max(0, tonumber(self.TurretSpread) or 0.03)
    end

    function ENT:GetTurretScanInterval()
        return math.max(0.05, tonumber(self.TurretScanInterval) or 0.2)
    end

    function ENT:GetMuzzlePos()
        if self.TurretMuzzleOffset and type(self.LocalToWorld) == "function" then
            return self:LocalToWorld(self.TurretMuzzleOffset)
        end
        return self:GetPos() + Vector(0, 0, 40)
    end

    function ENT:GetTargetPos(ply)
        if type(ply.WorldSpaceCenter) == "function" then
            return ply:WorldSpaceCenter()
        end
        return ply:GetPos() + Vector(0, 0, 40)
    end

    function ENT:HasLineOfSight(ply)
        local filter = {self}
        local owner = self:GetDeviceOwner()
        if IsValid(owner) then
            filter[#filter + 1] = owner
        end

        local tr = util.TraceLine({
            start = self:GetMuzzlePos(),
            endpos = self:GetTargetPos(ply),
            filter = filter,
            mask = MASK_SHOT
        })

        -- A clear line of sight means the trace did not hit anything before
        -- the target. If it hit a wall, prop, or another entity, shooting is
        -- blocked. This also covers brush hits where tr.Entity may be NULL.
        if tr.Hit then
            return tr.Entity == ply
        end

        return true
    end

    function ENT:IsValidTarget(ply)
        if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return false end

        local owner = self:GetDeviceOwner()
        if ply == owner then return false end

        local defaultTeam = (BW and BW.TEAM_DEFAULT) or 1000
        if self.TurretIgnoreSameTeam
            and IsValid(owner)
            and owner:IsPlayer()
            and owner:Team() ~= defaultTeam
            and ply:Team() == owner:Team() then
            return false
        end

        local range = self:GetTurretRange()
        if self:GetPos():DistToSqr(ply:GetPos()) > range * range then return false end

        return self:HasLineOfSight(ply)
    end

    function ENT:FindTarget()
        local best, bestDistance = nil, nil

        for _, ply in ipairs(player.GetAll()) do
            if self:IsValidTarget(ply) then
                local distance = self:GetPos():DistToSqr(ply:GetPos())
                if not best or distance < bestDistance then
                    best, bestDistance = ply, distance
                end
            end
        end

        return best
    end

    function ENT:AimAt(ply)
        if self.TurretAim == false then return end

        local direction = self:GetTargetPos(ply) - self:GetPos()
        if direction:LengthSqr() <= 0 then return end

        local yaw = direction:Angle().y
        self:SetAngles(Angle(0, yaw, 0))
    end

    function ENT:Shoot(ply)
        local src = self:GetMuzzlePos()
        local targetPos = self:GetTargetPos(ply)
        local direction = (targetPos - src):GetNormalized()
        local spread = self:GetTurretSpread()

        self:FireBullets({
            Src = src,
            Dir = direction,
            Spread = Vector(spread, spread, 0),
            Num = 1,
            Damage = self:GetTurretDamage(),
            Force = self:GetTurretDamage() * 3,
            Tracer = 1,
            TracerName = "Tracer",
            AmmoType = "SMG1",
            Attacker = self,
            Inflictor = self,
        })

        local effect = EffectData()
        effect:SetOrigin(src)
        effect:SetAngles(direction:Angle())
        effect:SetScale(1)
        util.Effect("MuzzleEffect", effect)

        self:EmitSound(self.TurretSound or "Weapon_SMG1.Single", 75, 100)
    end

    function ENT:TurretThink()
        local now = CurTime()

        if now >= (self.NextTargetScan or 0) then
            self.NextTargetScan = now + self:GetTurretScanInterval()
            self.CurrentTarget = self:FindTarget()
        end

        local target = self.CurrentTarget
        if not IsValid(target) or not self:IsValidTarget(target) then
            self.CurrentTarget = nil
            return
        end

        self:AimAt(target)

        if now < (self.NextShot or 0) then return end
        self.NextShot = now + self:GetTurretFireRate()
        self:Shoot(target)
    end

    function ENT:Think()
        BaseClass.Think(self)

        if not self:IsPowered() then
            self.CurrentTarget = nil
            return
        end

        self:TurretThink()
    end
end
