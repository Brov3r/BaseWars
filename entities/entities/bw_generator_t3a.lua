if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_generator"
ENT.PrintName = "Generator T3-A"
ENT.ID = "generator_t3a"
ENT.Spawnable = true

ENT.Model = "models/props_combine/combine_generator01.mdl"
ENT.DefaultMaxHealth = 600

ENT.EnergyCapacity = 8000
ENT.EnergyGeneration = 80
ENT.EnergyOutput = 200
ENT.PowerRadius = 800
