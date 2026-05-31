hook.Add("HUDDrawTargetID", "BW_HideDefaultTargetID", function()
    return false 
end)

hook.Add("PostPlayerDraw", "BW_BeautifulOverheadNames", function(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if ply == LocalPlayer() then return end
    if ply:GetNoDraw() then return end

    local cfg = BW.Config.NameTag
    if not cfg then return end

    local eyePos = LocalPlayer():EyePos()
    local plyPos = ply:GetPos()
    local dist   = eyePos:Distance(plyPos)

    if dist > cfg.MaxDist then return end

    local targetAlpha = 255
    if dist > (cfg.MaxDist - cfg.FadeDist) then
        targetAlpha = math.Remap(dist, cfg.MaxDist - cfg.FadeDist, cfg.MaxDist, 255, 0)
    end

    ply._overheadAlpha = ply._overheadAlpha or 255
    ply._overheadAlpha = Lerp(FrameTime() * cfg.FadeSpeed, ply._overheadAlpha, targetAlpha)

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

    cam.Start3D2D(pos, ang, cfg.Scale)
        
        local nick      = ply:Nick()
        local teamColor = team.GetColor(ply:Team()) or BW.Config.Colors.White
        local teamName  = team.GetName(ply:Team()) or ""

        local textWhite = Color(BW.Config.Colors.White.r, BW.Config.Colors.White.g, BW.Config.Colors.White.b, currentAlpha)
        local textBlack = Color(BW.Config.Colors.Black.r, BW.Config.Colors.Black.g, BW.Config.Colors.Black.b, currentAlpha)
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
end)