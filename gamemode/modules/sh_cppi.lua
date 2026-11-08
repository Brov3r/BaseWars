local MODULE = MODULE
MODULE.Name = "CPPI"
MODULE.Author = "Brov3r"
MODULE.Require = SERVER and {"database", "notify", "ownership"} or {"database", "notify"}

local cfg = BW.Config.CPPI or {}
local ENABLED = cfg.Enabled ~= false
local MAX_FRIENDS = math.Clamp(tonumber(cfg.MaxFriends) or 32, 0, 64)

local ENTITY = FindMetaTable("Entity")
local PLAYER = FindMetaTable("Player")

BW.CPPI = BW.CPPI or {}
local cppi = BW.CPPI
cppi.Enabled = ENABLED

cppi.PermissionList = {}
cppi.PermissionIDs = {}
-- Server: [ownerSteamID64][permissionIndex] = { global = bool, [playerSteamID64] = true }
cppi.Permissions = {}
-- Client: [permissionIndex] = { global = bool, [playerSteamID64] = true } for the local player
cppi.ClientPermissions = {}
-- World/map entity permissions are global and editable by admins.
cppi.WorldPermissions = {}
cppi.ClientWorldPermissions = {}
-- Entity indexes known to belong to the map/world. Synced to clients because
-- CreatedByMap and networked owner vars are unreliable for some brush entities.
cppi.WorldEntities = {}
cppi.ClientWorldEntities = {}

local function NormalizeSID(sid)
    sid = tostring(sid or "")
    if not sid:match("^%d+$") then return nil end
    if #sid < 15 or #sid > 20 then return nil end
    return sid
end

-- Permission recipients may be bots. GMod gives all bots SteamID64 "0" and
-- SteamID "BOT", so those two values are valid targets too.
local function NormalizeTargetID(sid)
    sid = tostring(sid or "")
    if sid == "0" or sid == "BOT" then return sid end
    return NormalizeSID(sid)
end

local function Notify(ply, kind, text, duration)
    if IsValid(ply) and ply.Notify then ply:Notify(kind, text, duration or 5) end
end

local function GetNameFromSID(sid)
    local ply = player.GetBySteamID64(tostring(sid or ""))
    return IsValid(ply) and ply:Nick() or tostring(sid or "")
end

function cppi.IsEnabled()
    return cppi.Enabled == true
end

-- Permissions -------------------------------------------------------------
function cppi.CreatePermission(id, name, description, defaultAdminLevel)
    local index = #cppi.PermissionList + 1
    cppi.PermissionList[index] = {
        index = index,
        id = id,
        name = name,
        description = description,
        defaultAdminLevel = defaultAdminLevel or 0
    }
    cppi.PermissionIDs[id] = index
    return index
end

cppi.PERMISSION_ALL     = cppi.CreatePermission("all", "All access", "Grants every permission.", 3)
cppi.PERMISSION_PHYSGUN = cppi.CreatePermission("physgun", "Physgun", "Allows using the physgun on your props.", 1)
cppi.PERMISSION_GRAVGUN = cppi.CreatePermission("gravgun", "Gravgun", "Allows using the gravity gun on your props.", 1)
cppi.PERMISSION_TOOL    = cppi.CreatePermission("tool", "Toolgun", "Allows using tools and properties on your props.", 2)
cppi.PERMISSION_USE     = cppi.CreatePermission("use", "Use (E)", "Allows using your props, seats and buttons.", 1)

local DEFAULT_WORLD_PERMISSIONS = {
    all = false,
    physgun = false,
    gravgun = false,
    tool = false,
    use = true,
}

function cppi.GetDefaultWorldPermissions()
    local configured = cfg.WorldPermissions or {}
    local permissions = {}
    for _, permission in ipairs(cppi.PermissionList) do
        local value = configured[permission.id]
        if value == nil then value = DEFAULT_WORLD_PERMISSIONS[permission.id] end
        permissions[permission.index] = value == true
    end
    return permissions
end

cppi.WorldPermissions = cppi.GetDefaultWorldPermissions()
cppi.ClientWorldPermissions = cppi.GetDefaultWorldPermissions()

local ACTION_PERMISSIONS = {
    Physgun = cppi.PERMISSION_PHYSGUN,
    Gravgun = cppi.PERMISSION_GRAVGUN,
    Pickup = cppi.PERMISSION_GRAVGUN,
    Punt = cppi.PERMISSION_GRAVGUN,
    Tool = cppi.PERMISSION_TOOL,
    Property = cppi.PERMISSION_TOOL,
    Use = cppi.PERMISSION_USE,
    Unfreeze = cppi.PERMISSION_PHYSGUN,
}

local function ResolvePermission(permission)
    if permission == nil then return cppi.PERMISSION_ALL end
    if isnumber(permission) then return permission end
    return ACTION_PERMISSIONS[permission] or cppi.PERMISSION_ALL
end

function cppi.GetPermissionName(permission)
    local info = cppi.PermissionList[ResolvePermission(permission)]
    return info and Translate("CPPI.Permission." .. info.id, info.name) or "?"
end

function cppi.GetPermissionInfo(permission)
    return cppi.PermissionList[ResolvePermission(permission)]
end

-- Permission storage ------------------------------------------------------
function cppi.SetupPlayer(plyOrSID)
    local sid = isstring(plyOrSID) and NormalizeSID(plyOrSID) or (IsValid(plyOrSID) and plyOrSID:SteamID64())
    if not sid then return end

    local permissions = {}
    for index = 1, #cppi.PermissionList do
        permissions[index] = { global = false }
    end
    cppi.Permissions[sid] = permissions
    return permissions
end

function cppi.GetPermissions(plyOrSID)
    local sid = isstring(plyOrSID) and NormalizeSID(plyOrSID) or (IsValid(plyOrSID) and plyOrSID:SteamID64())
    if not sid then return end
    return cppi.Permissions[sid] or cppi.SetupPlayer(sid)
end

function cppi.HasPermissionBySID(owner, targetSID, permission)
    if not IsValid(owner) then return false end
    targetSID = NormalizeTargetID(targetSID)
    if not targetSID then return false end
    if targetSID == owner:SteamID64() then return true end

    permission = ResolvePermission(permission)

    -- "All access" includes every other permission.
    if permission ~= cppi.PERMISSION_ALL and cppi.HasPermissionBySID(owner, targetSID, cppi.PERMISSION_ALL) then
        return true
    end

    local permissions
    if SERVER then
        permissions = cppi.Permissions[owner:SteamID64()]
    else
        if owner ~= LocalPlayer() then return false end
        permissions = cppi.ClientPermissions
    end

    local entry = permissions and permissions[permission]
    if not entry then return false end

    -- A global grant and an individual grant cancel each other, so individual
    -- entries can be used as exceptions to a global rule.
    local global = entry.global == true
    local individual = entry[targetSID] == true
    return global ~= individual
end

function cppi.HasPermission(receiver, granter, permission)
    if not IsValid(receiver) or not IsValid(granter) then return false end
    return cppi.HasPermissionBySID(granter, receiver:SteamID64(), permission)
end

function cppi.AdminBypass(ply)
    return cfg.AdminBypass ~= false and IsValid(ply) and ply:IsAdmin()
end

local function IsPlayerOrWorld(ent)
    return IsValid(ent) and (ent:IsPlayer() or ent:IsWorld())
end

function cppi.GetOwner(ent)
    if not IsValid(ent) then return NULL end
    if ent:IsWorld() then return game.GetWorld() end

    -- Ignore non-player engine owners (doors/windows/brushes often have one);
    -- they are map entities, not player-owned props.
    local owner
    if SERVER then owner = ent.Owner end
    if IsPlayerOrWorld(owner) then return owner end

    owner = ent:GetNWEntity("OwnerEnt")
    if IsPlayerOrWorld(owner) then return owner end

    owner = ent:GetNWEntity("Owner")
    if IsPlayerOrWorld(owner) then return owner end

    local worldEntities = SERVER and cppi.WorldEntities or cppi.ClientWorldEntities
    if worldEntities and worldEntities[ent:EntIndex()] then return game.GetWorld() end

    -- Map entities belong to the world. The networked OwnerID fallback covers
    -- clients where CreatedByMap is unreliable.
    if ent:CreatedByMap() or ent:GetNWString("OwnerID", "") == "World" then
        return game.GetWorld()
    end

    -- The client cannot see all server-side ownership flags (map brushes in
    -- particular). Anything left without a player owner is world-owned for
    -- display purposes; the server remains authoritative for permissions.
    if not SERVER then return game.GetWorld() end
    return NULL
end

function cppi.HasWorldPermission(permission)
    permission = ResolvePermission(permission)
    local permissions = SERVER and cppi.WorldPermissions or cppi.ClientWorldPermissions
    if permissions[cppi.PERMISSION_ALL] then return true end
    return permissions[permission] == true
end

function cppi.CheckPermission(ply, ent, permission)
    if not cppi.IsEnabled() or not IsValid(ply) or not IsValid(ent) then return false end

    permission = ResolvePermission(permission)

    local owner = cppi.GetOwner(ent)
    if owner == game.GetWorld() then
        if cppi.AdminBypass(ply) then return true end
        return cppi.HasWorldPermission(permission)
    end
    if ent:CreatedByMap() then return false end

    if owner == ply then return true end
    if cppi.AdminBypass(ply) then return true end
    if not IsValid(owner) or not owner:IsPlayer() then return false end

    return cppi.HasPermission(ply, owner, permission)
end

cppi.CanAccess = cppi.CheckPermission

function cppi.GetFriends(ply)
    local friends = {}
    if not IsValid(ply) or not ply:IsPlayer() then return friends end

    for _, other in ipairs(player.GetAll()) do
        if other ~= ply and cppi.HasPermission(other, ply, cppi.PERMISSION_ALL) then
            friends[#friends + 1] = other
        end
    end
    return friends
end

-- Persistence -------------------------------------------------------------
if SERVER then
    local function SavePermissions(ply)
        if not cfg.Persist then return end
        local permissions = cppi.Permissions[ply:SteamID64()]
        if not permissions then return end

        local data = {}
        for _, permission in ipairs(cppi.PermissionList) do
            local entry = permissions[permission.index]
            local players = {}
            for sid, granted in pairs(entry) do
                if sid ~= "global" and granted == true then players[#players + 1] = sid end
            end
            data[#data + 1] = {
                id = permission.id,
                global = entry.global == true,
                players = players
            }
        end

        ply:SetPData("BW_CPPI_Permissions", util.TableToJSON(data))
    end

    function cppi.LoadPermissions(ply)
        local permissions = cppi.SetupPlayer(ply)
        if not permissions or not cfg.Persist then return end

        local raw = ply:GetPData("BW_CPPI_Permissions", "")
        if not isstring(raw) or raw == "" then return end

        local data = util.JSONToTable(raw)
        if not istable(data) then return end

        local ownerSID = ply:SteamID64()
        for _, saved in ipairs(data) do
            local permission = cppi.PermissionIDs[saved.id]
            if permission and permissions[permission] then
                local entry = permissions[permission]
                entry.global = saved.global == true
                if istable(saved.players) then
                    for _, sid in ipairs(saved.players) do
                        sid = NormalizeTargetID(sid)
                        if sid and sid ~= ownerSID then entry[sid] = true end
                    end
                end
            end
        end
    end

    function cppi.SyncPermissions(ply)
        if not IsValid(ply) then return end
        local permissions = cppi.Permissions[ply:SteamID64()]

        net.Start("BW_CPPI_Sync")
        net.WriteUInt(#cppi.PermissionList, 8)

        for _, permission in ipairs(cppi.PermissionList) do
            net.WriteUInt(permission.index, 8)
            net.WriteBool(cppi.WorldPermissions[permission.index] == true)
        end

        for _, permission in ipairs(cppi.PermissionList) do
            local entry = permissions and permissions[permission.index] or { global = false }
            local players = {}
            for sid, granted in pairs(entry) do
                if sid ~= "global" and granted == true then players[#players + 1] = sid end
            end

            net.WriteUInt(permission.index, 8)
            net.WriteBool(entry.global == true)
            net.WriteUInt(#players, 8)
            for _, sid in ipairs(players) do net.WriteString(sid) end
        end

        net.Send(ply)
    end

    function cppi.SyncWorldEntities(ply)
        if not IsValid(ply) then return end
        local indices = table.GetKeys(cppi.WorldEntities)

        net.Start("BW_CPPI_WorldEntities")
        net.WriteUInt(#indices, 32)
        for _, index in ipairs(indices) do net.WriteUInt(index, 16) end
        net.Send(ply)
    end

    local function Changed(owner)
        if not IsValid(owner) then return end
        SavePermissions(owner)
        cppi.SyncPermissions(owner)
        hook.Run("CPPIFriendsChanged", owner, cppi.GetFriends(owner))
        hook.Run("BW_CPPI_Changed", owner)
    end

    function cppi.SetGlobal(owner, permission, enabled)
        if not IsValid(owner) then return false end
        permission = ResolvePermission(permission)
        local permissions = cppi.GetPermissions(owner)
        local entry = permissions and permissions[permission]
        if not entry then return false end

        entry.global = enabled == true
        Changed(owner)
        return true
    end

    function cppi.SetPermission(owner, targetSID, permission, granted)
        if not IsValid(owner) then return false, "owner" end
        targetSID = NormalizeTargetID(targetSID)
        if not targetSID or targetSID == owner:SteamID64() then return false, "target" end

        permission = ResolvePermission(permission)
        local permissions = cppi.GetPermissions(owner)
        local entry = permissions and permissions[permission]
        if not entry then return false, "permission" end

        granted = granted == true

        if granted and MAX_FRIENDS > 0 then
            local count = 0
            for sid, value in pairs(entry) do
                if sid ~= "global" and value == true then count = count + 1 end
            end
            if count >= MAX_FRIENDS and not entry[targetSID] then return false, "limit" end
        end

        if entry.global == true then
            -- Individual entries are exceptions to a global grant.
            entry[targetSID] = (not granted) and true or nil
        else
            entry[targetSID] = granted and true or nil
        end

        Changed(owner)
        return true
    end

    function cppi.TogglePermission(owner, targetSID, permission)
        if not IsValid(owner) then return false, "owner" end
        local granted = cppi.HasPermissionBySID(owner, targetSID, permission)
        return cppi.SetPermission(owner, targetSID, permission, not granted)
    end

    function cppi.RevokeAllForSID(owner, targetSID)
        if not IsValid(owner) then return false end
        targetSID = NormalizeTargetID(targetSID)
        if not targetSID or targetSID == owner:SteamID64() then return false end

        local permissions = cppi.GetPermissions(owner)
        if not permissions then return false end

        for _, permission in ipairs(cppi.PermissionList) do
            local entry = permissions[permission.index]
            if entry then
                if entry.global == true then
                    entry[targetSID] = true
                else
                    entry[targetSID] = nil
                end
            end
        end

        Changed(owner)
        return true
    end

    function cppi.ClearPermissions(owner)
        if not IsValid(owner) then return false end
        cppi.SetupPlayer(owner)
        Changed(owner)
        return true
    end

    function cppi.SetOwner(ent, ply, itemID)
        if not IsValid(ent) or ent:IsPlayer() or ent:IsWorld() then return false end
        if not IsValid(ply) or not ply:IsPlayer() then return false end

        local allowed = hook.Run("CPPIAssignOwnership", ply, ent, ply:UniqueID())
        if allowed == false then return false end

        cppi.WorldEntities[ent:EntIndex()] = nil
        ent.Owner = ply
        ent:SetNWEntity("Owner", ply)
        ent:SetNWEntity("OwnerEnt", ply)
        ent:SetNWString("OwnerID", ply:SteamID64())
        ent:SetNWString("OwnerName", ply:Nick())
        if ent.SetPlayer then ent:SetPlayer(ply) end

        if BW.Ownership then
            BW.Ownership.Track(ply, ent, itemID)
        else
            ent.BW_OwnerSteamID = ply:SteamID64()
        end

        return true
    end

    function cppi.ClearOwner(ent)
        if not IsValid(ent) or ent:IsPlayer() or ent:IsWorld() then return false end

        cppi.WorldEntities[ent:EntIndex()] = nil
        local oldSID = ent.BW_OwnerSteamID
        if oldSID and BW.Ownership then
            local objects = BW.Ownership.BySteamID[oldSID]
            if objects then
                objects[ent] = nil
                if not next(objects) then BW.Ownership.BySteamID[oldSID] = nil end
            end
        end

        ent.Owner = nil
        ent.BW_OwnerSteamID = nil
        ent:SetNWEntity("Owner", NULL)
        ent:SetNWEntity("OwnerEnt", NULL)
        ent:SetNWString("OwnerID", nil)
        ent:SetNWString("OwnerName", nil)
        return true
    end

    function cppi.SetOwnerWorld(ent)
        if not IsValid(ent) or ent:IsPlayer() or ent:IsWorld() then return false end
        ent:SetNWEntity("Owner", game.GetWorld())
        ent:SetNWEntity("OwnerEnt", game.GetWorld())
        ent:SetNWString("OwnerID", "World")
        ent:SetNWString("OwnerName", "World")
        return true
    end

    function cppi.InitializeWorldOwners()
        local worldEntities = {}
        for _, ent in ipairs(ents.GetAll()) do
            if IsValid(ent) and not ent:IsPlayer() and not ent:IsWorld() then
                local owner = ent.Owner
                if not IsValid(owner) or not owner:IsPlayer() then
                    worldEntities[ent:EntIndex()] = true
                    pcall(cppi.SetOwnerWorld, ent)
                end
            end
        end
        cppi.WorldEntities = worldEntities

        for _, ply in ipairs(player.GetAll()) do
            cppi.SyncWorldEntities(ply)
        end
    end

    function cppi.SaveWorldPermissions()
        local data = {}
        for _, permission in ipairs(cppi.PermissionList) do
            data[#data + 1] = {
                id = permission.id,
                allowed = cppi.WorldPermissions[permission.index] == true
            }
        end
        file.Write("bw_cppi_world.json", util.TableToJSON(data))
    end

    function cppi.LoadWorldPermissions()
        cppi.WorldPermissions = cppi.GetDefaultWorldPermissions()

        local raw = file.Read("bw_cppi_world.json", "DATA")
        if not isstring(raw) or raw == "" then return end

        local data = util.JSONToTable(raw)
        if not istable(data) then return end

        for _, saved in ipairs(data) do
            local index = cppi.PermissionIDs[saved.id]
            if index then cppi.WorldPermissions[index] = saved.allowed == true end
        end
    end

    function cppi.SetWorldPermission(permission, enabled)
        permission = ResolvePermission(permission)
        if not cppi.PermissionList[permission] then return false end

        cppi.WorldPermissions[permission] = enabled == true
        cppi.SaveWorldPermissions()

        for _, ply in ipairs(player.GetAll()) do
            cppi.SyncPermissions(ply)
        end
        return true
    end
end

-- CPPI standard interface -------------------------------------------------
function cppi.InstallInterface()
    CPPI = CPPI or {}
    CPPI.CPPI_DEFER = "CPPI_DEFER"
    CPPI.CPPI_NOTIMPLEMENTED = "CPPI_NOTIMPLEMENTED"

    CPPI.GetName = function() return "BaseWars" end
    CPPI.GetVersion = function() return "1.0" end
    CPPI.GetInterfaceVersion = function() return 1.3 end
    CPPI.GetNameFromUID = function(uid)
        uid = tostring(uid or "")
        for _, ply in ipairs(player.GetAll()) do
            if tostring(ply:UniqueID()) == uid then return ply:Nick() end
        end
    end

    function ENTITY:CPPIGetOwner()
        local owner = cppi.GetOwner(self)
        if IsValid(owner) and owner:IsPlayer() then
            return owner, owner:SteamID64()
        end
        if IsValid(owner) and owner:IsWorld() then
            return owner, "World"
        end

        local ownerID = self:GetNWString("OwnerID", "")
        if ownerID ~= "" then return nil, ownerID end
    end

    if SERVER then
        function ENTITY:CPPISetOwner(ply, itemID)
            if not IsValid(ply) then return cppi.ClearOwner(self) end
            return cppi.SetOwner(self, ply, itemID)
        end

        function ENTITY:SetCPPIOwner(ply)
            return self:CPPISetOwner(ply)
        end

        function ENTITY:CPPISetOwnerUID(uid)
            uid = tostring(uid or "")
            for _, ply in ipairs(player.GetAll()) do
                if tostring(ply:UniqueID()) == uid then return cppi.SetOwner(self, ply) end
            end
            return false
        end

        function ENTITY:CPPICanTool(ply)
            return cppi.CheckPermission(ply, self, cppi.PERMISSION_TOOL)
        end
        ENTITY.CPPICanProperty = ENTITY.CPPICanTool
        ENTITY.CPPICanEditVariable = ENTITY.CPPICanTool

        function ENTITY:CPPICanPhysgun(ply)
            return cppi.CheckPermission(ply, self, cppi.PERMISSION_PHYSGUN)
        end

        function ENTITY:CPPICanPickup(ply)
            return cppi.CheckPermission(ply, self, cppi.PERMISSION_GRAVGUN)
        end

        function ENTITY:CPPICanPunt(ply)
            return cppi.CheckPermission(ply, self, cppi.PERMISSION_GRAVGUN)
        end

        function ENTITY:CPPICanUse(ply)
            return cppi.CheckPermission(ply, self, cppi.PERMISSION_USE)
        end
        ENTITY.CPPIDrive = ENTITY.CPPICanUse
    end

    function PLAYER:CPPIGetFriends()
        if SERVER then return cppi.GetFriends(self) end
        if self ~= LocalPlayer() then return CPPI.CPPI_NOTIMPLEMENTED end
        return cppi.GetFriends(self)
    end

    if SERVER then
        function PLAYER:CPPIAddFriend(ply)
            return cppi.SetPermission(self, IsValid(ply) and ply:SteamID64() or ply, cppi.PERMISSION_ALL, true)
        end

        function PLAYER:CPPIRemoveFriend(ply)
            return cppi.SetPermission(self, IsValid(ply) and ply:SteamID64() or ply, cppi.PERMISSION_ALL, false)
        end
    end
end

function MODULE:Init()
    if not cppi.IsEnabled() then
        Log("info", "CPPI module is disabled by config.")
        return
    end

    cppi.InstallInterface()

    if SERVER then
        self:InitServer()
    else
        self:InitClient()
    end
end

-- Client ------------------------------------------------------------------
function MODULE:InitClient()
    net.Receive("BW_CPPI_Sync", function()
        local count = net.ReadUInt(8)
        local worldPermissions = {}
        local permissions = {}

        for _ = 1, count do
            local index = net.ReadUInt(8)
            worldPermissions[index] = net.ReadBool()
        end

        for _ = 1, count do
            local index = net.ReadUInt(8)
            local entry = { global = net.ReadBool() }
            local playerCount = net.ReadUInt(8)
            for _ = 1, playerCount do
                local sid = NormalizeTargetID(net.ReadString())
                if sid then entry[sid] = true end
            end
            permissions[index] = entry
        end

        cppi.ClientWorldPermissions = worldPermissions
        cppi.ClientPermissions = permissions
        hook.Run("BW_CPPI_Updated")
        local ply = LocalPlayer()
        if IsValid(ply) then hook.Run("CPPIFriendsChanged", ply, cppi.GetFriends(ply)) end
    end)

    net.Receive("BW_CPPI_WorldEntities", function()
        local count = net.ReadUInt(32)
        local entities = {}
        for _ = 1, count do entities[net.ReadUInt(16)] = true end
        cppi.ClientWorldEntities = entities
    end)

    net.Receive("BW_CPPI_WorldEntity", function()
        cppi.ClientWorldEntities[net.ReadUInt(16)] = true
    end)

    hook.Add("OnEntityCreated", "BW_CPPI_WorldEntityReset", function(ent)
        if cppi.ClientWorldEntities then
            cppi.ClientWorldEntities[ent:EntIndex()] = nil
        end
    end)

    hook.Add("EntityRemoved", "BW_CPPI_WorldEntityRemove", function(ent)
        if cppi.ClientWorldEntities then
            cppi.ClientWorldEntities[ent:EntIndex()] = nil
        end
    end)

    -- The Utilities tab belongs to the tool menu (next to Main), not the
    -- creation tabs (Props, Shop, Rules, FAQ).
    hook.Add("AddToolMenuCategories", "BW_CPPI_UtilitiesCategory", function()
        spawnmenu.AddToolCategory("Utilities", "BW_CPPI", Translate("CPPI.UtilitiesCategory", "Prop Access"))
    end)

    hook.Add("PopulateToolMenu", "BW_CPPI_UtilitiesOption", function()
        spawnmenu.AddToolMenuOption(
            "Utilities",
            "BW_CPPI",
            "BW_CPPI_Access",
            Translate("CPPI.ToolOptionName", "Prop Access & Permissions"),
            "",
            "",
            function(panel)
                local ui = vgui.Create("BW_CPPI_Access", panel)
                panel:AddPanel(ui)
            end
        )
    end)
end

if CLIENT then
    function cppi.ClientHasPermission(targetSID, permission)
        return cppi.HasPermissionBySID(LocalPlayer(), targetSID, permission)
    end

    function cppi.GetClientEntry(permission)
        return cppi.ClientPermissions[ResolvePermission(permission)]
    end

    local function SendAction(action, permission, ownerSID, targetSID, value)
        if not cppi.IsEnabled() then return end
        net.Start("BW_CPPI_Action")
        net.WriteUInt(action, 8)
        net.WriteUInt(ResolvePermission(permission), 8)
        net.WriteString(tostring(ownerSID or ""))
        net.WriteString(tostring(targetSID or ""))
        net.WriteBool(value == true)
        net.SendToServer()
    end

    function cppi.RequestTogglePermission(permission, targetSID, ownerSID)
        SendAction(1, permission, ownerSID, targetSID, false)
    end

    function cppi.RequestSetGlobal(permission, enabled)
        SendAction(2, permission, "", "", enabled)
    end

    function cppi.RequestClearPermissions(ownerSID)
        SendAction(3, cppi.PERMISSION_ALL, ownerSID, "", false)
    end

    function cppi.RequestRevokeAll(targetSID, ownerSID)
        SendAction(4, cppi.PERMISSION_ALL, ownerSID, targetSID, false)
    end

    function cppi.RequestAdminOwner(targetSID)
        SendAction(5, cppi.PERMISSION_ALL, "", targetSID, false)
    end

    function cppi.RequestAdminClearOwner()
        SendAction(6, cppi.PERMISSION_ALL, "", "", false)
    end

    function cppi.RequestAdminRemoveProps(ownerSID)
        SendAction(7, cppi.PERMISSION_ALL, ownerSID, "", false)
    end

    function cppi.RequestAdminShowPermissions(ownerSID)
        SendAction(8, cppi.PERMISSION_ALL, ownerSID, "", false)
    end

    function cppi.RequestAdminFreezeProps(ownerSID)
        SendAction(9, cppi.PERMISSION_ALL, ownerSID, "", false)
    end

    function cppi.RequestAdminCleanupDisconnected()
        SendAction(10, cppi.PERMISSION_ALL, "", "", false)
    end

    function cppi.RequestSetWorldPermission(permission, enabled)
        SendAction(11, permission, "", "", enabled)
    end
end

-- Server ------------------------------------------------------------------
if SERVER then
    util.AddNetworkString("BW_CPPI_Sync")
    util.AddNetworkString("BW_CPPI_Action")
    util.AddNetworkString("BW_CPPI_WorldEntities")
    util.AddNetworkString("BW_CPPI_WorldEntity")

    local function GetLookedAtEntity(ply)
        if not IsValid(ply) then return end
        local trace = ply:GetEyeTrace()
        local ent = trace.Entity
        if not IsValid(ent) or ent:IsPlayer() or ent:IsWorld() or ent:CreatedByMap() then return end
        if ply:GetShootPos():DistToSqr(trace.HitPos) > 400 * 400 then return end
        return ent
    end

    local function GetRegisteredEntities(steamID64)
        local objects = BW.Ownership.BySteamID[steamID64]
        if not objects then return {} end

        local result = {}
        for ent in pairs(objects) do
            if IsValid(ent) then result[#result + 1] = ent end
        end
        return result
    end

    local function RemoveOwnedEntities(steamID64)
        local entities = GetRegisteredEntities(steamID64)
        local removed = 0
        for _, ent in ipairs(entities) do
            ent:Remove()
            removed = removed + 1
        end
        return removed
    end

    local function FreezeOwnedEntities(steamID64)
        local entities = GetRegisteredEntities(steamID64)
        local frozen = 0
        for _, ent in ipairs(entities) do
            for index = 0, ent:GetPhysicsObjectCount() - 1 do
                local phys = ent:GetPhysicsObjectNum(index)
                if IsValid(phys) then
                    phys:EnableMotion(false)
                    frozen = frozen + 1
                end
            end
        end
        return frozen
    end

    local function CleanupDisconnectedProps()
        local steamIDs = {}
        for steamID64 in pairs(BW.Ownership.BySteamID) do steamIDs[#steamIDs + 1] = steamID64 end

        local removed = 0
        for _, steamID64 in ipairs(steamIDs) do
            if not IsValid(player.GetBySteamID64(steamID64)) then
                removed = removed + RemoveOwnedEntities(steamID64)
            end
        end
        return removed
    end

    function cppi.ScheduleCleanup(ply)
        if not IsValid(ply) then return end

        local steamID64 = ply:SteamID64()
        local timerName = "BW_CPPI_Cleanup_" .. steamID64
        timer.Remove(timerName)

        local delay = tonumber(cfg.CleanupDelay) or 600
        if delay < 0 then delay = 0 end

        local name = ply:Nick()
        timer.Create(timerName, delay, 1, function()
            if IsValid(player.GetBySteamID64(steamID64)) then return end
            local removed = RemoveOwnedEntities(steamID64)
            Log("info", "[CPPI] Removed", removed, "entities of disconnected player", name)
        end)
    end

    local function FormatPermissions(owner)
        local permissions = cppi.GetPermissions(owner)
        local result = {}

        for _, permission in ipairs(cppi.PermissionList) do
            local entry = permissions[permission.index]
            if entry then
                local names = {}
                for sid, granted in pairs(entry) do
                    if sid ~= "global" and granted then
                        local ply = player.GetBySteamID64(sid)
                        names[#names + 1] = ply and ply:Nick() or sid
                    end
                end

                if entry.global then
                    if #names > 0 then
                        result[#result + 1] = string.format(
                            Translate("CPPI.PermissionEveryoneExcept", "%s: everyone except %s"),
                            cppi.GetPermissionName(permission.index),
                            table.concat(names, ", ")
                        )
                    else
                        result[#result + 1] = string.format(
                            Translate("CPPI.PermissionEveryone", "%s: everyone"),
                            cppi.GetPermissionName(permission.index)
                        )
                    end
                elseif #names > 0 then
                    result[#result + 1] = cppi.GetPermissionName(permission.index) .. ": " .. table.concat(names, ", ")
                end
            end
        end

        return #result > 0 and table.concat(result, " | ") or Translate("CPPI.None", "none")
    end

    function MODULE:InitServer()
        cppi.LoadWorldPermissions()
        for _, delay in ipairs({0, 1, 5}) do
            timer.Simple(delay, function()
                if cppi.IsEnabled() then cppi.InitializeWorldOwners() end
            end)
        end

        hook.Add("OnEntityCreated", "BW_CPPI_WorldOwner", function(ent)
            timer.Simple(0, function()
                if not IsValid(ent) or ent:IsPlayer() or ent:IsWorld() then return end

                local owner = ent.Owner
                if IsValid(owner) and owner:IsPlayer() then return end

                -- Any still-unowned entity belongs to the world. This also
                -- covers map brushes whose CreatedByMap state is unreliable.
                local isMapEntity = ent:CreatedByMap()
                cppi.WorldEntities[ent:EntIndex()] = true
                pcall(cppi.SetOwnerWorld, ent)

                if isMapEntity then
                    net.Start("BW_CPPI_WorldEntity")
                    net.WriteUInt(ent:EntIndex(), 16)
                    net.Broadcast()
                end
            end)
        end)

        hook.Add("EntityRemoved", "BW_CPPI_WorldEntityRemove", function(ent)
            cppi.WorldEntities[ent:EntIndex()] = nil
        end)

        hook.Add("PlayerInitialSpawn", "BW_CPPI_Load", function(ply)
            if not IsValid(ply) then return end
            timer.Remove("BW_CPPI_Cleanup_" .. ply:SteamID64())
            if ply:IsBot() then return end
            cppi.LoadPermissions(ply)
            cppi.SyncPermissions(ply)
            cppi.SyncWorldEntities(ply)
            hook.Run("CPPIFriendsChanged", ply, cppi.GetFriends(ply))
        end)

        hook.Add("PlayerDisconnected", "BW_CPPI_Cleanup", function(ply)
            cppi.Permissions[ply:SteamID64()] = nil
        end)

        if cfg.EnforceUse ~= false then
            hook.Add("PlayerUse", "BW_CPPI_Use", function(ply, ent)
                if not IsValid(ply) or not IsValid(ent) or ent:IsWorld() then return end
                if not cppi.GetOwner(ent):IsValid() then return end
                if cppi.CheckPermission(ply, ent, cppi.PERMISSION_USE) then return end
                return false
            end)
        end

        hook.Add("CanEditVariable", "BW_CPPI_EditVariable", function(ent, ply)
            if not IsValid(ent) or not IsValid(ply) or ent:IsWorld() then return end
            return cppi.CheckPermission(ply, ent, cppi.PERMISSION_TOOL)
        end)

        net.Receive("BW_CPPI_Action", function(len, ply)
            if not BW.Utils.AllowRequest(ply, "cppi_action", 0.1, 10, len, 64) then return end
            if not IsValid(ply) then return end

            local action = net.ReadUInt(8)
            local permission = net.ReadUInt(8)
            local ownerSID = net.ReadString()
            local targetSID = net.ReadString()
            local value = net.ReadBool()

            if #ownerSID > 32 or #targetSID > 32 then return end
            if permission ~= 0 and not cppi.PermissionList[permission] then return end

            local function ResolveOwner()
                if ownerSID == "" or ownerSID == ply:SteamID64() then return ply end
                if not ply:IsAdmin() or cfg.AdminManagePermissions == false then return end
                local owner = player.GetBySteamID64(ownerSID)
                if IsValid(owner) then return owner end
            end

            if action == 1 then
                local owner = ResolveOwner()
                if not owner then return end

                local permissionName = cppi.GetPermissionName(permission)
                local targetName = GetNameFromSID(targetSID)
                local before = cppi.HasPermissionBySID(owner, targetSID, permission)
                local ok, reason = cppi.TogglePermission(owner, targetSID, permission)

                if not ok then
                    if reason == "limit" then
                        Notify(ply, NOTIFY_ERROR, string.format(Translate("CPPI.FriendLimit", "Permission limit reached (%d)."), MAX_FRIENDS), 5)
                    end
                    return
                end

                local granted = cppi.HasPermissionBySID(owner, targetSID, permission) and not before
                if owner == ply then
                    local text = granted
                        and string.format(Translate("CPPI.NotifyGrantedSelf", "You granted \"%s\" to %s."), permissionName, targetName)
                        or string.format(Translate("CPPI.NotifyRevokedSelf", "You revoked \"%s\" from %s."), permissionName, targetName)
                    Notify(ply, granted and NOTIFY_SUCCESS or NOTIFY_WARNING, text, 5)
                else
                    Notify(ply, NOTIFY_INFO, string.format(
                        Translate("CPPI.NotifyAdminChanged", "Changed \"%s\" for %s (owner: %s)."),
                        permissionName,
                        targetName,
                        owner:Nick()
                    ), 5)
                end

                local target = player.GetBySteamID64(targetSID)
                if IsValid(target) and target ~= ply then
                    local text = granted
                        and string.format(Translate("CPPI.NotifyGrantedTo", "%s granted you \"%s\"."), owner:Nick(), permissionName)
                        or string.format(Translate("CPPI.NotifyRevokedFrom", "%s revoked your \"%s\"."), owner:Nick(), permissionName)
                    Notify(target, granted and NOTIFY_INFO or NOTIFY_WARNING, text, 5)
                end

            elseif action == 2 then
                local owner = ResolveOwner()
                if not owner then return end
                if not cppi.SetGlobal(owner, permission, value) then return end

                local permissionName = cppi.GetPermissionName(permission)
                if owner == ply then
                    local text = value
                        and string.format(Translate("CPPI.NotifyGlobalGranted", "You granted \"%s\" to everyone."), permissionName)
                        or string.format(Translate("CPPI.NotifyGlobalRevoked", "You revoked \"%s\" from everyone."), permissionName)
                    Notify(ply, value and NOTIFY_SUCCESS or NOTIFY_WARNING, text, 5)
                else
                    Notify(ply, NOTIFY_INFO, string.format(
                        Translate("CPPI.NotifyAdminGlobal", "Changed global \"%s\" for %s."),
                        permissionName,
                        owner:Nick()
                    ), 5)
                end

            elseif action == 3 then
                local owner = ResolveOwner()
                if not owner or not cppi.ClearPermissions(owner) then return end

                if owner == ply then
                    Notify(ply, NOTIFY_WARNING, Translate("CPPI.NotifyClearedSelf", "You cleared all your prop permissions."), 5)
                else
                    Notify(ply, NOTIFY_WARNING, string.format(Translate("CPPI.NotifyClearedOther", "Cleared all permissions of %s."), owner:Nick()), 5)
                    Notify(owner, NOTIFY_WARNING, Translate("CPPI.NotifyClearedFor", "An administrator cleared your prop permissions."), 5)
                end

            elseif action == 4 then
                local owner = ResolveOwner()
                if not owner then return end

                local targetName = GetNameFromSID(targetSID)
                if cppi.RevokeAllForSID(owner, targetSID) then
                    Notify(ply, NOTIFY_WARNING, string.format(Translate("CPPI.NotifyRevokeAllSelf", "You revoked all permissions from %s."), targetName), 5)

                    local target = player.GetBySteamID64(targetSID)
                    if IsValid(target) and target ~= ply then
                        Notify(target, NOTIFY_WARNING, string.format(Translate("CPPI.NotifyRevokeAllTo", "%s revoked all permissions from you."), owner:Nick()), 5)
                    end
                end

            elseif action == 5 then
                if not ply:IsAdmin() or cfg.AdminManageOwnership == false then return end
                local target = player.GetBySteamID64(targetSID)
                if not IsValid(target) then return end
                local ent = GetLookedAtEntity(ply)
                if not ent then
                    Notify(ply, NOTIFY_ERROR, Translate("CPPI.LookAtProp", "Look at a valid prop first."), 5)
                    return
                end
                if cppi.SetOwner(ent, target) then
                    Notify(ply, NOTIFY_SUCCESS, string.format(Translate("CPPI.AdminOwnerSet", "Assigned %s as the owner of the prop."), target:Nick()), 5)
                    Notify(target, NOTIFY_INFO, string.format(Translate("CPPI.AdminOwnerSetTo", "%s assigned a prop to you."), ply:Nick()), 5)
                    Log("warn", "[CPPI] Admin", ply:Nick(), "assigned prop", ent, "to", target:Nick())
                end

            elseif action == 6 then
                if not ply:IsAdmin() or cfg.AdminManageOwnership == false then return end
                local ent = GetLookedAtEntity(ply)
                if not ent then
                    Notify(ply, NOTIFY_ERROR, Translate("CPPI.LookAtProp", "Look at a valid prop first."), 5)
                    return
                end
                local oldOwner = cppi.GetOwner(ent)
                if cppi.ClearOwner(ent) then
                    Notify(ply, NOTIFY_SUCCESS, Translate("CPPI.AdminOwnerCleared", "Prop ownership cleared."), 5)
                    if IsValid(oldOwner) and oldOwner ~= ply then
                        Notify(oldOwner, NOTIFY_WARNING, Translate("CPPI.AdminOwnerClearedFor", "An administrator cleared ownership of one of your props."), 5)
                    end
                end

            elseif action == 7 then
                if not ply:IsAdmin() or cfg.AdminManageOwnership == false then return end
                if ownerSID == "" then return end
                local target = player.GetBySteamID64(ownerSID)
                local removed = RemoveOwnedEntities(ownerSID)
                Notify(ply, NOTIFY_SUCCESS, string.format(
                    Translate("CPPI.AdminPropsRemoved", "Removed %d entities of %s."),
                    removed,
                    target and target:Nick() or ownerSID
                ), 5)
                Log("warn", "[CPPI] Admin", ply:Nick(), "removed", removed, "entities of", target and target:Nick() or ownerSID)

            elseif action == 8 then
                if not ply:IsAdmin() or cfg.AdminManagePermissions == false then return end
                local target = player.GetBySteamID64(ownerSID)
                if not IsValid(target) then return end
                Notify(ply, NOTIFY_INFO, string.format(
                    Translate("CPPI.AdminPermissionsList", "Permissions of %s: %s"),
                    target:Nick(),
                    FormatPermissions(target)
                ), 10)

            elseif action == 9 then
                if not ply:IsAdmin() or cfg.AdminManageOwnership == false then return end
                if ownerSID == "" then return end
                local frozen = FreezeOwnedEntities(ownerSID)
                local target = player.GetBySteamID64(ownerSID)
                Notify(ply, NOTIFY_SUCCESS, string.format(
                    Translate("CPPI.AdminPropsFrozen", "Froze %d physics objects of %s."),
                    frozen,
                    target and target:Nick() or ownerSID
                ), 5)
                Log("warn", "[CPPI] Admin", ply:Nick(), "froze", frozen, "objects of", target and target:Nick() or ownerSID)

            elseif action == 10 then
                if not ply:IsAdmin() or cfg.AdminManageOwnership == false then return end
                local removed = CleanupDisconnectedProps()
                Notify(ply, NOTIFY_SUCCESS, string.format(
                    Translate("CPPI.AdminDisconnectedCleanup", "Removed %d entities of disconnected players."),
                    removed
                ), 5)
                Log("warn", "[CPPI] Admin", ply:Nick(), "cleaned up", removed, "entities of disconnected players")

            elseif action == 11 then
                if not ply:IsAdmin() or cfg.AdminManagePermissions == false then return end
                if not cppi.SetWorldPermission(permission, value) then return end

                local permissionName = cppi.GetPermissionName(permission)
                local text = value
                    and string.format(Translate("CPPI.NotifyWorldGranted", "Allowed \"%s\" for map entities."), permissionName)
                    or string.format(Translate("CPPI.NotifyWorldRevoked", "Disabled \"%s\" for map entities."), permissionName)
                Notify(ply, value and NOTIFY_SUCCESS or NOTIFY_WARNING, text, 5)
                Log("warn", "[CPPI] Admin", ply:Nick(), "set world permission", permissionName, "to", tostring(value))
            end
        end)

        self:RegisterAdminCommands()
    end

    local function IsCommandAdmin(ply)
        if not IsValid(ply) then return true end
        if ply:IsAdmin() then return true end
        Notify(ply, NOTIFY_ERROR, Translate("CPPI.AdminOnly", "This command is available to administrators only."), 5)
        return false
    end

    local function FindPlayer(query)
        if not query or query == "" then return end
        query = tostring(query)
        local lowerQuery = query:lower()

        for _, ply in ipairs(player.GetAll()) do
            if ply:SteamID64() == query or ply:SteamID() == query
                or tostring(ply:UserID()) == query or ply:Nick():lower() == lowerQuery then
                return ply
            end
        end

        for _, ply in ipairs(player.GetAll()) do
            if ply:Nick():lower():find(lowerQuery, 1, true) then return ply end
        end
    end

    local function Respond(ply, text)
        if IsValid(ply) then
            Notify(ply, NOTIFY_INFO, text, 6)
            ply:PrintMessage(HUD_PRINTCONSOLE, "[CPPI] " .. text)
        else
            MsgN("[CPPI] " .. text)
        end
    end

    function MODULE:RegisterAdminCommands()
        concommand.Add("bw_cppi_info", function(ply)
            if not IsCommandAdmin(ply) then return end
            local ent = GetLookedAtEntity(ply)
            if not ent then
                Respond(ply, Translate("CPPI.LookAtProp", "Look at a valid prop first."))
                return
            end

            local owner = cppi.GetOwner(ent)
            local ownerText = IsValid(owner) and (owner:Nick() .. " [" .. owner:SteamID64() .. "]") or Translate("CPPI.None", "none")
            Respond(ply, string.format(Translate("CPPI.AdminPropInfo", "Prop %s | owner: %s"), ent:GetClass(), ownerText))
        end, nil, "Show CPPI ownership information for the prop you are looking at.")

        concommand.Add("bw_cppi_setowner", function(ply, cmd, args)
            if not IsCommandAdmin(ply) then return end
            if cfg.AdminManageOwnership == false then return end

            local target = FindPlayer(args[1])
            if not IsValid(target) then
                Respond(ply, Translate("CPPI.PlayerNotFound", "Player not found. Usage: bw_cppi_setowner <player>"))
                return
            end

            local ent = GetLookedAtEntity(ply)
            if not ent then
                Respond(ply, Translate("CPPI.LookAtProp", "Look at a valid prop first."))
                return
            end

            if cppi.SetOwner(ent, target) then
                Respond(ply, string.format(Translate("CPPI.AdminOwnerSet", "Assigned %s as the owner of the prop."), target:Nick()))
                Notify(target, NOTIFY_INFO, string.format(Translate("CPPI.AdminOwnerSetTo", "%s assigned a prop to you."), IsValid(ply) and ply:Nick() or "Console"), 5)
            else
                Respond(ply, Translate("CPPI.AdminOwnerFailed", "Could not change the prop owner."))
            end
        end, nil, "Assign the prop you are looking at to a player.")

        concommand.Add("bw_cppi_clearowner", function(ply)
            if not IsCommandAdmin(ply) then return end
            if cfg.AdminManageOwnership == false then return end

            local ent = GetLookedAtEntity(ply)
            if not ent then
                Respond(ply, Translate("CPPI.LookAtProp", "Look at a valid prop first."))
                return
            end

            if cppi.ClearOwner(ent) then
                Respond(ply, Translate("CPPI.AdminOwnerCleared", "Prop ownership cleared."))
            end
        end, nil, "Clear ownership of the prop you are looking at.")

        concommand.Add("bw_cppi_permissions", function(ply, cmd, args)
            if not IsCommandAdmin(ply) then return end
            local target = FindPlayer(args[1])
            if not IsValid(target) then
                Respond(ply, Translate("CPPI.PlayerNotFound", "Player not found."))
                return
            end
            Respond(ply, string.format(
                Translate("CPPI.AdminPermissionsList", "Permissions of %s: %s"),
                target:Nick(),
                FormatPermissions(target)
            ))
        end, nil, "List CPPI permissions of a player.")

        concommand.Add("bw_cppi_clearpermissions", function(ply, cmd, args)
            if not IsCommandAdmin(ply) then return end
            if cfg.AdminManagePermissions == false then return end

            local target = FindPlayer(args[1])
            if not IsValid(target) then
                Respond(ply, Translate("CPPI.PlayerNotFound", "Player not found."))
                return
            end

            cppi.ClearPermissions(target)
            Respond(ply, string.format(Translate("CPPI.AdminPermissionsCleared", "Cleared all permissions of %s."), target:Nick()))
            Notify(target, NOTIFY_WARNING, Translate("CPPI.AdminPermissionsClearedFor", "An administrator cleared your prop permissions."), 6)
        end, nil, "Clear all CPPI permissions granted by a player.")

        concommand.Add("bw_cppi_world", function(ply, cmd, args)
            if not IsCommandAdmin(ply) then return end
            if cfg.AdminManagePermissions == false then return end

            local permissionID = tostring(args[1] or ""):lower()
            local permission = cppi.PermissionIDs[permissionID]
            if not permission then
                Respond(ply, "Usage: bw_cppi_world <all|physgun|gravgun|tool|use> <0|1>")
                return
            end

            local value = args[2] == "1" or tostring(args[2] or ""):lower() == "true"
            cppi.SetWorldPermission(permission, value)
            Respond(ply, string.format(
                Translate("CPPI.AdminWorldSet", "Map entities: \"%s\" — %s."),
                cppi.GetPermissionName(permission),
                value and Translate("CPPI.Enabled", "enabled") or Translate("CPPI.Disabled", "disabled")
            ))
        end, nil, "Allow or deny a permission for map entities.")

        concommand.Add("bw_cppi_removeprops", function(ply, cmd, args)
            if not IsCommandAdmin(ply) then return end
            if cfg.AdminManageOwnership == false then return end

            local target = FindPlayer(args[1])
            if not IsValid(target) then
                Respond(ply, Translate("CPPI.PlayerNotFound", "Player not found."))
                return
            end

            local removed = RemoveOwnedEntities(target:SteamID64())
            Respond(ply, string.format(Translate("CPPI.AdminPropsRemoved", "Removed %d entities of %s."), removed, target:Nick()))
        end, nil, "Remove all entities owned by a player.")
    end
end
