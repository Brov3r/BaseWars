if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_base_module"
ENT.PrintName = "Shield Module"
ENT.Spawnable = false
ENT.Model = "models/props_lab/jar01b.mdl"

-- Amount is added to the device's maximum health and to its current health.
ENT.Amount = 100

function ENT:CanUseOn(device)
    return IsValid(device)
        and type(device.Health) == "function"
        and type(device.GetMaxHealth) == "function"
        and type(device.SetMaxHealth) == "function"
        and type(device.SetHealth) == "function"
end

function ENT:Apply(device)
    if not self:CanUseOn(device) then return false end

    local amount = math.max(0, tonumber(self:GetAmount()) or 0)
    if amount <= 0 then return false end

    local maxHealth = math.max(0, tonumber(device:GetMaxHealth()) or 0)
    local currentHealth = math.Clamp(tonumber(device:Health()) or 0, 0, maxHealth)
    local newMaxHealth = maxHealth + amount

    device:SetMaxHealth(newMaxHealth)
    device:SetHealth(math.Clamp(currentHealth + amount, 0, newMaxHealth))
    return true
end
