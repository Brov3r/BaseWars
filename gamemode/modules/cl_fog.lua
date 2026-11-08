local MODULE = MODULE

MODULE.Name = "Fog"
MODULE.Author = "Brov3r"
MODULE.Require = {}

local fogCfg = BW.Config.Fog or {}
local waterCfg = fogCfg.Water or {}
local mapZones = BW.Config.MapZones or {}
local zone = mapZones[game.GetMap()] or mapZones.Default
local waterZ = zone and (zone.WaterZ or zone.MinZ) or -450

local fogEnabled = fogCfg.Enabled and true or false
local waterEnabled = fogEnabled and waterCfg.Enabled ~= false
local zoneEnabled = zone and zone.Enabled ~= false or false

BW.Fog = BW.Fog or {}
BW.Fog.WaterBlend = 0

local function Num(value, default, min, max)
    value = tonumber(value)
    if not BW.Utils.IsFinite(value) then value = default end
    return math.Clamp(value, min, max)
end

function BW.Fog.GetViewZ()
    local thirdPerson = BW.ThirdPerson
    if thirdPerson and thirdPerson.Active and thirdPerson.ViewOrigin then
        return thirdPerson.ViewOrigin.z
    end
    if render and render.GetViewOrigin then
        local origin = render.GetViewOrigin()
        if origin then return origin.z end
    end
    local eye = EyePos()
    return eye and eye.z or 0
end

local fogMode = fogCfg.Mode or MATERIAL_FOG_LINEAR
local fogColor = fogCfg.Color or Color(191, 191, 191)
local waterColor = waterCfg.Color or Color(24, 104, 108)

local fogStart = Num(fogCfg.Start, 1500, 0, 1000000)
local fogEnd = Num(fogCfg.End, 3000, 0, 1000000)
if fogEnd <= fogStart then fogEnd = fogStart + 1 end
local fogDensity = Num(fogCfg.MaxDensity, 1, 0, 1)

local waterStart = Num(waterCfg.Start, 0, 0, 1000000)
local waterEnd = Num(waterCfg.End, 500, 0, 1000000)
if waterEnd <= waterStart then waterEnd = waterStart + 1 end
local waterDensity = Num(waterCfg.MaxDensity, 0.9, 0, 1)
local fadeTime = Num(waterCfg.FadeTime, 0.25, 0.01, 10)

local function Blend(a, b, t)
    return a + (b - a) * t
end

local function ApplyFog(start, endpos, density, r, g, b, scale)
    render.FogMode(fogMode)
    render.FogStart(start * scale)
    render.FogEnd(endpos * scale)
    render.FogMaxDensity(density)
    render.FogColor(r, g, b)
end

function MODULE:UpdateWaterBlend()
    local frame = FrameNumber()
    if self.LastBlendFrame == frame then return end
    self.LastBlendFrame = frame

    local target = 0
    if waterEnabled and zoneEnabled and BW.Fog.GetViewZ() < waterZ then
        target = 1
    end

    local step = math.min(1, RealFrameTime() / fadeTime)
    self.WaterBlend = math.Approach(self.WaterBlend or 0, target, step)
    BW.Fog.WaterBlend = self.WaterBlend
end

function MODULE:GetFogValues()
    local blend = self.WaterBlend or 0
    return Blend(fogStart, waterStart, blend),
        Blend(fogEnd, waterEnd, blend),
        Blend(fogDensity, waterDensity, blend),
        Blend(fogColor.r, waterColor.r, blend),
        Blend(fogColor.g, waterColor.g, blend),
        Blend(fogColor.b, waterColor.b, blend)
end

function MODULE:Init()
    if not fogEnabled then
        BW.Fog.WaterBlend = 0
        return
    end

    hook.Add("Think", "BW_Fog_UpdateWaterBlend", function()
        self:UpdateWaterBlend()
    end)

    hook.Add("SetupWorldFog", "BW_FogWorld", function()
        local start, endpos, density, r, g, b = self:GetFogValues()
        ApplyFog(start, endpos, density, r, g, b, 1)
        return true
    end)

    hook.Add("SetupSkyboxFog", "BW_FogSkybox", function(scale)
        scale = math.max(0.01, tonumber(scale) or 1)
        local start, endpos, density, r, g, b = self:GetFogValues()
        ApplyFog(start, endpos, density, r, g, b, scale)
        return true
    end)
end
