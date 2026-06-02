local config = BW.Config
local hud = config.HUD
local colors = config.Colors
local animTime = hud.AnimTime

local cachedPlayer = nil

local avatar = vgui.Create("HexAvatar")
avatar:SetPos(ScrW(), ScrH())
avatar:SetSize(hud.Dimensions.Avatar, hud.Dimensions.Avatar)

local HiddenElementsLookup = {
    ["CHudHealth"]  = true,
    ["CHudBattery"] = true,
    ["CHudAmmo"]    = true,
    ["CHudSecondaryAmmo"] = true,
    ["CHudWeaponSelection"] = true,
}

local function GetReserveAmmo(ply)
    if not IsValid(ply) then return 0 end
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then return 0 end
    local ammoType = wep:GetPrimaryAmmoType()
    if ammoType < 0 then return 0 end
    return ply:GetAmmoCount(ammoType)
end

local function ShouldShowAmmo(ply, weapon)
    if not IsValid(weapon) then return false end
    if not weapon.IsWeapon or not weapon:IsWeapon() then return false end

    local class = weapon:GetClass()
    if class == "weapon_physgun" or class == "gmod_tool" or class == "weapon_physcannon" then
        return false
    end

    if weapon:Clip1() <= 0 and GetReserveAmmo(ply) <= 0 then
        return false
    end

    return true
end

hook.Add("HUDPaint", "BW_HUD", function()
    local player = LocalPlayer()
    local weapon = player:GetActiveWeapon()
    local isCamera = IsValid(weapon) and weapon:GetClass() == "gmod_camera"
    
    if not IsValid(player) or not player:Alive() or isCamera then
        avatar:SetVisible(false)
        return
    end

    if player ~= cachedPlayer then
        avatar:SetPlayer(player, hud.Dimensions.Avatar)
        cachedPlayer = player
    end
    avatar:SetVisible(true)

    local sh     = ScrH()
    local sw     = ScrW()
    local margin = hud.Margin
    local dim    = hud.Dimensions

    avatar:SetPos(margin, sh - dim.Avatar - margin)

    local barX       = margin * 2 + dim.Avatar
    local healthBarY = sh - margin - dim.HealthBarH * 2 - dim.Avatar / hud.AvatarCornerOffset
    local armorBarY  = healthBarY - dim.ArmorBarH - margin / 2

    -- Health
    BW.Utils.DrawAnimatedProgressBar("health", barX, healthBarY,
        dim.HealthBarW, dim.HealthBarH,
        player:Health(), 0, player:GetMaxHealth(),
        colors.White, colors.DarkGray, animTime)

    -- Armor
    BW.Utils.DrawAnimatedProgressBar("armor", barX, armorBarY,
        dim.ArmorBarW, dim.ArmorBarH,
        player:Armor(), 0, player:GetMaxArmor(),
        colors.Cyan, colors.DarkGray, animTime)

    -- Money
    local smoothMoney = BW.Utils.SmoothValue("money", player:GetMoney(), animTime)
    local moneyString = BW.Utils.StringMoney(math.floor(smoothMoney))
    BW.Utils.DrawShadowedText(BW.Config.Currency .. moneyString, "Inter24", barX,
        sh - margin - dim.Avatar, colors.White, colors.Black, 2, 2)

    -- Ammo
    local weapon = player:GetActiveWeapon()
    if ShouldShowAmmo(player, weapon) then
        local ammo = GetReserveAmmo(player)
        local clip = math.Max(weapon:Clip1(), 0)

        local clip = BW.Utils.SmoothValue("clip", clip, animTime)
        local reserve = BW.Utils.SmoothValue("reserve", ammo, animTime)

        local ammoX = sw - 100
        local ammoY = sh - 90

        local clipColor, reserveColor
        if clip <= 5 and clip > 0 then
            clipColor = colors.Orange
        elseif clip <= 0 then
            clipColor = colors.Red
        else
            clipColor = colors.White
        end

        if reserve <= 0 then
            reserveColor = Colors.Gray
        else
            reserveColor = colors.LightGray
        end

        draw.SimpleText(tostring(math.floor(clip)), "Inter28",
            ammoX + 10, ammoY,
            clipColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        draw.SimpleText("/ " .. tostring(math.floor(reserve)), "Inter18Thin",
            ammoX + 10, ammoY + 32,
            reserveColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
end)

local selector = vgui.Create("WeaponSelector")

hook.Add("PlayerBindPress", "BW_WeaponSelectorTrigger", function(ply, bind, pressed)
    if not pressed then return end

    local isAttacking = ply:KeyDown(IN_ATTACK)

    local isSelectorOpen = IsValid(selector) and (selector.TargetAlpha or 0) > 0

    local function PerformSelection()
        if not IsValid(selector) or not selector.Weapons then return end
        local wep = selector.Weapons[selector.Selected]
        if IsValid(wep) then
            surface.PlaySound("items/gunpickup2.wav")
            RunConsoleCommand("use", wep:GetClass())
        end
        selector.TargetAlpha = 0
    end

    if string.find(bind, "invprev") or string.find(bind, "invnext") then
        if isAttacking then return end 

        if not IsValid(selector) then 
            selector = vgui.Create("WeaponSelector")
        end
        
        selector:ShowSelector()
        
        local oldSelected = selector.Selected or 1
        
        if string.find(bind, "invnext") then
            selector.Selected = math.Clamp(oldSelected + 1, 1, #selector.Weapons)
        else
            selector.Selected = math.Clamp(oldSelected - 1, 1, #selector.Weapons)
        end
        
        if selector.Selected ~= oldSelected then
            surface.PlaySound("buttons/button15.wav") 
        end
        
        return true
    end

    if bind == "+attack" then
        if isSelectorOpen then
            PerformSelection()
            return true
        end
    end

    local slotNum = tonumber(string.match(bind, "slot(%d+)"))
    if slotNum then
        if not IsValid(selector) then 
            selector = vgui.Create("WeaponSelector")
        end

        local targetIndex = (slotNum == 0) and 10 or slotNum
        
        if selector.Weapons and targetIndex >= 1 and targetIndex <= #selector.Weapons then
            selector:ShowSelector()
            
            local oldSelected = selector.Selected or 1
            selector.Selected = targetIndex
            
            if selector.Selected ~= oldSelected then
                surface.PlaySound("buttons/button15.wav")
            end

            return true
        else
            if isSelectorOpen then
                selector.TargetAlpha = 0
            end
            return true
        end
    end

    if string.find(bind, "slot") and isSelectorOpen then
        return true
    end
end)

hook.Add("HUDShouldDraw", "BW_HideElementsHUD", function(name)
    if HiddenElementsLookup[name] then return false end
end)