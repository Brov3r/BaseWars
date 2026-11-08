local PANEL = {}

local matCache = {}
local function GetCachedMaterial(path)
    if not matCache[path] then
        matCache[path] = Material(path, "noclamp smooth")
    end
    return matCache[path]
end

local function StyleScrollBar(scroll, colors, visible)
    local bar = scroll:GetVBar()
    bar:SetWide(5)
    bar:SetHideButtons(true)
    bar.btnUp.Paint = function() end
    bar.btnDown.Paint = function() end
    bar.Paint = function(_, w, h)
        if visible and not visible() then return end
        draw.RoundedBox(3, 0, 0, w, h, colors.Row)
    end
    bar.btnGrip.Paint = function(grip, w, h)
        if visible and not visible() then return end
        draw.RoundedBox(3, 0, 0, w, h, (grip.Depressed or grip:IsHovered()) and colors.Accent or colors.ScrollGrip)
    end
end

function PANEL:Init()
    local cfgChat = BW.Config.Chat
    local accent = (BW.Config.Scoreboard or {}).AccentColor or Color(62, 214, 153)
    self.Colors = {
        Background = Color(13, 18, 24, 252), Border = Color(43, 54, 65),
        Row = Color(24, 31, 40), Selected = Color(24, 43, 42),
        White = Color(255, 255, 255), Muted = Color(155, 168, 182),
        Accent = accent, ScrollGrip = Color(63, 91, 91)
    }
    local colors = self.Colors
    self.InputHeight = 34
    self:SetSize(cfgChat.SizeX, cfgChat.SizeY)
    self:SetPos(cfgChat.HPosOffset, ScrH() - cfgChat.VPosOffset)

    self.IsOpen = false
    self.IsTeamChat = false
    self.LastMessageTime = RealTime()
    self.MessageAlpha = 255
    
    self.History = {}
    self.HistoryPos = 0

    self.DragHeight = 12
    self.DragHandle = vgui.Create("DPanel", self)
    self.DragHandle:Dock(TOP)
    self.DragHandle:SetTall(self.DragHeight)
    self.DragHandle:SetCursor("sizeall")
    self.DragHandle:SetTooltip(Translate("Chat.MoveHint", "Drag to move. Right click to reset position."))
    self.DragHandle.Paint = function(handle, w, h)
        draw.RoundedBox(1, (w - 28) / 2, 5, 28, 2, (self.Dragging or handle:IsHovered()) and colors.Accent or colors.Border)
    end
    self.DragHandle.OnMousePressed = function(handle, button)
        if button == MOUSE_LEFT then
            local mouseX, mouseY = gui.MousePos()
            local x, y = self:LocalToScreen(0, 0)
            self.Dragging = {x = mouseX - x, y = mouseY - y}
            handle:MouseCapture(true)
        elseif button == MOUSE_RIGHT then
            local menu = DermaMenu()
            menu:AddOption(Translate("Chat.ResetPosition", "Reset chat position"), function()
                if IsValid(self) then self:ResetPosition() end
            end):SetIcon("icon16/arrow_refresh.png")
            menu:Open()
        end
    end
    self.DragHandle.OnMouseReleased = function(handle, button)
        if button ~= MOUSE_LEFT then return end
        self.Dragging = nil
        handle:MouseCapture(false)
        self:SavePosition()
    end

    self.Scroll = vgui.Create("DScrollPanel", self)
    self.Scroll:Dock(FILL)
    self.Scroll:DockMargin(10, 8, 10, 8)
    StyleScrollBar(self.Scroll, colors, function() return self.IsOpen end)

    self.EmojiPanel = vgui.Create("DPanel")
    self.EmojiPanel:SetMouseInputEnabled(true)
    self.EmojiPanel:SetKeyboardInputEnabled(false)
    self.EmojiPanel:SetVisible(false)
    self.EmojiPanel.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, colors.Border)
        draw.RoundedBox(8, 1, 1, w - 2, h - 2, colors.Background)
    end

    local emojiScroll = vgui.Create("DScrollPanel", self.EmojiPanel)
    emojiScroll:Dock(FILL)
    emojiScroll:DockMargin(8, 8, 8, 8)
    StyleScrollBar(emojiScroll, colors)

    local emojiList = vgui.Create("DIconLayout", emojiScroll)
    emojiList:Dock(FILL)
    emojiList:SetSpaceX(5)
    emojiList:SetSpaceY(5)

    if cfgChat and cfgChat.Emojis then
        local tags = table.GetKeys(cfgChat.Emojis)
        table.sort(tags)
        for _, tag in ipairs(tags) do
            local path = cfgChat.Emojis[tag]
            local btn = emojiList:Add("DButton")
            btn:SetSize(26, 26)
            btn:SetText("")
            btn:SetTooltip(self:GetEmojiTooltip(tag))
            
            local cachedMat = GetCachedMaterial(path)
            btn.Paint = function(s, w, h)
                if s:IsHovered() then draw.RoundedBox(5, 0, 0, w, h, colors.Selected) end
                surface.SetDrawColor(255, 255, 255, 255)
                surface.SetMaterial(cachedMat)
                surface.DrawTexturedRect((w - 16) / 2, (h - 16) / 2, 16, 16)
            end
            btn.DoClick = function()
                local current = self.Entry:GetValue()
                self.Entry:SetText(current .. tag)
                self.Entry:SetCaretPos(#self.Entry:GetValue())
                self:SetEmojiVisible(false)
                self.Entry:RequestFocus()
            end
        end
    end

    self.InputPanel = vgui.Create("DPanel", self)
    self.InputPanel:Dock(BOTTOM)
    self.InputPanel:SetHeight(self.InputHeight)
    self.InputPanel:DockMargin(8, 0, 8, 8)
    self.InputPanel.Paint = function(_, w, h)
        draw.RoundedBox(7, 0, 0, w, h, colors.Border)
        draw.RoundedBox(7, 1, 1, w - 2, h - 2, colors.Row)
    end

    self.TeamLabel = vgui.Create("DLabel", self.InputPanel)
    self.TeamLabel:Dock(LEFT)
    self.TeamLabel:DockMargin(8, 0, 2, 0)
    self.TeamLabel:SetFont("Inter18")
    self.TeamLabel:SetTextColor(colors.Accent)
    self.TeamLabel:SetText("")
    self.TeamLabel:SetVisible(false)
    self.TeamLabel.Paint = function(s, w, h)
        draw.SimpleText(s:GetText(), s:GetFont(), 0, h / 2, colors.Accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        return true
    end

    self.SendButton = vgui.Create("DButton", self.InputPanel)
    self.SendButton:Dock(RIGHT)
    self.SendButton:SetWide(30)
    self.SendButton:DockMargin(0, 3, 3, 3)
    self.SendButton:SetText("")
    self.SendButton:SetTooltip(Translate("Chat.SendMessage", "Send message"))
    self.SendButton:SetFont("Inter18")
    self.SendButton:SetTextColor(color_white)
    self.SendButton.Paint = function(s, w, h)
        if s:IsHovered() then draw.RoundedBox(5, 0, 0, w, h, colors.Selected) end
        draw.SimpleText("›", "Inter24", w / 2, h / 2 - 1, colors.Accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    self.SendButton.DoClick = function()
        self:SendMessage()
    end

    self.EmojiBtn = vgui.Create("DButton", self.InputPanel)
    self.EmojiBtn:Dock(RIGHT)
    self.EmojiBtn:SetWide(30)
    self.EmojiBtn:DockMargin(0, 3, 3, 3)
    self.EmojiBtn:SetText("")
    self.EmojiBtn:SetTooltip(Translate("Chat.ChooseEmoji", "Choose emoji"))
    self.EmojiBtn:SetFont("Inter18")
    self.EmojiBtn:SetTextColor(color_white)
    
    local smileMat = GetCachedMaterial("icon16/emoticon_smile.png")
    self.EmojiBtn.Paint = function(s, w, h)
        if self.EmojiPanel:IsVisible() or s:IsHovered() then draw.RoundedBox(5, 0, 0, w, h, colors.Selected) end
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(smileMat)
        surface.DrawTexturedRect(w/2 - 8, h/2 - 8, 16, 16)
    end
    self.EmojiBtn.DoClick = function()
        self:SetEmojiVisible(not self.EmojiPanel:IsVisible())
    end

    self.Entry = vgui.Create("DTextEntry", self.InputPanel)
    self.Entry:Dock(FILL)
    self.Entry:DockMargin(8, 0, 4, 0)
    self.Entry:SetPaintBackground(false)
    self.Entry:SetTextColor(color_white)
    self.Entry:SetFont("Inter18")
    self.Entry:SetCursorColor(colors.Accent)
    self.Entry:SetHighlightColor(colors.Selected)
    self.Entry.Paint = function(s, w, h)
        s:DrawTextEntryText(colors.White, colors.Selected, colors.Accent)
    end
    
    self.Entry.OnKeyCode = function(s, code)
        if code == KEY_ENTER or code == KEY_PAD_ENTER then
            self:SendMessage()
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

    self:OpenChat(false)
    self:CloseChat()
end

function PANEL:GetEmojiTooltip(tag)
    local id = tag:match("^:([%w_]+):$") or tag
    local fallback = id:gsub("_", " "):gsub("^%l", string.upper)
    return Translate("Chat.Emojis." .. id, fallback) .. " (" .. tag .. ")"
end

function PANEL:GetChatSize()
    local cfg = BW.Config.Chat
    local emojiWidth = math.min(cfg.EmojiWidth or 180, math.max(80, ScrW() * 0.3))
    -- Reserve enough room to keep the picker on the right, even on small screens.
    local width = math.max(1, math.min(cfg.SizeX, ScrW() - emojiWidth - 5 - 16))
    local height = math.max(1, math.min(cfg.SizeY, ScrH() - 16))
    return width, height, emojiWidth
end

function PANEL:SetChatPosition(x, y)
    local width, height, emojiWidth = self:GetChatSize()
    local pickerVisible = IsValid(self.EmojiPanel) and self.EmojiPanel:IsVisible()
    local extraWidth = pickerVisible and emojiWidth + 5 or 0
    self:SetPos(math.Clamp(x, 0, math.max(0, ScrW() - width - extraWidth)), math.Clamp(y, 0, math.max(0, ScrH() - height)))
    self:PositionEmojiPicker()
end

function PANEL:ApplyGeometry()
    local width, height = self:GetChatSize()
    local closedOffset = self.InputHeight + 8 + self.DragHeight
    self:SetSize(width, self.IsOpen and height or math.max(1, height - closedOffset))
    local savedX = cookie.GetNumber("bw_chat_position_x", -1)
    local savedY = cookie.GetNumber("bw_chat_position_y", -1)
    local x = savedX >= 0 and math.Clamp(savedX, 0, 1) * math.max(0, ScrW() - width) or BW.Config.Chat.HPosOffset
    local y = savedY >= 0 and math.Clamp(savedY, 0, 1) * math.max(0, ScrH() - height) or ScrH() - BW.Config.Chat.VPosOffset
    self:SetChatPosition(x, y)
end

function PANEL:SavePosition()
    local width, height = self:GetChatSize()
    local x, y = self:GetPos()
    cookie.Set("bw_chat_position_x", x / math.max(1, ScrW() - width))
    cookie.Set("bw_chat_position_y", y / math.max(1, ScrH() - height))
end

function PANEL:ResetPosition()
    cookie.Set("bw_chat_position_x", -1)
    cookie.Set("bw_chat_position_y", -1)
    self:ApplyGeometry()
end

function PANEL:PositionEmojiPicker()
    if not IsValid(self.EmojiPanel) or not self.EmojiPanel:IsVisible() then return end
    local _, _, width = self:GetChatSize()
    local x, y = self:LocalToScreen(self:GetWide() + 5, 0)
    if self.EmojiPanel:GetWide() ~= width or self.EmojiPanel:GetTall() ~= self:GetTall() then
        self.EmojiPanel:SetSize(width, self:GetTall())
    end
    self.EmojiPanel:SetPos(x, y)
end

function PANEL:SetEmojiVisible(visible)
    if not IsValid(self.EmojiPanel) then return end
    visible = visible and self.IsOpen
    self.EmojiPanel:SetVisible(visible)
    if visible then
        local x, y = self:GetPos()
        self:SetChatPosition(x, y)
        self.EmojiPanel:MakePopup()
        self.EmojiPanel:SetKeyboardInputEnabled(false)
        self.Entry:RequestFocus()
    end
end

function PANEL:OnRemove()
    if IsValid(self.DragHandle) then self.DragHandle:MouseCapture(false) end
    if IsValid(self.EmojiPanel) then self.EmojiPanel:Remove() end
end

function PANEL:SendMessage()
    local txt = string.Trim(self.Entry:GetValue())
    if #txt > BW.Config.Chat.MaxMessageLenght or not utf8.len(txt) then return end
    local cleanText = tostring(txt)
    cleanText = string.gsub(cleanText, "<[^>]+>", "")
    cleanText = string.gsub(cleanText, "%s+", " ")
    cleanText = string.Trim(cleanText)
    if txt ~= "" then 
        net.Start("BW_CustomChat_Send")
            net.WriteString(txt)
            net.WriteBool(self.IsTeamChat)
        net.SendToServer()
        
        if self.History[#self.History] ~= cleanText then
            table.insert(self.History, cleanText)
            if #self.History > 50 then table.remove(self.History, 1) end
        end
    end
    self:UpdateScroll()
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
    local cleanText = tostring(text)
    cleanText = string.gsub(cleanText, "<[^>]+>", "")
    cleanText = string.gsub(cleanText, "%s+", " ")
    cleanText = string.Trim(cleanText)

    local sender = IsValid(ply) and ply:IsPlayer() and ply:Nick() or "Server"
    Log(sender .. ": " .. cleanText)
    
    self.LastMessageTime = RealTime()
    self.MessageAlpha = 255
    
    local cfgChat = BW.Config.Chat
    local isPlayer = IsValid(ply) and ply:IsPlayer()
    local font = "Inter18"

    local iconPath = cfgChat.SystemIcon or "icon16/information.png"
    if isPlayer then
        local groupData = BW.Config.PlayerGroups[ply:GetUserGroup()]
        iconPath = (groupData and groupData.PrefixIcon) or cfgChat.DefaultUserIcon or "icon16/user.png"
    end
    local iconMat = GetCachedMaterial(iconPath)

    local mStr = string.format("<font=%s>", font)
    mStr = mStr .. string.format("<color=155,168,182>%s</color> ", os.date("%H:%M"))
    
    if isDead then mStr = mStr .. string.format("<color=255,50,50>(%s)</color> ", Translate("Chat.DeadText","DEAD")) end
    if isTeam then
        local accent = self.Colors.Accent
        mStr = mStr .. string.format("<color=%d,%d,%d>(%s)</color> ", accent.r, accent.g, accent.b, Translate("Chat.TeamText","TEAM"))
    end
    
    if isPlayer then
        local groupData = BW.Config.PlayerGroups[ply:GetUserGroup()]
        if groupData and groupData.PrefixText then
            local pc = groupData.PrefixColor or color_white
            mStr = mStr .. string.format("<color=%d,%d,%d>[%s]</color> ", pc.r, pc.g, pc.b, groupData.PrefixText)
        end
        local tc = team.GetColor(ply:Team()) or color_white
        mStr = mStr .. string.format("<color=%d,%d,%d>%s:</color> ", tc.r, tc.g, tc.b, BW.Utils.EscapeMarkup(ply:Nick()))
    end
    
    local emojiID = 0
    local emojisUsed = {}
    if cfgChat.Emojis then
        for tag, path in pairs(cfgChat.Emojis) do
            if string.find(text, tag, 1, true) then
                local mat = GetCachedMaterial(path)
                if mat and not mat:IsError() then
                    local id = table.Count(emojisUsed) + 1
                    emojisUsed[id] = mat
                    local replacement = string.format("<color=1,2,3,%d>      </color>", id)
                    text = string.Replace(text, tag, replacement)
                end
            end
        end
    end
    
    mStr = mStr .. "<color=255,255,255>" .. text .. "</color></font>"
    
    local maxWidth = self.Scroll:GetWide() > 0 and self.Scroll:GetWide() or cfgChat.SizeX
    local parsed = markup.Parse(mStr, maxWidth - 35)
    
    local maxMessages = BW.Config.Chat.MaxMessageHistory
    local canvas = self.Scroll:GetCanvas()
    if #canvas:GetChildren() >= maxMessages then
        canvas:GetChildren()[1]:Remove()
    end

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
                local isEmoji = blk.colour and blk.colour.r == 1 and blk.colour.g == 2 and blk.colour.b == 3
                
                if isEmoji then
                    local emID = blk.colour.a
                    local emMat = emojisUsed[emID]
                    if emMat then
                        surface.SetDrawColor(255, 255, 255, self.MessageAlpha)
                        surface.SetMaterial(emMat)
                        surface.DrawTexturedRect(24 + blk.offset.x, 2 + blk.offset.y, 16, 16)
                    end
                elseif blk.text and blk.text ~= "" then
                    surface.SetFont(blk.font)
                    
                    local shadowAlpha = math.Clamp(self.MessageAlpha * 0.6, 0, 150)
                    surface.SetTextColor(0, 0, 0, shadowAlpha)
                    surface.SetTextPos(24 + blk.offset.x + 1, 2 + blk.offset.y + 1)
                    surface.DrawText(blk.text)
                    
                    local r, g, b = blk.colour.r, blk.colour.g, blk.colour.b
                    local a = math.min(blk.colour.a or 255, self.MessageAlpha)
                    surface.SetTextColor(r, g, b, a)
                    surface.SetTextPos(24 + blk.offset.x, 2 + blk.offset.y)
                    surface.DrawText(blk.text)
                end
            end
        end
    end

    surface.PlaySound("ambient/water/drip4.wav")
    self:UpdateScroll()
end

function PANEL:Think()
    if self.IsOpen and self.Dragging then
        local x, y = gui.MousePos()
        self:SetChatPosition(x - self.Dragging.x, y - self.Dragging.y)
    end
    self:PositionEmojiPicker()
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
        draw.RoundedBox(10, 0, 0, w, h, self.Colors.Border)
        draw.RoundedBox(10, 1, 1, w - 2, h - 2, self.Colors.Background)
    end
end

function PANEL:OpenChat(isTeam)
    self.IsOpen = true
    self.IsTeamChat = isTeam 
    self.HistoryPos = #self.History + 1
    
    self.DragHandle:SetVisible(true)
    self:ApplyGeometry()
    
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
    self:InvalidateLayout(true)
    self.Entry:RequestFocus()
    self:UpdateScroll()
end

function PANEL:CloseChat()
    self.Dragging = nil
    self.DragHandle:MouseCapture(false)
    self.DragHandle:SetVisible(false)
    self:SetEmojiVisible(false)
    self.IsOpen = false
    self.LastMessageTime = RealTime() 
    
    self:ApplyGeometry()
    
    self.Entry:SetText("")
    self.InputPanel:SetVisible(false)
    self.EmojiPanel:SetVisible(false)
    self.Entry:KillFocus()
    
    self:SetKeyboardInputEnabled(false)
    self:SetMouseInputEnabled(false)
    gui.EnableScreenClicker(false)
    self:InvalidateLayout(true)
end

vgui.Register("ChatBox", PANEL, "EditablePanel")
