if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_generator"
ENT.PrintName = "Generator T3 VIP 1"
ENT.ID = "generator_t3vip1"
ENT.Spawnable = true

ENT.Model = "models/props_lab/hev_machine.mdl"
ENT.DefaultMaxHealth = 800

ENT.EnergyCapacity = 16000
ENT.EnergyGeneration = 130
ENT.EnergyOutput = 325
ENT.PowerRadius = 1000
