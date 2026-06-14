local MODULE = MODULE

MODULE.Name = "Map Zone"
MODULE.Author = "Brov3r"
MODULE.Require = {}

local MIN_Z = -450
local MAX_Z = 1500
local DAMAGE_MULT = 0.2

function MODULE:Init()
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
        local matWater = CreateMaterial("FakeWaterSurface_Refract", "Refract", {
            ["$normalmap"] = "dev/water_normal", 
            ["$refracttint"] = "{ 12 110 100 }",
            ["$refractamount"] = 0.3,           
            ["$bluramount"] = 0.8,
            ["$nocull"] = 1,
            ["$ignorez"] = 0 
        })

        hook.Add("PostDrawTranslucentRenderables", "WaterZoneSurface", function(bDepth, bSkybox)
            if bSkybox then return end 
            
            local offset = RealTime() * 0.05 
            
            local tileSize = 100 
            
            cam.Start3D2D(Vector(0, 0, MIN_Z), Angle(0, 0, 0), 1)
                surface.SetDrawColor(255, 255, 255, 230)
                surface.SetMaterial(matWater)
                
                surface.DrawTexturedRectUV(
                    -30000, -30000, 
                    60000, 60000, 
                    offset, offset, 
                    tileSize + offset, tileSize + offset
                )
            cam.End3D2D()
        end)

        hook.Add("SetupFog", "WaterZoneFog", function()
            local ply = LocalPlayer()
            if not IsValid(ply) then return end

            if ply:EyePos().z < MIN_Z then
                render.FogMode(MATERIAL_FOG_LINEAR)
                render.FogStart(0)
                render.FogEnd(500)
                render.FogMaxDensity(0.9)
                render.FogColor(24, 104, 108)
                return true
            end
        end)

        hook.Add("HUDPaint", "WaterZoneOverlay", function()
            local ply = LocalPlayer()
            if not IsValid(ply) then return end
            
            if ply:EyePos().z < MIN_Z then
                surface.SetDrawColor(24, 104, 108, 150)
                surface.DrawRect(0, 0, ScrW(), ScrH())
            end
        end)
    end
end