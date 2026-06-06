BW.Utils = BW.Utils or {}
BW.Utils.AnimStates = BW.Utils.AnimStates or {}

BW.Lang = BW.Lang or {}
BW.Lang._Cache = BW.Lang._Cache or {}

local textCache = {} 

local math_Clamp = math.Clamp
local math_floor = math.floor
local math_abs   = math.abs
local math_log10 = math.log10
local string_sub = string.sub
local SysTime    = SysTime
local Lerp       = Lerp
local table_insert = table.insert

function BW.Utils.Log(...)
    local args = {...}
    if #args == 0 then return end

    local level = "info"
    local startIndex = 1
    local firstArg = args[1]

    if type(firstArg) == "string" then
        local l = string.lower(firstArg)
        if l == "warn" or l == "error" or l == "success" or l == "info" then
            level = l
            startIndex = 2
        end
    end

    local cols = BW.Config.Colors or {}
    local levelColor = cols.Info or color_white

    if level == "warn" then levelColor = cols.Warn or Color(255, 150, 0)
    elseif level == "error" then levelColor = cols.Error or Color(255, 0, 0)
    elseif level == "success" then levelColor = cols.Success or Color(0, 255, 0)
    end

    local msgArgs = {
        cols.Gray128 or Color(128, 128, 128), os.date("%H:%M:%S"),
        color_white, " • ",
        cols.Cyan or Color(0, 255, 255), "BW",
        color_white, " - ",
        levelColor, string.upper(level),
        color_white, " > "
    }

    for i = startIndex, #args do
        local v = args[i]
        
        if type(v) == "table" and v.r and v.g and v.b then
            table_insert(msgArgs, v)
        else
            table_insert(msgArgs, tostring(v))
            
            if i < #args then
                local nextArg = args[i + 1]
                if type(nextArg) ~= "table" or not (nextArg.r and nextArg.g and nextArg.b) then
                    table_insert(msgArgs, " ")
                end
            end
        end
    end

    table_insert(msgArgs, "\n")
    MsgC(unpack(msgArgs))
end

local function NormalizeKey(str)
    return string.lower(str):gsub("[_.%s%-]", "")
end

local function FindTranslation(tbl, normalizedKey)
    if type(tbl) ~= "table" then return nil end
    
    for k, v in pairs(tbl) do
        if NormalizeKey(k) == normalizedKey then
            return v
        end
    end
    
    for _, v in pairs(tbl) do
        if type(v) == "table" then
            local found = FindTranslation(v, normalizedKey)
            if found ~= nil then return found end
        end
    end
    
    return nil
end

function BW.Utils.Translate(id, fallback)
    if not id then return fallback or "" end
    
    local lang = GetConVar("gmod_language"):GetString() or "en"
    local cacheKey = lang .. ":" .. id
    
    if BW.Lang._Cache[cacheKey] ~= nil then
        return BW.Lang._Cache[cacheKey]
    end
    
    local result = nil
    
    if string.find(id, "%.") then
        local tbl = BW.Lang[lang]
        for part in string.gmatch(id, "[^.]+") do
            if type(tbl) == "table" then
                tbl = tbl[part]
            else
                tbl = nil
                break
            end
        end
        if type(tbl) == "string" then
            result = tbl
        end
    end
    
    if not result and BW.Lang[lang] then
        result = FindTranslation(BW.Lang[lang], NormalizeKey(id))
    end
    
    if not result and lang ~= "en" and BW.Lang["en"] then
        result = FindTranslation(BW.Lang["en"], NormalizeKey(id))
    end
    
    if not result and CLIENT then
        local phrase = language.GetPhrase(id)
        if phrase ~= id then
            result = phrase
        end
    end
    
    result = result or (fallback and fallback ~= "" and fallback) or id
    
    BW.Lang._Cache[cacheKey] = result
    return result
end

function BW.Utils.SmoothValue(stateKey, targetValue, animTime)
    animTime = animTime or 0.2
    local now = SysTime()

    local state = BW.Utils.AnimStates[stateKey]
    
    if not state then
        BW.Utils.AnimStates[stateKey] = {
            from = targetValue,
            to = targetValue,
            start = now,
            lastUpdate = now
        }
        return targetValue
    end

    state.lastUpdate = now

    if state.to ~= targetValue then
        local prog = math_Clamp((now - state.start) / animTime, 0, 1)
        state.from = Lerp(prog, state.from, state.to)
        state.to = targetValue
        state.start = now
        return state.from
    end

    local progress = math_Clamp((now - state.start) / animTime, 0, 1)
    return Lerp(progress, state.from, state.to)
end

function BW.Utils.TruncateText(text, font, maxWidth)
    if not maxWidth or maxWidth <= 0 then return text end
    
    local cacheKey = text .. font .. maxWidth
    if textCache[cacheKey] then return textCache[cacheKey] end

    surface.SetFont(font)
    if surface.GetTextSize(text) <= maxWidth then 
        textCache[cacheKey] = text
        return text 
    end

    local result = text
    while #result > 1 and surface.GetTextSize(result .. "...") > maxWidth do
        result = string_sub(result, 1, -2)
    end
    
    result = result .. "..."
    textCache[cacheKey] = result
    
    if table.Count(textCache) > 1000 then textCache = {} end

    return result
end

function BW.Utils.NumWithSep(amount)
    amount = tonumber(amount) or 0
    
    local sign = amount < 0 and "-" or ""
    local num = math_abs(amount)
    local str = tostring(math_floor(num + 0.5))

    local formatted = str:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return sign .. formatted
end

function BW.Utils.CompactNum(amount)
    amount = tonumber(amount) or 0
    local absAmount = math_abs(amount)
    
    if absAmount < 1 then return "0" end
    if absAmount < 1000000 then return BW.Utils.NumWithSep(amount) end
    
    local sign = amount < 0 and "-" or ""
    local tier = math_floor(math_log10(absAmount) / 3)
    
    local suffixes = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx"}
    local suffix = suffixes[tier + 1] or ("e" .. (tier * 3))
    
    local scaled = absAmount / (10 ^ (tier * 3))
    local formatted = string.format("%.1f", scaled):gsub("%.0$", "")
    
    return sign .. formatted .. suffix
end

function BW.Utils.DrawShadowedText(text, font, x, y, color, shadowColor, offsetX, offsetY, alignX, alignY)
    offsetX = offsetX or 2
    offsetY = offsetY or 2
    shadowColor = shadowColor or Color(0, 0, 0, 200)
    color = color or color_white
    alignX = alignX or TEXT_ALIGN_LEFT
    alignY = alignY or TEXT_ALIGN_TOP

    draw.SimpleText(text, font, x + offsetX, y + offsetY, shadowColor, alignX, alignY)
    draw.SimpleText(text, font, x, y, color, alignX, alignY)
end

function BW.Utils.DrawProgressBar(x, y, w, h, value, min, max, colorBar, colorBackground)
    local cols = BW.Config and BW.Config.Colors or {}
    colorBar = colorBar or cols.White or color_white
    colorBackground = colorBackground or cols.DarkGray or Color(40, 40, 40)

    local range = max - min
    local fraction = range ~= 0 and math_Clamp((value - min) / range, 0, 1) or 0

    surface.SetDrawColor(colorBackground)
    surface.DrawRect(x, y, w, h)

    if fraction > 0 then
        surface.SetDrawColor(colorBar)
        surface.DrawRect(x, y, math_floor(w * fraction), h)
    end
end

-- GC
if CLIENT then
    timer.Create("BW_AnimStates_GC", 5, 0, function()
        local now = SysTime()
        
        for key, state in pairs(BW.Utils.AnimStates) do
            if (now - state.lastUpdate) > 1 then
                BW.Utils.AnimStates[key] = nil
            end
        end    
	end)
end

-- Global Export
Utils = BW.Utils
Log = BW.Utils.Log
Translate = BW.Utils.Translate