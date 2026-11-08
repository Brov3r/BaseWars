local MODULE = MODULE

MODULE.Name = "Power"
MODULE.Author = "Brov3r"
MODULE.Require = {}

BW.Power = BW.Power or {}
local Power = BW.Power

-- Consumers are kept in a weak registry so generators do not have to scan
-- every entity on the map several times per second.
local consumers = setmetatable({}, { __mode = "k" })

local function IsFiniteNumber(value)
    value = tonumber(value)
    return value ~= nil and value == value and value > -math.huge and value < math.huge
end

function Power.ClampNumber(value, minValue, maxValue, fallback)
    if not IsFiniteNumber(value) then value = fallback end
    if not IsFiniteNumber(value) then return fallback or 0 end

    if minValue ~= nil then value = math.max(minValue, value) end
    if maxValue ~= nil then value = math.min(maxValue, value) end

    return value
end

function Power.Setting(section, key, fallback)
    local config = BW.Config and BW.Config.Power
    if type(config) ~= "table" then return fallback end

    local value = config[key]
    if value == nil and section and type(config[section]) == "table" then
        value = config[section][key]
    end

    if value == nil then return fallback end
    return value
end

-- Entity values take priority over the shared configuration, which makes it
-- possible to create specialised consumers without duplicating the base code.
function Power.GetValue(ent, field, section, key, fallback, minValue, maxValue)
    local value = ent and ent[field]
    if value == nil then value = Power.Setting(section, key, nil) end
    if value == nil then value = fallback end
    return Power.ClampNumber(value, minValue, maxValue, fallback)
end

function Power.GetBool(ent, field, section, key, fallback)
    local value = ent and ent[field]
    if value == nil then value = Power.Setting(section, key, nil) end
    if value == nil then value = fallback end
    return value == true
end

function Power.GetTickRate(ent)
    return Power.ClampNumber(ent and ent.PowerTick or Power.Setting(nil, "TickRate", 0.25), 0.05, 5, 0.25)
end

function Power.IsConsumer(ent)
    return IsValid(ent) and ent.PowerConsumer == true
end

function Power.RegisterConsumer(ent)
    if not Power.IsConsumer(ent) then return false end
    consumers[ent] = true
    return true
end

function Power.UnregisterConsumer(ent)
    consumers[ent] = nil
end

function Power.GetConsumers()
    local result = {}
    for ent in pairs(consumers) do
        if Power.IsConsumer(ent) then
            result[#result + 1] = ent
        else
            consumers[ent] = nil
        end
    end
    return result
end

local function GetFillRatio(ent)
    local stored = 0
    local capacity = 1

    if type(ent.GetStoredEnergy) == "function" then
        stored = tonumber(ent:GetStoredEnergy()) or 0
    end
    if type(ent.GetEnergyCapacity) == "function" then
        capacity = tonumber(ent:GetEnergyCapacity()) or 0
    end

    if capacity <= 0 then return 1 end
    return math.Clamp(stored / capacity, 0, 1)
end

function Power.GetConsumersInRadius(origin, radius)
    if not origin then return {} end

    radius = Power.ClampNumber(radius, 0, nil, 0)
    local radiusSqr = radius * radius
    local result = {}

    for _, ent in ipairs(Power.GetConsumers()) do
        local pos = ent.GetPos and ent:GetPos() or nil
        if pos and type(pos.DistToSqr) == "function" and pos:DistToSqr(origin) <= radiusSqr then
            result[#result + 1] = ent
        end
    end

    -- Empty consumers receive energy first, so a single generator can bring
    -- several devices online instead of fully charging the nearest one.
    table.sort(result, function(a, b)
        return GetFillRatio(a) < GetFillRatio(b)
    end)

    return result
end

function Power.GetOwner(ent)
    if not IsValid(ent) then return nil end

    if type(ent.GetDeviceOwner) == "function" then
        return ent:GetDeviceOwner()
    end

    if BW.Ownership and type(BW.Ownership.GetOwner) == "function" then
        return BW.Ownership.GetOwner(ent)
    end

    return ent.Owner
end

function Power.CanConnect(generator, consumer)
    if not IsValid(generator) or not IsValid(consumer) or generator == consumer then return false end
    if not Power.IsConsumer(consumer) then return false end

    if Power.GetBool(generator, "PowerOnlyOwner", "Generator", "OnlyOwner", false) then
        local generatorOwner = Power.GetOwner(generator)
        local consumerOwner = Power.GetOwner(consumer)
        if not IsValid(generatorOwner) or generatorOwner ~= consumerOwner then return false end
    end

    return true
end

function Power.FormatEnergy(value)
    value = Power.ClampNumber(value, 0, nil, 0)
    local absValue = math.abs(value)

    -- Keep small values readable, but abbreviate large energy pools so the
    -- HUD never shows long numbers such as 12500/250000.
    if absValue < 10000 then
        if BW.Utils and type(BW.Utils.NumWithSep) == "function" then
            return BW.Utils.NumWithSep(math.floor(value + 0.5))
        end

        local plain = tostring(math.floor(value + 0.5))
        local grouped = plain:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
        return grouped
    end

    local divisor, suffix
    if absValue >= 1000000000 then
        divisor, suffix = 1000000000, "b"
    elseif absValue >= 1000000 then
        divisor, suffix = 1000000, "m"
    else
        divisor, suffix = 1000, "k"
    end

    local scaled = absValue / divisor
    local formatted
    if scaled >= 100 then
        formatted = string.format("%.0f", scaled)
    elseif scaled >= 10 then
        formatted = string.format("%.1f", scaled):gsub("%.0$", "")
    else
        formatted = string.format("%.2f", scaled):gsub("0+$", ""):gsub("%.$", "")
    end

    return formatted .. suffix
end
