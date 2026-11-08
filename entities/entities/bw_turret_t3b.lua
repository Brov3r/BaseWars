if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_turret"
ENT.PrintName = "Turret T3-B"
ENT.ID = "turret_t3b"
ENT.Spawnable = true

ENT.Model = "models/combine_turrets/ground_turret.mdl"
ENT.DefaultMaxHealth = 700

ENT.EnergyCapacity = 900
ENT.EnergyRequired = 90
ENT.EnergyConsumption = 9

ENT.TurretRange = 1100
ENT.TurretDamage = 30
ENT.TurretFireRate = 0.55
ENT.TurretSpread = 0.035
ENT.TurretSound = "Weapon_Shotgun.Single"
