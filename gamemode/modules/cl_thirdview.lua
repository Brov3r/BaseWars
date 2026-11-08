local MODULE = MODULE

MODULE.Name = "ThirdView"
MODULE.Author = "Brov3r"
MODULE.Require = {}

local cfg = (BW.Config and BW.Config.ThirdPerson) or {}

BW.ThirdPerson = BW.ThirdPerson or {}
BW.ThirdPerson.Active = false
BW.ThirdPerson.ViewOrigin = nil

MODULE.Enabled = cfg.Enabled ~= false
MODULE.Distance = tonumber(cfg.Distance) or 50
MODULE.ShoulderOffset = tonumber(cfg.ShoulderOffset) or 20
MODULE.HeightOffset = tonumber(cfg.HeightOffset) or 0
MODULE.CollisionRadius = tonumber(cfg.CollisionRadius) or 6
MODULE.CollisionPadding = tonumber(cfg.CollisionPadding) or 6
MODULE.SmoothSpeed = tonumber(cfg.SmoothSpeed) or 14
MODULE.DrawViewerDistance = tonumber(cfg.DrawViewerDistance) or 24

function MODULE:IsActive(ply)
    if not self.Enabled then return false end
    if not IsValid(ply) or not ply:Alive() then return false end
    if ply:InVehicle() then return false end
    local weapon = ply:GetActiveWeapon()
    if IsValid(weapon) and weapon:GetClass() == "gmod_camera" then return false end
    return true
end

function MODULE:GetCollisionFilter(ply, weapon)
    local filter = {ply}
    if IsValid(weapon) then filter[#filter + 1] = weapon end
    local viewModel = ply.GetViewModel and ply:GetViewModel() or NULL
    if IsValid(viewModel) then filter[#filter + 1] = viewModel end
    return filter
end

function MODULE:TraceCamera(pivot, target, filter)
    local radius = self.CollisionRadius
    return util.TraceHull({
        start = pivot,
        endpos = target,
        mins = Vector(-radius, -radius, -radius),
        maxs = Vector(radius, radius, radius),
        filter = filter,
        -- Only world brushes and player clips: characters and props must not
        -- pull the camera in, otherwise strafing feels like it snags.
        mask = MASK_PLAYERSOLID_BRUSHONLY
    })
end

function MODULE:CalcView(ply, pos, angles, fov)
    if not self:IsActive(ply) then
        self.CurrentDistance = nil
        BW.ThirdPerson.Active = false
        BW.ThirdPerson.ViewOrigin = nil
        return
    end

    local weapon = ply:GetActiveWeapon()
    local pivot = ply:GetShootPos()
    local offset = angles:Right() * self.ShoulderOffset
        + angles:Up() * self.HeightOffset
        - angles:Forward() * self.Distance
    local fullDistance = offset:Length()
    local direction = fullDistance > 0 and offset * (1 / fullDistance) or -angles:Forward()

    local filter = self:GetCollisionFilter(ply, weapon)
    local trace = self:TraceCamera(pivot, pivot + direction * fullDistance, filter)
    local safeDistance = trace.Hit
        and math.max(0, trace.Fraction * fullDistance - self.CollisionPadding)
        or fullDistance

    if not self.CurrentDistance then
        self.CurrentDistance = safeDistance
    else
        local frame = math.min(FrameTime(), 0.1)
        local blend = 1 - math.exp(-self.SmoothSpeed * frame)

        if safeDistance < self.CurrentDistance then
            -- Pull in immediately so the camera cannot clip into a wall.
            self.CurrentDistance = safeDistance
        else
            self.CurrentDistance = Lerp(blend, self.CurrentDistance, safeDistance)
        end
    end

    local origin = pivot + direction * self.CurrentDistance

    -- Verify the smoothed distance one more time; geometry may have changed.
    local clampTrace = self:TraceCamera(pivot, origin, filter)
    if clampTrace.Hit then
        self.CurrentDistance = math.max(0, clampTrace.Fraction * self.CurrentDistance - self.CollisionPadding)
        origin = pivot + direction * self.CurrentDistance
    end

    BW.ThirdPerson.Active = true
    BW.ThirdPerson.ViewOrigin = origin

    local view = {}
    view.origin = origin
    view.angles = angles
    view.fov = fov
    view.drawviewer = self.CurrentDistance > self.DrawViewerDistance
    return view
end

function MODULE:CanToggle(ply, allowUI)
    if not IsValid(ply) or ply ~= LocalPlayer() then return false end
    if not ply:Alive() then return false end
    if not allowUI then
        if gui.IsGameUIVisible() then return false end
        if vgui.GetKeyboardFocus() ~= nil then return false end
    end
    return true
end

function MODULE:Toggle(ply, allowUI)
    if not self:CanToggle(ply, allowUI) then return end
    self.Enabled = not self.Enabled
    self.CurrentDistance = nil
end

function MODULE:Init()
    hook.Add("CalcView", "BW_ThirdPerson_View", function(ply, pos, angles, fov)
        return self:CalcView(ply, pos, angles, fov)
    end)

    hook.Add("PlayerButtonDown", "BW_ThirdPerson_Toggle", function(ply, button)
        if button == KEY_LALT then
            self:Toggle(ply)
        end
    end)

    hook.Add("PreDrawViewModel", "BW_ThirdPerson_HideViewModel", function(vm, ply, weapon)
        if ply == LocalPlayer() and self:IsActive(ply) then
            return true
        end
    end)

    concommand.Add("bw_thirdperson", function(ply)
        self:Toggle(ply or LocalPlayer(), true)
    end)

    hook.Add("HUDShouldDraw", "BW_ThirdPerson_HideCrosshair", function(name)
        if name == "CHudCrosshair" and self:IsActive(LocalPlayer()) then
            return false
        end
    end)

    hook.Add("HUDPaint", "BW_ThirdPerson_DrawCorrectCrosshair", function()
        if not self:IsActive(LocalPlayer()) then return end
        if gui.IsGameUIVisible() then return end

        local ply = LocalPlayer()
        local trace = util.TraceLine({
            start = ply:GetShootPos(),
            endpos = ply:GetShootPos() + ply:EyeAngles():Forward() * 10000,
            filter = ply
        })

        local screenPos = trace.HitPos:ToScreen()
        surface.SetDrawColor(255, 255, 255, 100)
        surface.DrawLine(screenPos.x - 5, screenPos.y, screenPos.x + 5, screenPos.y)
        surface.DrawLine(screenPos.x, screenPos.y - 5, screenPos.x, screenPos.y + 5)
    end)
end
