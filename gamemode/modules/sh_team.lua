local MODULE = MODULE
MODULE.Name = "Teams"
MODULE.Author = "Brov3r"
MODULE.Require = {"notify"}

local PLAYER = FindMetaTable("Player")

BW.Teams = BW.Teams or {}
BW.Teams.Data = BW.Teams.Data or {} 
BW.Teams.FreeIndex = BW.Teams.FreeIndex or 1
BW.TEAM_DEFAULT = 1000
local passwords = {}
local published = {}

function MODULE:Init()
    local defColor = (BW.Config and BW.Config.Colors and BW.Config.Colors.Gray150) or Color(150, 150, 150)
    team.SetUp(BW.TEAM_DEFAULT, Translate("Team.NoTeam", "Citizen"), defColor, false)

    if SERVER then
        self:InitServer()
    else
        self:InitClient()
    end
end

if SERVER then
    util.AddNetworkString("BW_Team_Sync")
    util.AddNetworkString("BW_Team_Create")
    util.AddNetworkString("BW_Team_Join")
    util.AddNetworkString("BW_Team_Action")
    util.AddNetworkString("BW_Team_OpenMenu")
    util.AddNetworkString("BW_Team_Ready")
    util.AddNetworkString("BW_Team_Settings")

    local function GetOwnedTeam(ply)
        local index = ply:Team()
        local data = BW.Teams.Data[index]
        if data and data.Creator == ply:SteamID64() then return index, data end
        return nil
    end

    local function SanitizeTeamName(name)
        name = BW.Utils.UTF8Sub(string.Trim(tostring(name or "")):gsub("[%c]", ""), 1, 32)
        return name ~= "" and name or nil
    end

    local function SanitizeTeamColor(color)
        if not istable(color) then return nil end
        for _, channel in ipairs({color.r, color.g, color.b}) do
            if not BW.Utils.IsFinite(channel) then return nil end
        end
        return Color(math.Clamp(math.floor(color.r), 0, 255), math.Clamp(math.floor(color.g), 0, 255), math.Clamp(math.floor(color.b), 0, 255), 255)
    end

    function PLAYER:IsTeamLeader()
        return GetOwnedTeam(self) ~= nil
    end

    function PLAYER:TeamUpdateSettings(name, color, passwordMode, password)
        local index, data = GetOwnedTeam(self)
        if not data then
            if self.Notify then self:Notify(NOTIFY_ERROR, Translate("Team.LeaderOnly", "Only the team leader can change team settings.")) end
            return false
        end
        name = SanitizeTeamName(name)
        color = SanitizeTeamColor(color)
        if not name or not color then return false end
        passwordMode = tonumber(passwordMode) or 0
        password = tostring(password or "")
        if #password > 128 then return false end
        if passwordMode == 1 and password == "" then passwordMode = 2 end
        if passwordMode < 0 or passwordMode > 2 then return false end
        data.Name, data.Color = name, color
        if passwordMode == 1 then
            passwords[index] = password
            data.HasPassword = true
        elseif passwordMode == 2 then
            passwords[index] = ""
            data.HasPassword = false
        end
        team.SetUp(index, name, color, true)
        MODULE:SyncData()
        if self.Notify then self:Notify(NOTIFY_SUCCESS, Translate("Team.SettingsSaved", "Team settings updated.")) end
        if Log then Log("info", self:Nick() .. " updated team settings: " .. name) end
        return true
    end

    function PLAYER:TeamTransfer(target)
        local index, data = GetOwnedTeam(self)
        if not data or not IsValid(target) or target == self or target:Team() ~= index then return false end
        data.Creator = target:SteamID64()
        MODULE:SyncData()
        if self.Notify then self:Notify(NOTIFY_INFO, string.format(Translate("Team.LeaderTransferred", "Leadership transferred to %s."), target:Nick())) end
        if target.Notify then target:Notify(NOTIFY_SUCCESS, Translate("Team.LeaderReceived", "You are now the team leader.")) end
        return true
    end

    function MODULE:SyncData(ply, force)
        local snapshot, changed, removed = {}, {}, {}
        for index, data in pairs(BW.Teams.Data) do
            -- Never serialize server-only fields, including legacy passwords.
            local public = {Name = data.Name, Color = data.Color, Creator = data.Creator,
                HasPassword = data.HasPassword == true, MaxPlayers = data.MaxPlayers}
            snapshot[index] = public
            local encoded = util.TableToJSON(public)
            if ply or published[index] ~= encoded then changed[index] = public end
        end
        for index in pairs(published) do
            if not snapshot[index] then removed[#removed + 1] = index end
        end
        if not ply and not force and not next(changed) and #removed == 0 then return end
        local jsonData = util.TableToJSON({Full = ply ~= nil, Teams = changed, Removed = removed})
        if not jsonData then return end
        
        local compressed = util.Compress(jsonData)
        if not compressed or compressed == "" or #compressed > 60000 then
            Log("error", "Team synchronization exceeds network limit")
            return
        end

        net.Start("BW_Team_Sync")
        net.WriteUInt(#compressed, 16)
        net.WriteData(compressed, #compressed)
        
        if ply then
            net.Send(ply)
        else
            net.Broadcast()
            published = {}
            for index, public in pairs(snapshot) do published[index] = util.TableToJSON(public) end
        end
    end

    function MODULE:DisbandTeam(teamIndex)
        if not BW.Teams.Data[teamIndex] then return end
        
        for _, p in ipairs(team.GetPlayers(teamIndex)) do
            p:SetTeam(BW.TEAM_DEFAULT)
            if p.Notify then 
                p:Notify(NOTIFY_INFO, Translate("Team.TeamDisbanded", "Your team has been disbanded.")) 
            end
        end
        
        BW.Teams.Data[teamIndex] = nil
        passwords[teamIndex] = nil
        self:SyncData()
    end

    function PLAYER:GetTeamData()
        return BW.Teams.Data[self:Team()]
    end

    function PLAYER:TeamCreate(name, pwd, color)
        if self:Team() ~= BW.TEAM_DEFAULT then 
            if self.Notify then self:Notify(NOTIFY_ERROR, Translate("Team.AlreadyInTeam", "You are already a member of the team!")) end
            return false 
        end

        name = BW.Utils.UTF8Sub(string.Trim(tostring(name or "")):gsub("[%c]", ""), 1, 32)
        if name == "" then return false end
        pwd = tostring(pwd or "")
        if #pwd > 128 then return false end

        local targetIndex = 1
        while BW.Teams.Data[targetIndex] or targetIndex == BW.TEAM_DEFAULT do targetIndex = targetIndex + 1 end
        if targetIndex > 65534 then return false end

        team.SetUp(targetIndex, name, color or Color(255, 255, 255), true)
        
        local maxPl = (BW.Config and BW.Config.Team and BW.Config.Team.MaxPlayers) or 5
        
        BW.Teams.Data[targetIndex] = {
            Name = name,
            Color = color or Color(255, 255, 255),
            Creator = self:SteamID64(),
            HasPassword = (pwd and pwd ~= ""),
            MaxPlayers = maxPl
        }
        passwords[targetIndex] = pwd

        self:SetTeam(targetIndex)
        if self.Notify then
            self:Notify(NOTIFY_SUCCESS, string.format(Translate("Team.TeamCreate", "The '%s' team has been successfully created!"), name))
        end
        
        MODULE:SyncData()
        if Log then Log("info", self:Nick() .. " created a team: " .. name) end
        return true
    end

    function PLAYER:TeamJoin(teamIndex, pwd)
        if teamIndex == BW.TEAM_DEFAULT then
            if self:Team() == BW.TEAM_DEFAULT then return false end
            return self:TeamLeave()
        end
        local data = BW.Teams.Data[teamIndex]
        if not data or not team.Valid(teamIndex) then return false end
        
        if self:Team() == teamIndex then return false end
        if self:Team() ~= BW.TEAM_DEFAULT then 
            if self.Notify then self:Notify(NOTIFY_ERROR, Translate("Team.LeaveFirst", "First, leave the current team!")) end
            return false 
        end
        
        if #team.GetPlayers(teamIndex) >= (data.MaxPlayers or 5) then 
            if self.Notify then self:Notify(NOTIFY_ERROR, Translate("Team.Full", "The team is full!")) end
            return false 
        end
        
        if data.HasPassword and passwords[teamIndex] ~= pwd then
            if self.Notify then
                self:Notify(NOTIFY_ERROR, Translate("Team.TeamWrongPass", "You have entered an incorrect password!"))
            end
            return false
        end

        self:Notify(NOTIFY_SUCCESS, string.format(Translate("Team.TeamJoin", "You have successfully joined the team: %s!"), data.Name))
        self:SetTeam(teamIndex)
        MODULE:SyncData(nil, true)
        return true
    end

    function PLAYER:TeamLeave()
        local t = self:Team()
        if t == BW.TEAM_DEFAULT then return false end
        local data = BW.Teams.Data[t]
        -- Leadership transfer is explicit. A leader who leaves disbands the team.
        if data and data.Creator == self:SteamID64() then
            MODULE:DisbandTeam(t)
            return true
        end
        self:SetTeam(BW.TEAM_DEFAULT)
        if self.Notify then self:Notify(NOTIFY_WARNING, Translate("Team.TeamLeave", "You have left your team!")) end
        MODULE:SyncData(nil, true)
        return true
    end

    function PLAYER:TeamKick(target)
        local t = self:Team()
        local data = BW.Teams.Data[t]
        if not data or data.Creator ~= self:SteamID64() then return false end

        if IsValid(target) and target:Team() == t and target ~= self then
            target:SetTeam(BW.TEAM_DEFAULT)
            if target.Notify then
                target:Notify(NOTIFY_WARNING, Translate("Team.TeamKick", "You were kicked out of the team!"))
            end
            if self.Notify then
                self:Notify(NOTIFY_SUCCESS, string.format(Translate("Team.KickSuccess", "Player %s was kicked from the team."), target:Nick()))
            end
            MODULE:SyncData(nil, true)
            return true
        end
        return false
    end

    function PLAYER:TeamDisband()
        local t = self:Team()
        local data = BW.Teams.Data[t]
        if not data or data.Creator ~= self:SteamID64() then return false end
        
        MODULE:DisbandTeam(t)
        return true
    end

    function MODULE:InitServer()
        for index, data in pairs(BW.Teams.Data) do
            passwords[index] = data._RealPassword or passwords[index] or ""
            data._RealPassword = nil
        end
        hook.Remove("PlayerInitialSpawn", "BW_Team_AssignDefault")
        net.Receive("BW_Team_Ready", function(len, ply)
            if BW.Utils.AllowRequest(ply, "team_ready", 5, 1, len, 1) then MODULE:SyncData(ply) end
        end)

        hook.Add("PlayerDisconnected", "BW_Team_Cleanup", function(ply)
            local t = ply:Team()
            ply:SetTeam(BW.TEAM_DEFAULT)
            if t ~= BW.TEAM_DEFAULT and BW.Teams.Data[t] then
                local members = team.GetPlayers(t)
                if #members > 0 then
                    for _, m in ipairs(members) do
                        if BW.Teams.Data[t].Creator == ply:SteamID64() and m ~= ply and IsValid(m) then
                            BW.Teams.Data[t].Creator = m:SteamID64()
                            MODULE:SyncData()
                            break
                        end
                    end
                else
                    MODULE:DisbandTeam(t)
                end
            end
            MODULE:SyncData(nil, true)
        end)

        net.Receive("BW_Team_Create", function(len, ply)
            if not BW.Utils.AllowRequest(ply, "team_create", 3, 1, len, 300) then return end
            ply:TeamCreate(net.ReadString(), net.ReadString(), net.ReadColor())
        end)

        net.Receive("BW_Team_Join", function(len, ply)
            if not BW.Utils.AllowRequest(ply, "team_join", 2, 1, len, 140) then return end
            local index, password = net.ReadUInt(16), net.ReadString()
            if #password > 128 then return end
            ply:TeamJoin(index, password)
        end)

        net.Receive("BW_Team_Action", function(len, ply)
            if not BW.Utils.AllowRequest(ply, "team_action", 0.5, 2, len, 32) then return end
            local action = net.ReadString()
            if action == "leave" then
                ply:TeamLeave()
            elseif action == "kick" then
                ply:TeamKick(net.ReadEntity())
            elseif action == "disband" then
                ply:TeamDisband()
            elseif action == "transfer" then
                ply:TeamTransfer(net.ReadEntity())
            end
        end)

        net.Receive("BW_Team_Settings", function(len, ply)
            if not BW.Utils.AllowRequest(ply, "team_settings", 2, 1, len, 300) then return end
            local name = net.ReadString()
            local color = net.ReadColor()
            local passwordMode = net.ReadUInt(2)
            local password = net.ReadString()
            ply:TeamUpdateSettings(name, color, passwordMode, password)
        end)
        
        hook.Add("ShowSpare2", "BW_TeamMenu_F4_Open", function(ply)
            net.Start("BW_Team_OpenMenu")
            net.Send(ply)
            return false
        end)
    end
end

if CLIENT then
    local function NetworkColor(value)
        if IsColor(value) then return value end
        if istable(value) then
            return Color(math.Clamp(math.floor(tonumber(value.r) or 255), 0, 255),
                math.Clamp(math.floor(tonumber(value.g) or 255), 0, 255),
                math.Clamp(math.floor(tonumber(value.b) or 255), 0, 255), 255)
        end
        return Color(255, 255, 255)
    end

    function MODULE:InitClient()
        hook.Add("InitPostEntity", "BW_Team_Ready", function()
            net.Start("BW_Team_Ready")
            net.SendToServer()
        end)
        net.Receive("BW_Team_Sync", function()
            local len = net.ReadUInt(16)
            if len == 0 then return end
            
            local compressed = net.ReadData(len)
            local decompressed = util.Decompress(compressed, 262144)
            if not decompressed then return end
            
            local update = util.JSONToTable(decompressed)
            if not istable(update) or not istable(update.Teams) then return end
            if update.Full then BW.Teams.Data = {} end
            for _, index in ipairs(update.Removed or {}) do BW.Teams.Data[tonumber(index)] = nil end
            for index, tData in pairs(update.Teams) do
                index = tonumber(index)
                if not index then continue end
                team.SetUp(index, tData.Name, tData.Color, true)
                BW.Teams.Data[index] = tData
            end
            hook.Run("BW_Team_DataUpdated")
        end)
    end

    function PLAYER:TeamCreate(name, pwd, color)
        net.Start("BW_Team_Create")
        net.WriteString(name or "")
        net.WriteString(pwd or "")
        net.WriteColor(NetworkColor(color))
        net.SendToServer()
    end

    function PLAYER:TeamJoin(teamIndex, pwd)
        net.Start("BW_Team_Join")
        net.WriteUInt(teamIndex, 16)
        net.WriteString(pwd or "")
        net.SendToServer()
    end

    function PLAYER:TeamLeave()
        net.Start("BW_Team_Action")
        net.WriteString("leave")
        net.SendToServer()
    end

    function PLAYER:TeamKick(target)
        net.Start("BW_Team_Action")
        net.WriteString("kick")
        net.WriteEntity(target)
        net.SendToServer()
    end

    function PLAYER:TeamDisband()
        net.Start("BW_Team_Action")
        net.WriteString("disband")
        net.SendToServer()
    end

    function PLAYER:TeamTransfer(target)
        net.Start("BW_Team_Action")
        net.WriteString("transfer")
        net.WriteEntity(target)
        net.SendToServer()
    end

    function PLAYER:TeamUpdateSettings(name, color, passwordMode, password)
        net.Start("BW_Team_Settings")
        net.WriteString(name or "")
        net.WriteColor(NetworkColor(color))
        net.WriteUInt(math.Clamp(tonumber(passwordMode) or 0, 0, 2), 2)
        net.WriteString(password or "")
        net.SendToServer()
    end

    function PLAYER:GetTeamData()
        return BW.Teams.Data[self:Team()]
    end
end
