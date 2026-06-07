local MODULE = MODULE
MODULE.Name = "Teams"
MODULE.Author = "Brov3r"
MODULE.Require = {"notify"}

local PLAYER = FindMetaTable("Player")

BW.Teams = BW.Teams or {}
BW.Teams.Data = BW.Teams.Data or {} 
BW.Teams.FreeIndex = BW.Teams.FreeIndex or 1
BW.TEAM_DEFAULT = 1000

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

    function MODULE:SyncData(ply)
        local jsonData = util.TableToJSON(BW.Teams.Data)
        if not jsonData then return end
        
        local compressed = util.Compress(jsonData)
        if not compressed or compressed == "" then return end

        net.Start("BW_Team_Sync")
        net.WriteUInt(#compressed, 16)
        net.WriteData(compressed, #compressed)
        
        if ply then net.Send(ply) else net.Broadcast() end
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
        self:SyncData()
    end

    function PLAYER:GetTeamData()
        return BW.Teams.Data[self:Team()]
    end

    function PLAYER:TeamCreate(name, pwd, color)
        if self:Team() ~= BW.TEAM_DEFAULT then 
            if self.Notify then self:Notify(NOTIFY_WARNING, Translate("Team.AlreadyInTeam", "You are already a member of the team!")) end
            return false 
        end

        name = string.sub(string.Trim(name or ""), 1, 32)
        if name == "" then return false end

        local targetIndex = BW.Teams.FreeIndex
        BW.Teams.FreeIndex = BW.Teams.FreeIndex + 1
        if targetIndex == BW.TEAM_DEFAULT then
            targetIndex = BW.Teams.FreeIndex
            BW.Teams.FreeIndex = BW.Teams.FreeIndex + 1
        end

        team.SetUp(targetIndex, name, color or Color(255, 255, 255), true)
        
        local maxPl = (BW.Config and BW.Config.Team and BW.Config.Team.MaxPlayers) or 5
        
        BW.Teams.Data[targetIndex] = {
            Name = name,
            Color = color or Color(255, 255, 255),
            Creator = self:SteamID64(),
            HasPassword = (pwd and pwd ~= ""),
            _RealPassword = pwd or "",
            MaxPlayers = maxPl
        }

        self:SetTeam(targetIndex)
        if self.Notify then
            self:Notify(NOTIFY_SUCCESS, string.format(Translate("Team.TeamCreate", "The '%s' team has been successfully created!"), name))
        end
        
        MODULE:SyncData()
        if Log then Log("info", self:Nick() .. " created a team: " .. name) end
        return true
    end

    function PLAYER:TeamJoin(teamIndex, pwd)
        local data = BW.Teams.Data[teamIndex]
        if not data or not team.Valid(teamIndex) then return false end
        
        if self:Team() == teamIndex then return false end
        if self:Team() ~= BW.TEAM_DEFAULT then 
            if self.Notify then self:Notify(NOTIFY_WARNING, Translate("Team.LeaveFirst", "First, leave the current team!")) end
            return false 
        end
        
        if #team.GetPlayers(teamIndex) >= (data.MaxPlayers or 5) then 
            if self.Notify then self:Notify(NOTIFY_WARNING, Translate("Team.Full", "The team is full!")) end
            return false 
        end
        
        if data.HasPassword and data._RealPassword ~= pwd then
            if self.Notify then
                self:Notify(NOTIFY_WARNING, Translate("Team.TeamWrongPass", "You have entered an incorrect password!"))
            end
            return false
        end

        self:Notify(NOTIFY_SUCCESS, string.format(Translate("Team.TeamJoin", "You have successfully joined the team: %s!"), data.Name))
        self:SetTeam(teamIndex)
        MODULE:SyncData()
        return true
    end

    function PLAYER:TeamLeave()
        local t = self:Team()
        if t ~= BW.TEAM_DEFAULT then
            if self.Notify then self:Notify(NOTIFY_WARNING, Translate("Team.TeamLeave", "You have left your team!")) end
            self:SetTeam(BW.TEAM_DEFAULT)
            
            local members = team.GetPlayers(t)
            if #members == 0 then 
                MODULE:DisbandTeam(t) 
            else
                local data = BW.Teams.Data[t]
                if data and data.Creator == self:SteamID64() and IsValid(members[1]) then
                    data.Creator = members[1]:SteamID64()
                end
                MODULE:SyncData()
            end
            return true
        end
        return false
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
            MODULE:SyncData()
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
        hook.Add("PlayerInitialSpawn", "BW_Team_AssignDefault", function(ply)
            timer.Simple(0.1, function()
                if IsValid(ply) then
                    ply:SetTeam(BW.TEAM_DEFAULT)
                    MODULE:SyncData(ply)
                end
            end)
        end)

        hook.Add("PlayerDisconnected", "BW_Team_Cleanup", function(ply)
            local t = ply:Team()
            if t ~= BW.TEAM_DEFAULT and BW.Teams.Data[t] and BW.Teams.Data[t].Creator == ply:SteamID64() then
                local members = team.GetPlayers(t)
                if #members > 1 then
                    for _, m in ipairs(members) do
                        if m ~= ply and IsValid(m) then
                            BW.Teams.Data[t].Creator = m:SteamID64()
                            MODULE:SyncData()
                            break
                        end
                    end
                else
                    MODULE:DisbandTeam(t)
                end
            end
        end)

        net.Receive("BW_Team_Create", function(len, ply)
            ply:TeamCreate(net.ReadString(), net.ReadString(), net.ReadColor())
        end)

        net.Receive("BW_Team_Join", function(len, ply)
            ply:TeamJoin(net.ReadUInt(16), net.ReadString())
        end)

        net.Receive("BW_Team_Action", function(len, ply)
            local action = net.ReadString()
            if action == "leave" then
                ply:TeamLeave()
            elseif action == "kick" then
                ply:TeamKick(net.ReadEntity())
            elseif action == "disband" then
                ply:TeamDisband()
            end
        end)
        
        hook.Add("ShowSpare2", "BW_TeamMenu_F4_Open", function(ply)
            net.Start("BW_Team_OpenMenu")
            net.Send(ply)
            return false
        end)
    end
end

if CLIENT then
    function MODULE:InitClient()
        net.Receive("BW_Team_Sync", function()
            local len = net.ReadUInt(16)
            if len == 0 then return end
            
            local compressed = net.ReadData(len)
            local decompressed = util.Decompress(compressed)
            if not decompressed then return end
            
            local data = util.JSONToTable(decompressed) or {}
            
            for index, tData in pairs(data) do
                team.SetUp(index, tData.Name, tData.Color, true)
            end
            
            BW.Teams.Data = data
            hook.Run("BW_Team_DataUpdated")
        end)
    end

    function PLAYER:TeamCreate(name, pwd, color)
        net.Start("BW_Team_Create")
        net.WriteString(name or "")
        net.WriteString(pwd or "")
        net.WriteColor(color or Color(255, 255, 255))
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

    function PLAYER:GetTeamData()
        return BW.Teams.Data[self:Team()]
    end
end