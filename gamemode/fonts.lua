resource.AddFile("content/fonts/Inter.ttf")

local function createFont(name, base, size, weight)
    surface.CreateFont(name, {
        font = base,
        size = size,
        extended = true,
        weight = weight,
        antialias = true,
        shadow = false,
        outline = false,
        additive = false,
        blursize = 0,
        scanlines = 0
    })
end

local function createFontSize(font, min, max, step, useThin)
    for i = min, max, step do
        createFont(font .. i, font, i, 900)
        
        if useThin then
            createFont(font .. i .. "Thin", font, i, 400) 
        end
    end
end

createFontSize("Inter", 10, 30, 2, true)