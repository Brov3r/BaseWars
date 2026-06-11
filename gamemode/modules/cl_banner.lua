local MODULE = MODULE 

MODULE.Name = "Banner"
MODULE.Author = "Brov3r"

MODULE.BannerConfig = {
	pos = Vector(-1671, -1320, 191), 
	ang = Angle(0, 90, 90), 
	height = 1270,
	width = 2720,
	font = "BW_BannerFont",
	distance = 2500,
}
   
function MODULE:Init()
	local banner = self.BannerConfig

	surface.CreateFont("BW_BannerFont", {
        font = "Inter",
        extended = true,
        size = 120,
        weight = 800,
        antialias = true,
        shadow = true,
    })

	surface.CreateFont("BW_BannerFontSmall", {
        font = "Inter",
        extended = true,
        size = 90,
        weight = 800,
        antialias = true,
        shadow = true,
    })

    hook.Add("PostDrawOpaqueRenderables", "BW_DrawBanners", function()
        local ply = LocalPlayer()
		if not IsValid(ply) or not ply:Alive() then return end

		if ply:GetPos():DistToSqr(banner.pos) < banner.distance * banner.distance then 
			self:DrawBanner(banner)
		end
    end)
end

function MODULE:DrawBanner(b) 
    cam.Start3D2D(b.pos, b.ang, 0.1)
        draw.RoundedBox(20, 0, 0, b.width, b.height, Color(0, 0, 0, 230))
        surface.SetDrawColor(255, 165, 0, 255)
        surface.DrawOutlinedRect(0, 0, b.width, b.height, 12)
        
        draw.SimpleText(Translate("Banner.Title", "Welcome to BaseWars!"), "BW_BannerFont", b.width / 2, 120, Color(255, 165, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        surface.DrawLine(100, 220, b.width - 100, 220)

        local lines = {
            Translate("Banner.Line1", "New here? Check out the Rules and FAQ (Q key)."),
            Translate("Banner.Line2", "Shop: Q - Shop"),
            Translate("Banner.Line3", "FAQ: Q - FAQ"),
            Translate("Banner.Line4", "Rules: Q - Rules"),
            Translate("Banner.Line5", "Commands: F4"),
            Translate("Banner.Line6", "3rd Person: ALT"),
        }

        for i, line in ipairs(lines) do
            local y = (i == 1) and 350 or (300 + (i * 140))
            
            if string.find(line, ": ") then
                local split = string.Split(line, ": ")
                draw.SimpleText(split[1], "BW_BannerFont", 100, y, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(split[2], "BW_BannerFont", b.width - 100, y, Color(0, 255, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            else
                draw.SimpleText(line, "BW_BannerFont", b.width / 2, y, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
    cam.End3D2D()
end