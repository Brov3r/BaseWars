local PANEL = {}

function PANEL:Init()
    self:SetSize(500, 65)
    self:SetPos(ScrW() / 2 - self:GetWide() / 2, 30)
    
    self.Weapons = {}
    self.WeaponData = {} -- Кэш для имен и ширины текста
    self.Selected = 1
    self.TargetAlpha = 0
    self.CurrentAlpha = 0
    self.ScrollOffset = 0
    self.FullListWidth = 0
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
        local classA, classB = a:GetClass(), b:GetClass()
        if classA == "weapon_physgun" then return true end
        if classB == "weapon_physgun" then return false end

        local slotA = (a.GetSlot and a:GetSlot()) or 0
        local slotB = (b.GetSlot and b:GetSlot()) or 0
        
        if slotA == slotB then
            return classA < classB
        end
        return slotA < slotB
    end)

    self.Weapons = sortedWeapons
    self:CacheWeaponNames()
end

function PANEL:CacheWeaponNames()
    self.WeaponData = {}
    local totalWidth = 0
    surface.SetFont("Inter16")
    
    for i, wep in ipairs(self.Weapons) do
        local rawName = Translate("Weapons."..wep:GetClass(), Translate(wep:GetClass(), wep:GetPrintName()))
        local name = self:ToUpperUTF8(rawName)
        local w = surface.GetTextSize(name)
        
        self.WeaponData[i] = { name = name, width = w, x = totalWidth }
        totalWidth = totalWidth + w + (i < #self.Weapons and 25 or 0)
    end
    self.FullListWidth = totalWidth
end

function PANEL:ToUpperUTF8(str)
    if not str or str == "" then return "" end
    
    local res = ""
    for _, cp in utf8.codes(str) do
        if cp >= 97 and cp <= 122 then
            cp = cp - 32
        elseif cp >= 1072 and cp <= 1103 then
            cp = cp - 32
        elseif cp == 1105 then
            cp = 1025
        end
        res = res .. utf8.char(cp)
    end
    return res
end

function PANEL:Paint(w, h)
    self.CurrentAlpha = Lerp(FrameTime() * 10, self.CurrentAlpha, self.TargetAlpha)
    if self.CurrentAlpha <= 0 then return end
    
    local alpha = self.CurrentAlpha / 255
    local c = BW.Config.Colors

    draw.RoundedBox(8, 0, 0, w, h, Color(c.DarkGray35.r, c.DarkGray35.g, c.DarkGray35.b, 240 * alpha))
    draw.RoundedBoxEx(8, 0, 0, w, 1, Color(c.Gray50.r, c.Gray50.g, c.Gray50.b, 150 * alpha), true, true, false, false)

    local title = self:ToUpperUTF8(Translate("WeaponSelectorTitle", "WEAPONS") .. "  •  " .. #self.Weapons)
    draw.SimpleText(title, "Inter12", w / 2, 10, Color(c.White.r, c.White.g, c.White.b, 200 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    if self.FullListWidth == 0 then return end

    local targetOffset = 0
    if self.FullListWidth < (w - 60) then
        targetOffset = (w - self.FullListWidth) / 2
    else
        local selectedData = self.WeaponData[self.Selected] or { width = 0, x = 0 }
        local idealOffset = (w / 2) - selectedData.x - (selectedData.width / 2)
        targetOffset = math.Clamp(idealOffset, (w - 30) - self.FullListWidth, 30)
    end

    self.ScrollOffset = Lerp(FrameTime() * 12, self.ScrollOffset, targetOffset)

    local cyanPill = Color(c.Cyan.r, c.Cyan.g, c.Cyan.b, 40 * alpha)
    local whiteText = Color(c.White.r, c.White.g, c.White.b, 255 * alpha)
    local grayText  = Color(c.Gray100.r, c.Gray100.g, c.Gray100.b, 255 * alpha)

    local x = self.ScrollOffset
    local centerY = (h / 2) + 5

    for i, data in ipairs(self.WeaponData) do
        if x > -data.width - 20 and x < w + 20 then
            if self.Selected == i then
                local pillW = data.width + 20
                local pillH = 26
                draw.RoundedBox(13, x - 10, centerY - (pillH / 2), pillW, pillH, cyanPill)
                draw.SimpleText(data.name, "Inter16", x, centerY, whiteText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            else
                draw.SimpleText(data.name, "Inter16", x, centerY, grayText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end
        x = x + data.width + 25
    end
end

function PANEL:ShowSelector()
    self.TargetAlpha = 255
    self:UpdateWeapons()

    local timerName = "WeaponSelectorHide"
    timer.Remove(timerName)
    timer.Create(timerName, 2.5, 1, function()
        if IsValid(self) then
            self.TargetAlpha = 0
        end
    end)
end

vgui.Register("WeaponSelector", PANEL, "EditablePanel")