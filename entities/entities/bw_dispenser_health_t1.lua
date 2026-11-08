if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_dispenser"
ENT.PrintName = "Health Dispenser T1"
ENT.ID = "dispenser_health_t1"
ENT.Spawnable = true

ENT.Model = "models/props_combine/health_charger001.mdl"
ENT.DefaultMaxHealth = 200

ENT.EnergyCapacity = 200
ENT.EnergyRequired = 20
ENT.EnergyConsumption = 2

ENT.DispenseRadius = 150
ENT.DispenseEnergyCost = 20
ENT.DispenseAmount = 30

ENT.DispenseSound = "items/medshot4.wav"

DEFINE_BASECLASS("bw_power_dispenser")

if SERVER then
    function ENT:CanDispenseTo(ply)
        if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return false end
        return (tonumber(ply:Health()) or 0) < (tonumber(ply:GetMaxHealth()) or 100)
    end

    function ENT:DispenseTo(ply)
        local maxHealth = tonumber(ply:GetMaxHealth()) or 100
        local current = math.Clamp(tonumber(ply:Health()) or 0, 0, maxHealth)
        local restored = math.min(self:GetDispenseAmount(), maxHealth - current)
        if restored <= 0 then return false end

        ply:SetHealth(current + restored)
        return true
    end
end
