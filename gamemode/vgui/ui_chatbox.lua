local PANEL = {}

function PANEL:Init()
    self:SetSize(500, 250)
    self:SetPos(10, ScrH() - 420)
    
    self.IsOpen = false
    self.IsTeamChat = false
    self.LastMessageTime = RealTime()
    self.MessageAlpha = 255
    
    self.History = {}
    self.HistoryPos = 0

    self.Scroll = vgui.Create("DScrollPanel", self)
    self.Scroll:Dock(FILL)
    self.Scroll:DockMargin(5, 5, 5, 5)
    
    local vbar = self.Scroll:GetVBar()
    vbar:SetWide(6)
    vbar.Paint = function() end
    vbar.btnUp.Paint = function() end
    vbar.btnDown.Paint = function() end
    vbar.btnGrip.Paint = function(s, w, h)
        draw.RoundedBox(3, 0, 0, w, h, Color(128, 128, 128, self.MessageAlpha))
    end

    self.InputPanel = vgui.Create("DPanel", self)
    self.InputPanel:Dock(BOTTOM)
    self.InputPanel:SetHeight(25)
    self.InputPanel:SetPaintBackground(false)

    self.TeamLabel = vgui.Create("DLabel", self.InputPanel)
    self.TeamLabel:Dock(LEFT)
    self.TeamLabel:DockMargin(0, 3, 0, 0) 
    self.TeamLabel:SetFont("Inter18")
    self.TeamLabel:SetTextColor(Color(46, 204, 113))
    self.TeamLabel:SetText("")
    self.TeamLabel:SetVisible(false)
    self.TeamLabel.Paint = function(s, w, h)
        draw.SimpleText(s:GetText(), s:GetFont(), 1, 1, Color(0, 0, 0, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(s:GetText(), s:GetFont(), 0, 0, s:GetTextColor(), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        return true
    end

    self.Entry = vgui.Create("DTextEntry", self.InputPanel)
    self.Entry:Dock(FILL)
    self.Entry:SetPaintBackground(false)
    self.Entry:SetTextColor(color_white)
    self.Entry:SetFont("Inter18")
    self.Entry.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 220))
        s:DrawTextEntryText(color_white, Color(30, 130, 255), color_white)
    end
    
    self.Entry.OnKeyCode = function(s, code)
        if code == KEY_ENTER or code == KEY_PAD_ENTER then
            local txt = string.Trim(s:GetValue())
            if txt ~= "" then 
                if self.IsTeamChat then
                    RunConsoleCommand("say_team", txt)
                else
                    RunConsoleCommand("say", txt) 
                end
                
                if self.History[#self.History] ~= txt then
                    table.insert(self.History, txt)
                    if #self.History > 50 then table.remove(self.History, 1) end
                end
            end
            self:CloseChat()
            return true
            
        elseif code == KEY_UP then
            if #self.History > 0 then
                self.HistoryPos = math.max(1, self.HistoryPos - 1)
                s:SetText(self.History[self.HistoryPos] or "")
                s:SetCaretPos(#s:GetValue())
            end
            return true
            
        elseif code == KEY_DOWN then
            if #self.History > 0 then
                self.HistoryPos = math.min(#self.History + 1, self.HistoryPos + 1)
                s:SetText(self.History[self.HistoryPos] or "")
                s:SetCaretPos(#s:GetValue())
            end
            return true
        end
    end

	self:OpenChat(false )
	self:CloseChat()
end

function PANEL:Paint(w, h)
    if self.IsOpen then
        local bg = BW.Config.Colors.DarkGray30
        draw.RoundedBox(8, 0, 0, w, h, Color(bg.r, bg.g, bg.b, 230))
    end
end

function PANEL:Think()
    if self.IsOpen then
        self.MessageAlpha = 255
        self.InputPanel:SetVisible(true)
        self.Scroll:SetVisible(true)
    else
        local timeSinceClose = RealTime() - self.LastMessageTime
        
        if timeSinceClose < 8 then
            self.MessageAlpha = 255
        elseif timeSinceClose < 10 then
            local fadeProgress = (timeSinceClose - 8) / 2
            self.MessageAlpha = 255 * (1 - fadeProgress)
        else
            self.MessageAlpha = 0
        end
        
        if self.MessageAlpha <= 1 then
            self.InputPanel:SetVisible(false)
            self.Scroll:SetVisible(false)
        else
            self.Scroll:SetVisible(true)
        end
    end
    
    if IsValid(self.Scroll) and IsValid(self.Scroll:GetCanvas()) then
        for _, row in pairs(self.Scroll:GetCanvas():GetChildren()) do
            if row.SetMessageAlpha then
                row:SetMessageAlpha(self.MessageAlpha)
            end
        end
    end
end

function PANEL:AddMessage(iconPath, prefixText, prefixColor, args)
    if not self.IsOpen then
        self.LastMessageTime = RealTime()
    end

    local row = self.Scroll:Add("DPanel")
    row:Dock(TOP)
    row:DockMargin(2, 2, 2, 2)
    row:SetPaintBackground(false)

    row.Time = vgui.Create("DLabel", row)
    row.Time:SetFont("Inter18")
    row.Time:SetText(os.date("[%H:%M]"))
    row.Time:SetTextColor(Color(0, 0, 0, 0))
    row.Time.CustomColor = Color(150, 150, 150)
    row.Time.Paint = function(s, w, h)
        local text = s:GetText()
        local font = s:GetFont()
        local col = s.CustomColor
        
        if not self.IsOpen then
            draw.SimpleText(text, font, 1, 1, Color(0, 0, 0, col.a), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
        draw.SimpleText(text, font, 0, 0, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        return true
    end
    
    row.Icon = vgui.Create("DImage", row)
    row.Icon:SetSize(16, 16)
    row.Icon:SetImage(iconPath or "icon16/information.png")

    row.Prefix = vgui.Create("DLabel", row)
    row.Prefix:SetFont("Inter18")
    if prefixText and prefixText ~= "" then
        row.Prefix:SetText("[" .. prefixText .. "]")
        row.Prefix.CustomColor = prefixColor or color_white
    else
        row.Prefix:SetVisible(false)
        row.Prefix.CustomColor = color_white
    end
    row.Prefix:SetTextColor(Color(0, 0, 0, 0))
    row.Prefix.Paint = function(s, w, h)
        local text = s:GetText()
        local font = s:GetFont()
        local col = s.CustomColor
        
        if not self.IsOpen then
            draw.SimpleText(text, font, 1, 1, Color(0, 0, 0, col.a), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
        draw.SimpleText(text, font, 0, 0, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        return true
    end

    local strColor = "<font=Inter18>"
    local strShadow = "<font=Inter18>"
    local curColor = color_white

    for _, v in ipairs(args) do
        if type(v) == "table" and v.r and v.g and v.b then
            curColor = v
        elseif IsColor(v) then
            curColor = v
        elseif IsEntity(v) and v:IsPlayer() then
            local c = team.GetColor(v:Team())
            strColor = strColor .. string.format("<color=%d,%d,%d>%s</color>", c.r, c.g, c.b, v:Nick())
            strShadow = strShadow .. string.format("<color=0,0,0>%s</color>", v:Nick())
        else
            local safeText = tostring(v):gsub("<", "&lt;"):gsub(">", "&gt;")
            strColor = strColor .. string.format("<color=%d,%d,%d>%s</color>", curColor.r, curColor.g, curColor.b, safeText)
            strShadow = strShadow .. string.format("<color=0,0,0>%s</color>", safeText)
        end
    end
    strColor = strColor .. "</font>"
    strShadow = strShadow .. "</font>"

    row.MarkupObj = markup.Parse(strColor, 350) 
    row.MarkupShadow = markup.Parse(strShadow, 350)

    row.TextPanel = vgui.Create("DPanel", row)
    row.TextPanel.Paint = function(s, w, h)
        if not self.IsOpen and row.MarkupShadow then
            row.MarkupShadow:Draw(1, 1, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, self.MessageAlpha)
        end
        if row.MarkupObj then
            row.MarkupObj:Draw(0, 0, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, self.MessageAlpha)
        end
    end

    row.PerformLayout = function(s, w, h)
        local left = 4
        local firstLineH = 20
        
        s.Time:SizeToContents()
        s.Time:SetPos(left, (firstLineH - s.Time:GetTall()) / 2)
        left = left + s.Time:GetWide() + 6
        
        s.Icon:SetPos(left, (firstLineH - 16) / 2)
        left = left + 16 + 6
        
        if s.Prefix:IsVisible() then
            s.Prefix:SizeToContents()
            s.Prefix:SetPos(left, (firstLineH - s.Prefix:GetTall()) / 2)
            left = left + s.Prefix:GetWide() + 4
        end
        
        local textSpace = w - left - 10
        if s.LastW ~= textSpace then
            row.MarkupObj = markup.Parse(strColor, textSpace)
            row.MarkupShadow = markup.Parse(strShadow, textSpace)
            s.LastW = textSpace
        end

        s.TextPanel:SetPos(left, 2)
        s.TextPanel:SetSize(textSpace, row.MarkupObj:GetHeight())
        
        local calculatedHeight = math.max(20, s.TextPanel:GetTall() + 4)
        if s:GetTall() ~= calculatedHeight then
            s:SetHeight(calculatedHeight)
            self.Scroll:GetCanvas():InvalidateLayout()
        end
    end

    function row:SetMessageAlpha(alpha)
        local a = math.Clamp(alpha, 0, 255)
        self.Time.CustomColor.a = a
        self.Prefix.CustomColor.a = a
        self.Icon:SetAlpha(a)
    end

    timer.Simple(0.05, function()
        if IsValid(self) and IsValid(self.Scroll) and IsValid(self.Scroll:GetVBar()) then
            self.Scroll:GetVBar():AnimateTo(self.Scroll:GetCanvas():GetTall(), 0.1, 0, -1)
        end
    end)
end

function PANEL:OpenChat(isTeam)
    self.IsOpen = true
    self.IsTeamChat = isTeam 
    self.HistoryPos = #self.History + 1
    
    self:SetVisible(true)
    self:SetMouseInputEnabled(true)
    self:SetKeyboardInputEnabled(true)
    self:MakePopup()
    
    self.InputPanel:SetVisible(true)
    self.Scroll:SetVisible(true)
    
    if isTeam then
        local teamStr = string.format("(%s) ", Translate and Translate("Chat.TeamText", "TEAM") or "TEAM")
        self.TeamLabel:SetText(teamStr)
        self.TeamLabel:SizeToContents()
        self.TeamLabel:SetVisible(true)
    else
        self.TeamLabel:SetVisible(false)
    end
    
    self.InputPanel:InvalidateLayout(true)
    
    self.Entry:RequestFocus()
end

function PANEL:CloseChat()
    self.IsOpen = false
    self.LastMessageTime = RealTime() 
    
    self.Entry:SetText("")
    self.InputPanel:SetVisible(false)
    self.Entry:KillFocus()
    
    self:SetKeyboardInputEnabled(false)
    self:SetMouseInputEnabled(false)
    -- gui.EnableScreenClicker(false) 
end

vgui.Register("ChatBox", PANEL, "EditablePanel")