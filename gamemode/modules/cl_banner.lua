local MODULE = MODULE

MODULE.Name = "Banner"
MODULE.Author = "Brov3r"

local FALLBACK_LINES = {
    "Welcome! The main menu is on Q.",
    "Shop / FAQ / rules: Q",
    "Commands & factions: F4",
    "Third person: ALT",
    "Economy: /sell — sell items",
    "Money: /dropmoney [amount]",
}

local function WithAlpha(color, alpha)
    return Color(color.r, color.g, color.b, (color.a or 255) * alpha)
end

local function Merge(base, override)
    local result = {}
    for key, value in pairs(base or {}) do result[key] = value end
    for key, value in pairs(override or {}) do result[key] = value end
    return result
end

local function GetViewOrigin()
    local thirdPerson = BW.ThirdPerson
    if thirdPerson and thirdPerson.Active and thirdPerson.ViewOrigin then
        return thirdPerson.ViewOrigin
    end

    local ply = LocalPlayer()
    return IsValid(ply) and ply:EyePos() or nil
end

function MODULE:GetBannerFont(size)
    size = math.max(8, math.floor(tonumber(size) or 120))
    local name = self.FontCache[size]
    if not name then
        local fontFamily = (BW.Config.Fonts and BW.Config.Fonts[1]) or "Inter"
        name = "BW_BannerFont_" .. size
        surface.CreateFont(name, {
            font = fontFamily,
            extended = true,
            size = size,
            weight = 800,
            antialias = true,
            shadow = true,
        })
        self.FontCache[size] = name
    end
    return name
end

function MODULE:BuildText()
    self.Title = Translate("Banner.Title", "Welcome to BaseWars!")
    self.Lines = {}

    for i = 1, #FALLBACK_LINES do
        local text = Translate("Banner.Line" .. i, FALLBACK_LINES[i])
        if text and text ~= "" then
            local label, value = string.match(text, "^(.-):%s+(.*)$")
            self.Lines[#self.Lines + 1] = label and {label = label, value = value} or {text = text}
        end
    end
end

function MODULE:Init()
    local root = BW.Config.Banner or {}
    local style = root.Style or {}
    local mapBanners = (root.Maps or {})[game.GetMap()]
    if not mapBanners or style.Enabled == false then return end
    if type(mapBanners) ~= "table" then return end
    if mapBanners.Position then mapBanners = { mapBanners } end

    self.Banners = {}
    self.FontCache = {}

    for _, entry in ipairs(mapBanners) do
        if type(entry) == "table" then
            local banner = Merge(style, entry)
            if banner.Enabled ~= false and isvector(banner.Position) and isangle(banner.Angles) then
                banner.Font = self:GetBannerFont(banner.FontSize)
                banner.SmallFont = self:GetBannerFont(banner.SmallFontSize)
                self.Banners[#self.Banners + 1] = banner
            end
        end
    end

    if #self.Banners == 0 then return end

    self:BuildText()

    if GetConVar("gmod_language") then
        cvars.AddChangeCallback("gmod_language", function()
            self:BuildText()
        end, "BW_Banner_RefreshText")
    end

    hook.Add("PostDrawOpaqueRenderables", "BW_DrawBanners", function(bDrawingDepth)
        -- Only skip the depth pass. The skybox flags are unreliable with r_3dsky 0.
        if bDrawingDepth then return end
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then return end

        local playerPos = ply:GetPos()
        local viewOrigin = GetViewOrigin()

        for _, banner in ipairs(self.Banners) do
            local distance = playerPos:Distance(banner.Position)
            if viewOrigin then
                distance = math.min(distance, viewOrigin:Distance(banner.Position))
            end

            local maxDistance = tonumber(banner.Distance) or 2500
            if distance <= maxDistance then
                local fadeDistance = math.max(0, tonumber(banner.FadeDistance) or 0)
                local alpha = 1
                if fadeDistance > 0 then
                    local fadeStart = maxDistance - fadeDistance
                    if distance > fadeStart then
                        alpha = math.Clamp((maxDistance - distance) / fadeDistance, 0, 1)
                    end
                end

                if alpha > 0.01 then
                    self:DrawBanner(banner, alpha)
                end
            end
        end
    end)
end

function MODULE:DrawBanner(b, alpha)
    local width = tonumber(b.Width) or 2720
    local height = tonumber(b.Height) or 1270
    local padding = tonumber(b.Padding) or 100
    local scale = tonumber(b.Scale) or 0.1
    local lineStartY = tonumber(b.LineStartY) or 300
    local lineFirstY = tonumber(b.LineFirstY) or 350
    local lineSpacing = tonumber(b.LineSpacing) or 140
    local borderColor = b.Border or Color(255, 165, 0, 255)
    local textColor = b.TextColor or Color(255, 255, 255, 255)
    local accentColor = b.AccentColor or Color(0, 255, 255, 255)
    local titleColor = b.TitleColor or borderColor

    cam.Start3D2D(b.Position, b.Angles, scale)
        draw.RoundedBox(
            tonumber(b.CornerRadius) or 20,
            0, 0, width, height,
            WithAlpha(b.Background or Color(0, 0, 0, 230), alpha)
        )

        surface.SetDrawColor(WithAlpha(borderColor, alpha))
        surface.DrawOutlinedRect(0, 0, width, height, tonumber(b.BorderWidth) or 12)

        draw.SimpleText(
            self.Title or "",
            b.Font,
            width / 2,
            tonumber(b.TitleY) or 120,
            WithAlpha(titleColor, alpha),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )

        local separatorY = tonumber(b.SeparatorY) or 220
        surface.DrawLine(padding, separatorY, width - padding, separatorY)

        for i, line in ipairs(self.Lines or {}) do
            local y = (i == 1) and lineFirstY or (lineStartY + i * lineSpacing)
            if line.label then
                draw.SimpleText(
                    line.label,
                    b.SmallFont,
                    padding,
                    y,
                    WithAlpha(textColor, alpha),
                    TEXT_ALIGN_LEFT,
                    TEXT_ALIGN_CENTER
                )
                draw.SimpleText(
                    line.value,
                    b.SmallFont,
                    width - padding,
                    y,
                    WithAlpha(accentColor, alpha),
                    TEXT_ALIGN_RIGHT,
                    TEXT_ALIGN_CENTER
                )
            else
                draw.SimpleText(
                    line.text,
                    b.SmallFont,
                    width / 2,
                    y,
                    WithAlpha(textColor, alpha),
                    TEXT_ALIGN_CENTER,
                    TEXT_ALIGN_CENTER
                )
            end
        end
    cam.End3D2D()
end
