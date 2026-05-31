local config = BW.Config
local colors = config.Colors
local sbConfig = config.Scoreboard
local spacing = sbConfig.Spacing
local translate = BW.Translate.Scoreboard

local COLUMNS = {
    {
        id = "nick",
        header = translate.Nick or "Player",
        icon = "icon16/user.png",
        width = 200,
        align = TEXT_ALIGN_LEFT,
        color = colors.White,
        noAutoDraw = true
    },
    {
        id = "team",
        header = translate.Team or "Team",
        icon = "icon16/group.png",
        width = 220,
        align = TEXT_ALIGN_CENTER,
        color = colors.White,
        getter = function(ply) return team.GetName(ply:Team()) or "-" end,
        maxWidth = 200
    },
    {
        id = "kills",
        header = translate.Kills or "Kills",
        icon = "icon16/star.png",
        width = 110,
        align = TEXT_ALIGN_CENTER,
        color = colors.White,
        getter = function(ply) return tostring(ply:GetKills() or 0) end
    },
    {
        id = "deaths",
        header = translate.Deaths or "Deaths",
        icon = "icon16/cross.png",
        width = 110,
        align = TEXT_ALIGN_CENTER,
        color = colors.White,
        getter = function(ply) return tostring(ply:GetDeaths() or 0) end
    },
    {
        id = "ping",
        header = translate.Ping or "Ping",
        icon = "icon16/connect.png",
        width = 100,
        align = TEXT_ALIGN_CENTER,
        color = colors.White,
        getter = function(ply) return tostring(ply:Ping() or 0) end
    }
}

local AVATAR_SIZE      = sbConfig.AvatarSize
local AVATAR_OFFSET_X  = sbConfig.AvatarOffsetX
local MUTE_BTN_WIDTH   = sbConfig.MuteBtnWidth
local MUTE_BTN_MARGIN  = sbConfig.MuteBtnMargin
local PANEL_WIDTH      = sbConfig.PanelWidth
local PANEL_MAX_HEIGHT = sbConfig.PanelMaxHeight
local HEADER_HEIGHT    = sbConfig.HeaderHeight
local ROW_HEIGHT       = sbConfig.RowHeight
local LEFT_MARGIN      = sbConfig.LeftMargin

local scoreboardPanel = nil

local iconMaterials = {}
local function GetIconMaterial(path)
    if not iconMaterials[path] then
        iconMaterials[path] = Material(path, "smooth")
    end
    return iconMaterials[path]
end

local function TruncateText(text, font, maxWidth)
    if maxWidth <= 0 then return text end
    surface.SetFont(font)
    if surface.GetTextSize(text) <= maxWidth then return text end
    while #text > 1 and surface.GetTextSize(text .. "...") > maxWidth do
        text = string.sub(text, 1, -2)
    end
    return text .. "..."
end

local function ComputeColumnPositions()
    local pos = {}
    local x = LEFT_MARGIN
    for i, col in ipairs(COLUMNS) do
        pos[i] = x
        x = x + col.width
    end
    return pos
end

local function RowPaint(self, w, h)
    surface.SetDrawColor(colors.DarkGray45)
    surface.DrawRect(0, 0, w, h)

    local y = h / 2
    local colPositions = self.colPositions
    if not colPositions then return end

    if self.nick then
        draw.SimpleText(self.nick, "Inter16Thin", AVATAR_OFFSET_X, y, colors.White, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    for i = 2, #COLUMNS do
        local col = COLUMNS[i]
        local value = self["col_" .. col.id]
        if value then
            local displayValue = value
            if col.maxWidth then
                displayValue = TruncateText(displayValue, "Inter16Thin", col.maxWidth)
            end

            local left = colPositions[i] - LEFT_MARGIN
            local x = left
            if col.align == TEXT_ALIGN_CENTER then
                x = left + col.width / 2
            elseif col.align == TEXT_ALIGN_RIGHT then
                x = left + col.width - 5
            end

            local textColor = self["col_color_" .. col.id] or col.color

            draw.SimpleText(displayValue, "Inter16Thin", x, y, textColor, col.align, TEXT_ALIGN_CENTER)
        end
    end
end

local function CreateScoreboard()
    if IsValid(scoreboardPanel) then
        scoreboardPanel:Close()
    end

    local scrW, scrH = ScrW(), ScrH()
    local panelW = math.min(scrW * 0.85, PANEL_WIDTH)
    local panelH = math.min(scrH * 0.75, PANEL_MAX_HEIGHT)
    local panelX = (scrW - panelW) / 2
    local panelY = (scrH - panelH) / 2

    scoreboardPanel = vgui.Create("DFrame")
    scoreboardPanel:SetSize(panelW, panelH)
    scoreboardPanel:SetPos(panelX, panelY)
    scoreboardPanel:SetTitle("")
    scoreboardPanel:ShowCloseButton(false)
    scoreboardPanel:SetDraggable(false)
    scoreboardPanel:MakePopup()
    scoreboardPanel:SetAlpha(0)
    scoreboardPanel:AlphaTo(255, 0.2)

    scoreboardPanel.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, colors.DarkGray)
        draw.RoundedBox(8, 1, 1, w - 2, h - 2, colors.DarkGray35)
        draw.SimpleText(GetHostName(), "Inter24", w/2, 15, colors.White, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end

    local colPositions = ComputeColumnPositions()
    local rowW = panelW - LEFT_MARGIN * 2

    local headerPanel = vgui.Create("DPanel", scoreboardPanel)
    headerPanel:SetPos(LEFT_MARGIN, 50)
    headerPanel:SetSize(rowW, HEADER_HEIGHT)
    headerPanel.Paint = function(self, w, h)
        surface.SetDrawColor(colors.BlackAlpha200)
        surface.DrawRect(0, 0, w, h)

        local firstCol = COLUMNS[1]
        local iconMat = firstCol.icon and GetIconMaterial(firstCol.icon)
        if iconMat and not iconMat:IsError() then
            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetMaterial(iconMat)
            surface.DrawTexturedRect(5, h/2 - 8, 16, 16)
        end
        draw.SimpleText(firstCol.header or "", "Inter18", AVATAR_OFFSET_X, h/2, colors.White, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        for i = 2, #COLUMNS do
            local col = COLUMNS[i]
            local left = colPositions[i] - LEFT_MARGIN
            local centerX = left + col.width / 2

            surface.SetFont("Inter18")
            local textW = surface.GetTextSize(col.header or "")
            local iconW = 16
            local gap = 6
            local totalW = iconW + gap + textW
            local startX = centerX - totalW / 2

            local iconMat = col.icon and GetIconMaterial(col.icon)
            if iconMat and not iconMat:IsError() then
                surface.SetDrawColor(255, 255, 255, 255)
                surface.SetMaterial(iconMat)
                surface.DrawTexturedRect(startX, h/2 - iconW/2, iconW, iconW)
                draw.SimpleText(col.header or "", "Inter18", startX + iconW + gap, h/2, colors.White, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            else
                draw.SimpleText(col.header or "", "Inter18", centerX, h/2, colors.White, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
    end

    local container = vgui.Create("DScrollPanel", scoreboardPanel)
    container:SetPos(LEFT_MARGIN, 80)
    container:SetSize(rowW, panelH - 100)

    local rows = {}

    local function RefreshRows()
        local players = player.GetAll()
        table.sort(players, function(a, b)
            local teamA = tonumber(a:Team()) or 0
            local teamB = tonumber(b:Team()) or 0
            if teamA == teamB then
                return a:Nick():lower() < b:Nick():lower()
            end
            return teamA > teamB
        end)

        while #rows > #players do
            local row = table.remove(rows)
            if IsValid(row) then row:Remove() end
        end

        for i = #rows + 1, #players do
            local row = vgui.Create("DPanel", container)
            row:SetTall(ROW_HEIGHT)
            row:Dock(TOP)
            row:DockMargin(0, spacing, 0, spacing)
            row.Paint = RowPaint
            row.index = i
            row.colPositions = colPositions

            local avatar = vgui.Create("CircularAvatar", row)
            avatar:SetSize(AVATAR_SIZE, AVATAR_SIZE)
            avatar:SetPos(5, (ROW_HEIGHT - AVATAR_SIZE) / 2)
            row.avatar = avatar
            row._cachedPly = nil

            local muteBtn = vgui.Create("DButton", row)
            muteBtn:SetSize(MUTE_BTN_WIDTH, MUTE_BTN_WIDTH)
            muteBtn:SetPos(rowW - MUTE_BTN_WIDTH - MUTE_BTN_MARGIN, (ROW_HEIGHT - MUTE_BTN_WIDTH) / 2)
            muteBtn:SetText("")
            muteBtn.Paint = function(self, w, h)
                local muted = self._muted
                local iconPath = muted and "icon16/sound_mute.png" or "icon16/sound.png"
                local iconMat = GetIconMaterial(iconPath)
                if iconMat and not iconMat:IsError() then
                    surface.SetDrawColor(255, 255, 255, 255)
                    surface.SetMaterial(iconMat)
                    surface.DrawTexturedRect(4, 4, 16, 16)
                end
            end
            muteBtn.DoClick = function(self)
                local target = self._ply
                if IsValid(target) and target ~= LocalPlayer() then
                    target:SetMuted(not target:IsMuted())
                    self._muted = target:IsMuted()
                end
            end
            row.muteBtn = muteBtn
            rows[i] = row
        end

        for i, ply in ipairs(players) do
            if not IsValid(ply) then continue end
            local row = rows[i]
            row.ply = ply
            row.index = i
            row.nick = ply:Nick()

            for j = 2, #COLUMNS do
                local col = COLUMNS[j]
                local val = col.getter(ply)
                row["col_" .. col.id] = val
                
                if col.id == "team" then
                    row["col_color_team"] = team.GetColor(ply:Team()) or colors.White
                end
            end

            if row._cachedPly ~= ply then
                row.avatar:SetPlayer(ply, 64)
                row._cachedPly = ply
            end

            local btn = row.muteBtn
            btn._ply = ply
            btn._muted = ply:IsMuted()
            btn:SetVisible(ply ~= LocalPlayer())
        end
    end

    RefreshRows()
end

hook.Add("ScoreboardShow", "BW_ScoreboardShow", function()
    CreateScoreboard()
    return false
end)

hook.Add("ScoreboardHide", "BW_ScoreboardHide", function()
    if IsValid(scoreboardPanel) then
        scoreboardPanel:AlphaTo(0, 0.2, 0, function()
            if IsValid(scoreboardPanel) then
                scoreboardPanel:Close()
                scoreboardPanel = nil
            end
        end)
    end
end)

hook.Add("PlayerDisconnected", "BW_ScoreboardCleanup", function()
    if IsValid(scoreboardPanel) then
        scoreboardPanel:Close()
        scoreboardPanel = nil
    end
end)