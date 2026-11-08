if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_generator"
ENT.PrintName = "Generator T2-D"
ENT.ID = "generator_t2d"
ENT.Spawnable = true

ENT.Model = "models/props_c17/substation_transformer01d.mdl"
ENT.DefaultMaxHealth = 420

ENT.EnergyCapacity = 3500
ENT.EnergyGeneration = 35
ENT.EnergyOutput = 88
ENT.PowerRadius = 650
