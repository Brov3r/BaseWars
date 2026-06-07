local ActiveTeamMenu = nil
local colors = BW.Config.Colors

local TEAM_MENU = {}

function TEAM_MENU:Init()
    self:SetSize(650, 550)
    self:Center()
    self:SetTitle("")
    self:SetDraggable(true)
    self:ShowCloseButton(true)
    self:MakePopup()
    
    self.OnClose = function()
        ActiveTeamMenu = nil
    end

    self.ActiveTab = "browse"
    self.TabBuilders = {}
    
    self.TabContainer = vgui.Create("Panel", self)
    self.TabContainer:Dock(TOP)
    self.TabContainer:SetTall(30)
    self.TabContainer:DockMargin(0, 0, 0, 0)

    self.TabContainer.PerformLayout = function(container)
        local children = container:GetChildren()
        local count = #children
        if count > 0 then
            local widthPerChild = container:GetWide() / count
            for _, child in ipairs(children) do
                child:SetWide(widthPerChild)
                child:Dock(LEFT)
            end
        end
    end

    self.ContentPanel = vgui.Create("Panel", self)
    self.ContentPanel:Dock(FILL)
    self.ContentPanel:DockMargin(15, 10, 15, 15)

    self:BuildTabs()
    self:SwitchTab(self.ActiveTab)
end

function TEAM_MENU:Paint(w, h)
    local headerH = 25
    
    draw.RoundedBox(8, 0, 0, w, h, colors.DarkGray35)
    draw.RoundedBoxEx(8, 0, 0, w, headerH, colors.DarkGray30, true, true, false, false)
    
    local iconX = 10
    local iconY = (headerH / 2) - 8
    local iconSize = 16
    local textX = iconX + iconSize + 6
    local textY = headerH / 2
    
    local iconMat = Material("icon16/group.png", "smooth")
    if iconMat and not iconMat:IsError() then
        surface.SetDrawColor(colors.White)
        surface.SetMaterial(iconMat)
        surface.DrawTexturedRect(iconX, iconY, iconSize, iconSize)
    end
    
    draw.SimpleText(Translate("Team.MenuTitle", "Teams"), "Inter14Thin", textX, textY, colors.White, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

function TEAM_MENU:BuildTabs()
    local accentColor = colors.Blue
    self.Tabs = {}

    local tabsConfig = {
        {
            id = "browse",
            textKey = "Team.MenuTeamTab",
            defaultText = "Teams",
            icon = "icon16/group.png",
            builder = self.BuildBrowseContent
        },
        {
            id = "manage",
            textKey = "Team.MenuControlTab",
            defaultText = "Team Management",
            icon = "icon16/cog.png",
            builder = self.BuildManageContent
        }
    }

    for _, config in ipairs(tabsConfig) do
        self.TabBuilders[config.id] = config.builder

        local btn = vgui.Create("DButton", self.TabContainer)
        btn:Dock(LEFT)
        btn:SetText("")
        self.Tabs[config.id] = btn

        btn.Paint = function(s, w, h)
            local isActive = self.ActiveTab == config.id
            local isHovered = s:IsHovered()
            local textColor = isActive and colors.White or (isHovered and colors.Gray150 or colors.Grey)
            
            local text = Translate(config.textKey, config.defaultText)
            local font = "Inter16Thin"
            
            surface.SetFont(font)
            local textW = surface.GetTextSize(text)
            
            local iconSize = 16
            local spacing = 6
            local totalBlockW = iconSize + spacing + textW
            local startX = (w - totalBlockW) / 2
            local centerY = h / 2
            
            local iconMat = Material(config.icon, "smooth")
            if iconMat and not iconMat:IsError() then
                surface.SetDrawColor(textColor)
                surface.SetMaterial(iconMat)
                surface.DrawTexturedRect(startX, centerY - (iconSize / 2), iconSize, iconSize)
            end
            
            draw.SimpleText(text, font, startX + iconSize + spacing, centerY, textColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            
            if isActive then
                surface.SetDrawColor(accentColor)
                surface.DrawRect(0, h - 2, w, 2)
            end
        end

        btn.DoClick = function()
            self:SwitchTab(config.id)
        end
    end
end

function TEAM_MENU:SwitchTab(tabId)
    self.ActiveTab = tabId
    self.ContentPanel:Clear()
    
    local builder = self.TabBuilders[tabId]
    if builder then
        builder(self)
    end
    
    for _, btn in pairs(self.Tabs) do
        btn:InvalidateLayout(true)
    end
end

function TEAM_MENU:BuildBrowseContent(expandedState)
    self.ContentPanel:Clear()
    
    local scroll = vgui.Create("DScrollPanel", self.ContentPanel)
    scroll:Dock(FILL)
    local sbar = scroll:GetVBar()
    sbar.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(40, 40, 40, 100))
    end

    sbar.btnGrip.Paint = function(s, w, h)
        local color = s:IsHovered() and Color(150, 150, 150) or Color(100, 100, 100)
        draw.RoundedBox(4, 2, 0, w - 4, h, color)
    end

    sbar.btnUp.Paint = function() end
    sbar.btnDown.Paint = function() end

    sbar:SetWide(10)
    
    local teamsList = {}
    
    for team_idx, tData in pairs(team.GetAllTeams()) do
        if team_idx == TEAM_SPECTATOR or team_idx == TEAM_CONNECTING or team_idx == TEAM_UNASSIGNED then continue end
        
        local bwData = BW.Teams and BW.Teams.Data and BW.Teams.Data[team_idx]
        
        local name = (bwData and bwData.Name) or team.GetName(team_idx)
        local color = (bwData and bwData.Color) or team.GetColor(team_idx)
        local maxPl = (bwData and bwData.MaxPlayers) or 0
        local maxStr = (maxPl == 0) and "∞" or tostring(maxPl)
        local current = team.NumPlayers(team_idx) or 0
        
        if current == 0 and team_idx ~= BW.TEAM_DEFAULT then continue end

        table.insert(teamsList, {
            index = team_idx,
            name = name,
            current = current,
            maxStr = maxStr,
            color = color
        })
    end

    table.sort(teamsList, function(a, b)
        if a.index == BW.TEAM_DEFAULT then return true end
        if b.index == BW.TEAM_DEFAULT then return false end
        return a.name < b.name
    end)

    for _, t in ipairs(teamsList) do
        local cat = vgui.Create("DCollapsibleCategory", scroll)
        cat:Dock(TOP)
        cat:DockMargin(0, 0, 0, 8)
        cat:SetLabel("")
        
        cat.TeamIndex = t.index
        cat:SetExpanded(expandedState and expandedState[t.index] or false)
        
        local myTeam = LocalPlayer():Team()
        local bwData = BW.Teams and BW.Teams.Data and BW.Teams.Data[t.index]
        local isCreator = bwData and bwData.Creator == LocalPlayer():SteamID64()

        local lockIconMat = nil
        local textStartX = 12
        local iconSize = 16

        if t.index ~= BW.TEAM_DEFAULT and bwData then
            if bwData.HasPassword then
                lockIconMat = Material("icon16/lock.png")
            else
                lockIconMat = Material("icon16/key.png")
            end
            textStartX = 12 + iconSize + 6
        end
        cat.Header:SetTall(48)
        cat.Header.Paint = function(s, w, h)
            draw.RoundedBox(0, 0, 0, w, h, colors.DarkGray30)
            
            if lockIconMat and not lockIconMat:IsError() then
                surface.SetDrawColor(colors.Grey)
                surface.SetMaterial(lockIconMat)
                surface.DrawTexturedRect(12, (h / 2) - (iconSize / 2), iconSize, iconSize)
            end
            
            draw.SimpleText(t.name, "Inter18Thin", textStartX, h/2, t.color or colors.White, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        
            local countText = t.current .. " / " .. t.maxStr
            draw.SimpleText(countText, "Inter14", w - 12, h/2, colors.Grey, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        local showButton = (myTeam == BW.TEAM_DEFAULT and t.index ~= BW.TEAM_DEFAULT) or 
                           (myTeam ~= BW.TEAM_DEFAULT and t.index == myTeam)

        if showButton then
            if isCreator and t.index == myTeam then
                local btnLeave = vgui.Create("DButton", cat.Header)
                btnLeave:SetText("")
                btnLeave:Dock(RIGHT)
                btnLeave:SetWide(90)
                btnLeave:SetTall(30)
                btnLeave:DockMargin(0, 9, 50, 9)
                
                btnLeave.Paint = function(s, w, h)
                    local bgColor = s:IsHovered() and colors.Grey or colors.DarkGray45
                    draw.RoundedBox(4, 0, 0, w, h, bgColor)
                    draw.SimpleText(Translate("Team.MenuBrowseLeaveBtn", "Leave"), "Inter14", w/2, h/2, colors.White, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                
                btnLeave.DoClick = function()
                    Derma_Query(
                        Translate("Team.MenuBrowseLeaveText", "Do you really want to leave the team?"),
                        Translate("Team.MenuBrowseLeaveTitle", "Exiting the team"),
                        Translate("Team.MenuBrowseDisbandYes", "Yes"),
                        function() 
                            LocalPlayer():TeamLeave() 
                            if IsValid(ActiveTeamMenu) then ActiveTeamMenu:Refresh() end
                        end,
                        Translate("Team.MenuBrowseDisbandNo", "No")
                    )
                end

                local btnDisband = vgui.Create("DButton", cat.Header)
                btnDisband:SetText("")
                btnDisband:Dock(RIGHT)
                btnDisband:SetWide(110)
                btnDisband:SetTall(30)
                btnDisband:DockMargin(0, 9, 12, 9)
                
                btnDisband.Paint = function(s, w, h)
                    local bgColor = s:IsHovered() and Color(180, 50, 50, 255) or colors.DarkGray45
                    draw.RoundedBox(4, 0, 0, w, h, bgColor)
                    draw.SimpleText(Translate("Team.MenuBrowseDisbandBtn", "Disband"), "Inter14", w/2, h/2, colors.White, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                
                btnDisband.DoClick = function()
                    Derma_Query(
                        Translate("Team.MenuBrowseDisbandText", "Are you sure you want to disband the team? This action is irreversible."),
                        Translate("Team.MenuBrowseDisbandTitle", "Liquidation of the team"),
                        Translate("Team.MenuBrowseDisbandYes", "Yes"),
                        function() 
                            LocalPlayer():TeamDisband() 
                            if IsValid(ActiveTeamMenu) then ActiveTeamMenu:Refresh() end
                        end,
                        Translate("Team.MenuBrowseDisbandNo", "No")
                    )
                end

            else
                local actionBtn = vgui.Create("DButton", cat.Header)
                actionBtn:SetText("")
                
                actionBtn:Dock(RIGHT)
                actionBtn:SetWide(90)
                actionBtn:SetTall(30)
                actionBtn:DockMargin(0, 9, 50, 9) 
                
                local btnText = (t.index == myTeam) and Translate("Team.MenuBrowseLeaveBtn", "Leave") or Translate("Team.JoinBtn", "Войти")
                
                actionBtn.Paint = function(s, w, h)
                    local bgColor = s:IsHovered() and colors.Grey or colors.DarkGray45
                    draw.RoundedBox(4, 0, 0, w, h, bgColor)
                    draw.SimpleText(btnText, "Inter14", w/2, h/2, colors.White, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end

                actionBtn.DoClick = function()
                    if t.index == myTeam then
                        Derma_Query(
                            Translate("Team.MenuBrowseLeaveText", "Do you really want to leave the team?"),
                            Translate("Team.MenuBrowseLeaveTitle", "Exiting the team"),
                            Translate("Team.MenuBrowseLeaveYes", "Yes"),
                            function() 
                                LocalPlayer():TeamLeave() 
                                if IsValid(ActiveTeamMenu) then ActiveTeamMenu:Refresh() end
                            end,
                            Translate("Team.MenuBrowseLeaveNo", "No")
                        )
                    else
                        if bwData and bwData.HasPassword then
                            Derma_StringRequest(
                                Translate("Team.MenuBrowseJoinTitle", "Joining the team"),
                                Translate("Team.MenuBrowseJoinText", "Enter the team's password:"),
                                "",
                                function(enteredPassword)
                                    LocalPlayer():TeamJoin(t.index, enteredPassword)
                                    if IsValid(ActiveTeamMenu) then ActiveTeamMenu:Refresh() end
                                end,
                                function(enteredPassword)
                                    
                                end,
                                Translate("Team.MenuBrowseJoinYes", "Cancel"),
                                Translate("Team.MenuBrowseJoinNo", "Password")
                            )
                        else
                            LocalPlayer():TeamJoin(t.index, "")
                            if IsValid(ActiveTeamMenu) then ActiveTeamMenu:Refresh() end
                        end
                    end
                end
            end
        end
                
        local contents = vgui.Create("DPanel")
        contents:DockPadding(8, 8, 8, 8)
        contents.Paint = function(s, w, h)
            draw.RoundedBoxEx(0, 0, 0, w, h, Color(0, 0, 0, 0), false, false, true, true)
        end
        cat:SetContents(contents)
        
        local players = team.GetPlayers(t.index)
        local bwData = BW.Teams and BW.Teams.Data and BW.Teams.Data[t.index]

        if #players == 0 then
            local emptyLbl = vgui.Create("DLabel", contents)
            emptyLbl:Dock(TOP)
            emptyLbl:SetText(Translate("Team.MenuBrowseNoTeamPlayers", "There are no players in the team"))
            emptyLbl:SetFont("Inter14")
            emptyLbl:SetTextColor(colors.Grey)
            emptyLbl:SetContentAlignment(5)
            emptyLbl:SetTall(36)
        else
            table.sort(players, function(a, b) return a:Nick() < b:Nick() end)
        
            -- Проверяем, является ли локальный игрок создателем этой команды
            local isLocalCreator = bwData and bwData.Creator == LocalPlayer():SteamID64()
            
            for _, ply in ipairs(players) do
                local row = vgui.Create("DPanel", contents)
                row:Dock(TOP)
                row:DockMargin(0, 0, 0, 4)
                row:SetTall(46)
                
                row.Paint = function(s, w, h)
                    draw.RoundedBox(4, 0, 0, w, h, colors.DarkGray30)
                end
                
                local avatar = vgui.Create("CircularAvatar", row)
                avatar:Dock(LEFT)
                avatar:SetWide(32)
                avatar:SetPlayer(ply, 32)
                avatar:DockMargin(8, 7, 10, 7)
                
                local isPlayerCreator = bwData and bwData.Creator == ply:SteamID64()
                
                if isPlayerCreator then
                    local starLbl = vgui.Create("DLabel", row)
                    starLbl:Dock(LEFT)
                    starLbl:SetWide(20)
                    starLbl:SetText("★")
                    starLbl:SetFont("Inter16Thin")
                    starLbl:SetTextColor(colors.Yellow)
                    starLbl:SetContentAlignment(5)
                end
                
                local nameLbl = vgui.Create("DLabel", row)
                nameLbl:Dock(FILL)
                nameLbl:SetText(ply:Nick())
                nameLbl:SetFont("Inter16Thin")
                nameLbl:SetTextColor(colors.White)
                nameLbl:SetContentAlignment(4)
                
                if isLocalCreator and ply ~= LocalPlayer() then
                    local kickBtn = vgui.Create("DButton", row)
                    kickBtn:SetText("")
                    kickBtn:Dock(RIGHT)
                    kickBtn:SetWide(70)
                    kickBtn:SetTall(30)
                    kickBtn:DockMargin(0, 8, 8, 8)
                    
                    kickBtn.Paint = function(s, w, h)
                        local bg = s:IsHovered() and Color(180, 50, 50, 255) or colors.DarkGray45
                        draw.RoundedBox(4, 0, 0, w, h, bg)
                        draw.SimpleText(Translate("Team.MenuBrowseKickBtn", "Кик"), "Inter14", w/2, h/2, colors.White, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end
                    
                    kickBtn.DoClick = function()
                        Derma_Query(
                            string.format(Translate("Team.MenuBrowseKickText", "Are you sure you want to kick %s from the team?"), ply:Nick()),
                            Translate("Team.MenuBrowseKickTitle", "Kick from the team"),
                            Translate("Team.MenuBrowseKickYes", "Yes"),
                            function() 
                                local success = LocalPlayer():TeamKick(ply)
                                
                                if success then
                                    if LocalPlayer().Notify then
                                        local msg = string.format(Translate("Team.KickSuccess", "Player %s has been kicked from the team."), ply:Nick())
                                        LocalPlayer():Notify(NOTIFY_SUCCESS, msg)
                                    end
                                else
                                    if LocalPlayer().Notify then
                                        LocalPlayer():Notify(NOTIFY_ERROR, Translate("Team.KickFailed", "Failed to kick a player from the team."))
                                    end
                                end
                                if IsValid(ActiveTeamMenu) then ActiveTeamMenu:Refresh() end
                            end,
                            Translate("Team.MenuBrowseKickNo", "No")
                        )
                    end
                end
            end
        end
    end
end

function TEAM_MENU:Refresh()
    timer.Simple(0.1, function()
        if not IsValid(self) then return end
        
        local expandedState = {}
        
        for _, panel in pairs(self.ContentPanel:GetChildren()) do
            if IsValid(panel) then
                local container = panel.GetCanvas and panel:GetCanvas() or panel
                
                if IsValid(container) and container.GetChildren then
                    local children = container:GetChildren()
                    
                    if type(children) == "table" then
                        for _, cat in pairs(children) do
                            if IsValid(cat) and type(cat) == "Panel" and cat.TeamIndex ~= nil then
                                expandedState[cat.TeamIndex] = cat:GetExpanded()
                            end
                        end
                    end
                end
            end
        end
        
        self.ContentPanel:Clear()
        local builder = self.TabBuilders[self.ActiveTab]
        if builder then
            builder(self, expandedState)
        end
        
        self:InvalidateLayout(true)
    end)
end

local function CreateStyledInput(parent, placeholder, isPassword)
    local entry = vgui.Create("DTextEntry", parent)
    entry:SetTall(36)
    entry:SetPaintBackground(false)
    
    entry.placeholder = placeholder
    entry.hasFocus = false
    
    entry.OnGetFocus = function(s) s.hasFocus = true end
    entry.OnLoseFocus = function(s) s.hasFocus = false end
    entry.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, colors.DarkGray30)
        
        local text = s:GetValue()
        
        if text == "" and not s.hasFocus then
            draw.SimpleText(s.placeholder, "Inter14", 12, h/2, colors.Grey, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            return
        end
        
        local drawText = isPassword and string.rep("*", utf8.len(text)) or text
        
        draw.SimpleText(drawText, "Inter14", 12, h/2, colors.White, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    
    return entry
end

local function CreateStyledButton(parent, text, bgColor, hoverColor, onClick)
    local btn = vgui.Create("DButton", parent)
    btn:SetTall(38)
    btn:SetText("")
    btn.Paint = function(s, w, h)
        local isHovered = s:IsHovered()
        local bg = isHovered and hoverColor or bgColor
        draw.RoundedBox(4, 0, 0, w, h, bg)
        draw.SimpleText(text, "Inter16Thin", w/2, h/2, colors.White, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btn.DoClick = onClick
    return btn
end

function TEAM_MENU:BuildManageContent()
    local ply = LocalPlayer()
    local currentTeam = ply:Team()
    local isUnassigned = (currentTeam == BW.TEAM_DEFAULT)
    
    local innerPanel = vgui.Create("Panel", self.ContentPanel)
    innerPanel:Dock(FILL)

    if isUnassigned then
        local lblCreate = vgui.Create("DLabel", innerPanel)
        lblCreate:Dock(TOP)
        lblCreate:SetText(Translate("Team.MenuControlNewTeamTitle", "Creating a new team"))
        lblCreate:SetFont("Inter18")
        lblCreate:SetTextColor(colors.White)
        lblCreate:DockMargin(0, 10, 0, 15)

        local inpName = CreateStyledInput(innerPanel, Translate("Team.MenuControlInputName", "Team name"), false)
        inpName:Dock(TOP)
        inpName:DockMargin(0, 0, 0, 10)

        local inpPwdCreate = CreateStyledInput(innerPanel, Translate("Team.MenuControlInputPass", "Password (leave it blank for the open one)"), true)
        inpPwdCreate:Dock(TOP)
        inpPwdCreate:DockMargin(0, 0, 0, 15)

        local lblColor = vgui.Create("DLabel", innerPanel)
        lblColor:Dock(TOP)
        lblColor:SetText(Translate("Team.MenuControlInputColor", "Team color:"))
        lblColor:SetFont("Inter14")
        lblColor:SetTextColor(colors.Grey)
        lblColor:DockMargin(0, 0, 0, 5)

        local colorMixer = vgui.Create("DColorMixer", innerPanel)
        colorMixer:Dock(TOP)
        colorMixer:SetTall(100)
        colorMixer:SetPalette(false)
        colorMixer:SetAlphaBar(false)
        colorMixer:DockMargin(0, 0, 0, 15)
        colorMixer:SetColor(Color(math.Rand(0,255), math.Rand(0,255), math.Rand(0,255)))

        local btnCreate = CreateStyledButton(innerPanel, Translate("Team.MenuControlCreateBtn","Create team"), colors.Green, colors.LightGreen, function()
            local name = inpName:GetValue()
            if name == "" then
                if ply.Notify then ply:Notify(NOTIFY_ERROR, Translate("Team.MenuControlWarnBlankName", ""), 5) end
                return
            end
            ply:TeamCreate(name, inpPwdCreate:GetValue(), colorMixer:GetColor())
        end)
        btnCreate:Dock(TOP)
        btnCreate:DockMargin(0, 0, 0, 30)
    else
        local tData = BW.Teams.Data[currentTeam]
        local tName = tData and tData.Name or team.GetName(currentTeam)
        local tColor = tData and tData.Color or team.GetColor(currentTeam)
        local isCreator = tData and (tData.Creator == ply:SteamID64())

        local centerPanel = vgui.Create("Panel", innerPanel)
        centerPanel:Dock(FILL)
        
        local lblStatus = vgui.Create("DLabel", innerPanel)
        lblStatus:Dock(TOP)
        lblStatus:SetText(Translate("Team.MenuControlInTeamTitle",""))
        lblStatus:SetFont("Inter16Thin")
        lblStatus:SetTextColor(colors.Grey)
        lblStatus:SetContentAlignment(5)
        lblStatus:DockMargin(0, 0, 0, 5)

        local lblTeamName = vgui.Create("DLabel", innerPanel)
        lblTeamName:Dock(TOP)
        lblTeamName:SetText(tName)
        lblTeamName:SetFont("Inter24")
        lblTeamName:SetTextColor(tColor)
        lblTeamName:SetContentAlignment(5)
        lblTeamName:DockMargin(0, 0, 0, 40)

        local btnLeave = CreateStyledButton(innerPanel, Translate("Team.MenuControlLeaveBtn", "Leave the team"), colors.Red, colors.LightRed, function()
            ply:TeamLeave()
            if IsValid(ActiveTeamMenu) then ActiveTeamMenu:Refresh() end
        end)
        btnLeave:Dock(TOP)
        btnLeave:DockMargin(0, 0, 0, 15)

        if isCreator then
            local btnDisband = CreateStyledButton(innerPanel, Translate("Team.MenuControlDisbandBtn", "Disband the team"), colors.Red, colors.LightRed, function()
                Derma_Query(Translate("Team.MenuControlDisbandText", "Are you sure you want to disband the team? This action is irreversible."), Translate("Team.MenuControlDisbandTitle", "Liquidation of the team."), Translate("Team.MenuControlDisbandYes", "Yes"), function()
                    ply:TeamDisband()
                    if IsValid(ActiveTeamMenu) then ActiveTeamMenu:Refresh() end
                end, Translate("Team.MenuControlDisbandNo", "No"))
            end)
            btnDisband:Dock(TOP)
        end
    end
end

function TEAM_MENU:ShowMenu()
    if not IsValid(self) then return end
    self:SetVisible(true)
    self:MakePopup()
    self:MoveToFront()
    self:Center()
end

function TEAM_MENU:CloseMenu()
    if IsValid(self) then
        self:Remove()
        ActiveTeamMenu = nil
    end
end

vgui.Register("TeamMenu", TEAM_MENU, "DFrame")

local function OpenTeamMenu()
    if IsValid(ActiveTeamMenu) then
        ActiveTeamMenu:ShowMenu()
    else
        ActiveTeamMenu = vgui.Create("TeamMenu")
    end
end

hook.Add("BW_Team_DataUpdated", "BW_UpdateTeamMenu", function()
    if IsValid(ActiveTeamMenu) then
        ActiveTeamMenu:Refresh()
    end
end)
net.Receive("BW_Team_OpenMenu", function()
    OpenTeamMenu()
end)

concommand.Add("bw_open_team_menu", OpenTeamMenu)