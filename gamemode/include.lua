local function IncludeShared(path)
	include(path)

	if SERVER then
		AddCSLuaFile(path)
	end
end

local function IncludeClient(path)
	if CLIENT then
		include(path)
	else
		AddCSLuaFile(path)
	end
end

local function IncludeServer(path)
	if SERVER then
		include(path)
	end
end

local function IncludeVgui()
	local vguiFolder = "vgui/"
	local vguiPath = engine.ActiveGamemode() .. "/gamemode/" .. vguiFolder
    local files, dirs = file.Find(vguiPath .. "*", "LUA")
    
    -- Single file
    for _, fileName in ipairs(files) do
        if string.sub(fileName, -4) ~= ".lua" then continue end
        IncludeClient(vguiFolder .. fileName)
    end
end

-- SHARED
IncludeShared("config.lua")
IncludeShared("utils.lua")
IncludeShared("localization/ru_RU.lua")

-- CLIENT ONLY
IncludeClient("fonts.lua")

-- VGUI
IncludeVgui()

-- SERVER ONLY

-- Modules
IncludeShared("modules.lua")