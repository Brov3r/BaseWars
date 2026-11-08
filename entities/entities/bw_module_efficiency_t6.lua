if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_module_efficiency"
ENT.PrintName = "Efficiency Module T6"
ENT.ID = "m_efficiency_t6"
ENT.Spawnable = true

ENT.Model = "models/items/battery.mdl"
ENT.Efficiency = 0.90
