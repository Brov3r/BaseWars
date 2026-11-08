if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_generator"
ENT.PrintName = "Generator T2-B"
ENT.ID = "generator_t2b"
ENT.Spawnable = true

ENT.Model = "models/props_c17/substation_transformer01b.mdl"
ENT.DefaultMaxHealth = 450

ENT.EnergyCapacity = 4500
ENT.EnergyGeneration = 25
ENT.EnergyOutput = 60
ENT.PowerRadius = 700
