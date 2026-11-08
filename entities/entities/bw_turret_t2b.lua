if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_turret"
ENT.PrintName = "Turret T2-B"
ENT.ID = "turret_t2b"
ENT.Spawnable = true

ENT.Model = "models/props_combine/bunker_gun01.mdl"
ENT.DefaultMaxHealth = 450

ENT.EnergyCapacity = 450
ENT.EnergyRequired = 45
ENT.EnergyConsumption = 5

ENT.TurretRange = 850
ENT.TurretDamage = 16
ENT.TurretFireRate = 0.6
ENT.TurretSpread = 0.04
ENT.TurretSound = "Weapon_Shotgun.Single"
