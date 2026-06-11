local MODULE = MODULE

MODULE.Name = "ThirdView"
MODULE.Author = "Brov3r"
MODULE.Require = {}

MODULE.Enabled = true
MODULE.Distance = 50

function MODULE:Init()
	hook.Add("CalcView", "BW_ThirdPerson_View", function(ply, pos, angles, fov)
        if not self.Enabled then return end
        if not ply:Alive() then return end

        local view = {}
        
        local trace = util.TraceLine({
            start = ply:GetShootPos(),
            endpos = ply:GetShootPos() - angles:Forward() * self.Distance + angles:Right() * 20,
            filter = ply
        })

        view.origin = trace.HitPos
        view.angles = angles
        view.fov = fov
        view.drawviewer = true

        return view
    end)

    hook.Add("PlayerButtonDown", "BW_ThirdPerson_Toggle", function(ply, button)
        if button == KEY_LALT then
            self.Enabled = not self.Enabled
        end
    end)

	hook.Add("HUDShouldDraw", "BW_ThirdPerson_HideCrosshair", function(name)
		if MODULE.Enabled and name == "CHudCrosshair" then
			return false
		end
	end)

	hook.Add("HUDPaint", "BW_ThirdPerson_DrawCorrectCrosshair", function()
		if not MODULE.Enabled then return end
		
		local ply = LocalPlayer()
		if not IsValid(ply) or not ply:Alive() then return end

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