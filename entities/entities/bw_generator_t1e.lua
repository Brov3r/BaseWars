if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_generator"
ENT.PrintName = "Generator T1-E"
ENT.ID = "generator_t1e"
ENT.Spawnable = true

ENT.Model = "models/props_c17/gasmeter002a.mdl"
ENT.DefaultMaxHealth = 260

ENT.EnergyCapacity = 900
ENT.EnergyGeneration = 16
ENT.EnergyOutput = 38
ENT.PowerRadius = 400
