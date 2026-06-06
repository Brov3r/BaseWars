local iconMaterials = {}
local function GetIconMaterial(path)
    if not iconMaterials[path] then
        iconMaterials[path] = Material(path, "smooth")
    end
    return iconMaterials[path]
end

local PANEL = {}

function PANEL:Init()
    local cfg = BW.Config or {}
    local sbCfg = cfg.Scoreboard or {}
    local colors = cfg.Colors or {}

    self.AvatarSize = sbCfg.AvatarSize or 32
    self.AvatarOffsetX = sbCfg.AvatarOffsetX or 50
    self.MuteBtnWidth = sbCfg.MuteBtnWidth or 24
    self.MuteBtnMargin = sbCfg.MuteBtnMargin or 10
    self.PanelWidth = sbCfg.PanelWidth or 800
    self.PanelMaxHeight = sbCfg.PanelMaxHeight or 600
    self.HeaderHeight = sbCfg.HeaderHeight or 40
    self.RowHeight = sbCfg.RowHeight or 40
    self.LeftMargin = sbCfg.LeftMargin or 20
    self.Spacing = sbCfg.Spacing or 2

    self.Colors = {
        White      = colors.White or Color(255, 255, 255, 255),
        DarkGray   = colors.DarkGray or Color(60, 60, 60, 255),
        DarkGray35 = colors.DarkGray35 or Color(35, 35, 40, 245),
        DarkGray45 = colors.DarkGray45 or Color(45, 45, 50, 245),
    }

    self.Columns = {}
    self.Rows = {}
    self.AvatarColumnIndex = nil  -- Индекс колонки с аватаром
    
    self:SetAlpha(0)
end

function PANEL:AddColumn(colData)
    local col = {
        id = colData.id,
        header = colData.header or "",
        icon = colData.icon,
        width = colData.width or 100,
        align = colData.align or TEXT_ALIGN_CENTER,
        color = colData.color or self.Colors.White,
        getter = colData.getter,
        maxWidth = colData.maxWidth,
        hasAvatar = colData.hasAvatar or false,
        hasPrefixIcon = colData.hasPrefixIcon or false,
        prefixIconGetter = colData.prefixIconGetter,
        prefixIconSize = colData.prefixIconSize or 16,
    }
    table.insert(self.Columns, col)
    
    if col.hasAvatar and not self.AvatarColumnIndex then
        self.AvatarColumnIndex = #self.Columns
    end
end

function PANEL:ComputeColumnPositions()
    local pos = {}
    local x = self.LeftMargin
    for i, col in ipairs(self.Columns) do
        pos[i] = x
        x = x + col.width
    end
    return pos
end

function PANEL:Build()
    local scrW, scrH = ScrW(), ScrH()
    local panelW = math.min(scrW * 0.85, self.PanelWidth)
    local panelH = math.min(scrH * 0.75, self.PanelMaxHeight)
    
    self:SetSize(panelW, panelH)
    self:Center()
    self:MakePopup()
    self:AlphaTo(255, 0.2)

    self.colPositions = self:ComputeColumnPositions()
    self.rowW = panelW - self.LeftMargin * 2

    self:CreateHeader()
    self:CreateContainer()
    self:RefreshRows()

    self.refreshTimer = "BW_Scoreboard_Refresh_" .. tostring(math.Round(SysTime() * 1000))
    timer.Create(self.refreshTimer, 1, 0, function()
        if IsValid(self) then self:RefreshRows() end
    end)
end

function PANEL:CreateHeader()
    self.headerPanel = vgui.Create("DPanel", self)
    self.headerPanel:SetPos(self.LeftMargin, 50)
    self.headerPanel:SetSize(self.rowW, self.HeaderHeight)
    self.headerPanel.Paint = function(s, w, h)
        if #self.Columns == 0 then return end

        for i = 1, #self.Columns do
            local col = self.Columns[i]
            local left = self.colPositions[i] - self.LeftMargin
            local centerX = left + col.width / 2

            surface.SetFont("Inter18")
            local textW = surface.GetTextSize(col.header)
            local iconW = 16
            local gap = 6
            local totalW = (col.icon and (iconW + gap) or 0) + textW
            
            local startX = centerX - totalW / 2
            if col.hasAvatar then
                startX = self.AvatarOffsetX
            end
            
            if col.header == nil or col.header == "" then
                startX = startX + 2
            end

            local colIconMat = col.icon and GetIconMaterial(col.icon)
            if colIconMat and not colIconMat:IsError() then
                surface.SetDrawColor(255, 255, 255, 255)
                surface.SetMaterial(colIconMat)
                surface.DrawTexturedRect(startX, h/2 - iconW/2 - 5, iconW, iconW)
                draw.SimpleText(col.header, "Inter18", startX + iconW + gap, h/2 - 5, self.Colors.White, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            else
                draw.SimpleText(col.header, "Inter18", centerX, h/2 - 5, self.Colors.White, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
    end
end

function PANEL:CreateContainer()
    self.container = vgui.Create("DScrollPanel", self)
    self.container:SetPos(self.LeftMargin, 80)
    self.container:SetSize(self.rowW, self:GetTall() - 100)

    local vbar = self.container:GetVBar()
    vbar:SetWide(6) 
    
    vbar.btnUp:SetTall(0)
    vbar.btnDown:SetTall(0)
    vbar.btnUp.Paint = function() end
    vbar.btnDown.Paint = function() end

    vbar.Paint = function(s, w, h)
        draw.RoundedBox(3, 0, 0, w, h, Color(20, 20, 20, 100))
    end

    vbar.btnGrip.Paint = function(s, w, h)
        local gripColor = Color(90, 90, 90, 250)
        
        if s.Depressed then
            gripColor = Color(130, 130, 130, 255)
        elseif s:IsHovered() then
            gripColor = Color(110, 110, 110, 255)
        end

        draw.RoundedBox(3, 0, 0, w, h, gripColor)
    end
end

function PANEL:RefreshRows()
    if not IsValid(self.container) then return end

    local players = player.GetAll()
    table.sort(players, function(a, b)
        local teamA = tonumber(a:Team()) or 0
        local teamB = tonumber(b:Team()) or 0
        if teamA == teamB then
            return a:Nick():lower() < b:Nick():lower()
        end
        return teamA > teamB
    end)

    while #self.Rows > #players do
        local row = table.remove(self.Rows)
        if IsValid(row) then row:Remove() end
    end

    for i = #self.Rows + 1, #players do
        local row = vgui.Create("DPanel", self.container)
        row:SetTall(self.RowHeight)
        row:Dock(TOP)
        row:DockMargin(0, self.Spacing, 0, self.Spacing)
        
        row.Paint = function(s, w, h)
            surface.SetDrawColor(self.Colors.DarkGray45)
            surface.DrawRect(0, 0, w, h)

            local y = h / 2

            for c = 1, #self.Columns do
                local col = self.Columns[c]
                local value = s["col_" .. col.id]
                
                if value then
                    local displayValue = tostring(value)
                    if col.maxWidth and BW and BW.Utils then
                        displayValue = BW.Utils.TruncateText(displayValue, "Inter16Thin", col.maxWidth)
                    end

                    local left = self.colPositions[c] - self.LeftMargin
                    local x = left
                    if col.align == TEXT_ALIGN_CENTER then
                        x = left + col.width / 2
                    elseif col.align == TEXT_ALIGN_RIGHT then
                        x = left + col.width - 5
                    end
                    
                    if col.hasAvatar then
                        x = self.AvatarOffsetX + self.Spacing * 2
                    end

                    local prefixIconPath = s["col_prefixIcon_" .. col.id]
                    if prefixIconPath and col.hasPrefixIcon then
                        local iconMat = GetIconMaterial(prefixIconPath)
                        if iconMat and not iconMat:IsError() then
                            local iconSize = col.prefixIconSize or 16
                            local iconGap = 4
                            surface.SetDrawColor(255, 255, 255, 255)
                            surface.SetMaterial(iconMat)
                            surface.DrawTexturedRect(x, y - iconSize/2, iconSize, iconSize)
                            x = x + iconSize + iconGap
                        end
                    end

                    local textColor = s["col_color_" .. col.id] or col.color or self.Colors.White
                    draw.SimpleText(displayValue, "Inter16Thin", x, y, textColor, col.align, TEXT_ALIGN_CENTER)
                end
            end
        end

        if self.AvatarColumnIndex then
            local avatar = vgui.Create("CircularAvatar", row)
            avatar:SetSize(self.AvatarSize, self.AvatarSize)
            avatar:SetPos(5, (self.RowHeight - self.AvatarSize) / 2)
            row.avatar = avatar
        end

        local muteBtn = vgui.Create("DButton", row)
        muteBtn:SetSize(self.MuteBtnWidth, self.MuteBtnWidth)
        muteBtn:SetPos(self.rowW - self.MuteBtnWidth - self.MuteBtnMargin - 15, (self.RowHeight - self.MuteBtnWidth) / 2)
        muteBtn:SetText("")
        
        muteBtn.Paint = function(s, w, h)
            local iconPath = s._muted and "icon16/sound_mute.png" or "icon16/sound.png"
            local iconMat = GetIconMaterial(iconPath)
            if iconMat and not iconMat:IsError() then
                surface.SetDrawColor(255, 255, 255, 255)
                surface.SetMaterial(iconMat)
                surface.DrawTexturedRect(w/2 - 8, h/2 - 8, 16, 16)
            end
        end
        
        muteBtn.DoClick = function(s)
            local target = s._ply
            if IsValid(target) and target ~= LocalPlayer() then
                target:SetMuted(not target:IsMuted())
                s._muted = target:IsMuted()
                surface.PlaySound("garrysmod/ui_click.wav")
            end
        end
        row.muteBtn = muteBtn

        self.Rows[i] = row
    end

    for i, ply in ipairs(players) do
        if not IsValid(ply) then continue end
        local row = self.Rows[i]
        
        row.ply = ply

        for j = 1, #self.Columns do
            local col = self.Columns[j]
            if col.getter then
                row["col_" .. col.id] = col.getter(ply)
            end
            
            if col.hasPrefixIcon and col.prefixIconGetter then
                row["col_prefixIcon_" .. col.id] = col.prefixIconGetter(ply)
            end
            
            if col.id == "team" then
                row["col_color_team"] = team.GetColor(ply:Team()) or self.Colors.White
            end
        end

        if row.avatar and row._cachedPly ~= ply then
            row.avatar:SetPlayer(ply, 64)
            row._cachedPly = ply
        end

        local btn = row.muteBtn
        btn._ply = ply
        btn._muted = ply:IsMuted()
        btn:SetVisible(ply ~= LocalPlayer())
    end
end

function PANEL:Paint(w, h)
    draw.RoundedBox(8, 0, 0, w, h, self.Colors.DarkGray)
    draw.RoundedBox(8, 1, 1, w - 2, h - 2, self.Colors.DarkGray35)
    draw.SimpleText(GetHostName(), "Inter24", w/2, 15, self.Colors.White, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
end

function PANEL:OnRemove()
    if self.refreshTimer and timer.Exists(self.refreshTimer) then
        timer.Remove(self.refreshTimer)
    end
end

vgui.Register("ScoreboardUI", PANEL, "EditablePanel")