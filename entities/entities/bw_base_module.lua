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

DEFINE_BASECLASS( "bw_base" )

function ENT:GetAmount()
    return self.Amount
end

if SERVER then
    function ENT:Initialize()
        BaseClass.Initialize(self)

        self:SetModel(self.Model or "models/items/battery.mdl")

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
        end
    end
end