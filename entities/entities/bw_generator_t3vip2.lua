if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_generator"
ENT.PrintName = "Generator T3 VIP 2"
ENT.ID = "generator_t3vip2"
ENT.Spawnable = true

ENT.Model = "models/props_citizen_tech/steamengine001a.mdl"
ENT.DefaultMaxHealth = 900

ENT.EnergyCapacity = 20000
ENT.EnergyGeneration = 160
ENT.EnergyOutput = 400
ENT.PowerRadius = 1100
