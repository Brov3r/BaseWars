if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_module_efficiency"
ENT.PrintName = "Efficiency Module T4"
ENT.ID = "m_efficiency_t4"
ENT.Spawnable = true

ENT.Model = "models/items/battery.mdl"
ENT.Efficiency = 0.65
