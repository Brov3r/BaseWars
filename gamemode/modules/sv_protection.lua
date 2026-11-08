local MODULE = MODULE

MODULE.Name = "Protection"
MODULE.Author = "Brov3r"
MODULE.Require = {"database", "ownership", "team"}

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

    -- First check: Use built-in GetCount if available (most efficient)
    if ply.GetCount then
        local props    = ply:GetCount("props") or 0
        local sents    = ply:GetCount("sents") or 0
        local vehicles = ply:GetCount("vehicles") or 0
        local ragdolls = ply:GetCount("ragdolls") or 0
        
        if (props + sents + vehicles + ragdolls) > 0 then 
            return true 
        end
    end

    return BW.Ownership.HasEntities(ply)
end

function MODULE:ApplyShield(ply)
    local submaterials = {}
    for k in ipairs(ply:GetMaterials()) do submaterials[k - 1] = ply:GetSubMaterial(k - 1) end
    ply.BW_PreShield = {material = ply:GetMaterial(), mode = ply:GetRenderMode(), color = ply:GetColor(), submaterials = submaterials}
    ply:SetMaterial(BW.Config.Protection.ProtectionMat)
    
    for k, _ in ipairs(ply:GetMaterials() or {}) do
        ply:SetSubMaterial(k - 1, BW.Config.Protection.ProtectionMat)
    end
    
    ply:SetRenderMode(RENDERMODE_TRANSALPHA)
    ply:SetColor(Color(255, 255, 255, 150)) 
end

function MODULE:RemoveShield(ply)
    local previous = ply.BW_PreShield
    if not previous then return end
    ply:SetMaterial(previous.material)
    for index, material in pairs(previous.submaterials) do ply:SetSubMaterial(index, material) end
    ply:SetRenderMode(previous.mode)
    ply:SetColor(previous.color)
    ply.BW_PreShield = nil
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
        if trace.HitWorld or (IsValid(hitEnt) and hitEnt:GetSolid() ~= SOLID_NONE) then
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
    self:StripProtection(ply)

    local teamAllowed = (ply:Team() == (BW.TEAM_DEFAULT or TEAM_CONNECT or 1))
    if not teamAllowed then return end

    ply.BW_LastSpawnTime = SysTime()
    if not ply:Alive() or ply.BW_IsInvis then return end
    if not self:IsNearWorldSpawn(ply) or self:HasEntities(ply) then return end
    ply.BW_IsInvulnerable = true
    self:ApplyShield(ply)
    if not self:IsPoor(ply) then
        timer.Create("BW_TempProtect_" .. ply:UserID(), BW.Config.Protection.TimeProtection, 1, function()
            if IsValid(ply) then self:StripProtection(ply) end
        end)
    end
end

function MODULE:Init()
    hook.Add("InitPostEntity", "BW_Protection_Spawns", function() self:CollectSpawnPoints() end)
    hook.Add("PostCleanupMap", "BW_Protection_Spawns", function() self:CollectSpawnPoints() end)
    table.Empty(self.AllowedLoadout)
    if BW.Config and BW.Config.PlayerLoadout then
        for _, wep in ipairs(BW.Config.PlayerLoadout) do
            self.AllowedLoadout[wep] = true
        end
    end

    hook.Add("PhysgunPickup", "BW_Protection_GhostProp", function(ply, ent)
        return self:OnPhysgunPickup(ply, ent)
    end)

    hook.Add("PhysgunDrop", "BW_Protection_UnghostProp", function(ply, ent)
        self:OnPhysgunDrop(ply, ent)
    end)

    hook.Add("PlayerShouldTakeDamage", "BW_SpawnProtection_Damage", function(ply, attacker)
        if not IsValid(ply) or not ply:IsPlayer() then return nil end

        if MODULE:IsNearWorldSpawn(ply) then 
            return false
        end

        if ply.BW_IsInvulnerable and IsValid(attacker) and not attacker:IsWorld() then
            return false
        end

    end)
    hook.Add("EntityTakeDamage", "BW_Protection_OutgoingDamage", function(target, damage)
        local attacker = damage:GetAttacker()
        if IsValid(attacker) and not attacker:IsPlayer() and IsValid(attacker:GetOwner()) then attacker = attacker:GetOwner() end
        if IsValid(attacker) and attacker:IsPlayer() and attacker ~= target then
            if attacker.BW_IsInvulnerable or self:IsNearWorldSpawn(attacker) then
                damage:SetDamage(0)
                return true
            end
        end
    end)
    hook.Add("PlayerDeath", "BW_Protection_Death", function(ply) self:StripProtection(ply) end)

    hook.Add("WeaponEquip", "BW_Protection_RemoveOnPickup", function(wep, ply)
        if not IsValid(ply) then ply = wep:GetOwner() end
        if not IsValid(ply) or not ply:IsPlayer() then return end
        
        timer.Simple(0, function()
            if IsValid(ply) and ply.BW_IsInvulnerable and IsValid(wep) and not MODULE.AllowedLoadout[wep:GetClass()] then
                MODULE:StripProtection(ply)
            end
        end)
    end)

    hook.Add("PlayerSpawnedSENT", "BW_Protection_RemoveOnSpawn", function(ply) self:StripProtection(ply) end)
    hook.Add("PlayerSpawnedProp", "BW_Protection_RemoveOnSpawn", function(ply) self:StripProtection(ply) end)
    hook.Add("PlayerSpawnedVehicle", "BW_Protection_RemoveOnSpawn", function(ply) self:StripProtection(ply) end)
    hook.Add("PlayerSpawnedNPC", "BW_Protection_RemoveOnSpawn", function(ply) self:StripProtection(ply) end)

    for _, event in ipairs({"PlayerSpawnedProp", "PlayerSpawnedSENT", "PlayerSpawnedVehicle", "PlayerSpawnedNPC", "PlayerSpawnedRagdoll"}) do
        hook.Add(event, "BW_Protection_SpawnZoneRemoval", function(ply, first, second)
            local ent = isentity(second) and second or first
            if IsValid(ent) then self:RemoveSpawnZoneEntity(ply, ent) end
        end)
    end

    timer.Remove("BW_Protection_SpawnZoneScan")
    timer.Create("BW_Protection_SpawnZoneScan", math.max(0.5, tonumber((BW.Config.Protection.SpawnPropRemoval or {}).ScanInterval) or 2), 0, function()
        local config = BW.Config.Protection.SpawnPropRemoval
        if not config or config.Enabled == false then return end

        for _, objects in pairs(BW.Ownership.BySteamID) do
            local pending = {}
            for ent in pairs(objects) do pending[#pending + 1] = ent end

            for _, ent in ipairs(pending) do
                if IsValid(ent) and not ent._IsHeld and self:IsPositionNearSpawn(ent:GetPos()) then
                    self:RemoveSpawnZoneEntity(nil, ent)
                end
            end
        end
    end)

    hook.Add("PlayerSpawn", "BW_Protection_SpawnLogic", function(ply)
        if not IsValid(ply.BW_LinkedSpawn) and not ply.BW_Resurrecting then self:RegisterWorldSpawn(ply:GetPos()) end
        self:CheckAndApplyProtection(ply)
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

function MODULE:CollectSpawnPoints()
        self.SpawnPoints = {}
        local classes = {"info_player_start", "info_player_deathmatch", "info_player_terrorist", "info_player_counterterrorist", "info_player_rebel", "info_player_combine"}
        for _, cls in ipairs(classes) do
            for _, ent in ipairs(ents.FindByClass(cls)) do
                table.insert(self.SpawnPoints, ent:GetPos())
            end
        end
        if #self.SpawnPoints == 0 then Log("warn", "No map spawn entities found; using actual world spawn positions") end
end

function MODULE:RegisterWorldSpawn(position)
    if not self.SpawnPoints then self:CollectSpawnPoints() end
    for _, existing in ipairs(self.SpawnPoints) do
        if existing:DistToSqr(position) <= 32 ^ 2 then return end
    end
    self.SpawnPoints[#self.SpawnPoints + 1] = Vector(position.x, position.y, position.z)
end

function MODULE:IsPositionNearSpawn(position)
    if not position then return false end
    if not self.SpawnPoints then self:CollectSpawnPoints() end
    if #self.SpawnPoints == 0 then return false end

    local radiusSqr = BW.Config.Protection.SpawnRadiusSqr
    for _, spawnPos in ipairs(self.SpawnPoints) do
        if position:DistToSqr(spawnPos) <= radiusSqr then
            return true
        end
    end
    return false
end

function MODULE:IsNearWorldSpawn(ply)
    if not IsValid(ply) then return false end
    return self:IsPositionNearSpawn(ply:GetPos())
end

function MODULE:RemoveSpawnZoneEntity(ply, ent)
    local config = BW.Config.Protection.SpawnPropRemoval
    if not config or config.Enabled == false then return end
    if not IsValid(ent) or ent:IsPlayer() or ent:IsWorld() or ent:CreatedByMap() then return end
    if ent._IsHeld or not self:IsPositionNearSpawn(ent:GetPos()) then return end

    local owner = BW.Ownership.GetOwner(ent)
    if not IsValid(owner) and IsValid(ply) then owner = ply end
    if config.IgnoreAdmins ~= false and IsValid(owner) and owner:IsAdmin() then return end

    local className = ent:GetClass()
    ent:Remove()

    if IsValid(owner) and owner.Notify then
        owner:Notify(
            NOTIFY_ERROR,
            string.format(
                Translate("Protection.SpawnZoneRemoved", "The prop %s was removed because it was in the spawn zone."),
                className
            ),
            5
        )
    end
end

function MODULE:OnPhysgunPickup(ply, ent)
    if not IsValid(ent) or ent:IsPlayer() or ent:IsWorld() then return end

    if ent:CreatedByMap() then return end

    if ent.BlockPhysGun then return false  end
    if not BW.Ownership.CanModify(ply, ent, "Physgun") then return false end


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
            MODULE:RemoveSpawnZoneEntity(ply, ent)
        end
    end)
end
