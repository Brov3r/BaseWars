MODULE.Name   = "NameTags"
MODULE.Author = "Brov3r"
MODULE.Realm  = BW.REALM_CLIENT

local config     = BW.Config
local colors     = config.Colors
local nameTagCfg = config.NameTag

function MODULE:Init()
    self:RegisterHooks()
end

function MODULE:RegisterHooks()
    hook.Add("HUDDrawTargetID", "BW_HideDefaultTargetID", function()
        return false 
    end)

    hook.Add("PostPlayerDraw", "BW_BeautifulOverheadNames", function(ply)
        self:DrawOverheadName(ply)
    end)
end

function MODULE:DrawOverheadName(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if ply == LocalPlayer() then return end
    if ply:GetNoDraw() then return end
    if not nameTagCfg then return end

    local eyePos = LocalPlayer():EyePos()
    local plyPos = ply:GetPos()
    local dist   = eyePos:Distance(plyPos)

    if dist > nameTagCfg.MaxDist then return end

    local targetAlpha = 255
    if dist > (nameTagCfg.MaxDist - nameTagCfg.FadeDist) then
        targetAlpha = math.Remap(dist, nameTagCfg.MaxDist - nameTagCfg.FadeDist, nameTagCfg.MaxDist, 255, 0)
    end

    ply._overheadAlpha = ply._overheadAlpha or 255
    ply._overheadAlpha = Lerp(FrameTime() * nameTagCfg.FadeSpeed, ply._overheadAlpha, targetAlpha)

    if ply._overheadAlpha < 1 then return end

    local pos
    local headBone = ply:LookupBone("ValveBiped.Bip01_Head1")
    if headBone then
        pos = ply:GetBonePosition(headBone) + Vector(0, 0, 15)
    else
        pos = ply:GetPos() + Vector(0, 0, ply:OBBMaxs().z + 12)
    end

    local ang = LocalPlayer():EyeAngles()
    ang:RotateAroundAxis(ang:Up(), -90)
    ang:RotateAroundAxis(ang:Forward(), 90)

    local currentAlpha = ply._overheadAlpha

    cam.Start3D2D(pos, ang, nameTagCfg.Scale)
        local nick      = ply:Nick()
        local teamColor = team.GetColor(ply:Team()) or colors.White
        local teamName  = team.GetName(ply:Team()) or ""

        local textWhite = Color(colors.White.r, colors.White.g, colors.White.b, currentAlpha)
        local textBlack = Color(colors.Black.r, colors.Black.g, colors.Black.b, currentAlpha)
        local textTeam  = Color(teamColor.r, teamColor.g, teamColor.b, currentAlpha)

        draw.SimpleTextOutlined(
            nick, 
            "Inter28", 
            0, 
            -10, 
            textWhite, 
            TEXT_ALIGN_CENTER, 
            TEXT_ALIGN_CENTER,
            1.5,
            textBlack
        )

        if teamName ~= "" then
            draw.SimpleTextOutlined(
                teamName, 
                "Inter20Thin", 
                0, 
                15, 
                textTeam, 
                TEXT_ALIGN_CENTER, 
                TEXT_ALIGN_CENTER,
                1.5,
                textBlack
            )
        end

    cam.End3D2D()
end