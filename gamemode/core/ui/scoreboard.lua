local scoreboardPanel = nil

local function CreateScoreboard()
    if IsValid(scoreboardPanel) then
        scoreboardPanel:Remove()
        scoreboardPanel = nil
    end

    scoreboardPanel = vgui.Create("ScoreboardUI")
    
    scoreboardPanel:AddColumn({
        id = "nick", header = BW.Translate.Scoreboard.Nick or "Player", icon = "icon16/user.png", 
        width = 150, align = TEXT_ALIGN_LEFT
    })
    
    scoreboardPanel:AddColumn({
        id = "team", header = BW.Translate.Scoreboard.Team or  "Team", icon = "icon16/group.png", 
        width = 250, align = TEXT_ALIGN_CENTER, maxWidth = 200,
        getter = function(ply) return team.GetName(ply:Team()) or "-" end
    })
    
    scoreboardPanel:AddColumn({
        id = "kills", header = BW.Translate.Scoreboard.Kills or  "Kills", icon = "icon16/star.png", 
        width = 110, align = TEXT_ALIGN_CENTER,
        getter = function(ply) return BW.Utils.StringNumber(ply:GetKills()) or 0 end
    })

    scoreboardPanel:AddColumn({
        id = "deaths", header = BW.Translate.Scoreboard.Deaths or "Deaths", icon = "icon16/cross.png", 
        width = 90, align = TEXT_ALIGN_CENTER,
        getter = function(ply) return BW.Utils.StringNumber(ply:GetDeaths()) or 0 end
    })

    scoreboardPanel:AddColumn({
        id = "ping", header = BW.Translate.Scoreboard.Ping or "Ping", icon = "icon16/connect.png", 
        width = 110, align = TEXT_ALIGN_CENTER,
        getter = function(ply) return BW.Utils.StringNumber(ply:Ping()) or 0 end
    })

    scoreboardPanel:Build()
end

hook.Add("ScoreboardShow", "BW_ScoreboardShow", function()
    CreateScoreboard()
    return false
end)

hook.Add("ScoreboardHide", "BW_ScoreboardHide", function()
    if IsValid(scoreboardPanel) then
        scoreboardPanel:AlphaTo(0, 0.2, 0, function()
            if IsValid(scoreboardPanel) then
                scoreboardPanel:Remove()
                scoreboardPanel = nil
            end
        end)
    end
end)

hook.Add("PlayerDisconnected", "BW_ScoreboardCleanup", function()
    if IsValid(scoreboardPanel) then
        scoreboardPanel:Remove()
        scoreboardPanel = nil
    end
end)