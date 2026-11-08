if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_dispenser"
ENT.PrintName = "Ammo Dispenser T2"
ENT.ID = "dispenser_ammo_t2"
ENT.Spawnable = true

ENT.Model = "models/props_junk/wood_crate001a.mdl"
ENT.DefaultMaxHealth = 350

ENT.EnergyCapacity = 500
ENT.EnergyRequired = 40
ENT.EnergyConsumption = 4

ENT.DispenseRadius = 200
ENT.DispenseEnergyCost = 40
ENT.DispenseAmount = 60
ENT.AmmoType = "SMG1"

ENT.DispenseSound = "items/ammo_pickup.wav"

DEFINE_BASECLASS("bw_power_dispenser")

if SERVER then
    function ENT:DispenseTo(ply)
        if type(ply.GiveAmmo) ~= "function" then return false end

        local added = ply:GiveAmmo(self:GetDispenseAmount(), self.AmmoType, true)
        if type(added) == "number" then return added > 0 end
        return true
    end
end
