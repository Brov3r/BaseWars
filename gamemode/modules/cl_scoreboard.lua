local MODULE = MODULE

MODULE.Name = "Scoreboard"
MODULE.Author = "Brov3r"
MODULE.Require = { "database" }


function MODULE:Init()
	self.scoreboardPanel = nil
    self:RegisterHooks()
end

function MODULE:CreateScoreboard()
    if IsValid(self.scoreboardPanel) then
        self.scoreboardPanel:Remove()
    end

    self.scoreboardPanel = vgui.Create("ScoreboardUI")
    if not IsValid(self.scoreboardPanel) then 
        return 
    end
    
    local function GetPlayerGroupIcon(ply)
        local group = ply:GetUserGroup()
        local groupCfg = BW.Config.PlayerGroups and BW.Config.PlayerGroups[group]
        return groupCfg and groupCfg.PrefixIcon or nil
    end
    
    self.scoreboardPanel:AddColumn({
        id = "nick", 
        header = Translate("Scoreboard.Nick", "Player"), 
        icon = "icon16/user.png", 
        width = 180,
        maxWidth = 150,
        align = TEXT_ALIGN_LEFT,
        hasAvatar = true,
        hasPrefixIcon = true,
        prefixIconGetter = GetPlayerGroupIcon,
        getter = function(ply) return ply:Nick() or "-" end
    })
    
    self.scoreboardPanel:AddColumn({
        id = "team", 
        header = Translate("Scoreboard.Team", "Team"), 
        icon = "icon16/group.png", 
        width = 320, 
        align = TEXT_ALIGN_CENTER, 
        maxWidth = 150,
        getter = function(ply) return team.GetName(ply:Team()) or "-" end
    })
    
    self.scoreboardPanel:AddColumn({
        id = "kills", 
        header = "", 
        icon = "icon16/gun.png", 
        width = 50, 
        align = TEXT_ALIGN_CENTER,
        getter = function(ply) return BW.Utils.NumWithSep(ply:GetKills() or 0) end
    })

    self.scoreboardPanel:AddColumn({
        id = "deaths", 
        header = "", 
        icon = "icon16/cross.png", 
        width = 50, 
        align = TEXT_ALIGN_CENTER,
        getter = function(ply) return BW.Utils.NumWithSep(ply:GetDeaths() or 0) end
    })

	self.scoreboardPanel:AddColumn({
        id = "reputation", 
        header = "", 
        icon = "icon16/heart.png", 
        width = 50, 
        align = TEXT_ALIGN_CENTER,
        getter = function(ply) return BW.Utils.NumWithSep(ply:GetReputation() or 0) end
    })

    self.scoreboardPanel:AddColumn({
        id = "ping", 
        header = "", 
        icon = "icon16/connect.png", 
        width = 50, 
        align = TEXT_ALIGN_CENTER,
        getter = function(ply) return BW.Utils.NumWithSep(ply:Ping() or 0) end
    })

    self.scoreboardPanel:Build()
end

function MODULE:RegisterHooks()
    hook.Add("ScoreboardShow", "BW_ScoreboardShow", function()
        MODULE:CreateScoreboard()
        return false
    end)

    hook.Add("ScoreboardHide", "BW_ScoreboardHide", function()
        if IsValid(MODULE.scoreboardPanel) then
            MODULE.scoreboardPanel:AlphaTo(0, 0.2, 0, function()
                if IsValid(MODULE.scoreboardPanel) then
                    MODULE.scoreboardPanel:Remove()
                    MODULE.scoreboardPanel = nil
                end
            end)
        end
    end)

    hook.Add("PlayerDisconnected", "BW_ScoreboardCleanup", function()
        if IsValid(MODULE.scoreboardPanel) then
            MODULE.scoreboardPanel:Remove()
            MODULE.scoreboardPanel = nil
        end
    end)
end