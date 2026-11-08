if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_turret"
ENT.PrintName = "Turret T2-C"
ENT.ID = "turret_t2c"
ENT.Spawnable = true

ENT.Model = "models/combine_turrets/combine_cannon_stand.mdl"
ENT.DefaultMaxHealth = 420

ENT.EnergyCapacity = 500
ENT.EnergyRequired = 50
ENT.EnergyConsumption = 5

ENT.TurretRange = 1000
ENT.TurretDamage = 8
ENT.TurretFireRate = 0.2
ENT.TurretSpread = 0.015
ENT.TurretSound = "Weapon_SMG1.Single"
