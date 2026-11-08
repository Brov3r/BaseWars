if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_generator"
ENT.PrintName = "Generator T3-B"
ENT.ID = "generator_t3b"
ENT.Spawnable = true

ENT.Model = "models/props_vehicles/generatortrailer01.mdl"
ENT.DefaultMaxHealth = 700

ENT.EnergyCapacity = 12000
ENT.EnergyGeneration = 65
ENT.EnergyOutput = 160
ENT.PowerRadius = 950
