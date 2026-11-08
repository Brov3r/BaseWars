if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_generator"
ENT.PrintName = "Generator T2-A"
ENT.ID = "generator_t2a"
ENT.Spawnable = true

ENT.Model = "models/props_c17/substation_transformer01a.mdl"
ENT.DefaultMaxHealth = 400

ENT.EnergyCapacity = 3000
ENT.EnergyGeneration = 30
ENT.EnergyOutput = 75
ENT.PowerRadius = 600
