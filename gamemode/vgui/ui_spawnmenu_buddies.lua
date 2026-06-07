local PANEL = {}

function PANEL:Init()
    self:Dock(FILL)
    
    self.Scroll = vgui.Create("DScrollPanel", self)
    self.Scroll:Dock(FILL)
    self.Scroll:DockMargin(5, 5, 5, 5)
end

function PANEL:SetModule(mod)
    self.MODULE = mod
    self:Refresh()
end

function PANEL:Refresh()
    if not self.Scroll or not IsValid(self.Scroll) then return end
    self.Scroll:Clear()

    local mod = self.MODULE
    if not mod or not mod.LocalBuddies then return end

    local players = player.GetAll()
    if #players <= 1 then
        local lbl = vgui.Create("DLabel", self.Scroll)
        lbl:SetText(Translate("Buddies.NoPlayers", "No other players online!"))
        lbl:SetFont("Inter16Thin")
        lbl:SetTextColor(BW.Config.Colors.White)
        lbl:Dock(TOP)
        lbl:DockMargin(10, 10, 10, 0)
        lbl:SizeToContents()
        return
    end

    for _, ply in ipairs(players) do
        if not IsValid(ply) or ply == LocalPlayer() then continue end

        local row = vgui.Create("DPanel", self.Scroll)
        row:Dock(TOP)
        row:SetHeight(40)
        row:DockMargin(0, 0, 0, 5)
        row.Paint = function(s, w, h)
            draw.RoundedBox(4, 0, 0, w, h, BW.Config.Colors.DarkGray)
        end

        local avatar = vgui.Create("AvatarImage", row)
        avatar:Dock(LEFT)
        avatar:SetSize(32, 32)
        avatar:DockMargin(4, 4, 4, 4)
        avatar:SetPlayer(ply, 32)

        local name = vgui.Create("DLabel", row)
        name:SetText(BW.Utils.TruncateText(ply:Name(), "Inter16Thin", 100))
        name:SetFont("Inter16Thin")
        name:SetTextColor(BW.Config.Colors.White)
        name:Dock(LEFT)
        name:DockMargin(10, 0, 0, 0)
        name:SizeToContents()
        name:SetContentAlignment(4)

        local btn = vgui.Create("DButton", row)
        btn:Dock(RIGHT)
        btn:SetWidth(80)
        btn:DockMargin(4, 4, 4, 4)
        
        local isBuddy = mod.LocalBuddies[ply:SteamID64()] or false
        btn:SetText(isBuddy and Translate("Buddies.RemoveFriend", "Remove") or Translate("Buddies.AddFriend", "Trust"))
        btn:SetFont("Inter16Thin")
        btn:SetTextColor(BW.Config.Colors.White)

        btn.Paint = function(s, w, h)
            local col = isBuddy and BW.Config.Colors.LightRed or BW.Config.Colors.Green
            if s:IsHovered() then
                col = Color(math.min(col.r + 20, 255), math.min(col.g + 20, 255), math.min(col.b + 20, 255))
            end
            draw.RoundedBox(4, 0, 0, w, h, col)
        end

        btn.DoClick = function()
            net.Start("BW_PP_ToggleBuddy")
            net.WriteString(ply:SteamID64())
            net.SendToServer()
        end
    end
end

vgui.Register("BW_SpawnMenu_Buddies", PANEL, "DPanel")