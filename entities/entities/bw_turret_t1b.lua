if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_turret"
ENT.PrintName = "Turret T1-B"
ENT.ID = "turret_t1b"
ENT.Spawnable = true

ENT.Model = "models/combine_turrets/floor_turret.mdl"
ENT.DefaultMaxHealth = 300

ENT.EnergyCapacity = 180
ENT.EnergyRequired = 25
ENT.EnergyConsumption = 2.5

ENT.TurretRange = 650
ENT.TurretDamage = 9
ENT.TurretFireRate = 0.7
ENT.TurretSpread = 0.05
ENT.TurretSound = "Weapon_Shotgun.Single"
