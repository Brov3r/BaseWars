if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_generator"
ENT.PrintName = "Generator T2-C"
ENT.ID = "generator_t2c"
ENT.Spawnable = true

ENT.Model = "models/props_c17/substation_transformer01c.mdl"
ENT.DefaultMaxHealth = 380

ENT.EnergyCapacity = 2500
ENT.EnergyGeneration = 40
ENT.EnergyOutput = 100
ENT.PowerRadius = 550
