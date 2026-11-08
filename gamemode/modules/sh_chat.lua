local MODULE = MODULE

MODULE.Name = "Chat"
MODULE.Author = "Brov3r"
MODULE.Require = {}

MODULE.ChatBox = nil

function MODULE:ParseStringToChatArgs(str)
    local args = {}
    local lastPos = 1

    for hex, pos in string.gmatch(str, "<#(%x%x%x%x%x%x)>()") do
        if pos - 9 > lastPos then
            local textSegment = string.sub(str, lastPos, pos - 10)
            if textSegment ~= "" then
                table.insert(args, textSegment)
            end
        end

        local r = tonumber(string.sub(hex, 1, 2), 16)
        local g = tonumber(string.sub(hex, 3, 4), 16)
        local b = tonumber(string.sub(hex, 5, 6), 16)
        
        -- Validate color values
        if r and g and b then
            r = math.Clamp(r or 0, 0, 255)
            g = math.Clamp(g or 0, 0, 255)
            b = math.Clamp(b or 0, 0, 255)
            table.insert(args, Color(r, g, b))
        end
        
        lastPos = pos
    end

    if lastPos <= #str then
        local textSegment = string.sub(str, lastPos)
        if textSegment ~= "" then
            table.insert(args, textSegment)
        end
    end

    return args
end

function MODULE:Init()
    if SERVER then
        util.AddNetworkString("BW_CustomChat_Send")
        util.AddNetworkString("BW_CustomChat_Message")

        net.Receive("BW_CustomChat_Send", function(len, ply)
            if not BW.Utils.AllowRequest(ply, "chat", 0.75, 3, len, BW.Config.Chat.MaxMessageLenght + 4) then return end
            if not IsValid(ply) then return end

            local text = net.ReadString()
            local isTeam = net.ReadBool()

            text = string.Trim(text)
            text = text:gsub("[%c]", " ")
            if not utf8.len(text) then return end
            if text == "" then return end
            if string.len(text) > BW.Config.Chat.MaxMessageLenght then
                return
            end

            local result = hook.Run("PlayerSay", ply, text, isTeam)

            if result == false or result == "" then return end
            if isstring(result) then text = result end
            if #text > BW.Config.Chat.MaxMessageLenght or not utf8.len(text) then return end

            local isDead = not ply:Alive()

            net.Start("BW_CustomChat_Message")
                net.WriteEntity(ply)
                net.WriteString(text)
                net.WriteBool(isTeam)
                net.WriteBool(isDead)

            if isTeam then
                local teamPlayers = team.GetPlayers(ply:Team())
                net.Send(teamPlayers)
            else
                net.Broadcast()
            end
        end)

        hook.Add("PlayerCanHearPlayersVoice", "BW_VoiceProximity", function(listener, talker)
            if not IsValid(listener) or not IsValid(talker) then return false, false end
        
            local maxDist = (BW.Config.Chat and BW.Config.Chat.VoiceDistance) or 550
            
            local distSqr = listener:GetPos():DistToSqr(talker:GetPos())

            if distSqr <= (maxDist * maxDist) then
                return true, true 
            end

            return false, false
        end)
        return 
    end

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
        if IsValid(MODULE.ChatBox) then 
            MODULE.ChatBox:ApplyGeometry()
        end
    end)

    hook.Add("OnPauseMenuShow", "DisableMenu", function()
        if IsValid(MODULE.ChatBox) and MODULE.ChatBox.IsOpen then 
            MODULE.ChatBox:CloseChat() 
            return false
        end
        return true
    end)

    hook.Add("ChatText", "hide_joinleave", function(index, name, text, msgType)
        if msgType == "joinleave" then return true end
        
        if IsValid(MODULE.ChatBox) then 
            local ply = (index == 0) and nil or player.GetByID(index)
            MODULE.ChatBox:HandleMessage(ply, text, false, false)
        end
    end)

    net.Receive("BW_CustomChat_Message", function()
        local ply  = net.ReadEntity()
        local text = net.ReadString()
        local isTeam = net.ReadBool()
        local isDead = net.ReadBool()
        text = BW.Utils.EscapeMarkup(text):gsub("‹#(%x%x%x%x%x%x)›", "<#%1>")
        if string.find(text, "<#%x%x%x%x%x%x>") then
            local parsedArgs = MODULE:ParseStringToChatArgs(text)
            local formattedStr = ""
            local hasColor = false

            for _, v in ipairs(parsedArgs) do
                if IsColor(v) then
                    if hasColor then 
                        formattedStr = formattedStr .. "</color>" 
                    end
                    formattedStr = formattedStr .. string.format("<color=%d,%d,%d>", v.r, v.g, v.b)
                    hasColor = true
                elseif isstring(v) then
                    formattedStr = formattedStr .. v
                end
            end

            if hasColor then
                formattedStr = formattedStr .. "</color>"
            end

            text = formattedStr
        end

        if not IsValid(MODULE.ChatBox) then MODULE.ChatBox = vgui.Create("ChatBox") end
        MODULE.ChatBox:HandleMessage(ply, text, isTeam, isDead)
    end)

    self:OverrideAddText()
end

function MODULE:OverrideAddText()
    BW.OriginalChatAddText = BW.OriginalChatAddText or chat.AddText
    local oldAddText = BW.OriginalChatAddText
    function chat.AddText(...)
        local args = {...}
        local processedArgs = {}
        for _, v in ipairs(args) do
            if isstring(v) and string.find(v, "<#%x%x%x%x%x%x>") then
                local parsed = MODULE:ParseStringToChatArgs(v)
                for _, subV in ipairs(parsed) do
                    table.insert(processedArgs, subV)
                end
            else
                table.insert(processedArgs, v)
            end
        end

        local mStr = ""
        local hasColor = false

        for _, v in ipairs(processedArgs) do
            if IsColor(v) then
                if hasColor then 
                    mStr = mStr .. "</color>" 
                end
                mStr = mStr .. string.format("<color=%d,%d,%d>", v.r, v.g, v.b)
                hasColor = true
            elseif isstring(v) then
                mStr = mStr .. v
            elseif IsValid(v) and v:IsPlayer() then
                mStr = mStr .. v:Nick()
            end
        end

        if hasColor then
            mStr = mStr .. "</color>"
        end

        if IsValid(MODULE.ChatBox) then
            MODULE.ChatBox:HandleMessage(nil, mStr, false, false)
        end

        oldAddText(unpack(processedArgs))
    end    
end

function MODULE:ChatTextHandler(ply, text, isTeam, isDead)
    if IsValid(MODULE.ChatBox) then 
        MODULE.ChatBox:HandleMessage(ply, BW.Utils.EscapeMarkup(text), isTeam, isDead)
        return true
    end
end
