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
    local dims = BW.Config.HUD.Dimensions
    local scale = BW.Utils.GetHUDScale and BW.Utils.GetHUDScale() or 1
    local padding = math.max(1, math.floor((dims.AvatarPadding or 10) * scale + 0.5))
    self.Padding = padding
    self.ExpWidth = math.max(2, math.floor((dims.AvatarExpWidth or 10) * scale + 0.5))

    if IsValid(self.base) then
        self.base:SetPos(padding, padding)
        self.base:SetSize(math.max(1, w - padding * 2), math.max(1, h - padding * 2))
    end

    self:CacheGeometry(w, h)
end

function PANEL:CacheGeometry(w, h)
    local cx, cy = w / 2, h / 2
    local rOut = math.max(2, h / 2 - 1)
    local rIn = math.max(1, rOut - (self.ExpWidth or 10))

    if self.GeomW == w and self.GeomH == h and self.GeomRIn == rIn then return end
    self.GeomW, self.GeomH, self.GeomRIn = w, h, rIn
    self.CenterX, self.CenterY = cx, cy
    self.RadiusOuter, self.RadiusInner = rOut, rIn
    self.PolyOuter = GetHexPoly(cx, cy, rOut)
    self.PolyInner = GetHexPoly(cx, cy, rIn)
    self.PolyBase = GetHexPoly(cx, cy, math.max(1, rIn - 1))
end

function PANEL:Paint(w, h)
    local progress = tonumber(self.XPProgress) or 0
    if progress ~= progress then progress = 0 end
    progress = math.Clamp(progress, 0, 1)

    if not self.PolyOuter or self.GeomW ~= w or self.GeomH ~= h then
        self:CacheGeometry(w, h)
    end

    local cx, cy = self.CenterX, self.CenterY
    local r_out = self.RadiusOuter
    
    local cols = BW.Config and BW.Config.Colors or {}


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
    surface.DrawPoly(self.PolyOuter)

    render.SetStencilFailOperation(STENCILOPERATION_DECR)
    render.SetStencilPassOperation(STENCILOPERATION_DECR)
    render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_ALWAYS)
    surface.DrawPoly(self.PolyInner)

    render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)
    render.SetStencilReferenceValue(1)
    render.SetStencilFailOperation(STENCILOPERATION_KEEP)
    render.SetStencilPassOperation(STENCILOPERATION_KEEP)

    surface.SetDrawColor(cols.DarkGray30 or Color(30, 30, 30, 255))
    surface.DrawRect(0, 0, w, h)

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
    surface.DrawPoly(self.PolyBase)

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