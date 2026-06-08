local MODULE = MODULE

MODULE.Name = "Chat"
MODULE.Author = "Brov3r"
MODULE.Require = {}

MODULE.ChatBox = nil

function MODULE:Init()
	hook.Add("OnPlayerChat", "ChatBox_CaptureSystem", function(ply, text, isTeam, isDead)
        return MODULE:ChatTextHandler(ply, text, isTeam, isDead)
    end)
	hook.Add("HUDShouldDraw", "ChatBox_HideDefault", function(name)
        if name == "CHudChat" then return false end
    end)
	hook.Add("InitPostEntity", "ChatBox_Init", function()
		if not IsValid(MODULE.ChatBox) then 
			MODULE.ChatBox = vgui.Create("ChatBox") 
		end
    end)
	hook.Add("StartChat", "ChatBox_Intercept", function(isTeamChat)
        if not IsValid(MODULE.ChatBox) then MODULE.ChatBox = vgui.Create("ChatBox") end
        	MODULE.ChatBox:OpenChat(isTeamChat)
        return true
    end)

	hook.Add("OnScreenSizeChanged", "ChatBox_Repos", function()
        if IsValid(MODULE.ChatBox) then MODULE.ChatBox:SetPos(BW.Config.Chat.HPosOffset, ScrH() - BW.Config.Chat.VPosOffset) end
    end)

	hook.Add( "OnPauseMenuShow", "DisableMenu", function()
		if IsValid(MODULE.ChatBox) and MODULE.ChatBox.IsOpen then 
			MODULE.ChatBox:CloseChat() 
			return false
		end
		return true
	end )

	hook.Add( "ChatText", "hide_joinleave", function( index, name, text, type )
		if ( type == "joinleave" ) then
			return true
		end
		if IsValid(MODULE.ChatBox) then 
			MODULE.ChatBox:HandleMessage(player.GetByID(index), text, isTeam, isDead)
		end
	end )

	local oldAddText = chat.AddText
	function chat.AddText(...)
		local args = {...}
		local mStr = ""

		for _, v in ipairs(args) do
			if IsColor(v) then
				mStr = mStr .. string.format("<color=%d,%d,%d>", v.r, v.g, v.b)
			elseif isstring(v) then
				mStr = mStr .. v
			elseif IsValid(v) and v:IsPlayer() then
				mStr = mStr .. v:Nick()
			end
		end

		mStr = mStr .. "</color>"

		if IsValid(MODULE.ChatBox) then
			MODULE.ChatBox:HandleMessage(nil, mStr, false, false)
		end

		oldAddText(...)
	end
end

function MODULE:ChatTextHandler(ply, text, isTeam, isDead)
	if IsValid(MODULE.ChatBox) then 
		MODULE.ChatBox:HandleMessage(ply, text, isTeam, isDead)
		return true
	end
end