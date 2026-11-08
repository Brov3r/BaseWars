local MODULE = MODULE
MODULE.Name = "Notify"
MODULE.Author = "Brov3r"
MODULE.Require = {}

local PLAYER = FindMetaTable("Player")
local config = BW.Config.Notify or {}

-- Title is slightly larger than the body text; a tighter line height keeps multiline notices compact.
local TITLE_FONT = "Inter20"
local TEXT_FONT = "Inter18Thin"
local TEXT_LINE_HEIGHT = 20
local TITLE_TOP, TEXT_TOP = 8, 30

NOTIFY_INFO, NOTIFY_ERROR, NOTIFY_SUCCESS, NOTIFY_WARNING = 0, 1, 2, 3
-- Keep Sandbox's global hint constant intact. Custom hints use BW.NOTIFY_HINT.
NOTIFY_HINT = 3
BW.NOTIFY_HINT = 4

local TYPES = {
    [0] = {key = "Info", fallback = "Info", color = Color(112, 182, 240), icon = "icon16/information.png", log = "info"},
    [1] = {key = "Error", fallback = "Error", color = Color(240, 115, 120), icon = "icon16/exclamation.png", log = "error"},
    [2] = {key = "Success", fallback = "Success", color = Color(62, 214, 153), icon = "icon16/tick.png", log = "success"},
    [3] = {key = "Warn", fallback = "Warning", color = Color(235, 192, 102), icon = "icon16/error.png", log = "warn"},
    [4] = {key = "Hint", fallback = "Hint", color = Color(170, 155, 235), icon = "icon16/lightbulb.png", log = "info"}
}

local function Number(value, default, minimum, maximum)
    value = tonumber(value)
    if not BW.Utils.IsFinite(value) then value = default end
    return math.Clamp(value, minimum, maximum)
end

function MODULE:NormalizeNotification(kind, text, duration)
    kind = tonumber(kind)
    if not BW.Utils.IsFinite(kind) or not TYPES[kind] then kind = NOTIFY_INFO end
    text = tostring(text or "")
    if not utf8.len(text) then
        if not utf8.force then return end
        text = utf8.force(text)
    end
    text = string.Trim(text:gsub("\r\n", "\n"):gsub("\r", "\n"):gsub("%z", ""):gsub("\t", "    "))
    text = text:gsub("<#%x%x%x%x%x%x>", ""):gsub("</?color[^>]*>", "")
    if text == "" then return end
    local maxLength = math.floor(Number(config.MaxTextLength, 512, 1, 2048))
    if utf8.len(text) > maxLength then text = BW.Utils.UTF8Sub(text, 1, maxLength) .. "..." end
    local defaultDuration = Number(config.DefaultDuration, 5, 0.75, 30)
    local maxDuration = Number(config.MaxDuration, 30, 0.75, 60)
    duration = tonumber(duration)
    if not BW.Utils.IsFinite(duration) or duration <= 0 then duration = defaultDuration end
    return kind, text, math.Clamp(duration, 0.75, maxDuration)
end

function MODULE:Init()
    if SERVER then
        util.AddNetworkString("BW_CustomNotify")
        function PLAYER:Notify(kind, text, duration)
            if not IsValid(self) then return end
            kind, text, duration = MODULE:NormalizeNotification(kind, text, duration)
            if kind == nil then return end
            net.Start("BW_CustomNotify")
            net.WriteUInt(kind, 8)
            net.WriteString(text)
            net.WriteFloat(duration)
            net.Send(self)
        end
    else
        self:InitClient()
    end
end

function MODULE:InitClient()
    self.notifications = self.notifications or {}
    self.queue = self.queue or {}
    self.MAX_NOTIFICATIONS = math.floor(Number(config.MaxNotification, 5, 1, 8))
    self.MAX_QUEUED = math.floor(Number(config.MaxQueued, 64, 1, 256))
    self.NOTIF_SPACING = Number(config.Spacing, 8, 0, 24)
    self.SLIDE_SPEED = Number(config.SlideSpeed, 12, 1, 30)
    self.Margin = Number(config.Margin, 16, 0, 64)
    self.Opacity = Number(config.Opacity, 0.88, 0.4, 1)

    function PLAYER:Notify(kind, text, duration)
        MODULE:AddNotification(kind, text, duration)
    end

    -- Sandbox calls GM:AddNotify(text, legacyType, duration), not with a player.
    local gm = gmod.GetGamemode()
    if gm then
        gm.AddNotify = function(_, text, legacyType, duration)
            notification.AddLegacy(text, legacyType, duration)
        end
    end
    notification.AddLegacy = function(text, legacyType, duration)
        if isstring(text) and text:sub(1, 1) == "#" then text = language.GetPhrase(text:sub(2)) end
        MODULE:AddNotification(MODULE:MapLegacyType(legacyType), text, duration)
    end

    net.Receive("BW_CustomNotify", function()
        self:AddNotification(net.ReadUInt(8), net.ReadString(), net.ReadFloat())
    end)
    hook.Add("HUDPaint", "BW_CustomNotify", function() self:DrawNotify() end)
    hook.Add("OnScreenSizeChanged", "BW_Notify_Resize", function()
        self:FitToScreen(true)
        self:PumpQueue(RealTime())
    end)
    hook.Remove("HUDShouldDraw", "BW_HideLegacyNotify")
end

function MODULE:MapLegacyType(kind)
    -- Native IDs are fixed, even if another addon changes global constants.
    local legacy = {[0] = 0, [1] = 1, [2] = 3, [3] = 4, [4] = 2}
    return legacy[tonumber(kind)] or NOTIFY_INFO
end

function MODULE:GetMaterial(path)
    self.iconMaterials = self.iconMaterials or {}
    if not self.iconMaterials[path] then self.iconMaterials[path] = Material(path, "smooth") end
    return self.iconMaterials[path]
end

function MODULE:GetNotificationSound(kind)
    if config.Sound == false then return end
    local sound = config.Sound
    if kind == NOTIFY_ERROR then
        local errorSound = config.ErrorSound
        if errorSound == nil then errorSound = "buttons/button10.wav" end
        sound = errorSound
    end
    if isstring(sound) and sound ~= "" then return sound end
end

function MODULE:WrapText(text, maxWidth, maxLines)
    local lines = {}
    maxWidth = math.max(1, maxWidth)
    for paragraph in (text .. "\n"):gmatch("(.-)\n") do
        local current = ""
        for word in paragraph:gmatch("%S+") do
            local combined = current == "" and word or current .. " " .. word
            if current ~= "" and surface.GetTextSize(combined) > maxWidth then
                lines[#lines + 1], current = current, ""
            end
            -- Split long URLs/IDs by complete UTF-8 characters, not bytes.
            while surface.GetTextSize(word) > maxWidth do
                local low, high = 1, utf8.len(word)
                while low < high do
                    local middle = math.ceil((low + high) / 2)
                    if surface.GetTextSize(BW.Utils.UTF8Sub(word, 1, middle)) <= maxWidth then low = middle else high = middle - 1 end
                end
                lines[#lines + 1] = BW.Utils.UTF8Sub(word, 1, low)
                word = BW.Utils.UTF8Sub(word, low + 1)
            end
            if word ~= "" then current = current == "" and word or current .. " " .. word end
        end
        if current ~= "" or paragraph == "" then lines[#lines + 1] = current end
    end
    if #lines == 0 then lines[1] = "" end
    if maxLines and #lines > maxLines then
        for i = #lines, maxLines + 1, -1 do lines[i] = nil end
        lines[maxLines] = BW.Utils.TruncateText(lines[maxLines] .. " ...", TEXT_FONT, maxWidth)
    end
    return lines
end

function MODULE:CalculateNotificationSize(notif)
    local maxWidth = math.max(1, math.min(Number(config.MaxWidth, 380, 160, 600), ScrW() - self.Margin * 2))
    local textWidth = math.max(1, maxWidth - 70)
    local maxLines = math.min(math.floor(Number(config.MaxLines, 6, 1, 12)), math.max(1, math.floor((ScrH() - self.Margin * 2 - 44) / TEXT_LINE_HEIGHT)))
    surface.SetFont(TEXT_FONT)
    notif.lines = self:WrapText(notif.text, textWidth, maxLines)
    local widest = 0
    for _, line in ipairs(notif.lines) do widest = math.max(widest, surface.GetTextSize(line)) end
    local data = TYPES[notif.type]
    notif.typeName = Translate("Notify." .. data.key, data.fallback)
    notif.title = notif.typeName
    surface.SetFont(TITLE_FONT)
    widest = math.max(widest, surface.GetTextSize(notif.title))
    notif.width = math.min(maxWidth, math.max(math.min(240, maxWidth), widest + 70))
    notif.title = BW.Utils.TruncateText(notif.title, TITLE_FONT, math.max(1, notif.width - 70))
    notif.height = 44 + #notif.lines * TEXT_LINE_HEIGHT
end

function MODULE:FitToScreen(force)
    self:RemoveExpired(RealTime())
    local resized = self.ScreenWidth ~= ScrW() or self.ScreenHeight ~= ScrH()
    if force or resized then
        self.ScreenWidth, self.ScreenHeight = ScrW(), ScrH()
        for _, notif in ipairs(self.notifications) do self:CalculateNotificationSize(notif) end
        for _, notif in ipairs(self.queue) do self:CalculateNotificationSize(notif) end
    end
    local totalHeight = 0
    for _, notif in ipairs(self.notifications) do totalHeight = totalHeight + notif.height + self.NOTIF_SPACING end
    totalHeight = totalHeight - self.NOTIF_SPACING
    local paused = {}
    local now = RealTime()
    while #self.notifications > 1 and (#self.notifications > self.MAX_NOTIFICATIONS or totalHeight > ScrH() - self.Margin * 2) do
        local old = table.remove(self.notifications)
        totalHeight = totalHeight - old.height - self.NOTIF_SPACING
        old.duration = math.max(0.01, old.startTime + old.duration - now)
        old.startTime, old.y = nil, nil
        old.x = ScrW() + 12
        paused[#paused + 1] = old
    end
    for i = #paused, 1, -1 do table.insert(self.queue, 1, paused[i]) end
end

function MODULE:RemoveExpired(now)
    for i = #self.notifications, 1, -1 do
        local notif = self.notifications[i]
        if now >= notif.startTime + notif.duration then table.remove(self.notifications, i) end
    end
end

function MODULE:PumpQueue(now)
    local totalHeight = 0
    for _, notif in ipairs(self.notifications) do totalHeight = totalHeight + notif.height + self.NOTIF_SPACING end
    local added, addedError, playSound = false, false, false
    while #self.queue > 0 and #self.notifications < self.MAX_NOTIFICATIONS do
        local nextNotice = self.queue[1]
        if #self.notifications > 0 and totalHeight + nextNotice.height > ScrH() - self.Margin * 2 then break end
        table.remove(self.queue, 1)
        nextNotice.startTime = now
        nextNotice.x, nextNotice.y = ScrW() + 12, nil
        if not nextNotice.soundPlayed then
            nextNotice.soundPlayed = true
            playSound = true
            if nextNotice.type == NOTIFY_ERROR then addedError = true end
        end
        table.insert(self.notifications, 1, nextNotice)
        totalHeight = totalHeight + nextNotice.height + self.NOTIF_SPACING
        added = true
    end
    if added and playSound then
        local sound = self:GetNotificationSound(addedError and NOTIFY_ERROR or nil)
        if sound then surface.PlaySound(sound) end
    end
end

function MODULE:AddNotification(kind, text, duration)
    kind, text, duration = self:NormalizeNotification(kind, text, duration)
    if kind == nil then return end
    local now = RealTime()
    self:RemoveExpired(now)
    self:FitToScreen()
    self:PumpQueue(now)
    if #self.queue >= self.MAX_QUEUED then return end
    local notif = {type = kind, text = text, duration = duration, x = ScrW() + 12}
    self:CalculateNotificationSize(notif)
    table.insert(self.queue, notif)
    self:PumpQueue(now)
    if config.Log ~= false then Log(TYPES[kind].log, "[Notify]", text) end
    return notif
end

function MODULE:DrawNotify()
    if not self.notifications then return end
    local now = RealTime()
    self:RemoveExpired(now)
    self:FitToScreen()
    self:PumpQueue(now)
    local frame = RealFrameTime and RealFrameTime() or FrameTime()
    local blend = 1 - math.exp(-math.max(0, frame) * self.SLIDE_SPEED)
    local bottom = ScrH() - self.Margin
    for _, notif in ipairs(self.notifications) do
        local elapsed = now - notif.startTime
        local remaining = notif.duration - elapsed
        local alpha = math.Clamp(math.min(elapsed / 0.16, remaining / 0.24, 1) * 255, 0, 255)
        local targetX, targetY = ScrW() - self.Margin - notif.width, bottom - notif.height
        notif.x = Lerp(blend, notif.x, targetX)
        notif.y = Lerp(blend, notif.y or targetY, targetY)
        local x, y = math.floor(notif.x), math.floor(notif.y)
        local w, h = notif.width, notif.height
        local color = TYPES[notif.type].color
        draw.RoundedBox(9, x, y, w, h, Color(13, 18, 24, alpha * self.Opacity))
        surface.SetDrawColor(43, 54, 65, alpha * self.Opacity)
        surface.DrawLine(x + 9, y, x + w - 9, y)
        draw.RoundedBox(7, x + 12, y + 12, 32, 32, Color(color.r, color.g, color.b, alpha * 0.12))
        local material = self:GetMaterial(TYPES[notif.type].icon)
        if not material:IsError() then
            surface.SetMaterial(material)
            surface.SetDrawColor(255, 255, 255, alpha)
            surface.DrawTexturedRect(x + 19, y + 19, 18, 18)
        end
        draw.SimpleText(notif.title, TITLE_FONT, x + 56, y + TITLE_TOP, Color(color.r, color.g, color.b, alpha))
        for i, line in ipairs(notif.lines) do
            draw.SimpleText(line, TEXT_FONT, x + 56, y + TEXT_TOP + (i - 1) * TEXT_LINE_HEIGHT, Color(255, 255, 255, alpha))
        end
        local progress = math.Clamp(remaining / notif.duration, 0, 1)
        draw.RoundedBox(1, x + 12, y + h - 7, w - 24, 2, Color(color.r, color.g, color.b, alpha * 0.12))
        if progress > 0 then draw.RoundedBox(1, x + 12, y + h - 7, (w - 24) * progress, 2, Color(color.r, color.g, color.b, alpha * 0.7)) end
        bottom = targetY - self.NOTIF_SPACING
    end
end
