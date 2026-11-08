if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_base_module"
ENT.PrintName = "Efficiency Module"
ENT.Spawnable = false
ENT.Model = "models/items/battery.mdl"

-- 0.10 = +10% generation for generators, or -10% consumption for consumers.
ENT.Efficiency = 0.10

function ENT:GetEfficiency()
    return math.max(0, tonumber(self.Efficiency) or 0)
end

function ENT:CanUseOn(device)
    return IsValid(device)
        and (device.PowerGenerator == true or device.PowerConsumer == true)
        and type(device.AddEfficiency) == "function"
end

function ENT:Apply(device)
    if not self:CanUseOn(device) then return false end

    local efficiency = self:GetEfficiency()
    if efficiency <= 0 then return false end

    device:AddEfficiency(efficiency)
    return true
end
