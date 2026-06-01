BW.Utils = BW.Utils or {}
BW.Utils.AnimStates = BW.Utils.AnimStates or {}

function BW.Log(...)
    local args = {...}
    local level = "info"
    local textParts = {}

    local validLevels = {info = true, warn = true, error = true, success = true}
    if validLevels[args[1]] then
        level = table.remove(args, 1)
    end

    local timestamp = os.date("%H:%M:%S")
    local prefix = "[BW]"

    for i, v in ipairs(args) do
        if type(v) == "table" then
            textParts[#textParts + 1] = "<Table>"
            PrintTable(v)
        else
            textParts[#textParts + 1] = tostring(v)
        end
    end
    local text = table.concat(textParts, " ")

    local colors = {
        info = BW.Config.Colors.Info,
        warn = BW.Config.Colors.Warn,
        error = BW.Config.Colors.Error,
        success = BW.Config.Colors.Success,
    }
    local levelColor = colors[level] or BW.Config.Colors.White

    MsgC(BW.Config.Colors.Gray, timestamp .. " ")
    MsgC(BW.Config.Colors.Cyan, prefix .. " ")
    MsgC(levelColor, "[" .. string.upper(level) .. "] ")
    MsgC(BW.Config.Colors.White, text)
    Msg("\n")
end

function BW.Utils.SmoothValue(stateKey, value, animTime)
    animTime = animTime or 0.2
    local now = SysTime()

    local state = BW.Utils.AnimStates[stateKey]
    if not state then
        state = {
            from = value,
            to = value,
            animStart = now,
        }
        BW.Utils.AnimStates[stateKey] = state
        return value
    end

    if state.to ~= value then
        local progress = math.Clamp((now - state.animStart) / animTime, 0, 1)
        local currentSmooth = Lerp(progress, state.from, state.to)
        state.from = currentSmooth
        state.to = value
        state.animStart = now
    end

    local progress = math.Clamp((now - state.animStart) / animTime, 0, 1)
    return Lerp(progress, state.from, state.to)
end

function BW.Utils.StringMoney(amount)
    amount = tonumber(amount) or 0
    
    local sign = ""
    local num = amount
    if num < 0 then
        sign = "-"
        num = -num
    end

    local intPart = math.floor(num + 0.5)
    local str = tostring(intPart)

    local formatted = str:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")

    return sign .. formatted
end

function BW.Utils.TruncateText(text, font, maxWidth)
    if not maxWidth or maxWidth <= 0 then return text end
    surface.SetFont(font)
    if surface.GetTextSize(text) <= maxWidth then return text end
    while #text > 1 and surface.GetTextSize(text .. "...") > maxWidth do
        text = string.sub(text, 1, -2)
    end
    return text .. "..."
end

function BW.Utils.DrawShadowedText(text, font, x, y, color, shadowColor, offsetX, offsetY)
    offsetX = offsetX or 2
    offsetY = offsetY or 2
    shadowColor = shadowColor or Color(0, 0, 0, 200)
    color = color or color_white

    draw.SimpleText(text, font, x + offsetX, y + offsetY, shadowColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText(text, font, x, y, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end

function BW.Utils.DrawFilledRect(x, y, w, h, color)
    surface.SetDrawColor(color)
    surface.DrawRect(x, y, w, h)
end

function BW.Utils.DrawProgressBar(x, y, w, h, value, min, max, colorBar, colorBackground)
    colorBar = colorBar or Colors.White
    colorBackground = colorBackground or Colors.DarkGray

    local range = max - min
    local fraction = 0
    if range ~= 0 then
        fraction = math.Clamp((value - min) / range, 0, 1)
    end

    surface.SetDrawColor(colorBackground)
    surface.DrawRect(x, y, w, h)

    if fraction > 0 then
        surface.SetDrawColor(colorBar)
        surface.DrawRect(x, y, w * fraction, h)
    end
end

function BW.Utils.DrawAnimatedProgressBar(id, x, y, w, h, value, min, max, colorBar, colorBackground, animTime)
    animTime = animTime or 0.2
    local smoothValue = BW.Utils.SmoothValue(id, value, animTime)

    BW.Utils.DrawProgressBar(x, y, w, h, smoothValue, min, max, colorBar, colorBackground)
end