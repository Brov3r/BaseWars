local MODULE = MODULE

MODULE.Name = "Notify"
MODULE.Author = "Brov3r"
MODULE.Require = {}

local PLAYER = FindMetaTable("Player")

local config    = BW.Config
local colors    = config.Colors
local mod       = MODULE

local NOTIFY_TYPES = {
    [0] = {logLevel = "info",    name = Translate("Notify.Info", "Info"),    color = colors.Info, icon = "icon16/information.png"},
    [1] = {logLevel = "error",   name = Translate("Notify.Error", "Error"),  color = colors.Error, icon = "icon16/exclamation.png"},
    [2] = {logLevel = "success", name = Translate("Notify.Success", "Success"), color = colors.Success, icon = "icon16/tick.png"},
    [3] = {logLevel = "warn",    name = Translate("Notify.Warn", "Warning"), color = colors.Warn,  icon = "icon16/error.png"},
    [4] = {logLevel = "info",    name = Translate("Notify.Hint", "Hint"),    color = colors.Hint or colors.Info, icon = "icon16/lightbulb.png"},
}

NOTIFY_INFO    = 0
NOTIFY_ERROR   = 1
NOTIFY_SUCCESS = 2
NOTIFY_WARNING = 3
NOTIFY_HINT    = 4

function MODULE:Init()
    if SERVER then
        util.AddNetworkString("BW_CustomNotify")

        function PLAYER:Notify(notifType, text, duration)
            if not IsValid(self) then return end
            notifType = tonumber(notifType) or NOTIFY_INFO
            text = tostring(text or "")
            duration = tonumber(duration) or 5

            net.Start("BW_CustomNotify")
                net.WriteUInt(notifType, 8)
                net.WriteString(text)
                net.WriteFloat(duration)
            net.Send(self)
        end
    else
        self.notifications = {}
        self:InitClient()
    end
end

function MODULE:InitClient()
    self.MAX_NOTIFICATIONS = (config.Notify and config.Notify.MaxNotification) or 5
    self.NOTIF_SPACING     = (config.Notify and config.Notify.Spacing) or 10
    self.SLIDE_SPEED       = (config.Notify and config.Notify.SlideSpeed) or 5

    function PLAYER:Notify(notifType, text, duration)
        MODULE:AddNotification(notifType, text, duration)
    end

    local gm = gmod.GetGamemode()
    if gm then
        gm.AddNotify = function(self, ply, msgType, text)
            if IsValid(ply) and ply == LocalPlayer() then
                MODULE:AddNotification(MODULE:MapLegacyType(msgType), text, 5)
            end
        end
    end

    function notification.AddLegacy(text, legacyType, duration)
        MODULE:AddNotification(MODULE:MapLegacyType(legacyType), text, duration or 5)
    end

    self:RegisterHooks()
end

function MODULE:RegisterHooks()
    hook.Add("HUDShouldDraw", "BW_HideLegacyNotify", function(name)
        if name == "Notify" then return false end
    end)

    net.Receive("BW_CustomNotify", function()
        MODULE:AddNotification(net.ReadUInt(8), net.ReadString(), net.ReadFloat())
    end)

    hook.Add("HUDPaint", "BW_CustomNotify", function()
        return MODULE:DrawNotify()
    end)
end

function MODULE:DrawNotify()
    if not IsValid(LocalPlayer()) then return end

    local scrW, scrH = ScrW(), ScrH()
    local now = CurTime()
    local ft = FrameTime()
    local baseY = scrH - 20
    local currentY = baseY

    for i = #self.notifications, 1, -1 do
        local notif = self.notifications[i]
        local elapsed = now - notif.startTime
        local timeLeft = notif.duration - elapsed

        if timeLeft <= 0 then
            table.remove(self.notifications, i)
            continue
        end

        local NOTIF_WIDTH = notif.width
        local NOTIF_HEIGHT = notif.height 
        notif.targetX = scrW - NOTIF_WIDTH - 20

        if elapsed < 0.4 then
            notif.alpha = math.Approach(notif.alpha or 0, 255, ft * 700)
            notif.x = Lerp(ft * self.SLIDE_SPEED * 1.2, notif.x, notif.targetX)
            notif.scale = Lerp(ft * 8, notif.scale or 0.95, 1)
        elseif timeLeft < 0.6 then
            notif.alpha = math.Approach(notif.alpha or 255, 0, ft * 400)
            notif.scale = Lerp(ft * 6, notif.scale or 1, 0.95)
        else
            notif.alpha = 255
            notif.scale = 1
        end

        local alpha = math.Clamp(notif.alpha or 0, 0, 255)
        currentY = currentY - NOTIF_HEIGHT - self.NOTIF_SPACING

        if alpha <= 0 then continue end

        local x = math.floor(notif.x)
        local y = currentY + self.NOTIF_SPACING
        local col = notif.color

        draw.RoundedBox(8, x, y, NOTIF_WIDTH, NOTIF_HEIGHT, Color(22, 22, 26, alpha * 0.95))
        draw.RoundedBox(8, x, y, NOTIF_WIDTH, 1, Color(255, 255, 255, alpha * 0.05))

        draw.RoundedBox(4, x, y, 4, NOTIF_HEIGHT, Color(col.r, col.g, col.b, alpha))

        local mat = self:GetMaterial(notif.icon)
        if mat and not mat:IsError() then
            draw.RoundedBox(6, x + 12, y + 8, 36, 36, Color(col.r, col.g, col.b, alpha * 0.1))
            surface.SetDrawColor(255, 255, 255, alpha)
            surface.SetMaterial(mat)
            surface.DrawTexturedRect(x + 18, y + 14, 24, 24)
        end

        draw.SimpleText(notif.typeName, "Inter18", x + 58, y + 8,
            Color(col.r, col.g, col.b, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        local textY = y + 29
        for _, line in ipairs(notif.lines) do
            draw.SimpleText(line, "Inter16Thin", x + 58, textY,
                Color(220, 220, 220, alpha * 0.9), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            textY = textY + 18
        end

        local barX = x
        local barWidth = NOTIF_WIDTH
        local barHeight = 4
        local barY = y + NOTIF_HEIGHT - barHeight
        
        local progressWidth = barWidth * math.Clamp(timeLeft / notif.duration, 0, 1)

        draw.RoundedBox(barHeight / 2, barX, barY, barWidth, barHeight, Color(col.r * 0.5, col.g * 0.5, col.b * 0.5, alpha * 0.4))
        
        if progressWidth > 0 then
            draw.RoundedBox(barHeight / 2, barX, barY, progressWidth, barHeight, Color(col.r, col.g, col.b, alpha))

            draw.RoundedBox(barHeight / 2, barX, barY, progressWidth, 1, Color(255, 255, 255, alpha * 0.25))
        end
    end
end

function MODULE:GetMaterial(iconPath)
    self.iconMaterials = self.iconMaterials or {}
    if not self.iconMaterials[iconPath] then
        self.iconMaterials[iconPath] = Material(iconPath)
    end
    return self.iconMaterials[iconPath]
end

function MODULE:MapLegacyType(legacyType)
    if legacyType == NOTIFY_GENERIC then return NOTIFY_INFO
    elseif legacyType == NOTIFY_ERROR   then return NOTIFY_ERROR
    elseif legacyType == NOTIFY_UNDO    then return NOTIFY_WARNING
    elseif legacyType == NOTIFY_HINT    then return NOTIFY_HINT
    elseif legacyType == NOTIFY_CLEANUP then return NOTIFY_SUCCESS
    end
    return NOTIFY_INFO
end

function MODULE:WrapText(text, maxWidth)
    local lines = {}
    local words = string.Explode(" ", text)
    local currentLine = ""
    for _, word in ipairs(words) do
        local testLine = (currentLine == "" and word) or (currentLine .. " " .. word)
        if surface.GetTextSize(testLine) > maxWidth and currentLine ~= "" then
            lines[#lines + 1] = currentLine
            currentLine = word
        else
            currentLine = testLine
        end
    end
    if currentLine ~= "" then lines[#lines + 1] = currentLine end
    return lines
end

function MODULE:CalculateNotificationSize(notif)
    if notif.calculatedSize then return end

    surface.SetFont("Inter16Thin")
    local maxWidth = 300
    local lines = self:WrapText(notif.text, maxWidth)

    notif.lines = lines
    local lineHeight = 20
    notif.textHeight = #lines * lineHeight

    local maxLineW = 0
    for _, line in ipairs(lines) do
        local w = surface.GetTextSize(line)
        if w > maxLineW then maxLineW = w end
    end
    notif.width = math.Clamp(maxLineW + 70, 150, 400)
    notif.height = 40 + notif.textHeight
    notif.calculatedSize = true
end

function MODULE:AddNotification(notifType, text, duration)
    local typeData = NOTIFY_TYPES[notifType] or NOTIFY_TYPES[NOTIFY_INFO]
    local notif = {
        type      = notifType,
        text      = text,
        duration  = duration,
        startTime = CurTime(),
        alpha     = 0,
        x         = ScrW(),
        targetX   = 0,
        color     = typeData.color or colors.Info,
        icon      = typeData.icon,
        typeName  = typeData.name,
    }
    self:CalculateNotificationSize(notif)

    table.insert(self.notifications, 1, notif)
    while #self.notifications > self.MAX_NOTIFICATIONS do
        table.remove(self.notifications)
    end

    surface.PlaySound("HL1/fvox/blip.wav")
    if Log then Log(typeData.logLevel, "[Notify]", text) end
end