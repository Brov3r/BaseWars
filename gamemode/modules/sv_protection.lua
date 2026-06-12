local MODULE = MODULE

MODULE.Name = "Protection"
MODULE.Author = "Brov3r"
MODULE.Require = {"database"}

MODULE.AllowedLoadout = MODULE.AllowedLoadout or {}

MODULE.IgnoreClasses = {
    ["predicted_viewmodel"]  = true,
    ["viewmodel"]            = true,
    ["player"]               = true,
    ["worldspawn"]           = true,
    ["gmod_tool"]            = true,
    ["gmod_camera"]          = true,
    ["hands"]                = true,
    ["gmod_hands"]           = true,
    ["physgun_beam"]         = true,
    ["player_manager"]       = true,
    ["soundent"]             = true,
    ["ai_network"]           = true,
}

function MODULE:IsPoor(ply)
    if not ply.HasMoney then return false end
    return not ply:HasMoney(BW.Config.Protection.MoneyForceProtection)
end

function MODULE:HasEntities(ply)
    if not IsValid(ply) then return false end

    if ply.GetCount then
        local props    = ply:GetCount("props") or 0
        local sents    = ply:GetCount("sents") or 0
        local vehicles = ply:GetCount("vehicles") or 0
        local ragdolls = ply:GetCount("ragdolls") or 0
        
        if (props + sents + vehicles + ragdolls) > 0 then 
            return true 
        end
    end

    if CPPI then
        local physicsProps = ents.FindByClass("prop_physics")
        for i = 1, #physicsProps do
            local ent = physicsProps[i]
            if IsValid(ent) and ent.CPPIGetOwner and ent:CPPIGetOwner() == ply then
                return true
            end
        end

        local allEnts = ents.GetAll()
        for i = 1, #allEnts do
            local ent = allEnts[i]
            
            if not IsValid(ent) or ent == ply or ent:IsPlayer() or ent:IsNPC() or ent:IsWeapon() then continue end
            
            if ent.CPPIGetOwner and ent:CPPIGetOwner() == ply then
                local class = ent:GetClass()
                if self.IgnoreClasses[class] then continue end

                return true
            end
        end
    end

    return false
end

function MODULE:ApplyShield(ply)
    ply:SetMaterial(BW.Config.Protection.ProtectionMat)
    
    for k, _ in ipairs(ply:GetMaterials() or {}) do
        ply:SetSubMaterial(k - 1, BW.Config.Protection.ProtectionMat)
    end
    
    ply:SetRenderMode(RENDERMODE_TRANSALPHA)
    ply:SetColor(Color(255, 255, 255, 150)) 
end

function MODULE:RemoveShield(ply)
    ply:SetMaterial("")
    
    for k, _ in ipairs(ply:GetMaterials() or {}) do
        ply:SetSubMaterial(k - 1, "")
    end
    
    ply:SetRenderMode(RENDERMODE_NORMAL)
    ply:SetColor(BW.Config.Colors.White)
end

function MODULE:StripProtection(ply)
    if not IsValid(ply) or not ply.BW_IsInvulnerable then return end
    
    ply.BW_IsInvulnerable = false
    self:RemoveShield(ply)
    
    timer.Remove("BW_TempProtect_" .. ply:UserID())
end

function MODULE:IsEntityClear(ent)
    local trace = util.TraceEntity({
        start = ent:GetPos(),
        endpos = ent:GetPos(),
        filter = ent
    }, ent)

    if trace.Hit then
        local hitEnt = trace.Entity
        if IsValid(hitEnt) and (hitEnt:IsPlayer() or hitEnt:GetClass() == "prop_physics") then
            return false
        end
    end

    local phys = ent:GetPhysicsObject()
    if IsValid(phys) and phys:IsPenetrating() then
        return false
    end

    return true
end

function MODULE:AttemptUnghost(ent)
    if not IsValid(ent) then return end
    if ent._IsHeld then return end

    if self:IsEntityClear(ent) then
        ent:SetCollisionGroup(ent.bw_OldCollision or COLLISION_GROUP_NONE)
        ent:SetRenderMode(ent.bw_OldRenderMode or RENDERMODE_NORMAL)
        ent:SetColor(ent.bw_OldColor or BW.Config.Colors.White)
        
        ent.bw_IsGhosted = false
        ent.bw_OldCollision = nil
        ent.bw_OldRenderMode = nil
        ent.bw_OldColor = nil
        
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then 
            phys:EnableMotion(false)
            phys:Wake()
        end
    else
        timer.Create("BW_Unghost_" .. ent:EntIndex(), BW.Config.Protection.CheckInterval, 1, function()
            MODULE:AttemptUnghost(ent)
        end)
    end
end

function MODULE:CheckAndApplyProtection(ply)
    if not IsValid(ply) then return end

    local teamAllowed = (ply:Team() == (BW.TEAM_DEFAULT or TEAM_CONNECT or 1))
    if not teamAllowed then return end

    self:StripProtection(ply)
    ply.BW_LastSpawnTime = SysTime()
    
    timer.Simple(0.1, function()
        if not IsValid(ply) or not ply:Alive() then return end
        
        if not MODULE:IsNearWorldSpawn(ply) then return end
        if MODULE:HasEntities(ply) then return end

        ply.BW_IsInvulnerable = true
        MODULE:ApplyShield(ply)

        if not MODULE:IsPoor(ply) then
            timer.Create("BW_TempProtect_" .. ply:UserID(), BW.Config.Protection.TimeProtection, 1, function()
                if IsValid(ply) then
                    MODULE:StripProtection(ply)
                end
            end)
        end
    end)
end

function MODULE:Init()
    table.Empty(self.AllowedLoadout)
    if BW.Config and BW.Config.PlayerLoadout then
        for _, wep in ipairs(BW.Config.PlayerLoadout) do
            self.AllowedLoadout[wep] = true
        end
    end

    hook.Add("PhysgunPickup", "BW_Protection_GhostProp", function(ply, ent)
        self:OnPhysgunPickup(ply, ent)
    end)

    hook.Add("PhysgunDrop", "BW_Protection_UnghostProp", function(ply, ent)
        self:OnPhysgunDrop(ply, ent)
    end)

    hook.Add("EntityTakeDamage", "BW_SpawnProtection_Damage", function(ent, dmginfo)
        if not IsValid(ent) or not ent:IsPlayer() then return end

        if self:IsNearWorldSpawn(ent) then 
            return true
        end

        if ent.BW_IsInvulnerable then
            if dmginfo:IsFallDamage() or dmginfo:IsDamageType(DMG_CRUSH) 
                or dmginfo:IsDamageType(DMG_DROWN) 
                or dmginfo:IsDamageType(DMG_RADIATION) 
                or (IsValid(dmginfo:GetAttacker()) and dmginfo:GetAttacker() == game.GetWorld()) then
                                return
            end
            
            return true
        end
    end)

    hook.Add("WeaponEquip", "BW_Protection_RemoveOnPickup", function(wep, ply)
        if not IsValid(ply) then ply = wep:GetOwner() end
        if not IsValid(ply) or not ply:IsPlayer() then return end
        
        timer.Simple(0, function()
            if IsValid(ply) and ply.BW_IsInvulnerable and IsValid(wep) and not MODULE.AllowedLoadout[wep:GetClass()] then
                if (ply.BW_LastSpawnTime or 0) + 1 > SysTime() then return end
                
                MODULE:StripProtection(ply)
            end
        end)
    end)

    hook.Add("PlayerSpawnedSENT", "BW_Protection_RemoveOnSpawn", function(ply) self:StripProtection(ply) end)
    hook.Add("PlayerSpawnedProp", "BW_Protection_RemoveOnSpawn", function(ply) self:StripProtection(ply) end)
    hook.Add("PlayerSpawnedVehicle", "BW_Protection_RemoveOnSpawn", function(ply) self:StripProtection(ply) end)
    hook.Add("PlayerSpawnedNPC", "BW_Protection_RemoveOnSpawn", function(ply) self:StripProtection(ply) end)

    hook.Add("PlayerSpawn", "BW_Protection_SpawnLogic", function(ply)
        timer.Simple(0.2, function()
            if IsValid(ply) then
                self:CheckAndApplyProtection(ply)
            end
        end)
    end)

    hook.Add("PlayerChangedTeam", "BW_Protection_RemoveOnTeam", function(ply, oldTeam, newTeam)
        if ply.BW_IsInvulnerable and newTeam ~= (BW.TEAM_DEFAULT or TEAM_CONNECT or 1) then
            self:StripProtection(ply)
        end
    end)

    hook.Add("PlayerDisconnected", "BW_Protection_Cleanup", function(ply)
        timer.Remove("BW_TempProtect_" .. ply:UserID())
    end)
end

function MODULE:IsNearWorldSpawn(ply)
    if not self.SpawnPoints or #self.SpawnPoints == 0 then
        self.SpawnPoints = {}
        local classes = {"info_player_start", "info_player_terrorist", "info_player_counterterrorist", "info_player_rebel"}
        for _, cls in ipairs(classes) do
            for _, ent in ipairs(ents.FindByClass(cls)) do
                table.insert(self.SpawnPoints, ent:GetPos())
            end
        end
        if #self.SpawnPoints == 0 then return true end
    end

    local plyPos = ply:GetPos()
    local radiusSqr = BW.Config.Protection.SpawnRadiusSqr
    for _, spawnPos in ipairs(self.SpawnPoints) do
        if plyPos:DistToSqr(spawnPos) <= radiusSqr then
            return true
        end
    end
    return false
end

function MODULE:OnPhysgunPickup(ply, ent)
    if not IsValid(ent) or ent:IsPlayer() or ent:IsWorld() then return end

    if ent:CreatedByMap() then return end

    local class = ent:GetClass()
    if string.match(class, "^func_") or string.match(class, "^trigger_") then return end

    if CPPI and ent.CPPIGetOwner then
        local owner = ent:CPPIGetOwner()
        if not IsValid(owner) or not owner:IsPlayer() then return end
    end

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

function MODULE:OnPhysgunDrop(ply, ent)
    if not IsValid(ent) or not ent.bw_IsGhosted then return end

    ent._IsHeld = false 

    timer.Simple(BW.Config.Protection.UnghostDelay, function()
        if IsValid(ent) and MODULE and MODULE.AttemptUnghost then
            MODULE:AttemptUnghost(ent)
        end
    end)
end