if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_base"
ENT.PrintName = "Base Module"
ENT.Spawnable = false
ENT.AutoRefund = true

ENT.Amount = 0
ENT.DefaultMaxHealth = 0

-- Modules are used by touching a bw_base device. This contract lets every
-- module decide what it does; the device only removes a module when UseOn
-- reports that it was consumed.
ENT.IsBWModule = true

DEFINE_BASECLASS( "bw_base" )

function ENT:GetAmount()
    return self.Amount
end

function ENT:GetModuleName()
    return self:GetTranslatedName()
end

-- Override in a concrete module to limit which devices accept it.
function ENT:CanUseOn(device)
    return IsValid(device)
end

-- Override in a concrete module. Return true when the module performed its
-- effect and should be consumed.
function ENT:Apply(device)
    return false
end

-- Entry point called by bw_base:Touch.
function ENT:UseOn(device)
    if not IsValid(self) or not IsValid(device) then return false end
    if not self:CanUseOn(device) then return false end

    return self:Apply(device) == true
end

if SERVER then
    function ENT:Initialize()
        BaseClass.Initialize(self)

        self.IsBWModule = true
        self:SetModel(self.Model or "models/items/battery.mdl")

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
        end
    end
end
