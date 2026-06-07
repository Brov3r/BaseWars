AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_entity"
ENT.PrintName = "Weapon Case"
ENT.Author = "Brov3r"
ENT.Spawnable = false
ENT.CanPhysGun = false

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "WeaponClass")
    self:NetworkVar("Int", 0, "AmmoCount")
end

if SERVER then
    function ENT:Initialize()
        self:SetModel("models/weapons/w_suitcase_passenger.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)
        self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
        
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
        end
    end

    function ENT:Use(activator)
        if IsValid(activator) and activator:IsPlayer() then
            local wepClass = self:GetWeaponClass()
            local ammo = self:GetAmmoCount()

            if not activator:HasWeapon(wepClass) then
                activator:Give(wepClass)
            end

            if ammo > 0 then
                activator:GiveAmmo(ammo, activator:GetWeapon(wepClass):GetPrimaryAmmoType())
            end
            
            self:Remove()
        end
    end
end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
        
        local pos = self:GetPos() + Vector(0, 0, 15)
        local ang = EyeAngles()
        ang:RotateAroundAxis(ang:Up(), 90)
        ang:RotateAroundAxis(ang:Right(), 90)
    end
end