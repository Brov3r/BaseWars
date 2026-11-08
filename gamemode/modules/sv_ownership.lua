local MODULE = MODULE
MODULE.Name = "Ownership"
MODULE.Author = "Brov3r"
MODULE.Require = {}

BW.Ownership = BW.Ownership or {}
local ownership = BW.Ownership
ownership.BySteamID = ownership.BySteamID or {}

function ownership.GetOwner(ent)
    if not IsValid(ent) then return NULL end
    if ent.CPPIGetOwner then
        local owner = ent:CPPIGetOwner()
        if IsValid(owner) then return owner end
    end
    if ent:IsWorld() or ent:CreatedByMap() then return game.GetWorld() end
    if IsValid(ent.Owner) then return ent.Owner end
    return ent:GetNWEntity("Owner")
end

function ownership.CanModify(ply, ent, permission)
    if not IsValid(ply) or not IsValid(ent) or ent:IsPlayer() then return false end

    local owner = ownership.GetOwner(ent)
    if owner == game.GetWorld() then
        if BW.CPPI and BW.CPPI.CheckPermission then return BW.CPPI.CheckPermission(ply, ent, permission) end
        return false
    end
    if ent:CreatedByMap() then return false end
    if owner == ply then return true end
    if BW.CPPI and BW.CPPI.CheckPermission then return BW.CPPI.CheckPermission(ply, ent, permission) end
    return false
end

function ownership.Track(ply, ent, itemID)
    if not IsValid(ply) or not IsValid(ent) then return end
    local sid = ply:SteamID64()
    local oldSID = ent.BW_OwnerSteamID
    if oldSID and oldSID ~= sid then
        local oldObjects = ownership.BySteamID[oldSID]
        if oldObjects then
            oldObjects[ent] = nil
            if not next(oldObjects) then ownership.BySteamID[oldSID] = nil end
        end
    end
    ownership.BySteamID[sid] = ownership.BySteamID[sid] or {}
    ownership.BySteamID[sid][ent] = itemID or ownership.BySteamID[sid][ent] or true
    ent.BW_OwnerSteamID = sid
    ent:CallOnRemove("BW_Ownership", function(removed)
        local objects = ownership.BySteamID[sid]
        if objects then
            objects[removed] = nil
            if not next(objects) then ownership.BySteamID[sid] = nil end
        end
    end)
end

function ownership.Assign(ply, ent, itemID)
    -- Prefer the CPPI setter so ownership hooks and the registry stay in sync.
    if ent.CPPISetOwner then return ent:CPPISetOwner(ply, itemID) end
    if ent.SetPlayer then ent:SetPlayer(ply) end
    if ent.SetCPPIOwner then ent:SetCPPIOwner(ply) end
    ent.Owner = ply
    ent:SetNWEntity("Owner", ply)
    ownership.Track(ply, ent, itemID)
    return true
end

function ownership.HasEntities(ply)
    local objects = ownership.BySteamID[ply:SteamID64()]
    for ent in pairs(objects or {}) do
        if IsValid(ent) and ownership.GetOwner(ent) == ply then return true end
        objects[ent] = nil
    end
    return false
end

function MODULE:Init()
    for _, event in ipairs({"PlayerSpawnedProp", "PlayerSpawnedSENT", "PlayerSpawnedVehicle", "PlayerSpawnedNPC", "PlayerSpawnedRagdoll", "PlayerSpawnedEffect"}) do
        hook.Add(event, "BW_Ownership_Track", function(ply, first, second)
            local ent = isentity(second) and second or first
            ownership.Track(ply, ent)
        end)
    end
    hook.Add("PlayerDisconnected", "BW_Ownership_Cleanup", function(ply)
        local objects = ownership.BySteamID[ply:SteamID64()]
        if not objects then return end
        -- Snapshot: removal callbacks mutate the registry.
        local pending = {}
        for ent in pairs(objects) do pending[#pending + 1] = ent end
        if BW.Config.Ownership.RemoveOnDisconnect then
            if BW.CPPI and BW.CPPI.IsEnabled and BW.CPPI.IsEnabled() and BW.CPPI.ScheduleCleanup then
                -- Keep the registry intact until the timer expires so a
                -- reconnecting player gets their props back.
                BW.CPPI.ScheduleCleanup(ply)
            else
                for _, ent in ipairs(pending) do
                    if IsValid(ent) and ownership.GetOwner(ent) == ply then ent:Remove() end
                end
                ownership.BySteamID[ply:SteamID64()] = nil
            end
        end
    end)
    hook.Add("PlayerInitialSpawn", "BW_Ownership_Restore", function(ply)
        local counts = {}
        for ent, itemID in pairs(ownership.BySteamID[ply:SteamID64()] or {}) do
            if IsValid(ent) then
                ownership.Assign(ply, ent, itemID)
                if isstring(itemID) then counts[itemID] = (counts[itemID] or 0) + 1 end
                local category = ent:GetClass() == "prop_physics" and "props" or "sents"
                ply:AddCount(category, ent)
                ply:AddCleanup(category, ent)
            end
        end
        for itemID, count in pairs(counts) do ply:SetNWInt("BW_ItemCount_" .. itemID, count) end
    end)
    hook.Add("PhysgunPickup", "BW_Ownership_Physgun", function(ply, ent)
        if not ownership.CanModify(ply, ent, "Physgun") then return false end
    end)
    hook.Add("GravGunPickupAllowed", "BW_Ownership_Gravgun", function(ply, ent)
        if not ownership.CanModify(ply, ent, "Pickup") then return false end
    end)
    hook.Add("GravGunPunt", "BW_Ownership_Gravgun", function(ply, ent)
        if not ownership.CanModify(ply, ent, "Punt") then return false end
    end)
    hook.Add("CanPlayerUnfreeze", "BW_Ownership_Unfreeze", function(ply, ent)
        if not ownership.CanModify(ply, ent, "Unfreeze") then return false end
    end)
    hook.Add("CanProperty", "BW_Ownership_Property", function(ply, property, ent)
        if not ownership.CanModify(ply, ent, "Property") then return false end
        if property ~= "skin" and property ~= "bodygroups" then return false end
    end)
    hook.Add("CanDrive", "BW_Ownership_Drive", function() return false end)
    hook.Add("PlayerNoClip", "BW_Ownership_Noclip", function(ply, enabled)
        if enabled and not ply:IsAdmin() then return false end
    end)
end
