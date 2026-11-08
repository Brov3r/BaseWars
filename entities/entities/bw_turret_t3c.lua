if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_turret"
ENT.PrintName = "Turret T3-C"
ENT.ID = "turret_t3c"
ENT.Spawnable = true

ENT.Model = "models/props_silo/turret.mdl"
ENT.DefaultMaxHealth = 650

ENT.EnergyCapacity = 1000
ENT.EnergyRequired = 100
ENT.EnergyConsumption = 10

ENT.TurretRange = 1400
ENT.TurretDamage = 14
ENT.TurretFireRate = 0.12
ENT.TurretSpread = 0.008
ENT.TurretSound = "Weapon_SMG1.Single"
