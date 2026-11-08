if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_turret"
ENT.PrintName = "Turret T3 VIP"
ENT.ID = "turret_t3vip"
ENT.Spawnable = true

ENT.Model = "models/combine_turrets/ceiling_turret.mdl"
ENT.DefaultMaxHealth = 900

ENT.EnergyCapacity = 1500
ENT.EnergyRequired = 120
ENT.EnergyConsumption = 12

ENT.TurretRange = 1600
ENT.TurretDamage = 35
ENT.TurretFireRate = 0.15
ENT.TurretSpread = 0.005
ENT.TurretSound = "Weapon_AR2.Single"
