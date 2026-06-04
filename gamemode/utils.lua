BW.Utils = BW.Utils or {}
BW.Utils.AnimStates = BW.Utils.AnimStates or {}

function BW.Log(...)
    local args = {...}
    local argCount = #args
    if argCount == 0 then return end

    local level = "info"
    local startIndex = 1
    local firstArg = args[1]

    if type(firstArg) == "string" then
        if firstArg == "warn" or firstArg == "error" or firstArg == "success" or firstArg == "info" then
            level = firstArg
            startIndex = 2
        end
    end

    local cols = BW.Config.Colors
    
    local levelColor = cols.Info
    if level == "warn" then levelColor = cols.Warn
    elseif level == "error" then levelColor = cols.Error
    elseif level == "success" then levelColor = cols.Success
    end

    local msgArgs = {
        cols.Gray128, os.date("%H:%M:%S"),
        cols.White,   " • ",
        cols.Cyan,    "BW",
        cols.White,   " - ",
        levelColor,   string.upper(level),
        cols.White,   " > "
    }
    
    local idx = 13 

    for i = startIndex, argCount do
        local v = args[i]
        
        if type(v) == "table" then
            if v.r and v.g and v.b then
                msgArgs[idx] = v
                idx = idx + 1
            else
                msgArgs[idx] = cols.White
                msgArgs[idx + 1] = "<Table>"
                idx = idx + 2
                PrintTable(v)
            end
        else
            msgArgs[idx] = tostring(v)
            idx = idx + 1
            
            if i < argCount then
                local nextArg = args[i + 1]
                if type(nextArg) ~= "table" or not (nextArg.r and nextArg.g and nextArg.b) then
                    msgArgs[idx] = " "
                    idx = idx + 1
                end
            end
        end
    end

    msgArgs[idx] = "\n"

    MsgC(unpack(msgArgs))
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

function BW.Utils.StringNumber(amount)
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