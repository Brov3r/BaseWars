if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_turret"
ENT.PrintName = "Turret T2 VIP"
ENT.ID = "turret_t2vip"
ENT.Spawnable = true

ENT.Model = "models/combine_turrets/combine_cannon.mdl"
ENT.DefaultMaxHealth = 550

ENT.EnergyCapacity = 700
ENT.EnergyRequired = 60
ENT.EnergyConsumption = 6

ENT.TurretRange = 1200
ENT.TurretDamage = 18
ENT.TurretFireRate = 0.25
ENT.TurretSpread = 0.01
ENT.TurretSound = "Weapon_AR2.Single"
