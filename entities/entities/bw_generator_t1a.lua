if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_generator"
ENT.PrintName = "Generator T1-A"
ENT.ID = "generator_t1a"
ENT.Spawnable = true

ENT.Model = "models/props_canal/generator01.mdl"
ENT.DefaultMaxHealth = 250

ENT.EnergyCapacity = 1000
ENT.EnergyGeneration = 10
ENT.EnergyOutput = 25
ENT.PowerRadius = 400
