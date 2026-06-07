local MODULE = MODULE

MODULE.Name = "Buddies"
MODULE.Author = "Brov3r"
MODULE.Require = { "database", "notify" }

local colors = BW.Config and BW.Config.Colors or {
    White = Color(255, 255, 255),
    Red = Color(244, 67, 54),
    Green = Color(76, 175, 80),
    DarkGray = Color(40, 40, 40),
    Black = Color(0, 0, 0, 200)
}

CPPI = CPPI or {}
function CPPI:GetName() return "BW Prop Protection" end
function CPPI:GetVersion() return "1.0" end

local PLAYER = FindMetaTable("Player")
local ENTITY = FindMetaTable("Entity")

function ENTITY:CPPIGetOwner()
    local owner = self:GetNW2Entity("BW_PropOwner")
    if IsValid(owner) and owner:IsPlayer() then
        return owner, owner:UniqueID()
    end
    return nil, nil
end

if SERVER then
    util.AddNetworkString("BW_PP_ToggleBuddy")
    util.AddNetworkString("BW_PP_SyncBuddies")

    function ENTITY:CPPISetOwner(ply)
        if not IsValid(ply) or not ply:IsPlayer() then 
            self.BW_OwnerSteamID = nil
            self:SetNW2Entity("BW_PropOwner", NULL)
            return 
        end
        self.BW_OwnerSteamID = ply:SteamID64()
        self:SetNW2Entity("BW_PropOwner", ply)
    end

    function MODULE:Init()
    end

    function MODULE:PlayerCanInteract(ply, ent)
        if not IsValid(ent) or ent:IsPlayer() then return false end
        
        if ent:CreatedByMap() then return false end

        if ply:IsAdmin() or (ply.IsSuperAdmin and ply:IsSuperAdmin()) then return true end

        local owner = ent:GetNW2Entity("BW_PropOwner")
        if ent:CreatedByMap() or not IsValid(owner) then
            return false
        end

        if owner == ply then return true end

        if ply.BW_Buddies and ply.BW_Buddies[owner:SteamID64()] then
            return true
        end

        return false
    end

    hook.Add("PlayerInitialSpawn", "BW_PP_LoadBuddies", function(ply)
        ply.BW_Buddies = {}
        local raw = ply:GetPData("BW_PP_Buddies", "")
        if raw and raw ~= "" then
            local tbl = util.JSONToTable(raw)
            if tbl then
                for sid64, _ in pairs(tbl) do
                    ply.BW_Buddies[sid64] = true
                end
            end
        end
        
        timer.Simple(2, function()
            if IsValid(ply) then ply:SyncBuddies() end
        end)
    end)

    function PLAYER:SyncBuddies()
        net.Start("BW_PP_SyncBuddies")
        net.WriteTable(self.BW_Buddies or {})
        net.Send(self)
    end

    net.Receive("BW_PP_ToggleBuddy", function(len, ply)
        if not IsValid(ply) then return end
        local targetSID64 = net.ReadString()
        if not targetSID64 or targetSID64 == "" then return end

        ply.BW_Buddies = ply.BW_Buddies or {}
        
        if ply.BW_Buddies[targetSID64] then
            ply.BW_Buddies[targetSID64] = nil
        else
            ply.BW_Buddies[targetSID64] = true
        end

        ply:SetPData("BW_PP_Buddies", util.TableToJSON(ply.BW_Buddies))
        ply:SyncBuddies()
    end)

    local function HandlePropSpawn(ply, ent)
        if IsValid(ent) then
            ent:CPPISetOwner(ply)
        end
    end
    hook.Add("PlayerSpawnedProp", "BW_PP_SpawnProp", HandlePropSpawn)
    hook.Add("PlayerSpawnedSENT", "BW_PP_SpawnSENT", HandlePropSpawn)
    hook.Add("PlayerSpawnedSWEP", "BW_PP_SpawnSWEP", HandlePropSpawn)
    hook.Add("PlayerSpawnedVehicle", "BW_PP_SpawnVehicle", HandlePropSpawn)
    hook.Add("PlayerSpawnedRagdoll", "BW_PP_SpawnRagdoll", HandlePropSpawn)

    local function StartDelayedCollisionRestore(ent, delay)
        if not IsValid(ent) or ent:IsPlayer() then return end
        
        delay = delay or 0.5
        
        local entIdx = ent:EntIndex()
        local timerName = "BW_PP_RestoreCol_" .. entIdx

        timer.Create(timerName, delay, 1, function()
            if not IsValid(ent) then return end

            local min, max = ent:WorldSpaceAABB()
            local isBlocked = false

            local foundEntities = ents.FindInBox(min, max)
            
            for _, found in ipairs(foundEntities) do
                if IsValid(found) and found ~= ent and found ~= game.GetWorld() then
                    
                    if found:IsPlayer() and found:Alive() then
                        isBlocked = true
                        break
                    end
                    
                    if found:GetClass() == "prop_physics" or found:GetMoveType() == MOVETYPE_VPHYSICS then
                        if found:GetCollisionGroup() == COLLISION_GROUP_WORLD and found.BW_OriginalCollisionGroup then
                            continue
                        end
                        
                        isBlocked = true
                        break
                    end
                end
            end

            if not isBlocked then
                if IsValid(ent) and ent.BW_OriginalCollisionGroup then
                    ent:SetCollisionGroup(ent.BW_OriginalCollisionGroup)
                    ent.BW_OriginalCollisionGroup = nil
                    
                    ent:SetRenderMode(RENDERMODE_NORMAL)
                    ent:SetColor(Color(255, 255, 255, 255))
                end
            end
        end)
    end
    hook.Add("PhysgunDrop", "BW_PP_PhysgunDrop", function(ply, ent)
        StartDelayedCollisionRestore(ent)
    end)
    hook.Add("OnPhysgunFreeze", "BW_PP_PhysgunFreeze", function(weapon, phys, ent, ply)
        StartDelayedCollisionRestore(ent)
    end)

    hook.Add("PhysgunPickup", "BW_PP_PhysgunPickup", function(ply, ent)
        if not MODULE:PlayerCanInteract(ply, ent) then return false end
        
        if IsValid(ent) and not ent:IsPlayer() then
            if ent.BlockPhysGun then
                return false
            end

            local mins, maxs = ent:WorldSpaceAABB()
            local searchMins = mins - Vector(15, 15, 15)
            local searchMaxs = maxs + Vector(15, 15, 75)

            for _, found in ipairs(ents.FindInBox(searchMins, searchMaxs)) do
                if IsValid(found) and found:IsPlayer() and found:Alive() then
                    found:SetGroundEntity(NULL)
                    
                    found:SetPos(found:GetPos() + Vector(0, 0, 2))
                    
                    local timerName = "BW_PP_AntiFlight_" .. found:EntIndex()
                    timer.Create(timerName, 0, 3, function()
                        if IsValid(found) then
                            found:SetVelocity(-found:GetVelocity())
                        end
                    end)
                end
            end

            if not ent.BW_OriginalCollisionGroup then
                ent.BW_OriginalCollisionGroup = ent:GetCollisionGroup()
            end
            
            ent:SetCollisionGroup(COLLISION_GROUP_WORLD)
            
            ent:SetRenderMode(RENDERMODE_TRANSALPHA)
            ent:SetColor(Color(255, 255, 255, 150))
        end
    end)

    hook.Add("CanTool", "BW_PP_CanTool", function(ply, tr, tool)
        if IsValid(tr.Entity) and not tr.Entity:IsPlayer() then
            if not MODULE:PlayerCanInteract(ply, tr.Entity) then return false end
        end
    end)

    hook.Add("GravGunPickupAllowed", "BW_PP_GravGunPickup", function(ply, ent)
        if not MODULE:PlayerCanInteract(ply, ent) then return false end
    end)

    hook.Add("GravGunPunt", "BW_PP_GravGunPunt", function(ply, ent)
        if not MODULE:PlayerCanInteract(ply, ent) then return false end
    end)

    hook.Add("CanProperty", "BW_PP_CanProperty", function(ply, property, ent)
        if not MODULE:PlayerCanInteract(ply, ent) then return false end
    end)

    hook.Add("CanDrive", "BW_PP_CanDrive", function(ply, ent)
        return false
    end)

    hook.Add("EntityTakeDamage", "BW_PP_PropKillProtect", function(target, dmginfo)
        if target:IsPlayer() then
            local inflictor = dmginfo:GetInflictor()
            local attacker = dmginfo:GetAttacker()
            
            if dmginfo:IsDamageType(DMG_CRUSH) or 
               (IsValid(inflictor) and inflictor:GetClass() == "prop_physics") or 
               (IsValid(attacker) and attacker:GetClass() == "prop_physics") then
                
                dmginfo:SetDamage(0)
                return true
            end
        end
    end)

    hook.Add("PlayerDisconnected", "BW_PP_RemovePropsOnDisconnect", function(ply)
        local sid64 = ply:SteamID64()
        for _, ent in ipairs(ents.GetAll()) do
            if ent.BW_OwnerSteamID == sid64 then
                ent:Remove()
            end
        end
    end)
end

if CLIENT then
    MODULE.LocalBuddies = MODULE.LocalBuddies or {}

    function MODULE:Init()
    end

    hook.Add("PopulateToolMenu", "BW_PP_RegisterUtilities", function()
        spawnmenu.AddToolMenuOption("Utilities", "BaseWars", "BW_PP_Menu", Translate("Buddies.CatName", "Buddies"), "", "", function(panel)
            panel:Clear()
            
            local utilsPanel = vgui.Create("BW_SpawnMenu_Buddies", panel)
            utilsPanel:Dock(TOP)
            utilsPanel:SetTall(500)
            utilsPanel:SetModule(MODULE)
            
            MODULE.UtilsPanel = utilsPanel
            
            panel:AddItem(utilsPanel)
        end)
    end)

    net.Receive("BW_PP_SyncBuddies", function()
        MODULE.LocalBuddies = net.ReadTable()
        if IsValid(MODULE.UtilsPanel) then
            MODULE.UtilsPanel:Refresh()
        end
    end)

    hook.Add("OnEntityCreated", "BW_PP_PlayerJoinRefresh", function(ent)
        if IsValid(ent) and ent:IsPlayer() then
            timer.Simple(1, function()
                if IsValid(MODULE.UtilsPanel) then
                    MODULE.UtilsPanel:Refresh()
                end
            end)
        end
    end)

    hook.Add("EntityRemoved", "BW_PP_PlayerLeaveRefresh", function(ent)
        if IsValid(ent) and ent:IsPlayer() then
            timer.Simple(0.1, function()
                if IsValid(MODULE.UtilsPanel) then
                    MODULE.UtilsPanel:Refresh()
                end
            end)
        end
    end)

    hook.Add("OnPlayerChangedName", "BW_PP_PlayerNameRefresh", function(ply, oldName, newName)
        if IsValid(MODULE.UtilsPanel) then
            MODULE.UtilsPanel:Refresh()
        end
    end)
end