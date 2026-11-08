local MODULE = MODULE

MODULE.Name = "Map Zone"
MODULE.Author = "Brov3r"
MODULE.Require = {}

local zone = BW.Config.MapZones[game.GetMap()] or BW.Config.MapZones.Default
local MIN_Z = zone and zone.MinZ or -450
local WATER_Z = zone and (zone.WaterZ or zone.MinZ) or MIN_Z
local MAX_Z = zone and zone.MaxZ or 1500
local DAMAGE_MULT = zone and zone.DamageMultiplier or 0.2

function MODULE:Init()
    if SERVER then timer.Remove("HeightDamageCheck") end
    if CLIENT then
        hook.Remove("PostDrawTranslucentRenderables", "WaterZoneSurface")
        hook.Remove("HUDPaint", "WaterZoneOverlay")
    end
    if not zone or zone.Enabled == false then return end
    assert(BW.Utils.IsFinite(MIN_Z) and BW.Utils.IsFinite(MAX_Z) and MIN_Z < MAX_Z, "Invalid map zone heights")
    assert(BW.Utils.IsFinite(DAMAGE_MULT) and DAMAGE_MULT >= 0, "Invalid map zone damage")
    if SERVER then
        timer.Create("HeightDamageCheck", 0.5, 0, function()
            for _, ply in ipairs(player.GetAll()) do
                if not IsValid(ply) or not ply:Alive() then continue end

                local z = ply:GetPos().z
                local inDanger = false
                local damage = 0
                local isDrowning = false

                if z > MAX_Z then
                    inDanger = true
                    damage = (z - MAX_Z) * DAMAGE_MULT
                elseif z < MIN_Z then
                    inDanger = true
                    isDrowning = true
                    damage = (MIN_Z - z) / 2 * DAMAGE_MULT
                end

                if inDanger then
                    if not ply._InHeightDanger then
                        ply._InHeightDanger = true
                        local text = Translate("MapZone.DangerZone", "You are in a dangerous area! Move to a safer location.")
                        ply:Notify(NOTIFY_WARNING, text, 5)
                    end
                    
                    if damage > 0 then
                        local finalDamage = math.max(1, math.ceil(damage)) 
                        local dmgInfo = DamageInfo()
                        dmgInfo:SetDamage(finalDamage)
                        dmgInfo:SetDamageType(isDrowning and DMG_DROWNING or DMG_RADIATION)
                        dmgInfo:SetAttacker(game.GetWorld())
                        dmgInfo:SetInflictor(game.GetWorld())
                        ply:TakeDamageInfo(dmgInfo)
                    end
                else
                    ply._InHeightDanger = false
                end
            end
        end)
    end

    if CLIENT then
        local fogCfg = BW.Config.Fog or {}
        local waterCfg = fogCfg.Water or {}
        local waterColor = waterCfg.Color or Color(24, 104, 108)
        local waterTint = string.format("{ %d %d %d }", waterColor.r, waterColor.g, waterColor.b)
        local waterAlpha = math.Clamp(tonumber(waterCfg.SurfaceAlpha) or 230, 0, 255)
        local refractDistance = math.max(0, tonumber(waterCfg.RefractDistance) or 1500)

        local matWater = CreateMaterial("FakeWaterSurface_Refract", "Refract", {
            ["$normalmap"] = "dev/water_normal", 
            ["$refracttint"] = waterTint,
            ["$refractamount"] = 0.3,           
            ["$bluramount"] = 0.8,
            ["$nocull"] = 1,
            ["$ignorez"] = 0 
        })

        hook.Add("PostDrawTranslucentRenderables", "WaterZoneSurface", function(bDepth, bDrawingSkybox, isDraw3DSkybox)
            -- Keep the main pass when r_3dsky 0 makes the 2D skybox flag true.
            if bDepth or (isDraw3DSkybox and bDrawingSkybox) or zone.DrawWater == false then return end

            local viewZ = BW.Fog and BW.Fog.GetViewZ and BW.Fog.GetViewZ() or EyePos().z
            local distance = math.abs(viewZ - WATER_Z)
            if distance > (zone.DrawDistance or 5000) then return end

            local useRefract = waterCfg.Refract ~= false and distance <= refractDistance
            if useRefract then render.UpdateRefractTexture() end
            
            local offset = RealTime() * 0.05 
            
            local tileSize = 100 
            
            local halfSize = zone.HalfSize or 16384
            cam.Start3D2D(Vector(0, 0, WATER_Z), Angle(0, 0, 0), 1)
                if useRefract then
                    surface.SetDrawColor(255, 255, 255, waterAlpha)
                    surface.SetMaterial(matWater)
                    
                    surface.DrawTexturedRectUV(
                        -halfSize, -halfSize,
                        halfSize * 2, halfSize * 2,
                        offset, offset, 
                        tileSize + offset, tileSize + offset
                    )
                else
                    -- Cheap flat water for distant views, no refraction pass.
                    draw.NoTexture()
                    surface.SetDrawColor(waterColor.r, waterColor.g, waterColor.b, waterAlpha)
                    surface.DrawRect(-halfSize, -halfSize, halfSize * 2, halfSize * 2)
                end
            cam.End3D2D()
        end)


        hook.Add("HUDPaint", "WaterZoneOverlay", function()
            local ply = LocalPlayer()
            if not IsValid(ply) then return end

            local cfg = BW.Config.Fog or {}
            local water = cfg.Water or {}
            if not cfg.Enabled or water.Enabled == false then return end

            local viewZ = BW.Fog and BW.Fog.GetViewZ and BW.Fog.GetViewZ() or ply:EyePos().z
            if viewZ >= WATER_Z then return end

            local blend = BW.Fog and BW.Fog.WaterBlend
            if blend == nil then blend = 1 end
            if blend <= 0.01 then return end

            local col = water.Color or Color(24, 104, 108)
            local alpha = math.Clamp(tonumber(water.OverlayAlpha) or 150, 0, 255) * blend
            surface.SetDrawColor(col.r, col.g, col.b, alpha)
            surface.DrawRect(0, 0, ScrW(), ScrH())
        end)
    end
end
