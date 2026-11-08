if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_base_module"
ENT.PrintName = "Capacity Module"
ENT.Spawnable = false
ENT.Model = "models/items/battery.mdl"

-- Amount is the extra energy storage added to a generator or consumer.
ENT.Amount = 250

function ENT:CanUseOn(device)
    return IsValid(device)
        and (device.PowerGenerator == true or device.PowerConsumer == true)
        and type(device.AddEnergyCapacity) == "function"
end

function ENT:Apply(device)
    if not self:CanUseOn(device) then return false end

    local amount = math.max(0, tonumber(self:GetAmount()) or 0)
    if amount <= 0 then return false end

    device:AddEnergyCapacity(amount)
    return true
end
