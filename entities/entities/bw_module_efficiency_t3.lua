if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_module_efficiency"
ENT.PrintName = "Efficiency Module T3"
ENT.ID = "m_efficiency_t3"
ENT.Spawnable = true

ENT.Model = "models/items/battery.mdl"
ENT.Efficiency = 0.50
