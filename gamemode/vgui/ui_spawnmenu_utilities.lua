local PANEL = {}

local ROW_HEIGHT = 30
local HEADER_HEIGHT = 26
local CHECK_WIDTH = 32
local CHECK_SIZE = 18

local PERMISSION_ICONS = {
    all = "icon16/shield.png",
    physgun = "icon16/lightning.png",
    gravgun = "icon16/box.png",
    tool = "icon16/wrench.png",
    use = "icon16/user.png",
}

local function ColumnX(rowWidth, index)
    return rowWidth - (#BW.CPPI.PermissionList * CHECK_WIDTH) - 6 + (index - 1) * CHECK_WIDTH
end

function PANEL:Init()
    if not (BW.Config.CPPI and BW.Config.CPPI.Enabled) then return end

    self.HookID = "BW_CPPI_Access_" .. tostring(self)
    self:Build()

    hook.Add("BW_CPPI_Updated", self.HookID, function()
        if IsValid(self) then self:Build() end
    end)
end

function PANEL:OnRemove()
    if self.HookID then hook.Remove("BW_CPPI_Updated", self.HookID) end
end

function PANEL:Think()
    local count = #player.GetAll()
    if self.LastPlayerCount ~= count then
        self:Build()
    end
end

function PANEL:AddHelp(text, height)
    local label = self:Add("DLabel")
    label:SetTall(height or 40)
    label:DockMargin(4, 2, 4, 4)
    label:SetFont("DermaDefault")
    label:SetWrap(true)
    label:SetTextColor(color_black)
    label:SetText(text)
    return label
end

function PANEL:AddHeaderRow()
    local row = self:Add("DPanel")
    row:SetTall(HEADER_HEIGHT)
    row:DockMargin(4, 2, 4, 0)
    row:SetPaintBackground(false)

    local name = vgui.Create("DLabel", row)
    name:SetFont("DermaDefaultBold")
    name:SetTextColor(color_black)
    name:SetText(Translate("CPPI.Player", "Player"))
    name:SetMouseInputEnabled(false)

    row.Columns = {}
    for _, permission in ipairs(BW.CPPI.PermissionList) do
        local icon = vgui.Create("DImage", row)
        local path = PERMISSION_ICONS[permission.id] or "icon16/help.png"
        icon:SetMaterial(Material(path, "smooth"))
        icon:SetMouseInputEnabled(true)
        icon:SetTooltip(BW.CPPI.GetPermissionName(permission.index))
        row.Columns[permission.index] = icon
    end

    row.PerformLayout = function(self)
        local w = self:GetWide()
        local firstX = ColumnX(w, 1)
        name:SetPos(8, 2)
        name:SetSize(math.max(10, firstX - 12), HEADER_HEIGHT - 4)
        for index, icon in pairs(self.Columns) do
            icon:SetPos(ColumnX(w, index) + math.floor((CHECK_WIDTH - CHECK_SIZE) / 2), math.floor((HEADER_HEIGHT - CHECK_SIZE) / 2))
            icon:SetSize(CHECK_SIZE, CHECK_SIZE)
        end
    end

    return row
end

function PANEL:AddPermissionRow(nick, sid, isGlobal, isBot, isWorld)
    local row = self:Add("DPanel")
    row:SetTall(ROW_HEIGHT)
    row:DockMargin(4, 1, 4, 1)
    row:SetPaintBackground(false)
    row:SetMouseInputEnabled(true)

    local tooltip = sid or nick
    if isBot then
        tooltip = Translate("CPPI.BotHint", "Bots share SteamID 0, so their permissions apply to all bots.")
    elseif isWorld then
        tooltip = Translate("CPPI.WorldHint", "Permissions for map entities (World). Only admins can change them.")
    end
    row:SetTooltip(tooltip)

    local name = vgui.Create("DLabel", row)
    name:SetFont("DermaDefault")
    name:SetTextColor(color_black)
    name:SetText(nick)
    name:SetMouseInputEnabled(false)

    local allGranted = not isGlobal and not isWorld and BW.CPPI.ClientHasPermission(sid, BW.CPPI.PERMISSION_ALL)
    local worldAll = isWorld and BW.CPPI.ClientWorldPermissions[BW.CPPI.PERMISSION_ALL] == true

    row.Checkboxes = {}
    for _, permission in ipairs(BW.CPPI.PermissionList) do
        local checkbox = vgui.Create("DCheckBox", row)
        checkbox:SetWide(CHECK_SIZE)
        checkbox:SetTooltip(BW.CPPI.GetPermissionName(permission.index))

        if isWorld then
            if worldAll and permission.index ~= BW.CPPI.PERMISSION_ALL then
                checkbox:SetValue(true)
                checkbox:SetEnabled(false)
                checkbox:SetTooltip(Translate("CPPI.AllAccessHint", "All access already includes this permission."))
            else
                checkbox:SetValue(BW.CPPI.ClientWorldPermissions[permission.index] == true)
                checkbox.OnChange = function(_, value)
                    if self.Updating then return end
                    BW.CPPI.RequestSetWorldPermission(permission.index, value)
                end
            end
        elseif isGlobal then
            local entry = BW.CPPI.GetClientEntry(permission.index)
            checkbox:SetValue(entry and entry.global == true or false)
            checkbox.OnChange = function(_, value)
                if self.Updating then return end
                BW.CPPI.RequestSetGlobal(permission.index, value)
            end
        elseif allGranted and permission.index ~= BW.CPPI.PERMISSION_ALL then
            checkbox:SetValue(true)
            checkbox:SetEnabled(false)
            checkbox:SetTooltip(Translate("CPPI.AllAccessHint", "All access already includes this permission."))
        else
            checkbox:SetValue(BW.CPPI.ClientHasPermission(sid, permission.index))
            checkbox.OnChange = function()
                if self.Updating then return end
                BW.CPPI.RequestTogglePermission(permission.index, sid)
            end
        end

        row.Checkboxes[permission.index] = checkbox
    end

    row.PerformLayout = function(self)
        local w = self:GetWide()
        local firstX = ColumnX(w, 1)
        name:SetPos(8, 3)
        name:SetSize(math.max(10, firstX - 12), ROW_HEIGHT - 6)
        for index, checkbox in pairs(self.Checkboxes) do
            checkbox:SetPos(ColumnX(w, index) + math.floor((CHECK_WIDTH - CHECK_SIZE) / 2), math.floor((ROW_HEIGHT - CHECK_SIZE) / 2))
            checkbox:SetSize(CHECK_SIZE, CHECK_SIZE)
        end
    end

    row.OnMousePressed = function(_, code)
        if code ~= MOUSE_RIGHT or isGlobal or isWorld then return end
        self:ShowRowMenu(sid, nick)
        return true
    end

    return row
end

function PANEL:ShowRowMenu(sid, nick)
    local menu = DermaMenu()

    menu:AddOption(Translate("CPPI.CopySteamID", "Copy SteamID"), function()
        SetClipboardText(sid)
    end):SetIcon("icon16/page_copy.png")

    menu:AddOption(Translate("CPPI.CopyName", "Copy name"), function()
        SetClipboardText(nick)
    end):SetIcon("icon16/page_copy.png")

    menu:AddSpacer()
    menu:AddOption(Translate("CPPI.RevokeAll", "Revoke all access"), function()
        BW.CPPI.RequestRevokeAll(sid)
    end):SetIcon("icon16/cross.png")

    local localPly = LocalPlayer()
    if IsValid(localPly) and localPly:IsAdmin() then
        local admin, adminOption = menu:AddSubMenu(Translate("CPPI.AdminOptions", "Admin options"))
        if IsValid(adminOption) then adminOption:SetIcon("icon16/shield.png") end

        admin:AddOption(Translate("CPPI.FreezeProps", "Freeze props"), function()
            BW.CPPI.RequestAdminFreezeProps(sid)
        end):SetIcon("icon16/lock.png")

        admin:AddOption(Translate("CPPI.RemoveProps", "Remove builds"), function()
            Derma_Query(
                string.format(Translate("CPPI.ConfirmRemoveProps", "Remove all entities owned by %s?"), nick),
                Translate("CPPI.ConfirmTitle", "Confirmation"),
                Translate("CPPI.Yes", "Yes"),
                function() BW.CPPI.RequestAdminRemoveProps(sid) end,
                Translate("CPPI.No", "No")
            )
        end):SetIcon("icon16/cross.png")
    end

    menu:Open()
end

function PANEL:Build()
    if self.Updating then return end
    self.Updating = true
    self:Clear()
    self.LastPlayerCount = #player.GetAll()

    local localPly = LocalPlayer()
    if not IsValid(localPly) then
        self.Updating = false
        return
    end

    self:AddHelp(Translate("CPPI.Help", "Grant permissions to other players. Use the global row to grant a permission to everyone. Right-click a player for admin actions."), 56)
    self:AddHeaderRow()
    self:AddPermissionRow(Translate("CPPI.GlobalRow", "[GLOBAL]"), nil, true)
    local config = BW.Config.CPPI or {}
    if localPly:IsAdmin() and config.AdminManagePermissions ~= false then
        self:AddPermissionRow(Translate("CPPI.WorldRow", "[MAP]"), nil, false, false, true)
    end

    local players = player.GetAll()
    table.sort(players, function(a, b) return a:Nick() < b:Nick() end)

    local online = {}
    for _, ply in ipairs(players) do
        if ply ~= localPly then
            local sid = ply:SteamID64()
            online[sid] = true
            self:AddPermissionRow(
                ply:IsBot() and (ply:Nick() .. " (BOT)") or ply:Nick(),
                sid,
                false,
                ply:IsBot()
            )
        end
    end

    -- Keep offline recipients manageable: permissions are stored by SteamID64.
    local offline = {}
    for _, permission in ipairs(BW.CPPI.PermissionList) do
        local entry = BW.CPPI.GetClientEntry(permission.index)
        if entry then
            for sid, granted in pairs(entry) do
                if sid ~= "global" and granted and not online[sid] then offline[sid] = true end
            end
        end
    end

    local offlineIDs = table.GetKeys(offline)
    table.sort(offlineIDs)
    for _, sid in ipairs(offlineIDs) do
        self:AddPermissionRow(Translate("CPPI.OfflinePlayer", "Offline player"), sid, false)
    end

    self:AddAdminFooter(localPly)

    self.Updating = false
    self:InvalidateLayout()
end

function PANEL:AddAdminFooter(localPly)
    local config = BW.Config.CPPI or {}
    if not localPly:IsAdmin() or config.AdminManageOwnership == false then return end

    local row = self:Add("DPanel")
    row:SetTall(34)
    row:DockMargin(4, 8, 4, 8)
    row:SetPaintBackground(false)

    local cleanup = vgui.Create("DButton", row)
    cleanup:Dock(FILL)
    cleanup:DockMargin(0, 5, 0, 5)
    cleanup:SetText(Translate("CPPI.CleanupDisconnected", "Clean up disconnected players' props"))
    cleanup.DoClick = function()
        Derma_Query(
            Translate("CPPI.ConfirmCleanupDisconnected", "Remove props owned by players who are no longer connected?"),
            Translate("CPPI.ConfirmTitle", "Confirmation"),
            Translate("CPPI.Yes", "Yes"),
            function() BW.CPPI.RequestAdminCleanupDisconnected() end,
            Translate("CPPI.No", "No")
        )
    end
end

vgui.Register("BW_CPPI_Access", PANEL, "DListLayout")
