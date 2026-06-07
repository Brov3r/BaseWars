AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_entity"
ENT.PrintName = "Money"
ENT.Author = "Brov3r"
ENT.Spawnable = false
ENT.BlockPhysGun = true 

if SERVER then
    function ENT:Initialize()
        self:SetModel("models/props/cs_assault/money.mdl")
        
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)
        self:SetCollisionGroup(COLLISION_GROUP_WEAPON)

        local mins, maxs = self:GetModelBounds()
        
        maxs.z = maxs.z * 5.5
        mins.z = mins.z * 5.5
		
        self:PhysicsInitBox(mins, maxs)
        
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
            phys:EnableMotion(true)
        end
    end

    function ENT:SetupDataTables()
        self:NetworkVar("Int", 0, "Amount")
    end

    function ENT:Use(activator)
        if IsValid(activator) and activator:IsPlayer() then
            if activator.AddMoney then
                activator:AddMoney(self:GetAmount())
            end
            
            activator:Notify(NOTIFY_SUCCESS, string.format(Translate("Entity.Money", "You have picked up %s%s"), BW.Config.Economy.Currency, self:GetAmount()), 5)
            self:Remove()
        end
    end
else

    function ENT:Initialize()
        self:SetColor(Color(76, 175, 80, 255))
    
        local mat = Matrix()
        mat:Scale(Vector(1, 1, 5.5)) -- Вот здесь можно менять оси отдельно
        self:EnableMatrix("RenderMultiply", mat)
    end
    function ENT:Draw()
        self:DrawModel() 
    end
end