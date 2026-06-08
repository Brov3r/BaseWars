local MODULE = MODULE

MODULE.Name = "Advert"
MODULE.Author = "Brov3r"
MODULE.Require = { "database", "chat" }

function MODULE:Init()
	-- timer.Create("BW_Advert", BW.Config.Advert.DelayTime, 0, function()
	-- 	chat.AddText(Color(255, 255, 255), "[Ads] ")
	-- end)

	gameevent.Listen( "player_connect" )
	hook.Add("player_connect", "BW_PlayerConnect", function(data)
		local lastSeen = player.GetByID(data.index):GetLastSeen()
		local humanReadable = os.date("%d.%m.%Y - %H:%M", SysTime())
		if lastSeen and lastSeen > 0 then
            humanReadable = os.date("%d.%m.%Y - %H:%M", lastSeen)
        end
		chat.AddText(string.format(
			Translate("Advert.JoinText", "<color=95,250,95>[BaseWars]</color> <color=255,165,0>Player</color> <color=0,255,255>%s</color> <color=255,165,0>connected to the server! (SteamID:</color> <color=0,255,255>%s</color><color=255,165,0>, last session:</color> <color=0,255,255>%s</color><color=255,165,0>)</color>"),
			data.name,
			data.networkid,
			humanReadable
		))
	end)

	gameevent.Listen( "player_disconnect" )
	hook.Add("player_disconnect", "BW_PlayerDisconnect", function(data)
		chat.AddText(string.format(
			Translate("Advert.LeaveText", "<color=95,250,95>[BaseWars]</color> <color=255,165,0>Player</color> <color=0,255,255>%s</color> <color=255,165,0>leave from the server! (SteamID:</color> <color=0,255,255>%s</color><color=255,165,0>)</color>"),
			data.name,
			data.networkid
		))
	end)
end