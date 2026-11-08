if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_turret"
ENT.PrintName = "Turret T2-A"
ENT.ID = "turret_t2a"
ENT.Spawnable = true

ENT.Model = "models/combine_turrets/ground_turret.mdl"
ENT.DefaultMaxHealth = 400

ENT.EnergyCapacity = 400
ENT.EnergyRequired = 40
ENT.EnergyConsumption = 4

ENT.TurretRange = 900
ENT.TurretDamage = 10
ENT.TurretFireRate = 0.35
ENT.TurretSpread = 0.025
ENT.TurretSound = "Weapon_AR2.Single"
