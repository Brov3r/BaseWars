if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_dispenser"
ENT.PrintName = "Armor Dispenser T3"
ENT.ID = "dispenser_armor_t3"
ENT.Spawnable = true

ENT.Model = "models/props_combine/suit_charger001.mdl"
ENT.DefaultMaxHealth = 500

ENT.EnergyCapacity = 1000
ENT.EnergyRequired = 80
ENT.EnergyConsumption = 8

ENT.DispenseRadius = 250
ENT.DispenseEnergyCost = 80
ENT.DispenseAmount = 120

ENT.DispenseSound = "items/suitcharge1.wav"

DEFINE_BASECLASS("bw_power_dispenser")

if SERVER then
    function ENT:CanDispenseTo(ply)
        if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return false end
        return (tonumber(ply:Armor()) or 0) < (tonumber(ply:GetMaxArmor()) or 100)
    end

    function ENT:DispenseTo(ply)
        local maxArmor = tonumber(ply:GetMaxArmor()) or 100
        local current = math.Clamp(tonumber(ply:Armor()) or 0, 0, maxArmor)
        local restored = math.min(self:GetDispenseAmount(), maxArmor - current)
        if restored <= 0 then return false end

        ply:SetArmor(current + restored)
        return true
    end
end
