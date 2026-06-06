local PANEL = {}

local function GetHexPoly(cx, cy, r)
    local poly = {}
    for i = 1, 6 do
        local a = math.rad(60 * i - 90)
        poly[i] = {
            x = cx + r * math.cos(a),
            y = cy + r * math.sin(a)
        }
    end
    return poly
end

function PANEL:Init()
    self.base = vgui.Create("AvatarImage", self)
    self.base:SetPaintedManually(true)
    
    self.XPProgress = 0
end

function PANEL:PerformLayout(w, h)
    local padding = BW.Config.HUD.Dimensions.AvatarPadding
    self.base:SetPos(padding, padding)
    self.base:SetSize(w - padding * 2, h - padding * 2)
end

function PANEL:Paint(w, h)
    local cx, cy = w / 2, h / 2
    local r_out = h / 2 - 1
    local r_in = r_out - (BW.Config.HUD.Dimensions.AvatarExpWidth or 4)
    
    local cols = BW.Config and BW.Config.Colors or {}
    local progress = math.Clamp(self.XPProgress or 0, 0, 1)


    render.ClearStencil()
    render.SetStencilEnable(true)

    render.SetStencilWriteMask(1)
    render.SetStencilTestMask(1)
    render.SetStencilFailOperation(STENCILOPERATION_REPLACE)
    render.SetStencilPassOperation(STENCILOPERATION_REPLACE)
    render.SetStencilZFailOperation(STENCILOPERATION_KEEP)
    render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_ALWAYS)
    render.SetStencilReferenceValue(1)

    draw.NoTexture()
    surface.SetDrawColor(255, 255, 255)
    surface.DrawPoly(GetHexPoly(cx, cy, r_out))

    render.SetStencilFailOperation(STENCILOPERATION_DECR)
    render.SetStencilPassOperation(STENCILOPERATION_DECR)
    render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_ALWAYS)
    surface.DrawPoly(GetHexPoly(cx, cy, r_in))

    render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)
    render.SetStencilReferenceValue(1)
    render.SetStencilFailOperation(STENCILOPERATION_KEEP)
    render.SetStencilPassOperation(STENCILOPERATION_KEEP)

    surface.SetDrawColor(cols.DarkGray30 or Color(30, 30, 30, 255))
    surface.DrawRect(0, 0, w, h)

    local progress = math.Clamp(self.XPProgress or 0, 0, 1)
    if progress > 0 then
        surface.SetDrawColor(cols.Amber or Color(255, 193, 7, 255))
        if progress >= 1 then
            surface.DrawRect(0, 0, w, h)
        else
            local segments = 30
            local maxAngle = 360 * progress
            local poly = { { x = cx, y = cy } }
            
            for i = 0, segments do
                local deg = (maxAngle / segments) * i - 90
                local rad = math.rad(deg)
                table.insert(poly, {
                    x = cx + r_out * math.cos(rad),
                    y = cy + r_out * math.sin(rad)
                })
            end
            surface.DrawPoly(poly)
        end
    end

    render.SetStencilEnable(false)

    render.ClearStencil()
    render.SetStencilEnable(true)
    
    render.SetStencilWriteMask(1)
    render.SetStencilTestMask(1)
    render.SetStencilFailOperation(STENCILOPERATION_REPLACE)
    render.SetStencilPassOperation(STENCILOPERATION_REPLACE)
    render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_ALWAYS)
    render.SetStencilReferenceValue(1)

    surface.SetDrawColor(255, 255, 255)
    surface.DrawPoly(GetHexPoly(cx, cy, r_in - 1))

    render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)
    
    if IsValid(self.base) then
        self.base:PaintManual()
    end

    render.SetStencilEnable(false)
end

function PANEL:SetPlayer(ply, size)
    if IsValid(self.base) then
        self.base:SetPlayer(ply, size)
    end
end

vgui.Register("HUDAvatar", PANEL)