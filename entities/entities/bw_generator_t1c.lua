if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_generator"
ENT.PrintName = "Generator T1-C"
ENT.ID = "generator_t1c"
ENT.Spawnable = true

ENT.Model = "models/props_c17/consolebox01a.mdl"
ENT.DefaultMaxHealth = 220

ENT.EnergyCapacity = 800
ENT.EnergyGeneration = 14
ENT.EnergyOutput = 35
ENT.PowerRadius = 350
