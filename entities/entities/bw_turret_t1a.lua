if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_turret"
ENT.PrintName = "Turret T1-A"
ENT.ID = "turret_t1a"
ENT.Spawnable = true

ENT.Model = "models/props_lab/labturret.mdl"
ENT.DefaultMaxHealth = 250

ENT.EnergyCapacity = 150
ENT.EnergyRequired = 20
ENT.EnergyConsumption = 2

ENT.TurretRange = 700
ENT.TurretDamage = 6
ENT.TurretFireRate = 0.5
ENT.TurretSpread = 0.035
ENT.TurretSound = "Weapon_SMG1.Single"
