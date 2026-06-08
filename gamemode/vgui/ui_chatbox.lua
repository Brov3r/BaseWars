local PANEL = {}

function PANEL:Init()
	self:SetSize(BW.Config.Chat.SizeX, BW.Config.Chat.SizeY)
    self:SetPos(BW.Config.Chat.HPosOffset, ScrH() - BW.Config.Chat.VPosOffset)

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
		if not self.IsOpen then return end
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
            
            self:UpdateScroll()
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

function PANEL:UpdateScroll()
    self.Scroll:GetCanvas():InvalidateLayout(true)
    timer.Simple(0, function() 
        if IsValid(self.Scroll) and IsValid(self.Scroll:GetVBar()) then 
            self.Scroll:GetVBar():AnimateTo(self.Scroll:GetCanvas():GetTall(), 0.1) 
        end
    end)
end
function PANEL:HandleMessage(ply, text, isTeam, isDead)
    self.LastMessageTime = RealTime()
    self.MessageAlpha = 255
    
    local isPlayer = IsValid(ply) and ply:IsPlayer()
    local font = "Inter18"

    local iconPath = (BW.Config.Chat and BW.Config.Chat.SystemIcon) or "icon16/information.png"
    if isPlayer then
        local groupData = BW.Config.PlayerGroups[ply:GetUserGroup()]
        iconPath = (groupData and groupData.PrefixIcon) and groupData.PrefixIcon or ((BW.Config.Chat and BW.Config.Chat.DefaultUserIcon) or "icon16/user.png")
    end
    local iconMat = Material(iconPath, "noclamp")

    local mStr = string.format("<font=%s>", font)
    mStr = mStr .. string.format("<color=97,97,97>%s •</color> ", os.date("%H:%M"))
    
    if isDead then mStr = mStr .. string.format("<color=255,50,50>(%s)</color> ", "DEAD") end
    if isTeam then mStr = mStr .. string.format("<color=46,204,113>(%s)</color> ", "TEAM") end
    
    if isPlayer then
        local groupData = BW.Config.PlayerGroups[ply:GetUserGroup()]
        if groupData and groupData.PrefixText then
            local pc = groupData.PrefixColor or color_white
            mStr = mStr .. string.format("<color=%d,%d,%d>[%s]</color> ", pc.r, pc.g, pc.b, groupData.PrefixText)
        end
        local tc = team.GetColor(ply:Team()) or color_white
        mStr = mStr .. string.format("<color=%d,%d,%d>%s:</color> ", tc.r, tc.g, tc.b, ply:Nick())
    end
    
    local emojiID = 0
	local emojisUsed = {}
    if BW.Config.Chat.Emojis then
        for tag, path in pairs(BW.Config.Chat.Emojis) do
            if string.find(text, tag, 1, true) then
                local mat = Material(path, "noclamp")
                
                if mat and !mat:IsError() then
                    local id = table.Count(emojisUsed) + 1
                    emojisUsed[id] = mat
                    local replacement = string.format("<color=1,2,3,%d>      </color>", id)
					text = string.Replace(text, tag, replacement)
                end
            end
        end
    end
    
    mStr = mStr .. "<color=255,255,255>" .. text .. "</color></font>"
    
    local maxWidth = self.Scroll:GetWide() > 0 and self.Scroll:GetWide() or BW.Config.Chat.SizeX
    local parsed = markup.Parse(mStr, maxWidth - 35)
    
    local msgPnl = self.Scroll:Add("DPanel")
    msgPnl:Dock(TOP)
    msgPnl:DockMargin(0, 0, 0, 4)
    msgPnl:SetTall(math.max(20, parsed:GetHeight() + 4))
    
    msgPnl.Paint = function(s, w, h)
        if self.MessageAlpha <= 0 then return end
        
        surface.SetDrawColor(255, 255, 255, self.MessageAlpha)
        surface.SetMaterial(iconMat)
        surface.DrawTexturedRect(2, 2, 16, 16)
        
        if parsed and parsed.blocks then
            for _, blk in ipairs(parsed.blocks) do
                if not (blk.colour and blk.colour.r == 1 and blk.colour.g == 2 and blk.colour.b == 3) then
                    if blk.text and blk.text ~= "" then
                        surface.SetFont(blk.font)
                        local shadowAlpha = math.Clamp(self.MessageAlpha * 0.6, 0, 150)
                        surface.SetTextColor(0, 0, 0, shadowAlpha)
                        surface.SetTextPos(24 + blk.offset.x + 1, 2 + blk.offset.y + 1)
                        surface.DrawText(blk.text)
                    end
                end
            end

            for _, blk in ipairs(parsed.blocks) do
                if blk.colour and blk.colour.r == 1 and blk.colour.g == 2 and blk.colour.b == 3 then
                    local emID = blk.colour.a
                    local emMat = emojisUsed[emID]
                    
                    if emMat then
                        surface.SetDrawColor(255, 255, 255, self.MessageAlpha)
                        surface.SetMaterial(emMat)
                        surface.DrawTexturedRect(24 + blk.offset.x, 2 + blk.offset.y, 16, 16)
                    end
                else
                    if blk.text and blk.text ~= "" then
                        surface.SetFont(blk.font)
                        local r, g, b = blk.colour.r, blk.colour.g, blk.colour.b
                        local a = math.min(blk.colour.a or 255, self.MessageAlpha)
                        
                        surface.SetTextColor(r, g, b, a)
                        surface.SetTextPos(24 + blk.offset.x, 2 + blk.offset.y)
                        surface.DrawText(blk.text)
                    end
                end
            end
        end
    end

    surface.PlaySound("ambient/water/drip4.wav")
    
    self:UpdateScroll()
end

function PANEL:Think()
    if self.IsOpen then
        self.MessageAlpha = 255
    else
        local fadeTime = BW.Config.Chat.MessageFadeTime or 10
        local timePassed = RealTime() - self.LastMessageTime
        
        if timePassed > fadeTime then
            self.MessageAlpha = math.Clamp(255 - (timePassed - fadeTime) * 255, 0, 255)
        else
            self.MessageAlpha = 255
        end
    end
end

function PANEL:Paint(w, h)
    if self.IsOpen then
        local bg = BW.Config.Colors.DarkGray30
        draw.RoundedBox(8, 0, 0, w, h, Color(bg.r, bg.g, bg.b, 230))
    end
end

function PANEL:OpenChat(isTeam)
    self.IsOpen = true
    self.IsTeamChat = isTeam 
    self.HistoryPos = #self.History + 1
    
    self:SetSize(BW.Config.Chat.SizeX, BW.Config.Chat.SizeY)
    
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
    self:UpdateScroll()
end

function PANEL:CloseChat()
    self.IsOpen = false
    self.LastMessageTime = RealTime() 
    
    self:SetSize(BW.Config.Chat.SizeX, BW.Config.Chat.SizeY - 25)
    
    self.Entry:SetText("")
    self.InputPanel:SetVisible(false)
    self.Entry:KillFocus()
    
    self:SetKeyboardInputEnabled(false)
    self:SetMouseInputEnabled(false)
    gui.EnableScreenClicker(false) 
end

vgui.Register("ChatBox", PANEL, "EditablePanel")