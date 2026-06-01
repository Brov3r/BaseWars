local PANEL = {}

function PANEL:Init()
    self:SetSize(400, 60)
    self:SetPos(ScrW() / 2 - 200, 20)
    self.Weapons = {}
    self.Selected = 1
    self.TargetAlpha = 0
    self.CurrentAlpha = 0
    self.ScrollOffset = 0
end

function PANEL:UpdateWeapons()
    self.Weapons = LocalPlayer():GetWeapons()
end

local WepSelectIcon = Material("icon16/gun.png", "smooth")

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

    draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 30, 240 * alpha))
    
    draw.SimpleText(BW.Translate.WeaponSelector, "Inter14", w / 2, 13, Color(255, 255, 255, 200 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    surface.SetFont("Inter16")
    
    local fullListWidth = 0
    local selectedX = 0
    local selectedW = 0
    
    local weaponNames = {}
    for i, wep in ipairs(self.Weapons) do
       	local rawName = language.GetPhrase(wep:GetPrintName() or "Unknown")
    	local name = ToUpperUTF8(rawName)
        weaponNames[i] = name
        local nameW = surface.GetTextSize(name)
        
        if i == self.Selected then 
            selectedX = fullListWidth 
            selectedW = nameW
        end
        fullListWidth = fullListWidth + nameW + (i < #self.Weapons and 30 or 0)
    end

    local targetOffset = 0
    if fullListWidth < (w - 40) then
        targetOffset = (w - fullListWidth) / 2
    else
        local idealOffset = 200 - selectedX - (selectedW / 2)
        targetOffset = math.Clamp(idealOffset, (w - 20) - fullListWidth, 20)
    end

    self.ScrollOffset = Lerp(FrameTime() * 10, self.ScrollOffset, targetOffset)

    local x = self.ScrollOffset
    for i, wep in ipairs(self.Weapons) do
        local name = weaponNames[i]
        local textW = surface.GetTextSize(name)
        local isSelected = (self.Selected == i)
        
        local textColor = isSelected and Color(Colors.Cyan.r, Colors.Cyan.g, Colors.Cyan.b, 255 * alpha) 
                                      or Color(150, 150, 150, 255 * alpha)
        
        if x > -textW and x < w then
            draw.SimpleText(name, "Inter16", x, 40, textColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            
            if isSelected then
                draw.RoundedBox(0, x, 52, textW, 2, Color(Colors.Cyan.r, Colors.Cyan.g, Colors.Cyan.b, 255 * alpha))
            end
        end
        
        x = x + textW + 30
    end
end

function PANEL:ShowSelector()
    self.TargetAlpha = 255
    self:UpdateWeapons()
    timer.Create("WeaponSelectorHide", 2, 1, function()
        if IsValid(self) then self.TargetAlpha = 0 end
    end)
end

vgui.Register("WeaponSelector", PANEL, "EditablePanel")