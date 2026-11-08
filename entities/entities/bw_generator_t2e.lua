if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_generator"
ENT.PrintName = "Generator T2-E"
ENT.ID = "generator_t2e"
ENT.Spawnable = true

ENT.Model = "models/props_c17/substation_transformer01e.mdl"
ENT.DefaultMaxHealth = 430

ENT.EnergyCapacity = 4000
ENT.EnergyGeneration = 32
ENT.EnergyOutput = 80
ENT.PowerRadius = 680
