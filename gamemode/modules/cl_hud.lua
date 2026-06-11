local MODULE = MODULE

MODULE.Name = "HUD"
MODULE.Author = "Brov3r"
MODULE.Require = { "database" }

local lvlIcon = Material("icon16/award_star_gold_3.png")
local iconRepUp   = Material("icon16/thumb_up.png")
local iconRepDown = Material("icon16/thumb_down.png")
local iconRepZero = Material("icon16/heart.png")
local config   = BW.Config
local hud      = config.HUD
local colors   = config.Colors
local animTime = hud.AnimTime
local margin   = hud.Margin
local dim      = hud.Dimensions


local HiddenElementsLookup = {
    ["CHudHealth"] = true, 
    ["CHudBattery"] = true, 
    ["CHudAmmo"] = true,
    ["CHudSecondaryAmmo"] = true, 
    ["CHudWeaponSelection"] = true,
}

function MODULE:Init()
    local dim = BW.Config.HUD.Dimensions

    self.Avatar = vgui.Create("HUDAvatar")
    self.Avatar:SetSize(dim.Avatar, dim.Avatar)
    self.Avatar:SetVisible(false)

    self.Selector = vgui.Create("WeaponSelector")

    self.CurrentWeapon = nil
    self.LastWeapon = nil
    self.LastW = 0
    self.LastH = 0
        
    hook.Add("HUDShouldDraw", "BW_HideElements", function(name)
        if HiddenElementsLookup[name] then return false end
    end)

    hook.Add("HUDPaint", "BW_HUDDraw", function()
        if MODULE and MODULE.DrawHUD then
            MODULE:DrawHUD()
        end
    end)

    hook.Add("PostDrawTranslucentRenderables", "BW_DrawEntInfo3D", function()
        if MODULE and MODULE.DrawEntInfo then
            MODULE:DrawEntInfo()
        end
    end)

    hook.Add("StartCommand", "BW_BlockInputWhenSelectorOpen", function(ply, cmd)
        if MODULE and MODULE.BlockInputWhenSelectorOpen then
            return MODULE:BlockInputWhenSelectorOpen(ply, cmd)
        end
       
    end)

    hook.Add("PlayerBindPress", "BW_WeaponSelector", function(ply, bind, pressed)
        if MODULE and MODULE.WeaponSelectionDraw then
            return MODULE:WeaponSelectionDraw(ply, bind, pressed)
        end
    end)

    hook.Add("PreDrawHalos", "BW_EntityHighlight", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        
        local tr = ply:GetEyeTrace()
        local ent = tr.Entity
        
        if IsValid(ent) and not ent:IsPlayer() and ent:GetClass() ~= "prop_physics" and not ent:CreatedByMap() then
            if tr.HitPos:DistToSqr(ply:GetShootPos()) < 100^2 then
                halo.Add({ent}, BW.Config.Colors.Amber, 0.5, 0.5, 0.5, true, true )
            end
        end
    end)
end

function MODULE:UpdateWeaponHistory()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    
    local wepEnt = ply:GetActiveWeapon()
    local currentClass = IsValid(wepEnt) and wepEnt:GetClass() or nil
    
    if currentClass ~= self.CurrentWeapon then
        if self.CurrentWeapon then
            self.LastWeapon = self.CurrentWeapon
        end
        self.CurrentWeapon = currentClass
    end
end

function MODULE:GetReserveAmmo(ply)
    if not IsValid(ply) then return 0 end
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then return 0 end
    local ammoType = wep:GetPrimaryAmmoType()
    if ammoType < 0 then return 0 end
    return ply:GetAmmoCount(ammoType)
end

function MODULE:ShouldShowAmmo(ply, weapon)
    if not IsValid(weapon) then return false end
    if not weapon.IsWeapon or not weapon:IsWeapon() then return false end

    local class = weapon:GetClass()
    if class == "weapon_physgun" or class == "gmod_tool" or class == "weapon_physcannon" then
        return false
    end

    if (weapon:Clip1() or 0) <= 0 and self:GetReserveAmmo(ply) <= 0 then
        return false
    end

    return true 
end

function MODULE:DrawHUD()
    self:UpdateWeaponHistory()

    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then 
        if IsValid(self.Avatar) then self.Avatar:SetVisible(false) end
        return 
    end

    local wep = ply:GetActiveWeapon()
    if IsValid(wep) and wep:GetClass() == "gmod_camera" then
        self.Avatar:SetVisible(false)
        return
    end

    if self.LastPly ~= ply then
        self.Avatar:SetPlayer(ply, dim.Avatar)
        self.LastPly = ply
    end
    self.Avatar:SetVisible(true)
    
    local sh = ScrH()
    local sw = ScrW()

    if self.LastW ~= sw or self.LastH ~= sh then
        self.LastW = sw
        self.LastH = sh
        self.Avatar:SetPos(margin, sh - dim.Avatar - margin)
    end

    local currentXP = ply.GetXP and ply:GetXP() or 0
    local maxXP     = ply.GetMaxXP and ply.GetMaxXP(ply) or 0
    local smoothXP  = BW.Utils.SmoothValue("hud_xp", currentXP, animTime)
    self.Avatar.XPProgress = smoothXP / maxXP

    local blockTop = sh - margin - dim.Avatar + 5
    local barX     = margin * 2 + dim.Avatar
    local barW     = dim.HealthBarW

    local smoothMoney = BW.Utils.SmoothValue("money", ply.GetMoney and ply:GetMoney() or 0, animTime)
    local moneyString = BW.Utils.NumWithSep(math.floor(smoothMoney))
    BW.Utils.DrawShadowedText(config.Economy.Currency .. moneyString, "Inter24", barX, blockTop, colors.White, colors.Black, 2, 2, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    local armorBarY = blockTop + 26
    local smoothArmor = BW.Utils.SmoothValue("hud_armor", ply:Armor(), animTime)
    BW.Utils.DrawProgressBar(barX, armorBarY, dim.ArmorBarW, dim.ArmorBarH, 
        smoothArmor, 0, ply:GetMaxArmor(), colors.Cyan, colors.DarkGray)

    local healthBarY = armorBarY + dim.ArmorBarH + 4
    local smoothHealth = BW.Utils.SmoothValue("hud_health", ply:Health(), animTime)
    BW.Utils.DrawProgressBar(barX, healthBarY, dim.HealthBarW, dim.HealthBarH, 
        smoothHealth, 0, ply:GetMaxHealth(), colors.White, colors.DarkGray)

    local statsY   = healthBarY + dim.HealthBarH + 6
    local iconSize = dim.IconSize
    local spacing  = 4
    local fontName = "Inter18"

    surface.SetFont(fontName)

    local currentLvl = ply.GetLevel and ply:GetLevel() or 1
    local levelStr   = tostring(currentLvl)

    surface.SetMaterial(lvlIcon)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawTexturedRect(barX, statsY, iconSize, iconSize)
    BW.Utils.DrawShadowedText(levelStr, fontName, barX + iconSize + spacing, statsY - 1, 
        colors.White, colors.Black, 1, 1, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    local currentRep = ply.GetReputation and ply:GetReputation() or 100
    local repStr     = tostring(currentRep)
    local rightEdge  = barX + barW
    local repW, _    = surface.GetTextSize(repStr)

    local repIcon = iconRepZero
    if currentRep > 0 then
        repIcon = iconRepUp
    elseif currentRep < 0 then
        repIcon = iconRepDown
    end
    
    surface.SetMaterial(repIcon)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawTexturedRect(rightEdge - repW - spacing - iconSize, statsY, iconSize, iconSize)
    BW.Utils.DrawShadowedText(repStr, fontName, rightEdge, statsY - 1, 
        colors.White, colors.Black, 1, 1, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)


    local weapon = ply:GetActiveWeapon()
    if self:ShouldShowAmmo(ply, weapon) then
        local ammo = self:GetReserveAmmo(ply)
        local clip = weapon:Clip1() or -1
        
        local isCliplessWeapon = clip == -1 and ammo > 0
        
        local displayClip, displayReserve
        if isCliplessWeapon then
            displayClip = ammo
            displayReserve = 0
        else
            displayClip = math.Max(clip, 0)
            displayReserve = ammo
        end

        local smoothClip = BW.Utils.SmoothValue("clip", displayClip, animTime)
        local smoothReserve = BW.Utils.SmoothValue("reserve", displayReserve, animTime)

        local ammoX = sw - 100
        local ammoY = sh - 90

        local clipColor, reserveColor
        if smoothClip <= 5 and smoothClip > 0 then
            clipColor = colors.Orange
        elseif smoothClip <= 0 then
            clipColor = colors.Red
        else
            clipColor = colors.White
        end

        if smoothReserve <= 0 then
            reserveColor = colors.Grey
        else
            reserveColor = colors.LightGray
        end

        BW.Utils.DrawShadowedText(tostring(math.floor(smoothClip)), "Inter28",
            ammoX + 10, ammoY,
            clipColor, colors.Black, 2, 2, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            
        BW.Utils.DrawShadowedText("/ " .. tostring(math.floor(smoothReserve)), "Inter18Thin",
            ammoX + 10, ammoY + 32,
            reserveColor, colors.Black, 1, 1, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    end
end

function MODULE:DrawEntInfo()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local tr = ply:GetEyeTrace()
    local ent = tr.Entity

    if not IsValid(ent) or ent:IsPlayer() or ent:IsWorld() then return end
    
    if tr.HitPos:DistToSqr(ply:GetShootPos()) > BW.Config.HUD.DrawEntInfoDistance ^2 then return end

    local ownerName = Translate("HUD.OwnerUnknown", "Unknown")

    if CPPI and CPPI.GetName() == "Warden" then
        ownerName = ent:WardenGetOwnerName()
        if ent:WardenGetOwnerID() == "World" then
            ownerName = Translate("HUD.WorldText", "World")
        end
    elseif ent.CPPIGetOwner then
        local cppiOwner = ent:CPPIGetOwner()
        if IsValid(cppiOwner) and cppiOwner:IsPlayer() then
            ownerName = cppiOwner:Nick()
        end
    elseif IsValid(ent.Owner) then
        ownerName = ent.Owner:Nick()
    end

    local maxHP = ent:GetMaxHealth()
    local currentHP = math.max(0, ent:Health())
    local textFont = "Inter14"

    local obbMins, obbMaxs = ent:OBBMins(), ent:OBBMaxs()
    local height = obbMaxs.z - obbMins.z
    
    local isSmall = height < 25 

    local obbCenter = ent:OBBCenter()
    local pos = ent:LocalToWorld(obbCenter)

    if isSmall then
        pos = pos + Vector(0, 0, (height / 2) + 5)
    end

    local ang = ply:EyeAngles()
    ang:RotateAroundAxis(ang:Up(), -90)
    ang:RotateAroundAxis(ang:Forward(), 90)

    local scale = 0.12

    cam.Start3D2D(pos, ang, scale)
        cam.IgnoreZ(true)

        if maxHP > 1 then
            local barW = 210
            local barH = 5
            local barX = -barW / 2
            local barY = 0

            BW.Utils.DrawProgressBar(barX, barY, barW, barH, currentHP, 0, maxHP, colors.White, colors.DarkGray)

            local hpString = string.format("%i/%i", currentHP, maxHP)
            local ownerString = string.format("%s: %s", Translate("HUD.OwnerLabel", "Owner"), BW.Utils.TruncateText(ownerName, textFont, 85))

            BW.Utils.DrawShadowedText(ownerString, textFont, barX, barY - 2, colors.White, colors.Black, 1, 1, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
            BW.Utils.DrawShadowedText(hpString, textFont, barX + barW, barY - 2, colors.White, colors.Black, 1, 1, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
        else
            local ownerString = string.format("%s: %s", Translate("HUD.OwnerLabel", "Owner"), BW.Utils.TruncateText(ownerName, textFont, 120))
            
            surface.SetFont(textFont)
            local textW, textH = surface.GetTextSize(ownerString)
            
            local textY = -textH / 2

            BW.Utils.DrawShadowedText(ownerString, textFont, 0, textY, colors.White, colors.Black, 1, 1, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

            surface.SetDrawColor(colors.White.r, colors.White.g, colors.White.b, 220)
            surface.DrawRect(-textW / 2, textY + textH + 2, textW, 1)

            surface.SetDrawColor(0, 0, 0, 200)
            surface.DrawRect(-textW / 2, textY + textH + 3, textW, 1)
        end
        cam.IgnoreZ(false)
    cam.End3D2D()
end

function MODULE:WeaponSelectionDraw(ply, bind, pressed)
    if not pressed then return end
    
    local isWeaponBind = bind == "+attack" 
                      or bind == "lastinv" 
                      or bind == "invprev" 
                      or bind == "invnext"
                      or string.match(bind, "^slot(%d+)$") ~= nil
    
    if not isWeaponBind then
        return
    end

    if not IsValid(self.Selector) then
        self.Selector = vgui.Create("WeaponSelector")
    end

    local isSelectorOpen = IsValid(self.Selector) and (self.Selector.TargetAlpha or 0) > 0

    if not isSelectorOpen and (ply:KeyDown(IN_ATTACK) or ply:KeyDown(IN_ATTACK2)) then
        return
    end

    if bind == "+attack" and isSelectorOpen then
        surface.PlaySound("common/wpn_select.wav")
        
        if IsValid(self.Selector) and self.Selector.Weapons and self.Selector.Weapons[self.Selector.Selected] then
            local wep = self.Selector.Weapons[self.Selector.Selected]
            if IsValid(wep) then
                RunConsoleCommand("use", wep:GetClass())
            end
        end
        
        self.Selector.TargetAlpha = 0
        return true 
    end

    if bind == "lastinv" then
        self.Selector.TargetAlpha = 0
        
        if self.LastWeapon then
            RunConsoleCommand("use", self.LastWeapon)
        else
            RunConsoleCommand("lastinv")
        end
        
        return true 
    end

    if bind == "invprev" or bind == "invnext" then
        self.Selector:ShowSelector()
        
        local weapons = self.Selector.Weapons
        if weapons and #weapons > 0 then
            local count = #weapons
            local old = self.Selector.Selected or 1
            local dir = (bind == "invnext") and 1 or -1
            
            if dir > 0 then
                self.Selector.Selected = (old % count) + 1
            else
                self.Selector.Selected = (old == 1) and count or (old - 1)
            end
            
            if self.Selector.Selected ~= old then
                surface.PlaySound("UI/buttonrollover.wav")
            end
        end
        
        return true 
    end

    local slotNum = tonumber(string.match(bind, "^slot(%d+)$"))
    if slotNum then
        self.Selector:ShowSelector()
        
        local weapons = self.Selector.Weapons
        if weapons and #weapons > 0 then
            local count = #weapons
            local target = (slotNum == 0) and 10 or slotNum
            self.Selector.Selected = ((target - 1) % count) + 1
            
            surface.PlaySound("UI/buttonrollover.wav")
        end
        
        return true 
    end

    return
end

function MODULE:BlockInputWhenSelectorOpen(ply, cmd)
    if ply ~= LocalPlayer() then return end
        
    local selector = self.Selector
    if IsValid(selector) and selector.TargetAlpha > 0 then
        cmd:RemoveKey(IN_ATTACK)
        cmd:RemoveKey(IN_ATTACK2)
        cmd:RemoveKey(IN_RELOAD)
    end
end