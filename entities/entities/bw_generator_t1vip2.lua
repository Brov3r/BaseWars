if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_generator"
ENT.PrintName = "Generator T1 VIP 2"
ENT.ID = "generator_t1vip2"
ENT.Spawnable = true

ENT.Model = "models/props_lab/powerbox02a.mdl"
ENT.DefaultMaxHealth = 400

ENT.EnergyCapacity = 2200
ENT.EnergyGeneration = 20
ENT.EnergyOutput = 50
ENT.PowerRadius = 550
