if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_generator"
ENT.PrintName = "Generator T1-B"
ENT.ID = "generator_t1b"
ENT.Spawnable = true

ENT.Model = "models/props_canal/generator02.mdl"
ENT.DefaultMaxHealth = 300

ENT.EnergyCapacity = 1500
ENT.EnergyGeneration = 8
ENT.EnergyOutput = 20
ENT.PowerRadius = 500
