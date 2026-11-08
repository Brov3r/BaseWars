if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_module_efficiency"
ENT.PrintName = "Efficiency Module T1"
ENT.ID = "m_efficiency_t1"
ENT.Spawnable = true

ENT.Model = "models/items/battery.mdl"
ENT.Efficiency = 0.10
