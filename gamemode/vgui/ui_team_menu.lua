local ActiveTeamMenu = nil
local TEAM_MENU = {}

local iconCache = {}
local function IconMaterial(path)
    if not iconCache[path] then iconCache[path] = Material(path, "smooth") end
    return iconCache[path]
end

local function DrawIcon(path, x, y, size, color)
    local material = IconMaterial(path)
    if material:IsError() then return end
    surface.SetMaterial(material)
    surface.SetDrawColor(color)
    surface.DrawTexturedRect(x, y, size, size)
end

local function FlatButton(button)
    button:SetPaintBackground(false)
    if button.SetDrawBorder then button:SetDrawBorder(false) end
    return button
end

local function TrimTeamName(name)
    return BW.Utils.UTF8Sub(string.Trim(tostring(name or "")):gsub("[%c]", ""), 1, 32)
end

local function ReadableTeamColor(color)
    local brightness = color.r * 0.299 + color.g * 0.587 + color.b * 0.114
    if brightness >= 105 then return color end
    local mix = (105 - brightness) / 255
    return Color(math.Round(color.r + (255 - color.r) * mix), math.Round(color.g + (255 - color.g) * mix), math.Round(color.b + (255 - color.b) * mix), 255)
end

function TEAM_MENU:Init()
    local cfg = BW.Config.TeamMenu or {}
    local scoreCfg = BW.Config.Scoreboard or {}
    local accent = scoreCfg.AccentColor or Color(62, 214, 153)
    local opacity = tonumber(cfg.Opacity) or 0.95
    if not BW.Utils.IsFinite(opacity) then opacity = 0.95 end
    local alpha = math.floor(math.Clamp(opacity, 0.4, 1) * 255)
    self.Colors = {
        Background = Color(13, 18, 24, alpha), Border = Color(65, 81, 94), RowBorder = Color(50, 64, 77),
        Row = Color(24, 31, 40), Hover = Color(32, 43, 53), Selected = Color(24, 43, 42),
        White = Color(255, 255, 255), Muted = Color(155, 168, 182),
        Accent = accent, Red = Color(240, 115, 120), Gold = Color(235, 192, 102)
    }
    self.Query, self.Filter = "", "all"
    self:SetPaintBackgroundEnabled(false)
    self.Expanded, self.PendingRefresh = {}, false

    self:SetSize(math.min(ScrW() * 0.94, cfg.Width or 1000), math.min(ScrH() * 0.9, cfg.Height or 680))
    self:Center()
    self:MakePopup()
    self:SetKeyboardInputEnabled(true)
    self:SetAlpha(0)
    self:AlphaTo(255, 0.16)

    self.Header = vgui.Create("DPanel", self)
    self.Header:Dock(TOP)
    self.Header:SetTall(54)
    self.Header:SetPaintBackground(false)
    self.Header:SetCursor("sizeall")
    self.Header.Paint = function(_, w, h) self:PaintHeader(w, h) end
    self.Header.OnMousePressed = function(panel, button)
        if button ~= MOUSE_LEFT then return end
        local mouseX, mouseY = gui.MousePos()
        local x, y = self:GetPos()
        self.DragOffset = {x = mouseX - x, y = mouseY - y}
        panel:MouseCapture(true)
    end
    self.Header.OnMouseReleased = function(panel, button)
        if button ~= MOUSE_LEFT then return end
        self.DragOffset = nil
        panel:MouseCapture(false)
    end

    self.CloseButton = FlatButton(vgui.Create("DButton", self.Header))
    self.CloseButton:SetSize(30, 30)
    self.CloseButton:SetText("")
    self.CloseButton:SetTooltip(Translate("Team.MenuClose", "Close"))
    self.CloseButton.Paint = function(button, w, h)
        if button:IsHovered() then draw.RoundedBox(7, 0, 0, w, h, self.Colors.Selected) end
        draw.SimpleText("×", "Inter24", w / 2, h / 2 - 1, button:IsHovered() and self.Colors.Red or self.Colors.Muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    self.CloseButton.DoClick = function() self:CloseMenu() end
    self.Header.PerformLayout = function(_, w)
        self.CloseButton:SetPos(w - 42, 17)
    end

    self.TabContainer = vgui.Create("DPanel", self)
    self.TabContainer:Dock(TOP)
    self.TabContainer:SetTall(44)
    self.TabContainer:SetPaintBackground(false)
    self.TabContainer.Paint = function() end

    self.Content = vgui.Create("DPanel", self)
    self.Content:Dock(FILL)
    self.Content:DockMargin(22, 14, 22, 18)
    self.Content:SetPaintBackground(false)
    self.Content.Paint = function() end

    self.TabButtons = {}
    self:BuildTabs()
    self:SwitchTab("browse")
    self.NextBrowseCheck = RealTime() + 2
end

function TEAM_MENU:Paint(w, h)
    draw.RoundedBox(14, 0, 0, w, h, self.Colors.Background)
    BW.Utils.DrawRoundedOutline(14, 0, 0, w, h, self.Colors.Border)
end

function TEAM_MENU:PaintHeader(w, h)
    local c = self.Colors
    local title = Translate("Team.MenuTitle", "Teams")
    surface.SetFont("Inter24")
    local titleW = surface.GetTextSize(title)
    draw.SimpleText(title, "Inter24", 22, 24, c.White, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.RoundedBox(1, 22, 39, titleW, 2, c.Accent)
    surface.SetDrawColor(c.Border)
    surface.DrawRect(22, h - 1, w - 44, 1)
end

function TEAM_MENU:BuildTabs()
    local tabs = {
        {id = "browse", key = "Team.MenuTeamTab", fallback = "Teams"},
        {id = "manage", key = "Team.MenuControlTab", fallback = "Manage"}
    }
    for _, tab in ipairs(tabs) do
        local button = FlatButton(vgui.Create("DButton", self.TabContainer))
        button:Dock(LEFT)
        button:SetWide(140)
        button:SetText("")
        self.TabButtons[tab.id] = button
        button.Paint = function(panel, w, h)
            local active = self.ActiveTab == tab.id
            local text = Translate(tab.key, tab.fallback)
            surface.SetFont("Inter16")
            local textW = surface.GetTextSize(text)
            local color = active and self.Colors.White or (panel:IsHovered() and self.Colors.White or self.Colors.Muted)
            draw.SimpleText(text, "Inter16", w / 2, h / 2 - 2, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            if active then draw.RoundedBox(1, (w - textW) / 2, h - 8, textW, 2, self.Colors.Accent) end
        end
        button.DoClick = function() self:SwitchTab(tab.id) end
    end
end

function TEAM_MENU:SwitchTab(id)
    self.ActiveTab = id
    self.Content:Clear()
    if id == "browse" then
        self:BuildBrowseContent()
    else
        self:BuildManageContent()
    end
end

function TEAM_MENU:CollectTeams()
    local ply = LocalPlayer()
    local myTeam = IsValid(ply) and ply:Team() or BW.TEAM_DEFAULT
    local list = {}
    for index, teamData in pairs(team.GetAllTeams()) do
        local data = BW.Teams.Data[index]
        local isDefault = index == BW.TEAM_DEFAULT
        local special = index == TEAM_SPECTATOR or index == TEAM_CONNECTING or index == TEAM_UNASSIGNED
        if not special and team.Valid(index) and (isDefault or data) then
            local members = team.GetPlayers(index) or {}
            local leaderName = Translate("Team.MenuCitizenSubtitle", "Open team for all players")
            local leaderOnline = true
            local creator
            if not isDefault then
                creator = data.Creator
                leaderName, leaderOnline = nil, false
                for _, member in ipairs(members) do
                    if member:SteamID64() == creator then
                        leaderName, leaderOnline = member:Nick(), true
                        break
                    end
                end
                leaderName = leaderName or tostring(creator or "?"):sub(-8)
            end
            local count = #members
            local unlimited = isDefault
            local maxPlayers = unlimited and math.huge or math.max(1, tonumber(data and data.MaxPlayers) or 5)
            local hasPassword = data and data.HasPassword == true or false
            local searchParts = {isDefault and Translate("Team.NoTeam", "Citizen") or data.Name or "", leaderName}
            for _, member in ipairs(members) do searchParts[#searchParts + 1] = member:Nick() end
            list[#list + 1] = {
                index = index, default = isDefault,
                name = isDefault and Translate("Team.NoTeam", "Citizen") or data.Name or team.GetName(index) or "?",
                color = isDefault and (team.GetColor(index) or Color(150, 150, 150)) or data.Color or Color(255, 255, 255),
                members = members, count = count, maxPlayers = maxPlayers, unlimited = unlimited,
                leader = leaderName, leaderOnline = leaderOnline,
                hasPassword = hasPassword, creator = creator,
                own = index == myTeam, full = not unlimited and count >= maxPlayers,
                search = string.lower(table.concat(searchParts, " "))
            }
        end
    end
    table.sort(list, function(a, b)
        if a.default ~= b.default then return a.default end
        if a.own ~= b.own then return a.own end
        if a.full ~= b.full then return not a.full end
        if a.count ~= b.count then return a.count > b.count end
        return string.lower(a.name) < string.lower(b.name)
    end)
    self.TeamCount = #list
    self.OnlineCount = #player.GetAll()
    return list
end

function TEAM_MENU:FilterTeams(list)
    local visible, query = {}, string.lower(string.Trim(self.Query or ""))
    for _, item in ipairs(list) do
        local matchesSearch = query == "" or string.find(item.search, query, 1, true) ~= nil
        local matchesFilter = self.Filter == "all"
            or (self.Filter == "open" and not item.hasPassword)
            or (self.Filter == "free" and not item.full)
        if matchesSearch and matchesFilter then visible[#visible + 1] = item end
    end
    return visible
end

function TEAM_MENU:GetSignature(list)
    local parts = {}
    for _, item in ipairs(list) do
        parts[#parts + 1] = table.concat({item.index, item.name, item.count, item.maxPlayers, tostring(item.hasPassword), item.creator or "", item.color.r, item.color.g, item.color.b}, ":")
    end
    table.sort(parts)
    return table.concat(parts, "|")
end

function TEAM_MENU:StyleScroll(scroll)
    local bar = scroll:GetVBar()
    bar:SetWide(6)
    bar:SetHideButtons(true)
    bar.btnUp.Paint = function() end
    bar.btnDown.Paint = function() end
    bar.Paint = function(_, w, h) draw.RoundedBox(3, 0, 0, w, h, self.Colors.Row) end
    bar.btnGrip.Paint = function(grip, w, h)
        draw.RoundedBox(3, 0, 0, w, h, (grip.Depressed or grip:IsHovered()) and self.Colors.Accent or Color(63, 91, 91))
    end
end

function TEAM_MENU:BuildBrowseContent()
    local toolbar = vgui.Create("DPanel", self.Content)
    toolbar:Dock(TOP)
    toolbar:SetTall(42)
    toolbar:DockMargin(0, 0, 8, 10)
    toolbar:SetPaintBackground(false)
    toolbar.Paint = function() end

    local filters = vgui.Create("DPanel", toolbar)
    filters:Dock(LEFT)
    filters:SetWide(240)
    filters:SetPaintBackground(false)
    filters.Paint = function() end
    local options = {
        {id = "all", key = "Team.MenuFilterAll", fallback = "All"},
        {id = "open", key = "Team.MenuFilterOpen", fallback = "Open"},
        {id = "free", key = "Team.MenuFilterFree", fallback = "Free"}
    }
    for _, option in ipairs(options) do
        local button = FlatButton(vgui.Create("DButton", filters))
        button:Dock(LEFT)
        button:SetWide(74)
        button:DockMargin(0, 0, 6, 0)
        button:SetText("")
        button.Paint = function(panel, w, h)
            local active = self.Filter == option.id
            draw.SimpleText(Translate(option.key, option.fallback), "Inter14", w / 2, h / 2,
                active and self.Colors.Accent or (panel:IsHovered() and self.Colors.White or self.Colors.Muted),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        button.DoClick = function()
            self.Filter = option.id
            self:BuildTeamList()
        end
    end

    self.CountLabel = vgui.Create("DLabel", toolbar)
    self.CountLabel:Dock(RIGHT)
    self.CountLabel:SetWide(150)
    self.CountLabel:SetFont("Inter14")
    self.CountLabel:SetTextColor(self.Colors.Muted)
    self.CountLabel:SetContentAlignment(6)

    self.List = vgui.Create("DScrollPanel", self.Content)
    self.List:SetPaintBackground(false)
    self.List:Dock(FILL)
    self:StyleScroll(self.List)
    self:BuildTeamList()
end

function TEAM_MENU:BuildTeamList(keepScroll)
    if not IsValid(self.List) then return end
    local scroll = self.List:GetVBar():GetScroll()
    self.List:Clear()
    local all = self:CollectTeams()
    self.Signature = self:GetSignature(all)
    local visible = self:FilterTeams(all)
    self.VisibleCount = #visible
    if IsValid(self.CountLabel) then
        self.CountLabel:SetText(string.format(Translate("Team.MenuShowing", "%d of %d"), #visible, #all))
    end
    if #visible == 0 then
        local empty = vgui.Create("DPanel", self.List)
        empty:Dock(TOP)
        empty:SetTall(120)
        empty.Paint = function(_, w)
            draw.SimpleText(Translate("Team.MenuEmpty", "No teams found"), "Inter20Thin", w / 2, 58, self.Colors.Muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        return
    end
    for _, item in ipairs(visible) do self:CreateTeamCard(item) end
    if keepScroll then
        timer.Simple(0, function()
            if IsValid(self.List) then self.List:GetVBar():SetScroll(scroll) end
        end)
    end
end

function TEAM_MENU:CreateTeamCard(item)
    local card = vgui.Create("DPanel", self.List)
    card:SetPaintBackground(false)
    card.Paint = function() end
    card:Dock(TOP)
    card:DockMargin(0, 0, 8, 6)
    card:SetTall(72)

    local header = FlatButton(vgui.Create("DButton", card))
    header:Dock(TOP)
    header:SetTall(72)
    header:SetText("")
    header.Paint = function(panel, w, h)
        local c = self.Colors
        local hover = panel:IsHovered()
        draw.RoundedBox(9, 0, 0, w, h, item.own and c.Selected or (hover and c.Hover or c.Row))
        BW.Utils.DrawRoundedOutline(9, 0, 0, w, h, item.own and c.Accent or c.RowBorder)
        local maxName = math.max(40, w - 300)
        local name = BW.Utils.TruncateText(item.name, "Inter20", maxName)
        local badge = item.color
        draw.RoundedBox(25, 12, h / 2 - 25, 50, 50, badge)
        local brightness = badge.r * 0.299 + badge.g * 0.587 + badge.b * 0.114
        local initial = utf8.sub(item.name, 1, 1)
        draw.SimpleText(initial, "Inter24", 37, h / 2 - 1, brightness > 128 and c.Background or c.White, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(name, "Inter20", 76, 21, ReadableTeamColor(item.color), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetFont("Inter20")
        if item.hasPassword and 76 + surface.GetTextSize(name) + 10 < w - 290 then
            DrawIcon("icon16/lock.png", 76 + surface.GetTextSize(name) + 8, 13, 14, c.Gold)
        end
        local leaderText = item.default and item.leader or (Translate("Team.MenuLeader", "Leader") .. ": " .. item.leader)
        if not item.default and not item.leaderOnline then leaderText = leaderText .. " (" .. Translate("Team.Offline", "offline") .. ")" end
        draw.SimpleText(BW.Utils.TruncateText(leaderText, "Inter14", math.max(40, w - 330)), "Inter14", 76, 45, c.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        local countText = item.unlimited and (item.count .. " / ∞") or (item.count .. " / " .. item.maxPlayers)
        draw.SimpleText(countText, "Inter14", w - 132, 24, c.Muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        local barW = 150
        local barX = w - 132 - barW
        draw.RoundedBox(2, barX, 47, barW, 3, Color(c.Border.r, c.Border.g, c.Border.b, 100))
        local fill = item.unlimited and 1 or math.Clamp(item.count / item.maxPlayers, 0, 1)
        if fill > 0 then draw.RoundedBox(2, barX, 47, barW * fill, 3, item.color) end
    end

    local action = FlatButton(vgui.Create("DButton", header))
    action:SetSize(104, 32)
    action:SetText("")
    local myTeam = IsValid(LocalPlayer()) and LocalPlayer():Team() or BW.TEAM_DEFAULT
    local mode, label
    if item.own then
        if item.default then
            mode, label = "blocked", Translate("Team.MenuCurrent", "Current")
        else
            mode, label = "manage", Translate("Team.MenuManage", "Manage")
        end
    elseif item.default then
        mode, label = "join", Translate("Team.MenuBrowseJoinBtn", "Join")
    elseif myTeam ~= BW.TEAM_DEFAULT then
        mode, label = "blocked", Translate("Team.MenuLocked", "In team")
    elseif item.full then
        mode, label = "blocked", Translate("Team.MenuFull", "Full")
    else
        mode, label = "join", Translate("Team.MenuBrowseJoinBtn", "Join")
    end
    action.Mode = mode
    action.Team = item
    action.Paint = function(button, w, h)
        local c = self.Colors
        local primary = button.Mode == "join" or button.Mode == "manage"
        local hover = button:IsHovered() and button.Mode ~= "blocked"
        draw.RoundedBox(6, 0, 0, w, h, primary and Color(c.Accent.r, c.Accent.g, c.Accent.b, hover and 42 or 24) or (hover and c.Hover or c.Row))
        BW.Utils.DrawRoundedOutline(6, 0, 0, w, h, primary and c.Accent or c.Border)
        draw.SimpleText(label, "Inter14", w / 2, h / 2, primary and c.Accent or c.Muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    action.DoClick = function()
        if mode == "join" then
            self:RequestJoin(item)
        elseif mode == "manage" then
            self:SwitchTab("manage")
        elseif mode == "blocked" then
            local text
            if item.default then
                text = Translate("Team.MenuAlreadyCitizen", "You are already a citizen.")
            elseif item.full then
                text = Translate("Team.Full", "The team is full!")
            else
                text = Translate("Team.LeaveFirst", "First, leave the current team!")
            end
            if LocalPlayer().Notify then LocalPlayer():Notify(NOTIFY_ERROR, text, 3) end
        end
    end
    header.PerformLayout = function(panel, w)
        action:SetPos(w - 116, 20)
    end

    header.DoClick = function()
        local expanded = not self.Expanded[item.index]
        self.Expanded[item.index] = expanded or nil
        if IsValid(card.Details) then card.Details:Remove() card.Details = nil end
        if expanded then
            card.Details = self:BuildTeamDetails(card, item)
            card:SetTall(72 + card.Details:GetTall())
        else
            card:SetTall(72)
        end
        if IsValid(self.List) then self.List:GetCanvas():InvalidateLayout() end
    end

    if self.Expanded[item.index] then
        card.Details = self:BuildTeamDetails(card, item)
        card:SetTall(72 + card.Details:GetTall())
    end
    card.TeamData = item
end

function TEAM_MENU:BuildTeamDetails(card, item)
    local details = vgui.Create("DPanel", card)
    details:SetPaintBackground(false)
    details:Dock(TOP)
    details.Paint = function(_, w, h)
        draw.RoundedBoxEx(9, 0, 0, w, h, Color(self.Colors.Row.r, self.Colors.Row.g, self.Colors.Row.b, 220), false, false, true, true)
    end
    local body = vgui.Create("DPanel", details)
    body:SetPaintBackground(false)
    body:Dock(FILL)
    body:DockMargin(16, 10, 16, 10)
    body.Paint = function() end
    local rowHeight = 46
    local height = 20
    if #item.members == 0 then
        local empty = vgui.Create("DLabel", body)
        empty:Dock(TOP)
        empty:SetTall(34)
        empty:SetText(Translate("Team.MenuBrowseNoTeamPlayers", "There are no players in the team"))
        empty:SetFont("Inter14")
        empty:SetTextColor(self.Colors.Muted)
        empty:SetContentAlignment(5)
        height = height + 34
    else
        table.sort(item.members, function(a, b) return a:Nick():lower() < b:Nick():lower() end)
        for _, member in ipairs(item.members) do
            self:BuildMemberRow(body, member, item, true)
            height = height + rowHeight + 4
        end
    end
    details:SetTall(height)
    return details
end

function TEAM_MENU:BuildMemberRow(parent, member, teamItem, showActions)
    local row = vgui.Create("DPanel", parent)
    row:SetPaintBackground(false)
    row:Dock(TOP)
    row:SetTall(46)
    row:DockMargin(0, 0, 0, 4)
    row:SetCursor("hand")
    row.OnMousePressed = function(_, button)
        if button == MOUSE_RIGHT then self:OpenPlayerMenu(member) end
    end
    row:SetTooltip(Translate("Team.MenuMemberHint", "Right click for player actions"))

    local avatar = vgui.Create("CircularAvatar", row)
    avatar:SetSize(32, 32)
    avatar:SetPos(7, 7)
    avatar:SetMouseInputEnabled(false)
    avatar:SetPlayer(member, 32)

    local isLeader = teamItem.creator == member:SteamID64()
    if isLeader then DrawIcon("icon16/award_star_gold_3.png", 47, 15, 16, self.Colors.Gold) end
    local nameX = isLeader and 68 or 48
    local actionsWidth = 0
    local localCreator = teamItem.creator == LocalPlayer():SteamID64()
    if showActions and localCreator and member ~= LocalPlayer() then actionsWidth = 142 end
    row.Paint = function(panel, w, h)
        draw.RoundedBox(7, 0, 0, w, h, panel:IsHovered() and self.Colors.Hover or self.Colors.Background)
        BW.Utils.DrawRoundedOutline(7, 0, 0, w, h, self.Colors.RowBorder)
        local reserved = actionsWidth > 0 and 156 or 12
        local name = BW.Utils.TruncateText(member:Nick(), "Inter18", math.max(40, w - nameX - reserved))
        draw.SimpleText(name, "Inter18", nameX, 14, self.Colors.White, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        local role = isLeader and Translate("Team.MenuRoleLeader", "Leader") or Translate("Team.MenuRoleMember", "Member")
        draw.SimpleText(role .. "  ·  " .. Translate("Scoreboard.Level", "LVL") .. " " .. tostring(member.GetLevel and member:GetLevel() or 1), "Inter12", nameX, 32, isLeader and self.Colors.Gold or self.Colors.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    if showActions and localCreator and member ~= LocalPlayer() then
        local kick = FlatButton(vgui.Create("DButton", row))
        kick:SetSize(58, 28)
        kick:SetPos(row:GetWide() - 66, 9)
        kick:SetText("")
        kick.Paint = function(button, w, h)
            draw.RoundedBox(6, 0, 0, w, h, button:IsHovered() and Color(90, 35, 40) or self.Colors.Row)
            BW.Utils.DrawRoundedOutline(6, 0, 0, w, h, self.Colors.Red)
            draw.SimpleText(Translate("Team.MenuBrowseKickBtn", "Kick"), "Inter13", w / 2, h / 2, self.Colors.Red, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        kick.DoClick = function()
            Derma_Query(
                string.format(Translate("Team.MenuBrowseKickText", "Are you sure you want to kick %s from the team?"), member:Nick()),
                Translate("Team.MenuBrowseKickTitle", "Kick from the team"),
                Translate("Team.MenuBrowseKickYes", "Yes"),
                function()
                    LocalPlayer():TeamKick(member)
                    self:RequestRefresh(true)
                end,
                Translate("Team.MenuBrowseKickNo", "No")
            )
        end
        local transfer = FlatButton(vgui.Create("DButton", row))
        transfer:SetSize(76, 28)
        transfer:SetPos(row:GetWide() - 148, 9)
        transfer:SetText("")
        transfer.Paint = function(button, w, h)
            draw.RoundedBox(6, 0, 0, w, h, button:IsHovered() and self.Colors.Selected or self.Colors.Row)
            BW.Utils.DrawRoundedOutline(6, 0, 0, w, h, self.Colors.Border)
            draw.SimpleText(Translate("Team.MenuMakeLeader", "Leader"), "Inter13", w / 2, h / 2, self.Colors.Gold, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        transfer.DoClick = function()
            Derma_Query(
                string.format(Translate("Team.MenuTransferText", "Make %s the team leader?"), member:Nick()),
                Translate("Team.MenuTransferTitle", "Transfer leadership"),
                Translate("Team.MenuTransferYes", "Yes"),
                function()
                    LocalPlayer():TeamTransfer(member)
                    self:RequestRefresh(true)
                end,
                Translate("Team.MenuBrowseKickNo", "No")
            )
        end
        row.PerformLayout = function(panel, w)
            kick:SetPos(w - 66, 9)
            transfer:SetPos(w - 148, 9)
        end
    end
    return row
end

function TEAM_MENU:OpenPlayerMenu(target)
    if not IsValid(target) then
        if LocalPlayer().Notify then LocalPlayer():Notify(NOTIFY_ERROR, Translate("Scoreboard.PlayerUnavailable", "This player is no longer available."), 3) end
        return
    end
    local menu = DermaMenu()
    if not target:IsBot() then
        menu:AddOption(Translate("Scoreboard.Profile", "Steam profile"), function()
            if IsValid(target) then target:ShowProfile() end
        end):SetIcon("icon16/user.png")
    end
    menu:AddOption(Translate("Scoreboard.CopySteamID", "Copy SteamID"), function()
        if IsValid(target) then
            SetClipboardText(target:SteamID())
            if LocalPlayer().Notify then LocalPlayer():Notify(NOTIFY_SUCCESS, string.format(Translate("Scoreboard.SteamIDCopied", "SteamID copied: %s"), target:SteamID()), 3) end
        end
    end):SetIcon("icon16/page_copy.png")
    menu:Open()
end

function TEAM_MENU:RequestJoin(item)
    if item.hasPassword then
        Derma_StringRequest(
            Translate("Team.MenuBrowseJoinTitle", "Joining the team"),
            Translate("Team.MenuBrowseJoinText", "Enter the team's password:"),
            "",
            function(password)
                if #password > 128 then return end
                LocalPlayer():TeamJoin(item.index, password)
                self:RequestRefresh(true)
            end,
            nil,
            Translate("Team.MenuBrowseJoinYes", "OK"),
            Translate("Team.MenuBrowseJoinNo", "Cancel")
        )
    else
        LocalPlayer():TeamJoin(item.index, "")
        self:RequestRefresh(true)
    end
end

function TEAM_MENU:CreateSection(parent, height, title, subtitle, titleColor)
    local section = vgui.Create("DPanel", parent)
    section:SetPaintBackground(false)
    section:Dock(TOP)
    section:SetTall(height)
    section:DockMargin(0, 0, 8, 10)
    section.Paint = function(_, w, h)
        draw.RoundedBox(9, 0, 0, w, h, self.Colors.Row)
        draw.SimpleText(title, "Inter20", 18, 20, titleColor or self.Colors.White, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if subtitle then draw.SimpleText(subtitle, "Inter14", 18, 42, self.Colors.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
    end
    local body = vgui.Create("DPanel", section)
    body:SetPaintBackground(false)
    body:Dock(FILL)
    body:DockMargin(18, 56, 18, 14)
    body.Paint = function() end
    return section, body
end

function TEAM_MENU:CreateInput(parent, placeholder, password)
    local entry = vgui.Create("DTextEntry", parent)
    entry:Dock(TOP)
    entry:SetTall(38)
    entry:SetPaintBackground(false)
    entry:SetFont("Inter18")
    entry:SetTextColor(self.Colors.White)
    entry:SetCursorColor(self.Colors.Accent)
    entry:SetHighlightColor(self.Colors.Selected)
    entry:SetDrawLanguageID(false)
    entry.placeholder = placeholder
    entry.Paint = function(input, w, h)
        draw.RoundedBox(7, 0, 0, w, h, self.Colors.Background)
        BW.Utils.DrawRoundedOutline(7, 0, 0, w, h, input:IsEditing() and self.Colors.Accent or self.Colors.Border)
        local value = input:GetValue()
        if value == "" and not input:IsEditing() then
            draw.SimpleText(placeholder, "Inter18", 12, h / 2, self.Colors.Muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        elseif password then
            draw.SimpleText(string.rep("•", utf8.len(value) or #value), "Inter16", 12, h / 2, self.Colors.White, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        else
            input:DrawTextEntryText(self.Colors.White, self.Colors.Selected, self.Colors.Accent)
        end
    end
    return entry
end

function TEAM_MENU:CreateButton(parent, label, kind, width)
    local button = FlatButton(vgui.Create("DButton", parent))
    button:SetText("")
    button:SetTall(38)
    if width then button:SetWide(width) else button:Dock(TOP) end
    local colors = self.Colors
    button.Paint = function(panel, w, h)
        local accent = kind == "danger" and colors.Red or colors.Accent
        local hover = panel:IsHovered()
        if kind == "primary" or kind == "danger" then
            draw.RoundedBox(7, 0, 0, w, h, Color(accent.r, accent.g, accent.b, hover and 38 or 18))
            BW.Utils.DrawRoundedOutline(7, 0, 0, w, h, accent)
            draw.SimpleText(label, "Inter18", w / 2, h / 2, accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        else
            draw.RoundedBox(7, 0, 0, w, h, hover and colors.Hover or colors.Row)
            BW.Utils.DrawRoundedOutline(7, 0, 0, w, h, colors.Border)
            draw.SimpleText(label, "Inter18", w / 2, h / 2, colors.White, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
    return button
end

function TEAM_MENU:BuildManageContent()
    local scroll = vgui.Create("DScrollPanel", self.Content)
    scroll:SetPaintBackground(false)
    scroll:Dock(FILL)
    self:StyleScroll(scroll)
    local ply = LocalPlayer()
    if not IsValid(ply) or ply:Team() == BW.TEAM_DEFAULT then
        self:BuildCreateTeam(scroll)
    else
        self:BuildMyTeam(scroll)
    end
    self.ManageSignature = self:GetManageSignature()
    self.NextManageCheck = RealTime() + 1
end

function TEAM_MENU:BuildCreateTeam(scroll)
    local ply = LocalPlayer()
    local maxPlayers = (BW.Config.Team and BW.Config.Team.MaxPlayers) or 5
    local section, body = self:CreateSection(scroll, 355, Translate("Team.MenuCreateTitle", "Create a team"),
        string.format(Translate("Team.MenuCreateSubtitle", "Up to %d members. Password is optional."), maxPlayers))
    local name = self:CreateInput(body, Translate("Team.MenuControlInputName", "Team name"), false)
    name:DockMargin(0, 2, 0, 9)
    local password = self:CreateInput(body, Translate("Team.MenuControlInputPass", "Password (leave empty for open team)"), true)
    password:DockMargin(0, 0, 0, 12)
    local colorLabel = vgui.Create("DLabel", body)
    colorLabel:Dock(TOP)
    colorLabel:SetTall(18)
    colorLabel:SetFont("Inter14")
    colorLabel:SetTextColor(self.Colors.Muted)
    colorLabel:SetText(Translate("Team.MenuColorLabel", "Team color"))
    local mixer = vgui.Create("DColorMixer", body)
    mixer:Dock(TOP)
    mixer:SetTall(112)
    mixer:SetPalette(false)
    mixer:SetAlphaBar(false)
    mixer:DockMargin(0, 4, 0, 10)
    mixer:SetColor(Color(math.random(30, 220), math.random(30, 220), math.random(30, 220)))
    local create = self:CreateButton(body, Translate("Team.MenuControlCreateBtn", "Create team"), "primary")
    create.DoClick = function()
        local teamName = TrimTeamName(name:GetValue())
        if teamName == "" then
            if ply.Notify then ply:Notify(NOTIFY_ERROR, Translate("Team.MenuControlWarnBlankName", "Enter a team name!"), 4) end
            return
        end
        name:KillFocus()
        password:KillFocus()
        ply:TeamCreate(teamName, password:GetValue(), mixer:GetColor())
        self:RequestRefresh(true)
    end
end

function TEAM_MENU:BuildMyTeam(scroll)
    local ply = LocalPlayer()
    local index = ply:Team()
    local data = BW.Teams.Data[index]
    if not data then return end
    local members = team.GetPlayers(index) or {}
    local isLeader = data.Creator == ply:SteamID64()
    local leaderName = data.Creator
    for _, member in ipairs(members) do
        if member:SteamID64() == data.Creator then leaderName = member:Nick() break end
    end
    local subtitle = string.format(Translate("Team.MenuMyTeamStats", "%d / %d members  ·  Leader: %s  ·  %s"),
        #members, data.MaxPlayers or 5, leaderName, data.HasPassword and Translate("Team.PasswordOn", "password protected") or Translate("Team.PasswordOff", "open"))
    local hero, heroBody = self:CreateSection(scroll, isLeader and 118 or 138, data.Name, subtitle, ReadableTeamColor(data.Color))
    local actions = vgui.Create("DPanel", heroBody)
    actions:SetPaintBackground(false)
    actions:Dock(TOP)
    actions:SetTall(38)
    actions.Paint = function() end
    if isLeader then
        local disband = self:CreateButton(actions, Translate("Team.MenuControlDisbandBtn", "Disband team"), "danger", 150)
        disband:Dock(LEFT)
        disband.DoClick = function()
            Derma_Query(Translate("Team.MenuControlDisbandText", "Are you sure you want to disband the team? This action is irreversible."),
                Translate("Team.MenuControlDisbandTitle", "Disband team"), Translate("Team.MenuControlDisbandYes", "Yes"),
                function()
                    LocalPlayer():TeamDisband()
                    self:RequestRefresh(true)
                end, Translate("Team.MenuControlDisbandNo", "No"))
        end
    else
        local leave = self:CreateButton(actions, Translate("Team.MenuControlLeaveBtn", "Leave team"), "neutral", 150)
        leave:Dock(LEFT)
        leave.DoClick = function()
            Derma_Query(Translate("Team.MenuBrowseLeaveText", "Do you really want to leave the team?"), Translate("Team.MenuBrowseLeaveTitle", "Leaving the team"),
                Translate("Team.MenuBrowseLeaveYes", "Yes"), function()
                    LocalPlayer():TeamLeave()
                    self:RequestRefresh(true)
                end, Translate("Team.MenuBrowseLeaveNo", "No"))
        end
        local note = vgui.Create("DLabel", heroBody)
        note:Dock(TOP)
        note:SetTall(20)
        note:DockMargin(0, 4, 0, 0)
        note:SetFont("Inter12")
        note:SetTextColor(self.Colors.Muted)
        note:SetText(Translate("Team.MenuLeaderOnlyNote", "Only the team leader can edit settings."))
    end

    local roster, rosterBody = self:CreateSection(scroll, 70 + math.max(1, #members) * 50,
        Translate("Team.MenuRoster", "Roster"), string.format(Translate("Team.MenuRosterSubtitle", "%d players"), #members))
    if #members == 0 then
        local empty = vgui.Create("DLabel", rosterBody)
        empty:Dock(TOP)
        empty:SetTall(30)
        empty:SetText(Translate("Team.MenuBrowseNoTeamPlayers", "There are no players in the team"))
        empty:SetFont("Inter14")
        empty:SetTextColor(self.Colors.Muted)
    else
        table.sort(members, function(a, b) return a:Nick():lower() < b:Nick():lower() end)
        for _, member in ipairs(members) do
            self:BuildMemberRow(rosterBody, member, {creator = data.Creator, members = members}, true)
        end
    end

    if isLeader then
        local settings, settingsBody = self:CreateSection(scroll, 380, Translate("Team.MenuSettings", "Team settings"),
            Translate("Team.MenuSettingsSubtitle", "Changes are applied to all members immediately."))
        local nameLabel = vgui.Create("DLabel", settingsBody)
        nameLabel:Dock(TOP)
        nameLabel:SetTall(16)
        nameLabel:SetFont("Inter12")
        nameLabel:SetTextColor(self.Colors.Muted)
        nameLabel:SetText(Translate("Team.MenuNameLabel", "Team name"))
        local name = self:CreateInput(settingsBody, Translate("Team.MenuControlInputName", "Team name"), false)
        name:SetValue(data.Name)
        name:DockMargin(0, 3, 0, 8)
        local colorLabel = vgui.Create("DLabel", settingsBody)
        colorLabel:Dock(TOP)
        colorLabel:SetTall(16)
        colorLabel:SetFont("Inter12")
        colorLabel:SetTextColor(self.Colors.Muted)
        colorLabel:SetText(Translate("Team.MenuColorLabel", "Team color"))
        local mixer = vgui.Create("DColorMixer", settingsBody)
        mixer:Dock(TOP)
        mixer:SetTall(106)
        mixer:SetPalette(false)
        mixer:SetAlphaBar(false)
        mixer:DockMargin(0, 3, 0, 8)
        mixer:SetColor(data.Color)
        local passwordLabel = vgui.Create("DLabel", settingsBody)
        passwordLabel:Dock(TOP)
        passwordLabel:SetTall(16)
        passwordLabel:SetFont("Inter12")
        passwordLabel:SetTextColor(self.Colors.Muted)
        passwordLabel:SetText(Translate("Team.MenuNewPassword", "New password (leave empty to keep current)"))
        local password = self:CreateInput(settingsBody, Translate("Team.MenuNewPasswordHint", "New password"), true)
        password:DockMargin(0, 3, 0, 8)
        local row = vgui.Create("DPanel", settingsBody)
        row:Dock(TOP)
        row:SetTall(38)
        row.Paint = function() end
        local save = self:CreateButton(row, Translate("Team.MenuSave", "Save changes"), "primary", 160)
        save:Dock(LEFT)
        save.DoClick = function()
            local newName = TrimTeamName(name:GetValue())
            if newName == "" then
                if LocalPlayer().Notify then LocalPlayer():Notify(NOTIFY_ERROR, Translate("Team.MenuControlWarnBlankName", "Enter a team name!"), 4) end
                return
            end
            local newPassword = password:GetValue()
            name:KillFocus()
            password:KillFocus()
            LocalPlayer():TeamUpdateSettings(newName, mixer:GetColor(), newPassword ~= "" and 1 or 0, newPassword)
            self:RequestRefresh(true)
        end
        if data.HasPassword then
            local remove = self:CreateButton(row, Translate("Team.MenuRemovePassword", "Remove password"), "danger", 170)
            remove:Dock(LEFT)
            remove:DockMargin(8, 0, 0, 0)
            remove.DoClick = function()
                Derma_Query(Translate("Team.MenuRemovePasswordText", "Remove the team password? Anyone will be able to join."),
                    Translate("Team.MenuRemovePassword", "Remove password"), Translate("Team.MenuBrowseKickYes", "Yes"),
                    function() LocalPlayer():TeamUpdateSettings(TrimTeamName(name:GetValue()), mixer:GetColor(), 2, "") end,
                    Translate("Team.MenuBrowseKickNo", "No"))
            end
        end
    end
end

function TEAM_MENU:RequestRefresh(force)
    self.PendingRefresh = true
    self.PendingSince = self.PendingSince or RealTime()
    if force then
        self.ForceRefreshAt = RealTime() + 0.5
        self.RefreshAfterSyncUntil = RealTime() + 1
    end
end

function TEAM_MENU:OnTeamDataUpdated()
    if self.RefreshAfterSyncUntil and RealTime() <= self.RefreshAfterSyncUntil then
        self.ForceRefreshAt = RealTime()
    end
    self:RequestRefresh()
end

function TEAM_MENU:GetManageSignature()
    local ply = LocalPlayer()
    if not IsValid(ply) then return "" end
    local index = ply:Team()
    local data = BW.Teams.Data[index]
    local members = team.GetPlayers(index) or {}
    if not data then return tostring(index) .. ":" .. #members end
    return table.concat({index, data.Name or "", data.Creator or "", tostring(data.HasPassword), data.MaxPlayers or 0, #members}, ":")
end

function TEAM_MENU:Refresh()
    self.PendingRefresh = false
    if not IsValid(self) then return end
    self:SwitchTab(self.ActiveTab or "browse")
end

function TEAM_MENU:Think()
    local now = RealTime()
    if self.DragOffset then
        local x, y = gui.MousePos()
        self:SetPos(x - self.DragOffset.x, y - self.DragOffset.y)
    end
    if self.PendingRefresh then
        local focus = vgui.GetKeyboardFocus()
        local forceReady = self.ForceRefreshAt and now >= self.ForceRefreshAt
        local timedOut = self.PendingSince and now - self.PendingSince > 2
        if forceReady or timedOut or not IsValid(focus) or not focus.GetValue then
            self.PendingRefresh, self.PendingSince, self.ForceRefreshAt = false, nil, nil
            self:Refresh()
        end
    end
    if self.ActiveTab == "browse" and now >= (self.NextBrowseCheck or 0) then
        self.NextBrowseCheck = now + 2
        if IsValid(self.List) then
            local list = self:CollectTeams()
            if self:GetSignature(list) ~= self.Signature then self:BuildTeamList(true) end
        end
    elseif self.ActiveTab == "manage" and now >= (self.NextManageCheck or 0) then
        self.NextManageCheck = now + 1
        if self.ManageSignature and self:GetManageSignature() ~= self.ManageSignature then
            self:RequestRefresh()
        end
    end
end

function TEAM_MENU:OnKeyCodePressed(key)
    if key == KEY_ESCAPE then self:CloseMenu() end
end

function TEAM_MENU:ShowMenu()
    if not IsValid(self) then return end
    self:SetVisible(true)
    self:MakePopup()
    self:SetKeyboardInputEnabled(true)
    self:MoveToFront()
    self:Center()
end

function TEAM_MENU:CloseMenu()
    if IsValid(self) then self:Remove() end
    ActiveTeamMenu = nil
end

function TEAM_MENU:OnRemove()
    ActiveTeamMenu = nil
end

vgui.Register("TeamMenu", TEAM_MENU, "EditablePanel")

local function OpenTeamMenu()
    if IsValid(ActiveTeamMenu) then
        ActiveTeamMenu:ShowMenu()
    else
        ActiveTeamMenu = vgui.Create("TeamMenu")
    end
end

hook.Add("BW_Team_DataUpdated", "BW_UpdateTeamMenu", function()
    if IsValid(ActiveTeamMenu) then ActiveTeamMenu:OnTeamDataUpdated() end
end)
net.Receive("BW_Team_OpenMenu", function() OpenTeamMenu() end)
concommand.Add("bw_open_team_menu", OpenTeamMenu)
