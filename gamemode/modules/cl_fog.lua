local MODULE = MODULE

MODULE.Name = "Fog"
MODULE.Author = "Brov3r"
MODULE.Require = {}

local fogCfg = BW.Config.Fog

function MODULE:Init()
    if not fogCfg then return end
    
    local fogColor = fogCfg.Color or Color(191, 191, 191, 255)
    local col = Vector(fogColor.r / 255, fogColor.g / 255, fogColor.b / 255)
    
    local fogStart = fogCfg.Start or 2000
    local fogEnd = fogCfg.End or 3000
    local fogDensity = fogCfg.MaxDensity or 1
    
    hook.Add("SetupWorldFog", "BW_FogWorld", function()
        local zone = BW.Config.MapZones[game.GetMap()] or BW.Config.MapZones.Default
        if zone and zone.Enabled ~= false and EyePos().z < (zone.MinZ or -450) then
            render.FogMode(MATERIAL_FOG_LINEAR)
            render.FogStart(0)
            render.FogEnd(500)
            render.FogMaxDensity(0.9)
            render.FogColor(24, 104, 108)
            return true
        end
        if not fogCfg.Enabled then return end
        render.FogMode(fogCfg.Mode or MATERIAL_FOG_LINEAR)
        render.FogStart(fogStart)
        render.FogEnd(fogEnd)
        render.FogMaxDensity(fogDensity)
        render.FogColor(col.x * 255, col.y * 255, col.z * 255)
        return true
    end)

    hook.Add("SetupSkyboxFog", "BW_FogSkybox", function(scale)
        if not fogCfg.Enabled then return end
        render.FogMode(fogCfg.Mode or MATERIAL_FOG_LINEAR)
        render.FogStart(fogStart * scale)
        render.FogEnd(fogEnd * scale)
        render.FogMaxDensity(fogDensity)
        render.FogColor(col.x * 255, col.y * 255, col.z * 255)
        return true
    end)
end
