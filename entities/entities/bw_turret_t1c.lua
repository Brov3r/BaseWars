if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_turret"
ENT.PrintName = "Turret T1-C"
ENT.ID = "turret_t1c"
ENT.Spawnable = true

ENT.Model = "models/props_silo/turret.mdl"
ENT.DefaultMaxHealth = 280

ENT.EnergyCapacity = 220
ENT.EnergyRequired = 30
ENT.EnergyConsumption = 3

ENT.TurretRange = 800
ENT.TurretDamage = 5
ENT.TurretFireRate = 0.3
ENT.TurretSpread = 0.02
ENT.TurretSound = "Weapon_SMG1.Single"
