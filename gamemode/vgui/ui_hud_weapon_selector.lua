local PANEL = {}

function PANEL:Init()
    local cfg = BW.Config.WeaponSelector or {}
    local opacity = tonumber(cfg.Opacity)
    if not BW.Utils.IsFinite(opacity) then opacity = 0.88 end
    local alpha = math.floor(math.Clamp(opacity, 0.4, 1) * 255)
    local accent = (BW.Config.Scoreboard or {}).AccentColor or Color(62, 214, 153)
    self.PanelWidth = cfg.Width or 520
    self.TopOffset = cfg.TopOffset or 30
    self.HideDelay = cfg.HideDelay or 2.5
    self.ScrollSound = cfg.ScrollSound == nil and "UI/buttonrollover.wav" or cfg.ScrollSound
    self.Padding, self.Gap, self.CardHeight = 8, 6, 30
    self.Weapons, self.WeaponData = {}, {}
    self.Selected = 1
    self.TargetAlpha, self.CurrentAlpha = 0, 0
    self.ScrollOffset, self.FullListWidth = 0, 0
    self.Colors = {
        Background = Color(13, 18, 24, alpha), Border = Color(65, 81, 94),
        Selected = Color(24, 43, 42), White = Color(255, 255, 255), Accent = accent,
        SelectedBorder = Color(math.Round(accent.r * 0.9), math.Round(accent.g * 0.9), math.Round(accent.b * 0.9), math.Round(255 * 0.85))
    }
    self:SetMouseInputEnabled(false)
    self:SetKeyboardInputEnabled(false)
    self:SetAlpha(0)
    self:UpdateLayout()
end

function PANEL:UpdateLayout()
    local maxWidth = math.max(1, math.min(ScrW() - 24, self.PanelWidth))
    local contentWidth = self.FullListWidth > 0 and math.max(140, self.FullListWidth + self.Padding * 2) or maxWidth
    self:SetSize(math.min(maxWidth, contentWidth), self.CardHeight + self.Padding * 2)
    self:SetPos((ScrW() - self:GetWide()) / 2, self.TopOffset)
    self.ScreenWidth, self.ScreenHeight = ScrW(), ScrH()
end

function PANEL:ToUpperUTF8(text)
    text = tostring(text or "")
    if not utf8.len(text) then return "" end
    local result = {}
    for _, cp in utf8.codes(text) do
        if cp >= 97 and cp <= 122 then cp = cp - 32
        elseif cp >= 1072 and cp <= 1103 then cp = cp - 32
        elseif cp == 1105 then cp = 1025 end
        result[#result + 1] = utf8.char(cp)
    end
    return table.concat(result)
end

function PANEL:UpdateWeapons()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local selectedWeapon = self.Weapons[self.Selected]
    local weapons = {}
    for _, wep in ipairs(ply:GetWeapons()) do
        if IsValid(wep) then weapons[#weapons + 1] = wep end
    end
    table.sort(weapons, function(a, b)
        local classA, classB = a:GetClass(), b:GetClass()
        if classA ~= classB then
            if classA == "weapon_physgun" then return true end
            if classB == "weapon_physgun" then return false end
        end
        local slotA, slotB = a:GetSlot(), b:GetSlot()
        if slotA ~= slotB then return slotA < slotB end
        if classA ~= classB then return classA < classB end
        return a:EntIndex() < b:EntIndex()
    end)
    self.Weapons = weapons
    self.Selected = math.Clamp(self.Selected, 1, math.max(1, #weapons))
    for index, weapon in ipairs(weapons) do
        if weapon == selectedWeapon then self.Selected = index break end
    end
    self:CacheWeaponNames()
end

function PANEL:CacheWeaponNames()
    self.WeaponData = {}
    local x = 0
    for index, wep in ipairs(self.Weapons) do
        local class = wep:GetClass()
        local rawName = Translate("Weapons." .. class, Translate(class, wep:GetPrintName()))
        local name = self:ToUpperUTF8(rawName)
        surface.SetFont("Inter16")
        local textWidth = surface.GetTextSize(name)
        local maxWidth = math.max(1, math.min(ScrW() - 24, self.PanelWidth) - self.Padding * 2)
        local width = math.min(math.Clamp(textWidth + 24, 80, 180), maxWidth)
        self.WeaponData[index] = {
            name = BW.Utils.TruncateText(name, "Inter16", math.max(1, width - 24)),
            width = width, x = x
        }
        x = x + width + self.Gap
    end
    self.FullListWidth = math.max(0, x - self.Gap)
    self:UpdateLayout()
end

function PANEL:GetTargetOffset()
    local available = self:GetWide() - self.Padding * 2
    if self.FullListWidth <= available then return (self:GetWide() - self.FullListWidth) / 2 end
    local selected = self.WeaponData[self.Selected]
    if not selected then return self.Padding end
    local center = self:GetWide() / 2 - selected.x - selected.width / 2
    return math.Clamp(center, self:GetWide() - self.Padding - self.FullListWidth, self.Padding)
end

function PANEL:SetSelected(index, forceSound)
    index = math.Clamp(tonumber(index) or 1, 1, math.max(1, #self.Weapons))
    local changed = index ~= self.Selected
    self.Selected = index
    if (changed or forceSound) and isstring(self.ScrollSound) and self.ScrollSound ~= "" then
        surface.PlaySound(self.ScrollSound)
    end
    return changed
end

function PANEL:Think()
    if self.ScreenWidth ~= ScrW() or self.ScreenHeight ~= ScrH() then
        self:UpdateLayout()
        self:CacheWeaponNames()
        self.ScrollOffset = self:GetTargetOffset()
    end
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() or (self.HideAt and CurTime() >= self.HideAt) then self.TargetAlpha = 0 end
    self.CurrentAlpha = math.Approach(self.CurrentAlpha, self.TargetAlpha, FrameTime() * 1500)
    self:SetAlpha(self.CurrentAlpha)
    self.ScrollOffset = Lerp(math.min(1, FrameTime() * 14), self.ScrollOffset, self:GetTargetOffset())
end

function PANEL:Paint(w, h)
    if self.CurrentAlpha <= 0 then return end
    local c = self.Colors
    draw.RoundedBox(10, 0, 0, w, h, c.Background)
    BW.Utils.DrawRoundedOutline(10, 0, 0, w, h, c.Border)

    -- Clip only the scrolling cards; leave the rounded outer frame untouched.
    local screenX, screenY = self:LocalToScreen(self.Padding, self.Padding)
    render.SetScissorRect(screenX, screenY, screenX + w - self.Padding * 2, screenY + self.CardHeight, true)
    for index, data in ipairs(self.WeaponData) do
        local x, y = self.ScrollOffset + data.x, self.Padding
        if x + data.width <= self.Padding or x >= w - self.Padding then continue end
        local selected = self.Selected == index
        if selected then
            draw.RoundedBox(6, x, y, data.width, self.CardHeight, c.Selected)
            BW.Utils.DrawRoundedOutline(6, x, y, data.width, self.CardHeight, c.SelectedBorder)
        end
        draw.SimpleText(data.name, "Inter16", x + data.width / 2, y + self.CardHeight / 2, selected and c.Accent or c.White, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    render.SetScissorRect(0, 0, 0, 0, false)
end

function PANEL:ShowSelector()
    local opening = self.TargetAlpha == 0
    self:UpdateWeapons()
    if #self.Weapons == 0 then self.TargetAlpha = 0 return end
    if opening then
        local ply = LocalPlayer()
        local active = IsValid(ply) and ply:GetActiveWeapon() or NULL
        for index, wep in ipairs(self.Weapons) do
            if wep == active then self.Selected = index break end
        end
        self.ScrollOffset = self:GetTargetOffset()
    end
    self.TargetAlpha = 255
    self.HideAt = CurTime() + self.HideDelay
end

vgui.Register("WeaponSelector", PANEL, "EditablePanel")
