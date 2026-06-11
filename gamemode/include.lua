-- Base loader
local function loadSH(path)
    include(path)
    if SERVER then AddCSLuaFile(path) end
end

local function loadCL(path)
    if CLIENT then include(path)
    else AddCSLuaFile(path) end
end

local function loadSV(path)
    if SERVER then include(path) end
end

-- LoadDir
local function loadDirectory(folderName, loadFunc, fileMask)
    fileMask = fileMask or "*.lua"
    
    local currentGamemode = engine.ActiveGamemode()
    local fullPath = currentGamemode .. "/gamemode/" .. folderName .. "/"
    
    local files = file.Find(fullPath .. fileMask, "LUA")
    
    if not files or #files == 0 then
        return
    end
    
    for _, f in ipairs(files) do
        loadFunc(folderName .. "/" .. f)
    end
end

-- Fonts
local function mkFont(name, font, size, weight)
    surface.CreateFont(name, {
        font = font,
        size = size,
        extended = true,
        weight = weight,
        antialias = true
    })
end

local function initFonts()
    local files = file.Find("resource/fonts/*.ttf", "GAME")
    
    for _, f in ipairs(files) do
        if SERVER then
            resource.AddFile("resource/fonts/" .. f)
        else
            local fontBase = string.StripExtension(f)
            
            for i = 10, 24, 2 do
                mkFont(fontBase .. i, fontBase, i, 900)
                mkFont(fontBase .. i .. "Thin", fontBase, i, 400)
            end
        end
    end
end

-- LOAD LUA
loadSH("config.lua")
loadSH("utils.lua")

initFonts()
loadDirectory("localization", loadSH)
loadDirectory("vgui", loadCL)

-- Modules
loadSH("modules.lua")