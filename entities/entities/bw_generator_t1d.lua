if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_generator"
ENT.PrintName = "Generator T1-D"
ENT.ID = "generator_t1d"
ENT.Spawnable = true

ENT.Model = "models/props_c17/gasmeter001a.mdl"
ENT.DefaultMaxHealth = 240

ENT.EnergyCapacity = 1200
ENT.EnergyGeneration = 12
ENT.EnergyOutput = 28
ENT.PowerRadius = 450
