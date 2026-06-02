DeriveGamemode("sandbox")

local function IncludeShared(File)
	include(File)

	if SERVER then
		AddCSLuaFile(File)
	end
end

local function IncludeClient(File)
	if CLIENT then
		include(File)
	else
		AddCSLuaFile(File)
	end
end

local function IncludeServer(file)
	if SERVER then
		include(file)
	end
end

-- SHARED
IncludeShared("config.lua")
IncludeShared("core/localization/ru_RU.lua") -- Localization
IncludeShared("core/utils.lua")
IncludeShared("core/economy/database.lua")
IncludeShared("core/notify.lua")
IncludeShared("core/team.lua")

-- CLIENT ONLY
IncludeClient("core/ui/fonts.lua")
IncludeClient("core/ui/vgui/ui_circularavatar.lua")
IncludeClient("core/ui/vgui/ui_hexavatar.lua")
IncludeClient("core/ui/vgui/ui_scoreboard.lua")
IncludeClient("core/ui/vgui/ui_weapon_selector.lua")
IncludeClient("core/ui/vgui/ui_spawnmenu_props.lua")
IncludeClient("core/ui/vgui/ui_spawnmenu_shop.lua")
IncludeClient("core/ui/hud.lua")
IncludeClient("core/ui/scoreboard.lua")
IncludeClient("core/ui/nametags.lua")
IncludeClient("core/spawnmenu.lua")

-- SERVER ONLY
IncludeServer("core/economy/payday.lua")