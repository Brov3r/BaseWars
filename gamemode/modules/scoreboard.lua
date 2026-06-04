MODULE.Name   = "Scoreboard"
MODULE.Author = "Brov3r"
MODULE.Realm  = BW.REALM_CLIENT

local translate = (BW.Translate and BW.Translate.Scoreboard) or {}

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
        BW.Log("error", "Failed to create ScoreboardUI. Make sure it is defined.")
        return 
    end
    
    self.scoreboardPanel:AddColumn({
        id = "nick", 
        header = translate.Nick or "Player", 
        icon = "icon16/user.png", 
        width = 150, 
        align = TEXT_ALIGN_LEFT
    })
    
    self.scoreboardPanel:AddColumn({
        id = "team", 
        header = translate.Team or "Team", 
        icon = "icon16/group.png", 
        width = 250, 
        align = TEXT_ALIGN_CENTER, 
        maxWidth = 200,
        getter = function(ply) return team.GetName(ply:Team()) or "-" end
    })
    
    self.scoreboardPanel:AddColumn({
        id = "kills", 
        header = translate.Kills or "Kills", 
        icon = "icon16/star.png", 
        width = 110, 
        align = TEXT_ALIGN_CENTER,
        getter = function(ply) return BW.Utils.StringNumber(ply:GetKills() or 0) end
    })

    self.scoreboardPanel:AddColumn({
        id = "deaths", 
        header = translate.Deaths or "Deaths", 
        icon = "icon16/cross.png", 
        width = 90, 
        align = TEXT_ALIGN_CENTER,
        getter = function(ply) return BW.Utils.StringNumber(ply:GetDeaths() or 0) end
    })

    self.scoreboardPanel:AddColumn({
        id = "ping", 
        header = translate.Ping or "Ping", 
        icon = "icon16/connect.png", 
        width = 110, 
        align = TEXT_ALIGN_CENTER,
        getter = function(ply) return BW.Utils.StringNumber(ply:Ping() or 0) end
    })

    self.scoreboardPanel:Build()
end

function MODULE:RegisterHooks()
    hook.Add("ScoreboardShow", "BW_ScoreboardShow", function()
        self:CreateScoreboard()
        return false
    end)

    hook.Add("ScoreboardHide", "BW_ScoreboardHide", function()
        if IsValid(self.scoreboardPanel) then
            self.scoreboardPanel:AlphaTo(0, 0.2, 0, function()
                if IsValid(self.scoreboardPanel) then
                    self.scoreboardPanel:Remove()
                    self.scoreboardPanel = nil
                end
            end)
        end
    end)

    hook.Add("PlayerDisconnected", "BW_ScoreboardCleanup", function()
        if IsValid(self.scoreboardPanel) then
            self.scoreboardPanel:Remove()
            self.scoreboardPanel = nil
        end
    end)
end