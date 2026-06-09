local MODULE = MODULE

MODULE.Name = "Advert"
MODULE.Author = "Brov3r"
MODULE.Require = {}


function MODULE:Init()
    local currentAdvertIndex = 1

	timer.Create("BW_Advert", BW.Config.Advert.DelayTime, 0, function()
		local text = Translate("Advert.DelayMsg.Msg" .. currentAdvertIndex, "")
		
		if text and text ~= "" then
			chat.AddText(text)
		end
		
		currentAdvertIndex = currentAdvertIndex + 1
		if currentAdvertIndex > BW.Config.Advert.MessageMaxIndex then
			currentAdvertIndex = 1
		end
	end)

    gameevent.Listen( "player_connect" )
    hook.Add("player_connect", "BW_PlayerConnect", function(data)
        local translatedStr = Translate("Advert.JoinText", "<#5FF05F>[BaseWars] <#FFA500>Player <#00FFFF>%s <#FFA500>connected to the server! (SteamID: <#00FFFF>%s<#FFA500>)")
        local formattedStr = string.format(translatedStr, data.name, data.networkid)
        chat.AddText(formattedStr)
    end)

    gameevent.Listen( "player_disconnect" )
    hook.Add("player_disconnect", "BW_PlayerDisconnect", function(data)
        local translatedStr = Translate("Advert.LeaveText", "<#5FF05F>[BaseWars] <#FFA500>Player <#00FFFF>%s <#FFA500>leave from the server! (SteamID: <#00FFFF>%s<#FFA500>)")
        local formattedStr = string.format(translatedStr, data.name, data.networkid)
        chat.AddText(formattedStr)
    end)
end