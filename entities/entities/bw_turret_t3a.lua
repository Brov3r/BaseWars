if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_turret"
ENT.PrintName = "Turret T3-A"
ENT.ID = "turret_t3a"
ENT.Spawnable = true

ENT.Model = "models/combine_turrets/combine_cannon.mdl"
ENT.DefaultMaxHealth = 600

ENT.EnergyCapacity = 800
ENT.EnergyRequired = 80
ENT.EnergyConsumption = 8

ENT.TurretRange = 1200
ENT.TurretDamage = 20
ENT.TurretFireRate = 0.25
ENT.TurretSpread = 0.015
ENT.TurretSound = "Weapon_AR2.Single"
