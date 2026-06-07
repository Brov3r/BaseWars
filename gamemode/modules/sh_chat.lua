local MODULE = MODULE or {}
MODULE.Name = "ChatBox"
MODULE.Author = "Brov3r"
MODULE.Require = { }

if SERVER then
    util.AddNetworkString("ChatBox_NewMessage")
    
    function MODULE:HandlePlayerSay(ply, text, teamChat)
        if not IsValid(ply) then return "" end
        local group = ply:GetUserGroup()
        local groupData = BW.Config.PlayerGroups[group] or BW.Config.PlayerGroups["user"]
        
        net.Start("ChatBox_NewMessage")
            net.WriteEntity(ply)
            net.WriteString(text)
            net.WriteString(group)
            net.WriteString(groupData.PrefixText or "")
            net.WriteString(groupData.PrefixIcon or "")
            net.WriteBool(teamChat)
            
        if teamChat then
            local filter = {}
            local pTeam = ply:Team()
            for _, p in ipairs(player.GetAll()) do
                if p:Team() == pTeam then
                    table.insert(filter, p)
                end
            end
            net.Send(filter)
        else
            net.Broadcast()
        end

        local logTag = teamChat and "(TEAM) " or ""
        Log(logTag .. "Player ", BW.Config.Colors.Cyan, ply:Nick(), BW.Config.Colors.White, " say: ", BW.Config.Colors.Cyan, text)
        return ""
    end

    hook.Add("PlayerSay", "ChatBox_Handle", function(ply, text, teamChat)
        return MODULE:HandlePlayerSay(ply, text, teamChat)
    end)
end

if CLIENT then
    local ChatBoxUI = nil
    
    hook.Add("InitPostEntity", "ChatBox_Init", function()
		if not IsValid(ChatBoxUI) then 
			ChatBoxUI = vgui.Create("ChatBox") 
		end
    end)
    
    net.Receive("ChatBox_NewMessage", function()
        if not IsValid(ChatBoxUI) then return end
        
        local ply = net.ReadEntity()
        local text = net.ReadString()
        local group = net.ReadString()
        local prefix = net.ReadString()
        local icon = net.ReadString()
        local isTeam = net.ReadBool()
        
        local args = {}
        
        if isTeam then
            table.insert(args, Color(46, 204, 113))
            table.insert(args, string.format("(%s) ", Translate("Chat.TeamText", "TEAM")))
        end
        
        if IsValid(ply) then
            table.insert(args, ply)
            table.insert(args, color_white)
            table.insert(args, ": " .. text)
            
            local groupData = BW.Config.PlayerGroups[group] or BW.Config.PlayerGroups["user"]
            ChatBoxUI:AddMessage(icon ~= "" and icon or "icon16/user.png", prefix, groupData.PrefixColor, args)
        end
    end)
    
    local oldAddText = chat.AddText
    function chat.AddText(...)
        local args = {...}
        if IsValid(ChatBoxUI) then
            ChatBoxUI:AddMessage("icon16/information.png", "", color_white, args)
        end
        oldAddText(...)
    end

    hook.Add("StartChat", "ChatBox_Intercept", function(isTeamChat)
        if not IsValid(ChatBoxUI) then ChatBoxUI = vgui.Create("ChatBox") end
        ChatBoxUI:OpenChat(isTeamChat)
        return true
    end)
    
    hook.Add("OnScreenSizeChanged", "ChatBox_Repos", function()
        if IsValid(ChatBoxUI) then ChatBoxUI:SetPos(10, ScrH() - 420) end
    end)
    
    hook.Add("HUDShouldDraw", "ChatBox_HideDefault", function(name)
        if name == "CHudChat" then return false end
    end)
	
	hook.Add( "OnPauseMenuShow", "DisableMenu", function()
		if IsValid(ChatBoxUI) and ChatBoxUI.IsOpen then 
			ChatBoxUI:CloseChat() 
			return false
		end
		return true
	end )

    hook.Add("ChatText", "ChatBox_CaptureSystem", function(index, name, text, type)
        if type == "chat" then return false end 
        
        if IsValid(ChatBoxUI) then
            ChatBoxUI:AddMessage("icon16/information.png", "", color_white, {color_white, text})
        end
        return true
    end)
end