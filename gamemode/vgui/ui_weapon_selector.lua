local PANEL = {}

function PANEL:Init()
    self:SetSize(500, 65)
    self:SetPos(ScrW() / 2 - 250, 30)
    self.Weapons = {}
    self.Selected = 1
    self.TargetAlpha = 0
    self.CurrentAlpha = 0
    self.ScrollOffset = 0
end

function PANEL:UpdateWeapons()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    
    local allWeapons = ply:GetWeapons()
    local sortedWeapons = {}

    for _, wep in ipairs(allWeapons) do
        if IsValid(wep) then
            table.insert(sortedWeapons, wep)
        end
    end

    table.sort(sortedWeapons, function(a, b)
        local classA = a:GetClass()
        local classB = b:GetClass()

        if classA == "weapon_physgun" then return true end
        if classB == "weapon_physgun" then return false end

        local slotA = a:GetSlot() or 0
        local slotB = b:GetSlot() or 0
        
        if slotA == slotB then
            return classA < classB
        end
        
        return slotA < slotB
    end)

    self.Weapons = sortedWeapons
end

local function ToUpperUTF8(str)
    local res = ""
    for _, cp in utf8.codes(str) do
        if cp >= 1072 and cp <= 1103 then
            cp = cp - 32
        elseif cp == 1105 then
            cp = 1077
        end
        res = res .. utf8.char(cp)
    end
    return res
end

function PANEL:Paint(w, h)
    self.CurrentAlpha = Lerp(FrameTime() * 10, self.CurrentAlpha, self.TargetAlpha)
    if self.CurrentAlpha < 1 then return end
    local alpha = self.CurrentAlpha / 255

    local c = BW.Config.Colors

    local bgColor = Color(c.DarkGray35.r, c.DarkGray35.g, c.DarkGray35.b, 240 * alpha)
    draw.RoundedBox(8, 0, 0, w, h, bgColor)
    
    draw.RoundedBoxEx(8, 0, 0, w, 1, Color(c.Gray50.r, c.Gray50.g, c.Gray50.b, 150 * alpha), true, true, false, false)

    local title = (BW.Translate and BW.Translate.WeaponSelector) or "WEAPONS"
    local count = #self.Weapons
    draw.SimpleText(title .. "  •  " .. count, "Inter12", w / 2, 10, Color(c.White.r, c.White.g, c.White.b, 200 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    surface.SetFont("Inter16")
    
    local fullListWidth = 0
    local selectedX = 0
    local selectedW = 0
    
    local weaponNames = {}
    for i, wep in ipairs(self.Weapons) do
        local rawName = (BW.Translate and BW.Translate.Weapon and BW.Translate.Weapon[wep:GetClass()]) or language.GetPhrase(wep:GetPrintName() or "Unknown")
        local name = ToUpperUTF8(rawName)
        weaponNames[i] = name
        local nameW = surface.GetTextSize(name)
        
        if i == self.Selected then 
            selectedX = fullListWidth 
            selectedW = nameW
        end
        fullListWidth = fullListWidth + nameW + (i < #self.Weapons and 25 or 0)
    end

    local targetOffset = 0
    if fullListWidth < (w - 60) then
        targetOffset = (w - fullListWidth) / 2
    else
        local idealOffset = (w / 2) - selectedX - (selectedW / 2)
        targetOffset = math.Clamp(idealOffset, (w - 30) - fullListWidth, 30)
    end

    self.ScrollOffset = Lerp(FrameTime() * 12, self.ScrollOffset, targetOffset)

    local cyanPill = Color(c.Cyan.r, c.Cyan.g, c.Cyan.b, 40 * alpha)
    local cyanText = Color(c.Cyan.r, c.Cyan.g, c.Cyan.b, 255 * alpha)
    local whiteText = Color(c.White.r, c.White.g, c.White.b, 255 * alpha)
    local grayText  = Color(c.Gray100.r, c.Gray100.g, c.Gray100.b, 255 * alpha)

    local x = self.ScrollOffset
    local centerY = (h / 2) + 5

    for i, wep in ipairs(self.Weapons) do
        local name = weaponNames[i]
        local textW = surface.GetTextSize(name)
        local isSelected = (self.Selected == i)
        
        if x > -textW - 20 and x < w + 20 then
            if isSelected then
                local pillW = textW + 20
                local pillH = 26
                local pillX = x - 10
                local pillY = centerY - (pillH / 2)
                
                draw.RoundedBox(13, pillX, pillY, pillW, pillH, cyanPill)
                draw.SimpleText(name, "Inter16", x, centerY, whiteText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            else
                draw.SimpleText(name, "Inter16", x, centerY, grayText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end
        
        x = x + textW + 25
    end
end

function PANEL:ShowSelector()
    self.TargetAlpha = 255
    self:UpdateWeapons()
    
    timer.Remove("WeaponSelectorHide")
    timer.Create("WeaponSelectorHide", 2.5, 1, function()
        if IsValid(self) then self.TargetAlpha = 0 end
    end)
end

vgui.Register("WeaponSelector", PANEL, "EditablePanel")