if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_base"
ENT.PrintName = "Power Consumer"
ENT.ID = "power_consumer"
ENT.Author = "Brov3r"
ENT.Spawnable = false
ENT.BlockPhysGun = false

ENT.Model = "models/items/battery.mdl"
ENT.DefaultMaxHealth = 150

ENT.PowerConsumer = true
ENT.PowerGenerator = false

-- Defaults live in BW.Config.Power.Consumer. A concrete consumer can override
-- EnergyCapacity / EnergyRequired / EnergyConsumption directly on its ENT table.

DEFINE_BASECLASS("bw_base")

local Power = BW.Power

if SERVER then

    function ENT:Initialize()
        BaseClass.Initialize(self)

        self.PowerConsumer = true
        self.PowerGenerator = false
        self.IsPowerConsumer = true

        self.StoredEnergy = math.Clamp(tonumber(self.StoredEnergy) or 0, 0, self:GetEnergyCapacity())
        self.Powered = false
        self.LastPowerTick = CurTime()
        self.NextPowerTick = CurTime()

        self:SetUseType(SIMPLE_USE)
        self:UpdatePowerNetwork()
        self:SetNWBool("BW_Powered", false)

        Power.RegisterConsumer(self)
        self:SetPowered(false)
    end

    function ENT:GetBaseEnergyCapacity()
        return Power.GetValue(self, "EnergyCapacity", "Consumer", "EnergyCapacity", 100, 0)
    end

    function ENT:GetEnergyCapacity()
        local bonus = math.max(0, tonumber(self.EnergyCapacityBonus) or 0)
        return self:GetBaseEnergyCapacity() + bonus
    end

    function ENT:AddEnergyCapacity(amount)
        amount = math.max(0, tonumber(amount) or 0)
        if amount <= 0 then return self:GetEnergyCapacity() end

        self.EnergyCapacityBonus = math.max(0, tonumber(self.EnergyCapacityBonus) or 0) + amount
        self:UpdatePowerNetwork()
        return self:GetEnergyCapacity()
    end

    function ENT:GetRequiredEnergy()
        return Power.GetValue(self, "EnergyRequired", "Consumer", "EnergyRequired", 10, 0)
    end

    function ENT:GetBaseEnergyConsumption()
        return Power.GetValue(self, "EnergyConsumption", "Consumer", "EnergyConsumption", 2, 0)
    end

    function ENT:GetEfficiency()
        return math.Clamp(tonumber(self.EfficiencyBonus) or 0, 0, 0.95)
    end

    function ENT:GetEnergyConsumption()
        return self:GetBaseEnergyConsumption() * (1 - self:GetEfficiency())
    end

    function ENT:AddEfficiency(amount)
        amount = math.max(0, tonumber(amount) or 0)
        if amount <= 0 then return self:GetEfficiency() end

        self.EfficiencyBonus = math.min(0.95, self:GetEfficiency() + amount)
        return self:GetEfficiency()
    end

    function ENT:GetStoredEnergy()
        local stored
        if SERVER then
            stored = self.StoredEnergy
        else
            stored = self:GetNWFloat("BW_PowerStored", 0)
        end

        return Power.ClampNumber(stored, 0, self:GetEnergyCapacity(), 0)
    end

    function ENT:SetStoredEnergy(value)
        if not SERVER then return end

        self.StoredEnergy = Power.ClampNumber(value, 0, self:GetEnergyCapacity(), 0)
        self:UpdatePowerNetwork()
    end

    function ENT:GetPowerDemand()
        return math.max(0, self:GetEnergyCapacity() - self:GetStoredEnergy())
    end

    function ENT:UpdatePowerNetwork()
        if not SERVER then return end

        self:SetNWFloat("BW_PowerStored", self:GetStoredEnergy())
        self:SetNWFloat("BW_PowerCapacity", self:GetEnergyCapacity())
        self:SetNWFloat("BW_PowerRequired", self:GetRequiredEnergy())
        self:SetNWFloat("BW_PowerConsumption", self:GetEnergyConsumption())
    end

    function ENT:IsPowered()
        return self.Powered == true
    end

    function ENT:SetPowered(state)
        state = state == true
        if self.Powered == state then return end

        self.Powered = state
        if SERVER then
            self:SetNWBool("BW_Powered", state)
        end

        if type(self.OnPowerChanged) == "function" then
            self:OnPowerChanged(state)
        end
    end

    function ENT:ReceiveEnergy(amount, generator)
        amount = Power.ClampNumber(amount, 0, nil, 0)
        if amount <= 0 then return 0 end

        local stored = self:GetStoredEnergy()
        local accepted = math.min(amount, self:GetEnergyCapacity() - stored)
        if accepted <= 0 then return 0 end

        self:SetStoredEnergy(stored + accepted)
        return accepted
    end

    function ENT:ConsumeEnergy(amount)
        amount = Power.ClampNumber(amount, 0, nil, 0)
        if amount <= 0 then return 0 end

        local stored = self:GetStoredEnergy()
        local used = math.min(stored, amount)
        if used > 0 then
            self:SetStoredEnergy(stored - used)
        end
        return used
    end

    function ENT:Think()
        if CLIENT then return end

        local now = CurTime()
        if now < (self.NextPowerTick or 0) then return end

        local dt = now - (self.LastPowerTick or now)
        self.LastPowerTick = now
        self.NextPowerTick = now + Power.GetTickRate(self)

        if dt <= 0 then return end
        dt = math.min(dt, 1)

        local stored = self:GetStoredEnergy()
        local required = self:GetRequiredEnergy()
        local consumption = self:GetEnergyConsumption()
        local powered = self.Powered == true

        if powered then
            if consumption > 0 then
                stored = math.max(0, stored - consumption * dt)
            end

            if stored <= 0 then
                powered = false
            end
        elseif stored >= required then
            powered = true
        end

        self:SetStoredEnergy(stored)
        self:SetPowered(powered)

        if powered and type(self.OnPoweredTick) == "function" then
            self:OnPoweredTick(dt)
        end
    end

    function ENT:Use(activator)
        if not IsValid(activator) or not activator:IsPlayer() or type(activator.Notify) ~= "function" then return end

        local text
        if self:IsPowered() then
            text = string.format(
                Translate("Power.ConsumerOnline", "Online. Energy: %s / %s."),
                Power.FormatEnergy(self:GetStoredEnergy()),
                Power.FormatEnergy(self:GetEnergyCapacity())
            )
            activator:Notify(NOTIFY_SUCCESS, text, 5)
        else
            text = string.format(
                Translate("Power.ConsumerOffline", "No power. Requires at least %s energy."),
                Power.FormatEnergy(self:GetRequiredEnergy())
            )
            activator:Notify(NOTIFY_WARNING, text, 5)
        end
    end

    function ENT:OnRemove()
        Power.UnregisterConsumer(self)

        if self.Powered then
            self:SetPowered(false)
        end

        if type(BaseClass.OnRemove) == "function" then
            BaseClass.OnRemove(self)
        end
    end
end
