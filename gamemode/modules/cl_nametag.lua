local MODULE = MODULE

MODULE.Name = "HUD"
MODULE.Author = "Brov3r"
MODULE.Require = { "database", "booster" }

local config     = BW.Config
local colors     = config.Colors
local nameTagCfg = config.NameTag

local lvlIcon = Material("icon16/award_star_gold_3.png")
local iconRepUp   = Material("icon16/thumb_up.png")
local iconRepDown = Material("icon16/thumb_down.png")
local iconRepZero = Material("icon16/heart.png")
local groupMaterials = {}

function MODULE:Init()
    hook.Add("HUDDrawTargetID", "BW_HideDefaultTargetID", function()
        return false 
    end)

    hook.Add("PostPlayerDraw", "BW_BeautifulOverheadNames", function(ply)
        MODULE:DrawOverheadName(ply)
    end)
end

function MODULE:DrawOverheadName(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if ply == LocalPlayer() then return end
    if ply:GetNWBool("BW_IsInvis") then return end
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
    if ply.BW_NameTagModel ~= ply:GetModel() then
        ply.BW_NameTagModel = ply:GetModel()
        ply.BW_NameTagBone = ply:LookupBone("ValveBiped.Bip01_Head1")
    end
    local headBone = ply.BW_NameTagBone
    if headBone then
        pos = (ply:GetBonePosition(headBone) or ply:EyePos()) + Vector(0, 0, 18)
    else
        pos = ply:GetPos() + Vector(0, 0, ply:OBBMaxs().z + 12)
    end

    local ang = LocalPlayer():EyeAngles()
    ang:RotateAroundAxis(ang:Up(), -90)
    ang:RotateAroundAxis(ang:Forward(), 90)

    local currentAlpha = ply._overheadAlpha

    local userGroup = ply:GetUserGroup()
    local groupCfg  = BW.Config.PlayerGroups[userGroup]
    local iconPath = groupCfg and groupCfg.PrefixIcon
    if iconPath and not groupMaterials[iconPath] then groupMaterials[iconPath] = Material(iconPath) end
    local groupIcon = iconPath and groupMaterials[iconPath]

    cam.Start3D2D(pos, ang, nameTagCfg.Scale)
        local nick      = ply:Nick()
        local teamColor = team.GetColor(ply:Team()) or colors.White
        local teamName  = team.GetName(ply:Team()) or ""

        local textWhite = Color(colors.White.r, colors.White.g, colors.White.b, currentAlpha)
        local textBlack = Color(colors.Black.r, colors.Black.g, colors.Black.b, currentAlpha)
        local textTeam  = Color(teamColor.r, teamColor.g, teamColor.b, currentAlpha)

        local iconSize = 22
        local iconGap = 5
        
        surface.SetFont("Inter28")
        local nickW = surface.GetTextSize(nick)
        
        local totalW = (groupIcon and (iconSize + iconGap + nickW) or nickW)
        local startX = -totalW / 2
        local currentX = startX
        
        if groupIcon then
            surface.SetMaterial(groupIcon)
            surface.SetDrawColor(255, 255, 255, currentAlpha)
            surface.DrawTexturedRect(currentX, -21, iconSize, iconSize)
            currentX = currentX + iconSize + iconGap
        end

        draw.SimpleTextOutlined(
            nick, 
            "Inter28", 
            currentX + (nickW / 2), 
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

        local lvl = ply.GetLevel and ply:GetLevel() or 1
        local rep = ply.GetReputation and ply:GetReputation() or 0
        local lvlStr = tostring(lvl)
        local repStr = tostring(rep)

        surface.SetFont("Inter14")
        local lvlW = surface.GetTextSize(lvlStr)
        local repW = surface.GetTextSize(repStr)

        local statsY = 34
        local iconSize = 10
        local iconTextGap = 3
        local blockGap = 12

        local totalWidth = iconSize + iconTextGap + lvlW + blockGap + iconSize + iconTextGap + repW
        local startX = -totalWidth / 2

        surface.SetMaterial(lvlIcon)
        surface.SetDrawColor(255, 255, 255, currentAlpha)
        surface.DrawTexturedRect(startX, statsY - iconSize / 2, iconSize, iconSize)
        
        draw.SimpleTextOutlined(
            lvlStr, 
            "Inter14", 
            startX + iconSize + iconTextGap, 
            statsY, 
            textWhite, 
            TEXT_ALIGN_LEFT, 
            TEXT_ALIGN_CENTER,
            1,
            textBlack
        )

        local repX = startX + iconSize + iconTextGap + lvlW + blockGap
        local repIcon = iconRepZero
        if rep > 0 then
            repIcon = iconRepUp
        elseif rep < 0 then
            repIcon = iconRepDown
        end
        
        surface.SetMaterial(repIcon)
        surface.SetDrawColor(255, 255, 255, currentAlpha)
        surface.DrawTexturedRect(repX, statsY - iconSize / 2, iconSize, iconSize)
        
        draw.SimpleTextOutlined(
            repStr, 
            "Inter14", 
            repX + iconSize + iconTextGap, 
            statsY, 
            textWhite, 
            TEXT_ALIGN_LEFT, 
            TEXT_ALIGN_CENTER,
            1,
            textBlack
        )

    cam.End3D2D()
end
