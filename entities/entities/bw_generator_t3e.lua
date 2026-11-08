if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_generator"
ENT.PrintName = "Generator T3-E"
ENT.ID = "generator_t3e"
ENT.Spawnable = true

ENT.Model = "models/props_combine/masterinterface.mdl"
ENT.DefaultMaxHealth = 750

ENT.EnergyCapacity = 9000
ENT.EnergyGeneration = 110
ENT.EnergyOutput = 275
ENT.PowerRadius = 820
