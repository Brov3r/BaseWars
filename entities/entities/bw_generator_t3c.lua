if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_generator"
ENT.PrintName = "Generator T3-C"
ENT.ID = "generator_t3c"
ENT.Spawnable = true

ENT.Model = "models/props_lab/generator.mdl"
ENT.DefaultMaxHealth = 550

ENT.EnergyCapacity = 7000
ENT.EnergyGeneration = 100
ENT.EnergyOutput = 250
ENT.PowerRadius = 750
