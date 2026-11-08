if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_dispenser"
ENT.PrintName = "Ammo Dispenser T1"
ENT.ID = "dispenser_ammo_t1"
ENT.Spawnable = true

ENT.Model = "models/props_junk/wood_crate001a.mdl"
ENT.DefaultMaxHealth = 200

ENT.EnergyCapacity = 200
ENT.EnergyRequired = 20
ENT.EnergyConsumption = 2

ENT.DispenseRadius = 150
ENT.DispenseEnergyCost = 20
ENT.DispenseAmount = 30
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
