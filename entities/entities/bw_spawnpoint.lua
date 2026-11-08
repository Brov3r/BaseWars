if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "bw_power_consumer"
ENT.PrintName = "Spawn Point"
ENT.ID = "spawnpoint"
ENT.Spawnable = true
ENT.BlockPhysGun = true 

ENT.DefaultMaxHealth = 200
ENT.EnergyCapacity = 100
ENT.EnergyRequired = 10
ENT.EnergyConsumption = 1

DEFINE_BASECLASS("bw_power_consumer")

if SERVER then

    function ENT:Initialize()
        self:SetModel("models/props_trainstation/trainstation_clock001.mdl")
        BaseClass.Initialize(self)
        
        self:SetUseType(SIMPLE_USE)
        
        timer.Simple(0, function()
            if not IsValid(self) then return end

            local owner = self:GetDeviceOwner()
            local startPos = IsValid(owner) and owner:GetPos() or self:GetPos()

            local tr = util.TraceLine({
                start = startPos + Vector(0, 0, 50),
                endpos = startPos - Vector(0, 0, 200),
                filter = {self, owner}
            })

            if tr.Hit then
                local newAng = tr.HitNormal:Angle()
                
                newAng:RotateAroundAxis(newAng:Right(), 0)
                
                self:SetPos(tr.HitPos)
                self:SetAngles(newAng)
            else
                self:SetPos(startPos)
            end

            local phys = self:GetPhysicsObject()
            if IsValid(phys) then
                phys:EnableMotion(false)
                phys:Sleep()
            end
        end)
    end

    function ENT:Use(activator, caller)
        if not IsValid(activator) or not activator:IsPlayer() then return end

        if not self:IsPowered() then
            if type(activator.Notify) == "function" then
                activator:Notify(
                    NOTIFY_WARNING,
                    Translate("Power.SpawnPointNoPower", "The spawn point has no power."),
                    5
                )
            end
            return
        end
        
        if activator.BW_LinkedSpawn == self then return end
        
        activator.BW_LinkedSpawn = self
        
        local entName = self:GetTranslatedName() or self.PrintName
        
        if type(activator.Notify) == "function" then
            activator:Notify(NOTIFY_SUCCESS, Translate("Entity.SpawnPoint.SetPoint", "You have set a new spawn point!"), 5)
        end
    end

    hook.Add("PlayerSpawn", "BW_CustomSpawnPointSystem", function(ply)
        timer.Simple(0, function()
            if not IsValid(ply) or not ply:Alive() then return end
            
            local spawnEnt = ply.BW_LinkedSpawn
            
            if IsValid(spawnEnt) then
                if type(spawnEnt.IsPowered) ~= "function" or not spawnEnt:IsPowered() then
                    if type(ply.Notify) == "function" then
                        ply:Notify(
                            NOTIFY_WARNING,
                            Translate("Power.SpawnPointNoPower", "The spawn point has no power."),
                            5
                        )
                    end
                    return
                end

                local targetPos = spawnEnt:GetPos() + Vector(0, 0, 20)
                
                local tr = util.TraceHull({
                    start = targetPos,
                    endpos = targetPos,
                    mins = Vector(-16, -16, 0),
                    maxs = Vector(16, 16, 72),
                    filter = {spawnEnt, ply}
                })

                if tr.Hit then
                    if type(ply.Notify) == "function" then
                        ply:Notify(NOTIFY_ERROR, Translate("Entity.SpawnPoint.Blocked", "Your spawn point is blocked!"), 5)
                    end
                else
                    ply:SetPos(targetPos)
                end
            else
                ply.BW_LinkedSpawn = nil
            end
        end)
    end)

    function ENT:OnRemove()
        if type(BaseClass.OnRemove) == "function" then
            BaseClass.OnRemove(self)
        end
    end
end