if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_turret"
ENT.PrintName = "Turret T1 VIP"
ENT.ID = "turret_t1vip"
ENT.Spawnable = true

ENT.Model = "models/combine_turrets/ceiling_turret.mdl"
ENT.DefaultMaxHealth = 350

ENT.EnergyCapacity = 300
ENT.EnergyRequired = 35
ENT.EnergyConsumption = 3.5

ENT.TurretRange = 900
ENT.TurretDamage = 10
ENT.TurretFireRate = 0.3
ENT.TurretSpread = 0.015
ENT.TurretSound = "Weapon_AR2.Single"
