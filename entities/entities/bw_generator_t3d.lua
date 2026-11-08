if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_generator"
ENT.PrintName = "Generator T3-D"
ENT.ID = "generator_t3d"
ENT.Spawnable = true

ENT.Model = "models/props_wasteland/powertower01.mdl"
ENT.DefaultMaxHealth = 650

ENT.EnergyCapacity = 10000
ENT.EnergyGeneration = 90
ENT.EnergyOutput = 220
ENT.PowerRadius = 850
