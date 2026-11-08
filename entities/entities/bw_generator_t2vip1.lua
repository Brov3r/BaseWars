if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_generator"
ENT.PrintName = "Generator T2 VIP 1"
ENT.ID = "generator_t2vip1"
ENT.Spawnable = true

ENT.Model = "models/props_lab/powerbox03a.mdl"
ENT.DefaultMaxHealth = 500

ENT.EnergyCapacity = 6000
ENT.EnergyGeneration = 50
ENT.EnergyOutput = 125
ENT.PowerRadius = 750
