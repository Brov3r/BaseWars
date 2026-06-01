local PANEL = {}

function PANEL:Init()
  self.base = vgui.Create("AvatarImage", self)
  self.base:Dock(FILL)
  self.base:SetPaintedManually(true)
end

function PANEL:GetBase()
  return self.base
end

function PANEL:PushHexMask()
    render.ClearStencil()
    render.SetStencilEnable(true)

    render.SetStencilWriteMask(1)
    render.SetStencilTestMask(1)

    render.SetStencilFailOperation(STENCILOPERATION_REPLACE)
    render.SetStencilPassOperation(STENCILOPERATION_ZERO)
    render.SetStencilZFailOperation(STENCILOPERATION_ZERO)
    render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_NEVER)
    render.SetStencilReferenceValue(1)

    local w, h = self:GetWide(), self:GetTall()
    local cx, cy, r = w / 2, h / 2, h / 2
    local poly = {}

    for i = 1, 6 do
        local a = math.rad(60 * i - 90)
        poly[i] = {
            x = cx + r * math.cos(a),
            y = cy + r * math.sin(a)
        }
    end

    draw.NoTexture()
    surface.SetDrawColor(255, 255, 255)
    surface.DrawPoly(poly)

    render.SetStencilFailOperation(STENCILOPERATION_ZERO)
    render.SetStencilPassOperation(STENCILOPERATION_REPLACE)
    render.SetStencilZFailOperation(STENCILOPERATION_ZERO)
    render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)
    render.SetStencilReferenceValue(1)
end

function PANEL:PopMask()
    render.SetStencilEnable(false)
    render.ClearStencil()
end

function PANEL:Paint(w, h)
    self:PushHexMask()
        self.base:PaintManual()
    self:PopMask()
end

function PANEL:SetPlayer(ply, size)
  self.base:SetPlayer(ply, size)
end

vgui.Register("HexAvatar", PANEL)