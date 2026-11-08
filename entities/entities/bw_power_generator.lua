if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_base"
ENT.PrintName = "Power Generator"
ENT.ID = "power_generator"
ENT.Author = "Brov3r"
ENT.Spawnable = false
ENT.BlockPhysGun = false

ENT.Model = "models/props_c17/consolebox01a.mdl"
ENT.DefaultMaxHealth = 300

ENT.PowerGenerator = true
ENT.PowerConsumer = false

-- All numeric tuning is read from BW.Config.Power.Generator. Individual
-- generators may override a field directly on the entity if needed.

DEFINE_BASECLASS("bw_base")

local Power = BW.Power

if SERVER then

    function ENT:Initialize()
        BaseClass.Initialize(self)

        self.PowerGenerator = true
        self.PowerConsumer = false
        self.IsPowerGenerator = true

        self.Energy = math.Clamp(tonumber(self.Energy) or 0, 0, self:GetEnergyCapacity())
        self.ConnectedConsumers = 0
        self.LastPowerTick = CurTime()
        self.NextPowerTick = CurTime()

        self:SetUseType(SIMPLE_USE)
        self:UpdatePowerNetwork()
    end

    function ENT:GetBaseEnergyCapacity()
        return Power.GetValue(self, "EnergyCapacity", "Generator", "EnergyCapacity", 5000, 0)
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

    function ENT:GetBaseEnergyGeneration()
        return Power.GetValue(self, "EnergyGeneration", "Generator", "EnergyGeneration", 50, 0)
    end

    function ENT:GetEfficiency()
        return math.Clamp(tonumber(self.EfficiencyBonus) or 0, 0, 10)
    end

    function ENT:GetEnergyGeneration()
        return self:GetBaseEnergyGeneration() * (1 + self:GetEfficiency())
    end

    function ENT:AddEfficiency(amount)
        amount = math.max(0, tonumber(amount) or 0)
        if amount <= 0 then return self:GetEfficiency() end

        self.EfficiencyBonus = self:GetEfficiency() + amount
        return self:GetEfficiency()
    end

    function ENT:GetEnergyOutput()
        return Power.GetValue(self, "EnergyOutput", "Generator", "EnergyOutput", 100, 0)
    end

    function ENT:GetPowerRadius()
        return Power.GetValue(self, "PowerRadius", "Generator", "Radius", 512, 0)
    end

    function ENT:SetPowerRadius(radius)
        self.PowerRadius = math.max(0, tonumber(radius) or 0)
        self:UpdatePowerNetwork()
    end

    function ENT:GetEnergy()
        local capacity = self:GetEnergyCapacity()
        return math.Clamp(tonumber(self.Energy) or 0, 0, capacity)
    end

    function ENT:SetEnergy(value)
        local capacity = self:GetEnergyCapacity()
        self.Energy = math.Clamp(tonumber(value) or 0, 0, capacity)
        self:UpdatePowerNetwork()
        return self.Energy
    end

    function ENT:UpdatePowerNetwork()
        self:SetNWFloat("BW_PowerStored", self:GetEnergy())
        self:SetNWFloat("BW_PowerCapacity", self:GetEnergyCapacity())
        self:SetNWFloat("BW_PowerRadius", self:GetPowerRadius())
        self:SetNWInt("BW_PowerConsumers", self.ConnectedConsumers or 0)
    end

    function ENT:DistributePower(dt)
        dt = math.max(0, tonumber(dt) or 0)
        if dt <= 0 then return 0 end

        local stored = self:GetEnergy()
        if stored <= 0 then
            self.ConnectedConsumers = 0
            self:SetNWInt("BW_PowerConsumers", 0)
            return 0
        end

        local outputRate = self:GetEnergyOutput()
        if outputRate <= 0 then return 0 end

        local budget = math.min(stored, outputRate * dt)
        if budget <= 0 then return 0 end

        local candidates = Power.GetConsumersInRadius(self:GetPos(), self:GetPowerRadius())
        local connected = {}
        for _, consumer in ipairs(candidates) do
            if Power.CanConnect(self, consumer) and type(consumer.ReceiveEnergy) == "function" then
                connected[#connected + 1] = consumer
            end
        end

        self.ConnectedConsumers = #connected

        local spent = 0
        local remaining = budget
        local active = connected
        local passes = 0

        -- Distribute evenly instead of filling the first consumer. Consumers
        -- that reach capacity are dropped and their share is redistributed.
        while remaining > 0 and #active > 0 and passes < 4 do
            local share = remaining / #active
            local nextActive = {}
            local moved = false

            for _, consumer in ipairs(active) do
                local capacity = tonumber(consumer:GetEnergyCapacity()) or 0
                local consumerStored = tonumber(consumer:GetStoredEnergy()) or 0
                local missing = math.max(0, capacity - consumerStored)

                if missing > 0 and remaining > 0 then
                    local accepted = consumer:ReceiveEnergy(math.min(share, missing, remaining), self)
                    accepted = math.Clamp(tonumber(accepted) or 0, 0, math.min(share, missing, remaining))

                    if accepted > 0 then
                        remaining = remaining - accepted
                        spent = spent + accepted
                        moved = true
                    end

                    local newMissing = capacity - (tonumber(consumer:GetStoredEnergy()) or 0)
                    if newMissing > 0 and remaining > 0 then
                        nextActive[#nextActive + 1] = consumer
                    end
                end
            end

            active = nextActive
            passes = passes + 1
            if not moved then break end
        end

        if spent > 0 then
            self:SetEnergy(stored - spent)
        else
            self:UpdatePowerNetwork()
        end

        return spent
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

        local generated = self:GetEnergyGeneration() * dt
        if generated > 0 then
            self:SetEnergy(self:GetEnergy() + generated)
        end

        self:DistributePower(dt)
    end

    function ENT:OnRemove()
        if type(BaseClass.OnRemove) == "function" then
            BaseClass.OnRemove(self)
        end
    end
end
