resource.AddFile("content/fonts/Inter.ttf")

if FONTS_LOADED then return end
FONTS_LOADED = true

local function createFont(name, base, size, weight)
    surface.CreateFont(name, {
        font = base,
        size = size,
        extended = false,
        weight = weight,
        antialias = true,
        shadow = false,
        outline = false,
        additive = false,
        blursize = 0,
        scanlines = 0
    })
end

createFont("Inter16",      "Inter", 16, 1000)
createFont("Inter18",      "Inter", 18, 1000)
createFont("Inter20",      "Inter", 20, 1000)
createFont("Inter22",      "Inter", 22, 1000)
createFont("Inter24",      "Inter", 24, 1000)
createFont("Inter28",      "Inter", 28, 1000)

createFont("Inter16Thin",  "Inter", 16, 500)
createFont("Inter18Thin",  "Inter", 18, 500)
createFont("Inter20Thin",  "Inter", 20, 500)
createFont("Inter22Thin",  "Inter", 22, 500)
createFont("Inter24Thin",  "Inter", 24, 500)
createFont("Inter28Thin",  "Inter", 28, 500)