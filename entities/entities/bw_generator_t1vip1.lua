if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_generator"
ENT.PrintName = "Generator T1 VIP 1"
ENT.ID = "generator_t1vip1"
ENT.Spawnable = true

ENT.Model = "models/props_lab/powerbox01a.mdl"
ENT.DefaultMaxHealth = 350

ENT.EnergyCapacity = 1800
ENT.EnergyGeneration = 16
ENT.EnergyOutput = 40
ENT.PowerRadius = 500
