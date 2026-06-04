MODULE.Name   = "HUD"
MODULE.Author = "Brov3r"
MODULE.Realm  = BW.REALM_CLIENT

local config   = BW.Config
local hud      = config.HUD
local colors   = config.Colors
local animTime = hud.AnimTime
local margin   = hud.Margin
local dim      = hud.Dimensions

function MODULE:Init()
    self.Avatar = vgui.Create("HexAvatar")
    self.Avatar:SetSize(dim.Avatar, dim.Avatar)
    self.Avatar:SetVisible(false)

    self.Selector = vgui.Create("WeaponSelector")

    self:RegisterHooks()
end

function MODULE:RegisterHooks()
    local HiddenElementsLookup = {
        ["CHudHealth"] = true, ["CHudBattery"] = true, ["CHudAmmo"] = true,
        ["CHudSecondaryAmmo"] = true, ["CHudWeaponSelection"] = true,
    }

    hook.Add("HUDShouldDraw", "BW_HideElements", function(name)
        if HiddenElementsLookup[name] then return false end
    end)

    hook.Add("HUDPaint", "BW_HUD", function()
        self:DrawHUD()
    end)

    hook.Add("PlayerBindPress", "BW_WeaponSelector", function(ply, bind, pressed)
        return self:HandleBinds(ply, bind, pressed)
    end)
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

    self.Avatar:SetPos(margin, sh - dim.Avatar - margin)

    local barX       = margin * 2 + dim.Avatar
    local healthBarY = sh - margin - dim.HealthBarH * 2 - (dim.Avatar / (hud.AvatarCornerOffset or 1))
    local armorBarY  = healthBarY - dim.ArmorBarH - margin / 2

    -- Health
    BW.Utils.DrawAnimatedProgressBar("health", barX, healthBarY,
        dim.HealthBarW, dim.HealthBarH,
        ply:Health(), 0, ply:GetMaxHealth(),
        colors.White, colors.DarkGray, animTime)

    -- Armor
    BW.Utils.DrawAnimatedProgressBar("armor", barX, armorBarY,
        dim.ArmorBarW, dim.ArmorBarH,
        ply:Armor(), 0, ply:GetMaxArmor(),
        colors.Cyan, colors.DarkGray, animTime)

    -- Money
    local smoothMoney = BW.Utils.SmoothValue("money", ply:GetMoney(), animTime)
    local moneyString = BW.Utils.StringNumber(math.floor(smoothMoney))
    BW.Utils.DrawShadowedText(config.Currency .. moneyString, "Inter24", barX,
        sh - margin - dim.Avatar, colors.White, colors.Black, 2, 2)

    -- Ammo
    local weapon = ply:GetActiveWeapon()
    if self:ShouldShowAmmo(ply, weapon) then
        local ammo = self:GetReserveAmmo(ply)
        local clip = math.Max(weapon:Clip1() or 0, 0)

        local smoothClip = BW.Utils.SmoothValue("clip", clip, animTime)
        local smoothReserve = BW.Utils.SmoothValue("reserve", ammo, animTime)

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
            reserveColor = colors.Gray
        else
            reserveColor = colors.LightGray
        end

        draw.SimpleText(tostring(math.floor(smoothClip)), "Inter28",
            ammoX + 10, ammoY,
            clipColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        draw.SimpleText("/ " .. tostring(math.floor(smoothReserve)), "Inter18Thin",
            ammoX + 10, ammoY + 32,
            reserveColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
end

function MODULE:HandleBinds(ply, bind, pressed)
    if not pressed then return end

    local isAttacking = ply:KeyDown(IN_ATTACK)
    local isSelectorOpen = IsValid(self.Selector) and (self.Selector.TargetAlpha or 0) > 0

    local function PerformSelection()
        if not IsValid(self.Selector) or not self.Selector.Weapons then return end
        local wep = self.Selector.Weapons[self.Selector.Selected]
        if IsValid(wep) then
            surface.PlaySound("items/gunpickup2.wav")
            RunConsoleCommand("use", wep:GetClass())
        end
        self.Selector.TargetAlpha = 0
    end

    if string.find(bind, "invprev") or string.find(bind, "invnext") then
        if isAttacking then return end 

        if not IsValid(self.Selector) then 
            self.Selector = vgui.Create("WeaponSelector")
        end
        
        self.Selector:ShowSelector()
        
        local oldSelected = self.Selector.Selected or 1
        
        if string.find(bind, "invnext") then
            self.Selector.Selected = math.Clamp(oldSelected + 1, 1, #self.Selector.Weapons)
        else
            self.Selector.Selected = math.Clamp(oldSelected - 1, 1, #self.Selector.Weapons)
        end
        
        if self.Selector.Selected ~= oldSelected then
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
        if not IsValid(self.Selector) then 
            self.Selector = vgui.Create("WeaponSelector")
        end

        local targetIndex = (slotNum == 0) and 10 or slotNum
        
        if self.Selector.Weapons and targetIndex >= 1 and targetIndex <= #self.Selector.Weapons then
            self.Selector:ShowSelector()
            
            local oldSelected = self.Selector.Selected or 1
            self.Selector.Selected = targetIndex
            
            if self.Selector.Selected ~= oldSelected then
                surface.PlaySound("buttons/button15.wav")
            end

            return true
        else
            if isSelectorOpen then
                self.Selector.TargetAlpha = 0
            end
            return true
        end
    end

    if string.find(bind, "slot") and isSelectorOpen then
        return true
    end
end