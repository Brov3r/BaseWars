local translate = BW.Translate.Notify

local NOTIFY_TYPES = {
    [0] = {logLevel = "info",    name = translate.Info,    color = Colors.Info, icon = "icon16/information.png"},
    [1] = {logLevel = "error",   name = translate.Error,   color = Colors.Error, icon = "icon16/exclamation.png"},
    [2] = {logLevel = "success", name = translate.Success, color = Colors.Success, icon = "icon16/tick.png"},
    [3] = {logLevel = "warn",    name = translate.Warn,    color = Colors.Warn,  icon = "icon16/error.png"},
    [4] = {logLevel = "info",    name = translate.Hint,    color = Colors.Hint, icon = "icon16/lightbulb.png"},
}

NOTIFY_INFO    = 0
NOTIFY_ERROR   = 1
NOTIFY_SUCCESS = 2
NOTIFY_WARNING = 3
NOTIFY_HINT    = 4

local PLAYER = FindMetaTable("Player")

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

    return
end

local notifications = {}
local MAX_NOTIFICATIONS = BW.Config.Notify.MaxNotification
local NOTIF_SPACING = BW.Config.Notify.Spacing
local SLIDE_SPEED = BW.Config.Notify.SlideSpeed

local iconMaterials = {}
local function GetMaterial(iconPath)
    if not iconMaterials[iconPath] then
        iconMaterials[iconPath] = Material(iconPath)
    end
    return iconMaterials[iconPath]
end

local function MapLegacyType(legacyType)
    if legacyType == NOTIFY_GENERIC then return NOTIFY_INFO
    elseif legacyType == NOTIFY_ERROR   then return NOTIFY_ERROR
    elseif legacyType == NOTIFY_UNDO    then return NOTIFY_WARNING
    elseif legacyType == NOTIFY_HINT    then return NOTIFY_HINT
    elseif legacyType == NOTIFY_CLEANUP then return NOTIFY_SUCCESS
    end
    return NOTIFY_INFO
end

local function WrapText(text, maxWidth)
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

local function CalculateNotificationSize(notif)
    if notif.calculatedSize then return end

    surface.SetFont("Inter16Thin")
    local maxWidth = 300
    local lines = WrapText(notif.text, maxWidth)

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

local function AddNotification(notifType, text, duration)
    local typeData = NOTIFY_TYPES[notifType] or NOTIFY_TYPES[NOTIFY_INFO]
    local notif = {
        type      = notifType,
        text      = text,
        duration  = duration,
        startTime = CurTime(),
        alpha     = 0,
        x         = ScrW(),
        targetX   = 0,
        color     = typeData.color or Colors.Info,
        icon      = typeData.icon,
        typeName  = typeData.name,
    }
    CalculateNotificationSize(notif)

    table.insert(notifications, 1, notif)
    while #notifications > MAX_NOTIFICATIONS do
        table.remove(notifications)
    end

    surface.PlaySound("buttons/blip1.wav")
    BW.Log(typeData.logLevel, "[Notify]", text)
end

function PLAYER:Notify(notifType, text, duration)
    AddNotification(notifType, text, duration)
end

local gm = gmod.GetGamemode()
if gm then
    gm.AddNotify = function(self, ply, msgType, text)
        if IsValid(ply) and ply == LocalPlayer() then
            AddNotification(MapLegacyType(msgType), text, 5)
        end
    end
end

function notification.AddLegacy(text, legacyType, duration)
    AddNotification(MapLegacyType(legacyType), text, duration or 5)
end

hook.Add("HUDShouldDraw", "BW_HideLegacyNotify", function(name)
    if name == "Notify" then return false end
end)

net.Receive("BW_CustomNotify", function()
    AddNotification(net.ReadUInt(8), net.ReadString(), net.ReadFloat())
end)
hook.Add("HUDPaint", "BW_CustomNotify", function()
    if not IsValid(LocalPlayer()) then return end

    local scrW, scrH = ScrW(), ScrH()
    local now = CurTime()
    local ft = FrameTime()
    local baseY = scrH - 20
    local currentY = baseY

    for i = #notifications, 1, -1 do
        local notif = notifications[i]
        local elapsed = now - notif.startTime
        local timeLeft = notif.duration - elapsed

        if timeLeft <= 0 then
            table.remove(notifications, i)
            continue
        end

        local NOTIF_WIDTH = notif.width
        local NOTIF_HEIGHT = notif.height
        notif.targetX = scrW - NOTIF_WIDTH - 20

        if elapsed < 0.3 then
            notif.alpha = math.Approach(notif.alpha or 0, 255, ft * 600)
            notif.x = Lerp(ft * SLIDE_SPEED, notif.x, notif.targetX)
        elseif timeLeft < 0.5 then
            notif.alpha = math.Approach(notif.alpha or 255, 0, ft * 500)
        else
            notif.alpha = 255
        end

        local alpha = math.Clamp(notif.alpha or 0, 0, 255)
        if alpha <= 0 then continue end

        local x = math.floor(notif.x)
        local y = currentY - NOTIF_HEIGHT
        local col = notif.color

        draw.RoundedBox(0, x + 2, y + 2, NOTIF_WIDTH, NOTIF_HEIGHT, Color(0, 0, 0, alpha * 0.3))
        draw.RoundedBox(0, x, y, NOTIF_WIDTH, NOTIF_HEIGHT, Color(40, 40, 40, alpha * 0.95))

        draw.RoundedBox(0, x, y, 6, NOTIF_HEIGHT, Color(col.r, col.g, col.b, alpha))

        local mat = GetMaterial(notif.icon)
        if mat and not mat:IsError() then
            surface.SetDrawColor(255, 255, 255, alpha)
            surface.SetMaterial(mat)
            surface.DrawTexturedRect(x + 15, y + 10, 32, 32)
        end

        draw.SimpleText(notif.typeName, "Inter18", x + 55, y + 10,
            Color(col.r, col.g, col.b, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        local textY = y + 30
        for _, line in ipairs(notif.lines) do
            draw.SimpleText(line, "Inter16Thin", x + 55, textY,
                Color(255, 255, 255, alpha * 0.9), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            textY = textY + 20
        end

        local progressWidth = (NOTIF_WIDTH - 10) * math.Clamp(timeLeft / notif.duration, 0, 1)
        draw.RoundedBox(0, x + 5, y + NOTIF_HEIGHT - 5, progressWidth, 5,
            Color(col.r, col.g, col.b, alpha))

        currentY = currentY - NOTIF_HEIGHT - NOTIF_SPACING
    end
end)