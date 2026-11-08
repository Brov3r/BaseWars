if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_generator"
ENT.PrintName = "Generator T2 VIP 2"
ENT.ID = "generator_t2vip2"
ENT.Spawnable = true

ENT.Model = "models/props_lab/generatorconsole.mdl"
ENT.DefaultMaxHealth = 550

ENT.EnergyCapacity = 7500
ENT.EnergyGeneration = 60
ENT.EnergyOutput = 150
ENT.PowerRadius = 800
