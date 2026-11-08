local iconMaterials = {}
local function GetIconMaterial(path)
    if not iconMaterials[path] then iconMaterials[path] = Material(path, "smooth") end
    return iconMaterials[path]
end

local function Icon(path, x, y, size, color)
    local material = GetIconMaterial(path)
    if material:IsError() then return end
    surface.SetMaterial(material)
    surface.SetDrawColor(color or color_white)
    surface.DrawTexturedRect(x, y, size, size)
end

local PANEL = {}

function PANEL:Init()
    local cfg = BW.Config.Scoreboard or {}
    local opacity = tonumber(cfg.Opacity)
    if not BW.Utils.IsFinite(opacity) then opacity = 0.88 end
    local alpha = math.floor(math.Clamp(opacity, 0.4, 1) * 255)
    self.PanelWidth = cfg.PanelWidth or 1060
    self.PanelMaxHeight = cfg.PanelMaxHeight or 780
    self.RowHeight = math.max(72, cfg.RowHeight or 72)
    self.LeftMargin = 24
    self.AvatarSize = 44
    self.NewPlayerMinutes = math.max(0, tonumber(cfg.NewPlayerMinutes) or 60)
    self.NewPlayerLabel = "NEW"
    self.Columns, self.Rows = {}, {}
    self.Colors = {
        White = Color(255, 255, 255), Muted = Color(155, 168, 182),
        Background = Color(13, 18, 24, alpha), Border = Color(65, 81, 94), RowBorder = Color(50, 64, 77),
        Row = Color(24, 31, 40, alpha * 0.35), Hover = Color(32, 43, 53, alpha * 0.35),
        Accent = cfg.AccentColor or Color(62, 214, 153),
        Red = Color(240, 115, 120), Gold = Color(235, 192, 102)
    }
    self:SetAlpha(0)
end

function PANEL:AddColumn(data)
    self.Columns[#self.Columns + 1] = {
        id = data.id, header = data.header or "", icon = data.icon,
        width = data.width or 100, getter = data.getter, color = data.color,
        align = data.align or TEXT_ALIGN_CENTER, hasAvatar = data.hasAvatar,
        hasPrefixIcon = data.hasPrefixIcon, prefixIconGetter = data.prefixIconGetter
    }
end

function PANEL:ComputeColumnPositions()
    local total = 0
    for _, col in ipairs(self.Columns) do total = total + col.width end
    local available = math.max(1, self.bodyW - 48)
    local x = 0
    for _, col in ipairs(self.Columns) do
        col.left = x
        col.actualWidth = available * col.width / math.max(1, total)
        x = x + col.actualWidth
    end
end

function PANEL:Build()
    self:SetSize(math.min(ScrW() * 0.94, self.PanelWidth), math.min(ScrH() * 0.88, self.PanelMaxHeight))
    self:Center()
    self:MakePopup()
    -- Do not consume movement/chat binds while TAB is held.
    self:SetKeyboardInputEnabled(false)
    self:AlphaTo(255, 0.16)
    self.rowW = self:GetWide() - self.LeftMargin * 2
    self.bodyW = self.rowW - 18
    self:ComputeColumnPositions()

    self:CreateHeader()
    self:CreateContainer()
    self:RefreshRows()
    self.NextRefresh = RealTime() + 1
end

function PANEL:CreateHeader()
    self.headerPanel = vgui.Create("DPanel", self)
    self.headerPanel:SetPos(self.LeftMargin, 128)
    self.headerPanel:SetSize(self.rowW, 38)
    self.headerPanel.Paint = function(_, w, h)
        for _, col in ipairs(self.Columns) do
            local x = col.left + col.actualWidth / 2
            local title = col.header
            if col.id == "nick" then
                draw.SimpleText(title, "Inter18", 16, h / 2, self.Colors.White, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            elseif col.id == "team" then
                draw.SimpleText(title, "Inter18", x, h / 2, self.Colors.White, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            elseif col.icon then
                Icon(col.icon, x - 9, h / 2 - 9, 18, self.Colors.White)
            end
        end
        surface.SetDrawColor(self.Colors.Border)
        surface.DrawRect(0, h - 1, w, 1)
    end
    for _, col in ipairs(self.Columns) do
        local tooltip = vgui.Create("DPanel", self.headerPanel)
        tooltip:SetPos(col.left, 0)
        tooltip:SetSize(col.actualWidth, 37)
        tooltip:SetTooltip(Translate("Scoreboard." .. string.upper(col.id:sub(1, 1)) .. col.id:sub(2), col.header))
        tooltip.Paint = function() end
    end
end

function PANEL:CreateContainer()
    self.container = vgui.Create("DScrollPanel", self)
    self.container:SetPos(self.LeftMargin, 174)
    self.container:SetSize(self.rowW, math.max(24, self:GetTall() - 198))
    local vbar = self.container:GetVBar()
    vbar:SetWide(6)
    vbar:SetHideButtons(true)
    vbar.btnUp.Paint = function() end
    vbar.btnDown.Paint = function() end
    vbar.Paint = function(_, w, h) draw.RoundedBox(3, 0, 0, w, h, self.Colors.Row) end
    vbar.btnGrip.Paint = function(grip, w, h)
        draw.RoundedBox(3, 0, 0, w, h, (grip.Depressed or grip:IsHovered()) and self.Colors.Accent or Color(63, 91, 91))
    end
end

function PANEL:PaintPlayerRow(row, w, h)
    if not IsValid(row.ply) then return end
    local c = self.Colors
    row.HoverAmount = math.Approach(row.HoverAmount or 0, row:IsHovered() and 1 or 0, FrameTime() * 7)
    row.BackgroundColor = row.BackgroundColor or Color(24, 31, 40, c.Row.a)
    local background = row.BackgroundColor
    background.r = Lerp(row.HoverAmount, c.Row.r, c.Hover.r)
    background.g = Lerp(row.HoverAmount, c.Row.g, c.Hover.g)
    background.b = Lerp(row.HoverAmount, c.Row.b, c.Hover.b)
    draw.RoundedBox(9, 0, 0, w, h, background)
    BW.Utils.DrawRoundedOutline(9, 0, 0, w, h, c.RowBorder)
    local avatarY = (h - self.AvatarSize) / 2
    draw.RoundedBox(25, 12, avatarY - 3, 50, 50, row.TeamColor)
    local y = h / 2
    for _, col in ipairs(self.Columns) do
        local value = row.Values[col.id]
        if value == nil then continue end
        local x, width = col.left, col.actualWidth
        local center = x + width / 2
        if col.id == "nick" then
            local nickX = 76
            local mat = row.PrefixIcon
            local nickY = 25
            if mat then Icon(mat, nickX, nickY - 8, 16) nickX = nickX + 23 end
            local name = BW.Utils.TruncateText(tostring(value), "Inter20", math.max(1, width - nickX - 12))
            draw.SimpleText(name, "Inter20", nickX, nickY, row.Alive and c.White or c.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            local subtitle = BW.Utils.TruncateText(row.Subtitle, "Inter16Thin", math.max(1, width - 88))
            draw.SimpleText(subtitle, "Inter16Thin", 76, 40, row.GroupColor)
        elseif col.id == "team" then
            local label = BW.Utils.TruncateText(tostring(value), "Inter18", math.max(1, width - 32))
            surface.SetFont("Inter18")
            local pillW = math.min(width - 12, surface.GetTextSize(label) + 22)
            draw.RoundedBox(6, center - pillW / 2, y - 17, pillW, 34, Color(row.TeamColor.r, row.TeamColor.g, row.TeamColor.b, 22))
            draw.SimpleText(label, "Inter18", center, y, row.TeamColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        elseif col.id == "ping" then
            local ping = row.Ping
            local color = ping < 80 and c.Accent or (ping < 150 and c.Gold or c.Red)
            local bars = ping < 80 and 4 or (ping < 150 and 3 or (ping < 250 and 2 or 1))
            for i = 1, 4 do
                surface.SetDrawColor(i <= bars and color or c.Border)
                surface.DrawRect(center - 24 + (i - 1) * 4, y + 6 - i * 3, 2, i * 3)
            end
            draw.SimpleText(row.IsBot and "BOT" or tostring(ping), "Inter18", center + 3, y, c.White, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        else
            draw.SimpleText(BW.Utils.TruncateText(tostring(value), "Inter20", math.max(1, width - 8)), "Inter20", center, y, c.White, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
end

function PANEL:NotifyAction(kind, text)
    local ply = LocalPlayer()
    if IsValid(ply) and ply.Notify then ply:Notify(kind, text, 3) end
end

function PANEL:IsNewPlayer(ply)
    if self.NewPlayerMinutes <= 0 or ply:IsBot() then return false end
    if not ply.GetCreatedAt or ply:GetCreatedAt() <= 0 or not ply.GetPlayTime then return false end
    return ply:GetPlayTime() < self.NewPlayerMinutes
end

function PANEL:CreatePlayerRow()
    local row = vgui.Create("DButton", self.container)
    row:SetText("")
    row:SetTall(self.RowHeight)
    row:Dock(TOP)
    row:DockMargin(0, 0, 10, 6)
    row.Paint = function(panel, w, h) self:PaintPlayerRow(panel, w, h) end
    row.PaintOver = function(panel)
        if not panel.IsNew or not IsValid(panel.ply) then return end
        surface.SetFont("Inter10")
        local badgeW = surface.GetTextSize(self.NewPlayerLabel) + 6
        local x = 15 + self.AvatarSize - badgeW + 4
        local y = math.max(0, (self.RowHeight - self.AvatarSize) / 2 - 4)
        draw.RoundedBox(4, x, y, badgeW, 13, self.Colors.Accent)
        draw.SimpleText(self.NewPlayerLabel, "Inter10", x + badgeW / 2, y + 6.5, self.Colors.Background, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    row.DoClick = function()
        local target = row.ply
        if not IsValid(target) then
            self:NotifyAction(NOTIFY_ERROR, Translate("Scoreboard.PlayerUnavailable", "This player is no longer available."))
            return
        end
        local menu = DermaMenu()
        if not target:IsBot() then
            menu:AddOption(Translate("Scoreboard.Profile", "Steam profile"), function()
                if not IsValid(target) then
                    self:NotifyAction(NOTIFY_ERROR, Translate("Scoreboard.PlayerUnavailable", "This player is no longer available."))
                    return
                end
                target:ShowProfile()
                self:NotifyAction(NOTIFY_INFO, string.format(Translate("Scoreboard.ProfileOpened", "Opening %s's Steam profile."), target:Nick()))
            end):SetIcon("icon16/user.png")
        end
        menu:AddOption(Translate("Scoreboard.CopySteamID", "Copy SteamID"), function()
            if not IsValid(target) then
                self:NotifyAction(NOTIFY_ERROR, Translate("Scoreboard.PlayerUnavailable", "This player is no longer available."))
                return
            end
            local steamID = target:SteamID()
            SetClipboardText(steamID)
            self:NotifyAction(NOTIFY_SUCCESS, string.format(Translate("Scoreboard.SteamIDCopied", "SteamID copied: %s"), steamID))
        end):SetIcon("icon16/page_copy.png")
        menu:Open()
    end
    row.DoRightClick = row.DoClick
    row.avatar = vgui.Create("CircularAvatar", row)
    row.avatar:SetSize(self.AvatarSize, self.AvatarSize)
    row.avatar:SetPos(15, (self.RowHeight - self.AvatarSize) / 2)
    row.avatar:SetMouseInputEnabled(false)
    row.muteBtn = vgui.Create("DButton", row)
    row.muteBtn:SetSize(30, 30)
    row.muteBtn:SetText("")
    row.muteBtn:SetTooltip(Translate("Scoreboard.Mute", "Toggle voice mute"))
    row.muteBtn.Paint = function(button, w, h)
        draw.RoundedBox(7, 0, 0, w, h, button:IsHovered() and self.Colors.Border or self.Colors.Background)
        Icon(button.Muted and "icon16/sound_mute.png" or "icon16/sound.png", 7, 7, 16, button.Muted and self.Colors.Red or self.Colors.Muted)
    end
    row.muteBtn.DoClick = function(button)
        if not IsValid(row.ply) or row.ply == LocalPlayer() then return end
        row.ply:SetMuted(not row.ply:IsMuted())
        button.Muted = row.ply:IsMuted()
        local message = button.Muted and Translate("Scoreboard.VoiceMuted", "%s's voice is muted.")
            or Translate("Scoreboard.VoiceUnmuted", "%s's voice is unmuted.")
        self:NotifyAction(NOTIFY_INFO, string.format(message, row.ply:Nick()))
        surface.PlaySound("garrysmod/ui_click.wav")
    end
    row.PerformLayout = function(panel, w)
        panel.muteBtn:SetPos(self.bodyW - 34, (self.RowHeight - 30) / 2)
    end
    return row
end

function PANEL:RefreshRows()
    if not IsValid(self.container) then return end
    local players = player.GetAll()
    self.OnlineCount = #players
    self.TeamCount = 0
    local seenTeams, visible = {}, {}
    for _, ply in ipairs(players) do
        local index = ply:Team()
        if index ~= BW.TEAM_DEFAULT and not seenTeams[index] then
            seenTeams[index] = true
            self.TeamCount = self.TeamCount + 1
        end
        visible[#visible + 1] = ply
    end
    table.sort(visible, function(a, b)
        if a:Team() ~= b:Team() then return a:Team() > b:Team() end
        if a:Nick() ~= b:Nick() then return a:Nick():lower() < b:Nick():lower() end
        return a:EntIndex() < b:EntIndex()
    end)
    self.VisibleCount = #visible
    while #self.Rows > #visible do table.remove(self.Rows):Remove() end
    for i, ply in ipairs(visible) do
        local row = self.Rows[i]
        if not IsValid(row) then row = self:CreatePlayerRow() self.Rows[i] = row end
        row.ply, row.Values = ply, {}
        row.TeamColor = team.GetColor(ply:Team()) or self.Colors.Muted
        row.Alive, row.IsBot, row.Ping = ply:Alive(), ply:IsBot(), math.max(0, ply:Ping())
        row.IsNew = self:IsNewPlayer(ply)
        row.avatar:SetPos(15, (self.RowHeight - self.AvatarSize) / 2)
        local group = BW.Config.PlayerGroups[ply:GetUserGroup()]
        row.GroupColor = group and group.PrefixColor or self.Colors.Muted
        local status = group and group.PrefixText or Translate("Scoreboard.Player", "Player")
        row.Subtitle = status .. "  ·  " .. Translate("Scoreboard.Level", "LVL") .. " " .. tostring(ply.GetLevel and ply:GetLevel() or 1)
        if not row.Alive then row.Subtitle = row.Subtitle .. "  ·  " .. Translate("Scoreboard.Dead", "Dead") end
        for _, col in ipairs(self.Columns) do
            if col.getter then row.Values[col.id] = col.getter(ply) end
            if col.prefixIconGetter then row.PrefixIcon = col.prefixIconGetter(ply) end
        end
        if row.CachedPlayer ~= ply then row.avatar:SetPlayer(ply, 64) row.CachedPlayer = ply end
        row.muteBtn.Muted = ply:IsMuted()
        row.muteBtn:SetVisible(ply ~= LocalPlayer())
    end
    self.container:InvalidateLayout(true)
end

function PANEL:Think()
    if self.NextRefresh and RealTime() >= self.NextRefresh then
        self.NextRefresh = RealTime() + 1
        self:RefreshRows()
    end
end

function PANEL:Paint(w, h)
    local c = self.Colors
    draw.RoundedBox(14, 0, 0, w, h, c.Background)
    BW.Utils.DrawRoundedOutline(14, 0, 0, w, h, c.Border)
    surface.SetFont("Inter28")
    local titleW = surface.GetTextSize("BASEWARS")
    draw.RoundedBox(2, self.LeftMargin, 17, titleW, 3, c.Accent)
    draw.SimpleText("BASEWARS", "Inter28", self.LeftMargin, 27, c.White)
    draw.SimpleText(BW.Utils.TruncateText(GetHostName(), "Inter24Thin", w - 52), "Inter24Thin", self.LeftMargin, 64, c.White)
    draw.SimpleText(game.GetMap() .. "  /  " .. Translate("Scoreboard.Teams", "Teams") .. ": " .. tostring(self.TeamCount or 0), "Inter18Thin", self.LeftMargin, 96, c.Muted)
    local online = tostring(self.OnlineCount or 0) .. " / " .. game.MaxPlayers()
    surface.SetFont("Inter16")
    local textW = surface.GetTextSize(online)
    local contentW = 6 + 8 + textW
    local badgeW = math.max(92, contentW + 24)
    local badgeX = w - self.LeftMargin - badgeW
    local contentX = badgeX + (badgeW - contentW) / 2
    draw.RoundedBox(7, badgeX, 30, badgeW, 28, Color(c.Accent.r, c.Accent.g, c.Accent.b, 18))
    draw.RoundedBox(3, contentX, 41, 6, 6, c.Accent)
    draw.SimpleText(online, "Inter16", contentX + 14, 44, c.Accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    if self.VisibleCount == 0 then
        draw.SimpleText(Translate("Scoreboard.NoResults", "No players found"), "Inter22Thin", w / 2, math.max(210, h / 2), c.Muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

vgui.Register("ScoreboardUI", PANEL, "EditablePanel")
