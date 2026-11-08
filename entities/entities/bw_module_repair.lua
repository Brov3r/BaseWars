if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_base_module"
ENT.PrintName = "Repair Module"
ENT.Spawnable = false
ENT.Model = "models/Items/combine_rifle_ammo01.mdl"

-- Amount is the number of health points restored by the module.
ENT.Amount = 250

function ENT:CanUseOn(device)
    return IsValid(device)
        and type(device.Health) == "function"
        and type(device.GetMaxHealth) == "function"
        and type(device.SetHealth) == "function"
end

function ENT:Apply(device)
    if not self:CanUseOn(device) then return false end

    local maxHealth = tonumber(device:GetMaxHealth()) or 0
    if maxHealth <= 0 then return false end

    local currentHealth = math.Clamp(tonumber(device:Health()) or 0, 0, maxHealth)
    if currentHealth >= maxHealth then return false end

    local amount = math.max(0, tonumber(self:GetAmount()) or 0)
    if amount <= 0 then return false end

    device:SetHealth(math.Clamp(currentHealth + amount, 0, maxHealth))
    return true
end
