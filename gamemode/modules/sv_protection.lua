local MODULE = MODULE

MODULE.Name = "Protection"
MODULE.Author = "Brov3r"
MODULE.Require = {}

function MODULE:Init()
    self:InitSpawnCache()

    hook.Add("PhysgunPickup", "BW_Protection_GhostProp", function(ply, ent)
        return self:OnPhysgunPickup(ply, ent)
    end)

    hook.Add("PhysgunDrop", "BW_Protection_UnghostProp", function(ply, ent)
        self:OnPhysgunDrop(ply, ent)
    end)

    hook.Add("PlayerShouldTakeDamage", "BW_Protection_SpawnProtect", function(ply, attacker)
        return self:CheckSpawnProtection(ply, attacker)
    end)
	
end

function MODULE:InitSpawnCache()
    self.SpawnPoints = {}
    
    local spawns = ents.FindByClass("info_player_start")
    table.Add(spawns, ents.FindByClass("info_player_terrorist"))
    table.Add(spawns, ents.FindByClass("info_player_counterterrorist"))
    table.Add(spawns, ents.FindByClass("info_player_rebel"))

    for _, ent in ipairs(spawns) do
        table.insert(self.SpawnPoints, ent:GetPos())
    end
end

function MODULE:CheckSpawnProtection(ply, attacker)
    if not IsValid(ply) then return end

    local plyPos = ply:GetPos()
    for _, spawnPos in ipairs(self.SpawnPoints) do
        if plyPos:DistToSqr(spawnPos) <= BW.Config.Protection.SpawnRadiusSqr then
            return true
        end
    end
    return nil
end

function MODULE:OnPhysgunPickup(ply, ent)
    if not IsValid(ent) or ent:IsPlayer() or ent:IsWorld() then return end

    if not ent.bw_IsGhosted then
        ent.bw_OldCollision = ent:GetCollisionGroup()
        ent.bw_OldRenderMode = ent:GetRenderMode()
        ent.bw_OldColor = ent:GetColor()
    end

    ent.bw_IsGhosted = true
    ent._IsHeld = true

    ent:SetRenderMode(RENDERMODE_TRANSALPHA)
    ent:SetColor(BW.Config.Protection.GhostColor)
    ent:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
    
    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
    end
end

local function IsEntityClear(ent)
    local trace = util.TraceEntity({
        start = ent:GetPos(),
        endpos = ent:GetPos(),
        filter = ent
    }, ent)

    if IsValid(trace.Entity) and (trace.Entity:IsPlayer() or trace.Entity:GetClass() == "prop_physics") then
        return false
    end

    local phys = ent:GetPhysicsObject()
    if IsValid(phys) and phys:IsPenetrating() then
        return false
    end

    return true
end

local function AttemptUnghost(ent)
    if not IsValid(ent) then return end
    if ent._IsHeld then return end

    if IsEntityClear(ent) then
        ent:SetCollisionGroup(ent.bw_OldCollision or COLLISION_GROUP_NONE)
        ent:SetRenderMode(ent.bw_OldRenderMode or RENDERMODE_NORMAL)
        ent:SetColor(ent.bw_OldColor or color_white)
        ent.bw_IsGhosted = false
        
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then 
            phys:EnableMotion(false)
            phys:Wake()
        end
    else
        timer.Create("BW_Unghost_" .. ent:EntIndex(), BW.Config.Protection.CheckInterval, 1, function()
            AttemptUnghost(ent)
        end)
    end
end

function MODULE:OnPhysgunDrop(ply, ent)
    if not IsValid(ent) or not ent.bw_IsGhosted then return end

    ent._IsHeld = false 

    timer.Simple(BW.Config.Protection.UnghostDelay, function()
        if IsValid(ent) then
            AttemptUnghost(ent)
        end
    end)
end