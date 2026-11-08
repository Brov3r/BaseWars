if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_consumer"
ENT.PrintName = "Power Dispenser"
ENT.ID = "power_dispenser"
ENT.Author = "Brov3r"
ENT.Spawnable = false
ENT.BlockPhysGun = false

ENT.Model = "models/items/battery.mdl"
ENT.DefaultMaxHealth = 200

-- Concrete dispensers override the effect and the numeric tier values.
ENT.DispenseRadius = 150
ENT.DispenseEnergyCost = 20
ENT.DispenseAmount = 30
ENT.DispenseSound = "buttons/button15.wav"
ENT.UseCooldown = 3

DEFINE_BASECLASS("bw_power_consumer")

if SERVER then

    function ENT:Initialize()
        BaseClass.Initialize(self)
        self.NextDispenseUse = 0
    end

    function ENT:GetDispenseRadius()
        return math.max(0, tonumber(self.DispenseRadius) or 150)
    end

    function ENT:GetDispenseEnergyCost()
        return math.max(0, tonumber(self.DispenseEnergyCost) or 20)
    end

    function ENT:GetDispenseAmount()
        return math.max(0, tonumber(self.DispenseAmount) or 30)
    end

    function ENT:GetDispenseSound()
        return self.DispenseSound
    end

    function ENT:PlayDispenseSound()
        local sound = self:GetDispenseSound()
        if isstring(sound) and sound ~= "" then
            self:EmitSound(sound, 65, 100)
        end
    end

    function ENT:GetUseCooldown()
        return math.max(0.1, tonumber(self.UseCooldown) or 3)
    end

    function ENT:CanDispenseTo(ply)
        return IsValid(ply) and ply:IsPlayer() and ply:Alive()
    end

    -- Override in concrete dispensers. Return true when something was given.
    function ENT:DispenseTo(ply)
        return false
    end

    function ENT:GetDispenseTargets()
        local origin = self:GetPos()
        local radiusSqr = self:GetDispenseRadius() ^ 2
        local result = {}

        for _, ply in ipairs(player.GetAll()) do
            if self:CanDispenseTo(ply) and origin:DistToSqr(ply:GetPos()) <= radiusSqr then
                result[#result + 1] = ply
            end
        end

        return result
    end

    function ENT:Dispense()
        local cost = self:GetDispenseEnergyCost()
        if self:GetStoredEnergy() < cost then return 0 end

        local given = 0
        for _, ply in ipairs(self:GetDispenseTargets()) do
            if self:DispenseTo(ply) then
                given = given + 1
            end
        end

        if given > 0 then
            self:ConsumeEnergy(cost)
            self:PlayDispenseSound()
        end

        return given
    end

    function ENT:Use(activator)
        if not IsValid(activator) or not activator:IsPlayer() or not activator:Alive() then return end

        local now = CurTime()
        if now < (self.NextDispenseUse or 0) then return end
        self.NextDispenseUse = now + self:GetUseCooldown()

        if not self:IsPowered() then
            if type(activator.Notify) == "function" then
                activator:Notify(
                    NOTIFY_WARNING,
                    Translate("Power.ConsumerNoPower", "This device has not enough energy to work."),
                    5
                )
            end
            return
        end

        self:Dispense()
    end

    function ENT:OnRemove()
        if type(BaseClass.OnRemove) == "function" then
            BaseClass.OnRemove(self)
        end
    end
end
