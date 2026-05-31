-- ============================================================================
-- 1. РАСШИРЕНИЕ КОНФИГУРАЦИИ (BW.Config)
-- ============================================================================
BW = BW or {}
BW.Config = BW.Config or {}

BW.Config.Colors = BW.Config.Colors or {
    White       = Color(255, 255, 255),
    Gray        = Color(150, 150, 150),
    LightGray   = Color(200, 200, 200),
    DarkGray    = Color(50, 50, 50),
    DarkGray30  = Color(30, 30, 30),
    DarkGray35  = Color(35, 35, 35),
    DarkGray45  = Color(45, 45, 45),
    Red         = Color(220, 50, 50),
    Green       = Color(50, 200, 50),
    Cyan        = Color(50, 200, 200),
    Gold        = Color(255, 215, 0),
    Info        = Color(60, 120, 200)
}

BW.Config.Teams = BW.Config.Teams or {
    MaxMembers      = 5,                
    MinNameLen      = 3,                
    MaxNameLen      = 16,               
    StartIndex      = 20,               
    DefaultName     = "Без команды",
    DefaultColor    = Color(120, 120, 120),
    
    Sounds = {
        Click   = "buttons/button14.wav",
        Success = "buttons/button6.wav",
        Error   = "buttons/button10.wav",
    }
}

local cfg = BW.Config.Teams
TEAM_NONE_INDEX = TEAM_NONE_INDEX or 0

hook.Add("Initialize", "BW_Teams_InitDefault", function()
    team.SetUp(TEAM_NONE_INDEX, cfg.DefaultName, cfg.DefaultColor, false)
end)

-- ============================================================================
-- 2. СЕРВЕРНАЯ ЧАСТЬ (Логика, Валидация, Менеджмент)
-- ============================================================================
if SERVER then
    util.AddNetworkString("BW_Teams_Create")
    util.AddNetworkString("BW_Teams_Join")
    util.AddNetworkString("BW_Teams_Leave")
    util.AddNetworkString("BW_Teams_Disband")
    util.AddNetworkString("BW_Teams_Kick")
    util.AddNetworkString("BW_Teams_Sync")
    util.AddNetworkString("BW_Teams_Register")

    BW.Teams = BW.Teams or {}
    BW.Teams.List = BW.Teams.List or {} 

    function BW.Teams.GetAvailableIndex()
        local idx = cfg.StartIndex
        while BW.Teams.List[idx] do idx = idx + 1 end
        return idx
    end

    function BW.Teams.Sync(target)
        net.Start("BW_Teams_Sync")
            net.WriteUInt(table.Count(BW.Teams.List), 8)
            for idx, tData in pairs(BW.Teams.List) do
                net.WriteUInt(idx, 8)
                net.WriteString(tData.name)
                net.WriteColor(tData.color)
                net.WriteBool(tData.password ~= nil)
                net.WriteEntity(tData.owner)
                
                local mems = {}
                for p, _ in pairs(tData.members) do
                    if IsValid(p) then table.insert(mems, p) end
                end
                
                net.WriteUInt(#mems, 8)
                for _, p in ipairs(mems) do net.WriteEntity(p) end
            end
        if target then net.Send(target) else net.Broadcast() end
    end

    function BW.Teams.LeavePlayer(ply)
        local curTeam = ply:Team()
        if curTeam == TEAM_NONE_INDEX or not BW.Teams.List[curTeam] then return end

        local tData = BW.Teams.List[curTeam]
        local teamName = tData.name
        
        tData.members[ply] = nil
        ply:SetTeam(TEAM_NONE_INDEX)

        local count = 0
        for p, _ in pairs(tData.members) do
            if IsValid(p) then count = count + 1 end
        end

        if count == 0 then
            BW.Teams.List[curTeam] = nil
        else
            if tData.owner == ply then
                local nextOwner = nil
                for p, _ in pairs(tData.members) do
                    if IsValid(p) then
                        nextOwner = p
                        break
                    end
                end
                tData.owner = nextOwner
                if IsValid(nextOwner) then
                    nextOwner:Notify(NOTIFY_INFO, "Вы стали новым лидером банды '" .. teamName .. "'!", 5)
                end
            end
        end

        ply:Notify(NOTIFY_INFO, "Вы покинули банду.", 3)
        BW.Teams.Sync()
    end

    hook.Add("PlayerInitialSpawn", "BW_Teams_InitialSpawn", function(ply)
        ply:SetTeam(TEAM_NONE_INDEX)
        timer.Simple(1, function()
            if IsValid(ply) then 
                ply:SetTeam(TEAM_NONE_INDEX) 
                BW.Teams.Sync(ply) 
            end
        end)
    end)

    hook.Add("PlayerDisconnected", "BW_Teams_Disconnect", function(ply)
        BW.Teams.LeavePlayer(ply)
    end)

    net.Receive("BW_Teams_Create", function(len, ply)
        if not IsValid(ply) then return end
        
        local rawName = net.ReadString()
        local color = net.ReadColor()
        local password = string.Trim(net.ReadString())

        local name = string.Trim(string.gsub(rawName, "[\r\n]", "")) 
        local nameLen = utf8.len(name) or 0

        if nameLen < cfg.MinNameLen then 
            ply:Notify(NOTIFY_ERROR, "Название слишком короткое!", 4) return 
        end
        if nameLen > cfg.MaxNameLen then 
            ply:Notify(NOTIFY_ERROR, "Название слишком длинное!", 4) return 
        end
        
        if ply:Team() ~= TEAM_NONE_INDEX then BW.Teams.LeavePlayer(ply) end

        local idx = BW.Teams.GetAvailableIndex()
        BW.Teams.List[idx] = {
            name = name,
            color = color,
            password = (password ~= "") and password or nil,
            owner = ply,
            members = { [ply] = true }
        }

        team.SetUp(idx, name, color, true)
        ply:SetTeam(idx)

        net.Start("BW_Teams_Register")
            net.WriteUInt(idx, 8)
            net.WriteString(name)
            net.WriteColor(color)
        net.Broadcast()

        ply:Notify(NOTIFY_SUCCESS, "Банда '" .. name .. "' успешно создана!", 4)
        BW.Teams.Sync()
    end)

    net.Receive("BW_Teams_Join", function(len, ply)
        if not IsValid(ply) then return end
        local idx = net.ReadUInt(8)
        local pass = net.ReadString()

        local tData = BW.Teams.List[idx]
        if not tData then 
            ply:Notify(NOTIFY_ERROR, "Эта банда больше не существует!", 4) return 
        end

        local count = 0
        for p, _ in pairs(tData.members) do if IsValid(p) then count = count + 1 end end
        if count >= cfg.MaxMembers then 
            ply:Notify(NOTIFY_WARNING, "В банде нет свободных мест!", 4) return 
        end

        if tData.password and tData.password ~= pass then 
            ply:Notify(NOTIFY_ERROR, "Неверный пароль!", 4) return 
        end

        if ply:Team() ~= TEAM_NONE_INDEX then BW.Teams.LeavePlayer(ply) end

        tData.members[ply] = true
        ply:SetTeam(idx)
        ply:Notify(NOTIFY_SUCCESS, "Вы вступили в банду '" .. tData.name .. "'!", 4)
        BW.Teams.Sync()
    end)

    net.Receive("BW_Teams_Leave", function(len, ply)
        if IsValid(ply) then BW.Teams.LeavePlayer(ply) end
    end)

    net.Receive("BW_Teams_Disband", function(len, ply)
        if not IsValid(ply) then return end
        local curTeam = ply:Team()
        local tData = BW.Teams.List[curTeam]
        
        if tData and tData.owner == ply then
            for p, _ in pairs(tData.members) do
                if IsValid(p) then
                    p:SetTeam(TEAM_NONE_INDEX)
                    if p ~= ply then
                        p:Notify(NOTIFY_WARNING, "Ваша банда была распущена лидером.", 5)
                    end
                end
            end
            BW.Teams.List[curTeam] = nil
            ply:Notify(NOTIFY_INFO, "Вы распустили банду.", 4)
            BW.Teams.Sync()
        end
    end)

    net.Receive("BW_Teams_Kick", function(len, ply)
        if not IsValid(ply) then return end
        local target = net.ReadEntity()
        if not IsValid(target) or ply == target then return end

        local curTeam = ply:Team()
        local tData = BW.Teams.List[curTeam]

        if tData and tData.owner == ply and tData.members[target] then
            tData.members[target] = nil
            target:SetTeam(TEAM_NONE_INDEX)
            target:Notify(NOTIFY_ERROR, "Вас выгнали из банды!", 5)
            ply:Notify(NOTIFY_SUCCESS, "Игрок " .. target:Nick() .. " выгнан.", 4)
            BW.Teams.Sync()
        end
    end)
end

-- ============================================================================
-- 3. КЛИЕНТСКАЯ ЧАСТЬ (UI)
-- ============================================================================
-- ============================================================================
-- 3. КЛИЕНТСКАЯ ЧАСТЬ (UI)
-- ============================================================================
if CLIENT then
    BW.Teams = BW.Teams or {}
    BW.Teams.List = BW.Teams.List or {}

    net.Receive("BW_Teams_Register", function()
        local idx = net.ReadUInt(8)
        local name = net.ReadString()
        local color = net.ReadColor()
        team.SetUp(idx, name, color, true)
    end)

    net.Receive("BW_Teams_Sync", function()
        local count = net.ReadUInt(8)
        local temp = {}
        for i = 1, count do
            local idx = net.ReadUInt(8)
            local name = net.ReadString()
            local color = net.ReadColor()
            local hasPass = net.ReadBool()
            local owner = net.ReadEntity()
            
            local memCount = net.ReadUInt(8)
            local members = {}
            for m = 1, memCount do
                table.insert(members, net.ReadEntity())
            end

            if team.GetName(idx) == "" then team.SetUp(idx, name, color, true) end

            temp[idx] = {
                name = name,
                color = color,
                hasPassword = hasPass,
                owner = owner,
                members = members
            }
        end
        BW.Teams.List = temp
        
        if IsValid(BW.Teams.Menu) then
            BW.Teams.Menu:Refresh()
        end
    end)

    hook.Add("PlayerBindPress", "BW_Teams_F4Bind", function(ply, bind, pressed)
        if string.find(bind, "gm_showspare2") and pressed then
            surface.PlaySound(cfg.Sounds.Click)
            BW.Teams.OpenMenu()
            return true
        end
    end)

    local icoGroup  = Material("icon16/group.png")
    local icoAdd    = Material("icon16/group_add.png")
    local icoLock   = Material("icon16/lock.png")
    local icoUser   = Material("icon16/user.png")
    local icoCrown  = Material("icon16/shield.png")

    function BW.Teams.OpenMenu()
        if IsValid(BW.Teams.Menu) then BW.Teams.Menu:Remove() end

        local C = BW.Config.Colors

        local frame = vgui.Create("DFrame")
        frame:SetSize(600, 650)
        frame:Center()
        frame:SetTitle("")
        frame:MakePopup()
        frame:SetDraggable(true)
        frame:ShowCloseButton(false)
        
        frame.Paint = function(s, w, h)
            draw.RoundedBox(8, 0, 0, w, h, C.DarkGray45)
            draw.RoundedBoxEx(8, 0, 0, w, 45, C.DarkGray35, true, true, false, false)
            
            surface.SetMaterial(icoGroup)
            surface.SetDrawColor(C.White)
            surface.DrawTexturedRect(15, 14, 16, 16)
            
            draw.SimpleText("Организация Банд", "Inter20", 42, 12, C.White, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            
            surface.SetDrawColor(C.DarkGray)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end

        local close = vgui.Create("DButton", frame)
        close:SetSize(45, 45)
        close:SetPos(frame:GetWide() - 45, 0)
        close:SetText("")
        close.Paint = function(s, w, h)
            local col = s:IsHovered() and C.Red or C.LightGray
            draw.SimpleText("✕", "Inter20", w/2, h/2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        close.DoClick = function() 
            surface.PlaySound(cfg.Sounds.Click)
            frame:Remove() 
        end

        local navBar = vgui.Create("DPanel", frame)
        navBar:SetPos(0, 45)
        navBar:SetSize(frame:GetWide(), 50)
        navBar.Paint = function(s, w, h)
            draw.RoundedBox(0, 0, 0, w, h, C.DarkGray30)
            surface.SetDrawColor(C.DarkGray)
            surface.DrawLine(0, h-1, w, h-1)
        end

        local content = vgui.Create("DPanel", frame)
        content:SetPos(0, 95)
        content:SetSize(frame:GetWide(), frame:GetTall() - 95)
        content.Paint = function() end

        local currentTab = nil
        local activeTabID = "list"

        local function setTab(tabID)
            if IsValid(currentTab) then currentTab:Remove() end
            activeTabID = tabID
            
            currentTab = vgui.Create("DPanel", content)
            currentTab:Dock(FILL)
            currentTab.Paint = function() end

            if tabID == "list" then
                local scroll = vgui.Create("DScrollPanel", currentTab)
                scroll:Dock(FILL)
                scroll:DockPadding(15, 15, 15, 15)

                local sbar = scroll:GetVBar()
                sbar:SetWide(8)
                sbar:SetHideButtons(true)
                sbar.Paint = function() end
                sbar.btnGrip.Paint = function(s, w, h) draw.RoundedBox(4, 0, 0, w, h, C.Gray) end

                local function CreateAccordion(idx, tData, isNoneTeam)
                    local item = scroll:Add("DPanel")
                    item:Dock(TOP)
                    item:SetTall(60)
                    item:DockMargin(0, 0, 0, 10)
                    item.isExpanded = false
                    
                    local headerBtn = vgui.Create("DButton", item)
                    headerBtn:Dock(TOP)
                    headerBtn:SetTall(60)
                    headerBtn:SetText("")
                    
                    headerBtn.Paint = function(s, w, h)
                        local bgCol = s:IsHovered() and Color(40, 40, 40) or C.DarkGray35
                        draw.RoundedBox(6, 0, 0, w, h, bgCol)
                        draw.RoundedBoxEx(6, 0, 0, 6, h, tData.color, true, false, true, false)
                        
                        draw.SimpleText(tData.name, "Inter20", 20, 12, C.White, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                        
                        local subText = isNoneTeam and "Свободные игроки" or ("Лидер: " .. (IsValid(tData.owner) and tData.owner:Nick() or "Отсутствует"))
                        draw.SimpleText(subText, "Inter16", 20, 36, C.LightGray, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                        
                        local memText = isNoneTeam and (#tData.members .. " чел.") or (#tData.members .. " / " .. cfg.MaxMembers)
                        draw.SimpleText(memText, "Inter18", w - 40, h/2, C.LightGray, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

                        if tData.hasPassword and not isNoneTeam then
                            surface.SetMaterial(icoLock)
                            surface.SetDrawColor(C.LightGray)
                            surface.DrawTexturedRect(w - 25, h/2 - 8, 16, 16)
                        end
                    end

                    -- ИСПРАВЛЕНИЕ: Используем только Dock систему
                    local body = vgui.Create("DPanel", item)
                    body:Dock(FILL)
                    body:DockPadding(10, 10, 10, 10)
                    body:SetVisible(false)
                    body.Paint = function(s, w, h)
                        draw.RoundedBox(6, 0, 0, w, h, C.DarkGray30)
                    end

                    headerBtn.DoClick = function()
                        surface.PlaySound(cfg.Sounds.Click)
                        item.isExpanded = not item.isExpanded
                        body:SetVisible(item.isExpanded)
                        
                        local calcHeight = 60 + (#tData.members * 45) + 20
                        
                        if not isNoneTeam then
                            calcHeight = calcHeight + 50
                        end
                        
                        if item.isExpanded then
                            item:SetTall(calcHeight)
                        else
                            item:SetTall(60)
                        end
                        
                        body:InvalidateLayout(true)
                        scroll:InvalidateLayout()
                    end

                    -- ИСПРАВЛЕНИЕ: Используем Dock для всех строк игроков
                    for _, ply in ipairs(tData.members) do
                        if not IsValid(ply) then continue end
                        
                        local pRow = vgui.Create("DPanel", body)
                        pRow:Dock(TOP)
                        pRow:SetTall(35)
                        pRow:DockMargin(0, 0, 0, 5)
                        pRow.Paint = function(s, w, h)
                            draw.RoundedBox(4, 0, 0, w, h, C.DarkGray35)
                            
                            local isOwner = (tData.owner == ply)
                            local iconMat = isOwner and icoCrown or icoUser
                            local iconCol = isOwner and C.Gold or C.LightGray
                            
                            surface.SetMaterial(iconMat)
                            surface.SetDrawColor(iconCol)
                            surface.DrawTexturedRect(10, h / 2 - 8, 16, 16)
                            draw.SimpleText(ply:Nick(), "Inter18", 35, h / 2, C.White, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                        end

                        if not isNoneTeam and LocalPlayer() == tData.owner and ply ~= LocalPlayer() then
                            local kickBtn = vgui.Create("DButton", pRow)
                            kickBtn:Dock(RIGHT)
                            kickBtn:SetWide(80)
                            kickBtn:DockMargin(0, 5, 5, 5)
                            kickBtn:SetText("Выгнать")
                            kickBtn:SetFont("Inter16")
                            kickBtn:SetTextColor(C.White)
                            kickBtn.Paint = function(s, w, h)
                                draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and C.Red or Color(150, 50, 50))
                            end
                            kickBtn.DoClick = function()
                                Derma_Query("Выгнать игрока " .. ply:Nick() .. "?", "Подтверждение",
                                    "Да", function()
                                        net.Start("BW_Teams_Kick")
                                        net.WriteEntity(ply)
                                        net.SendToServer()
                                    end,
                                    "Нет", function() end
                                )
                            end
                        end
                    end

                    if isNoneTeam then return end

                    -- ИСПРАВЛЕНИЕ: Используем Dock для actionBar
                    local actionBar = vgui.Create("DPanel", body)
                    actionBar:Dock(TOP)
                    actionBar:SetTall(40)
                    actionBar:DockMargin(0, 10, 0, 0)
                    actionBar.Paint = function() end

                    local myTeam = LocalPlayer():Team()
                    
                    if myTeam == idx then
                        if LocalPlayer() == tData.owner then
                            local btnDisband = vgui.Create("DButton", actionBar)
                            btnDisband:Dock(RIGHT)
                            btnDisband:SetWide(110)
                            btnDisband:DockMargin(0, 0, 0, 0)
                            btnDisband:SetText("Распустить")
                            btnDisband:SetFont("Inter16")
                            btnDisband:SetTextColor(C.White)
                            btnDisband.Paint = function(s, w, h) draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and C.Red or Color(150,50,50)) end
                            btnDisband.DoClick = function()
                                Derma_Query("Точно распустить банду?", "Внимание", "Да", function()
                                    net.Start("BW_Teams_Disband") net.SendToServer()
                                end, "Нет", function() end)
                            end

                            local btnLeave = vgui.Create("DButton", actionBar)
                            btnLeave:Dock(RIGHT)
                            btnLeave:SetWide(110)
                            btnLeave:DockMargin(0, 0, 10, 0)
                            btnLeave:SetText("Выйти")
                            btnLeave:SetFont("Inter16")
                            btnLeave:SetTextColor(C.White)
                            btnLeave.Paint = function(s, w, h) draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and C.Red or Color(150,50,50)) end
                            btnLeave.DoClick = function()
                                Derma_Query("Выйти из банды? Лидерство будет передано.", "Подтверждение",
                                    "Да", function()
                                        net.Start("BW_Teams_Leave") net.SendToServer()
                                    end,
                                    "Нет", function() end
                                )
                            end
                        else
                            local btnLeave = vgui.Create("DButton", actionBar)
                            btnLeave:Dock(RIGHT)
                            btnLeave:SetWide(110)
                            btnLeave:SetText("Выйти")
                            btnLeave:SetFont("Inter16")
                            btnLeave:SetTextColor(C.White)
                            btnLeave.Paint = function(s, w, h) draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and C.Red or Color(150,50,50)) end
                            btnLeave.DoClick = function()
                                Derma_Query("Выйти из банды?", "Подтверждение",
                                    "Да", function()
                                        net.Start("BW_Teams_Leave") net.SendToServer()
                                    end,
                                    "Нет", function() end
                                )
                            end
                        end
                    else
                        local btnJoin = vgui.Create("DButton", actionBar)
                        btnJoin:Dock(RIGHT)
                        btnJoin:SetWide(110)
                        btnJoin:SetText("Войти")
                        btnJoin:SetFont("Inter16")
                        btnJoin:SetTextColor(C.White)
                        btnJoin.Paint = function(s, w, h) draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and C.Green or Color(45,120,45)) end
                        btnJoin.DoClick = function()
                            if tData.hasPassword then
                                Derma_StringRequest("Вход", "Пароль:", "", function(text)
                                    net.Start("BW_Teams_Join") net.WriteUInt(idx, 8) net.WriteString(text) net.SendToServer()
                                end)
                            else
                                net.Start("BW_Teams_Join") net.WriteUInt(idx, 8) net.WriteString("") net.SendToServer()
                            end
                        end
                    end
                end

                local nonePlayers = {}
                for _, p in ipairs(player.GetAll()) do
                    if p:Team() == TEAM_NONE_INDEX then table.insert(nonePlayers, p) end
                end
                
                CreateAccordion(TEAM_NONE_INDEX, {
                    name = cfg.DefaultName, color = cfg.DefaultColor, 
                    members = nonePlayers, hasPassword = false
                }, true)

                for idx, tData in pairs(BW.Teams.List) do
                    CreateAccordion(idx, tData, false)
                end

            elseif tabID == "create" then
                if LocalPlayer():Team() ~= TEAM_NONE_INDEX then
                    local warn = vgui.Create("DLabel", currentTab)
                    warn:SetText("Вы уже состоите в команде!\nСначала покиньте её, чтобы создать свою.")
                    warn:SetFont("Inter20")
                    warn:SetTextColor(C.Gray)
                    warn:SetContentAlignment(5)
                    warn:Dock(FILL)
                    return
                end

                local scroll = vgui.Create("DScrollPanel", currentTab)
                scroll:Dock(FILL)
                scroll:DockPadding(40, 20, 40, 20)

                local function AddField(labelTxt)
                    local lbl = vgui.Create("DLabel", scroll)
                    lbl:SetText(labelTxt)
                    lbl:SetFont("Inter16")
                    lbl:SetTextColor(C.LightGray)
                    lbl:Dock(TOP)
                    lbl:DockMargin(0, 10, 0, 5)
                    return lbl
                end

                AddField("Название банды:")
                local entryName = vgui.Create("DTextEntry", scroll)
                entryName:Dock(TOP)
                entryName:SetTall(40)
                entryName:SetFont("Inter18")
                entryName:SetPaintBackground(false)
                entryName.Paint = function(s, w, h)
                    draw.RoundedBox(4, 0, 0, w, h, C.DarkGray30)
                    if s:IsEditing() then surface.SetDrawColor(C.Cyan) surface.DrawOutlinedRect(0, 0, w, h, 1) end
                    s:DrawTextEntryText(C.White, C.Info, C.White)
                end

                AddField("Пароль (Опционально):")
                local entryPass = vgui.Create("DTextEntry", scroll)
                entryPass:Dock(TOP)
                entryPass:SetTall(40)
                entryPass:SetFont("Inter18")
                entryPass:SetPlaceholderText("Для открытого входа оставьте пустым...")
                entryPass:SetPaintBackground(false)
                entryPass.Paint = function(s, w, h)
                    draw.RoundedBox(4, 0, 0, w, h, C.DarkGray30)
                    if s:IsEditing() then surface.SetDrawColor(C.Cyan) surface.DrawOutlinedRect(0, 0, w, h, 1) end
                    s:DrawTextEntryText(C.White, C.Info, C.White)
                end

                AddField("Цвет банды:")
                local mixer = vgui.Create("DColorMixer", scroll)
                mixer:Dock(TOP)
                mixer:SetTall(180)
                mixer:DockMargin(0, 0, 0, 30)
                mixer:SetPalette(true)
                mixer:SetAlphaBar(false)
                mixer:SetWangs(false)
                mixer:SetColor(C.Cyan)

                local btn = vgui.Create("DButton", scroll)
                btn:Dock(TOP)
                btn:SetTall(45)
                btn:SetText("Создать банду")
                btn:SetFont("Inter20")
                btn:SetTextColor(C.White)
                btn.Paint = function(s, w, h)
                    draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and C.Info or Color(45, 90, 140))
                end
                btn.DoClick = function()
                    local tName = string.Trim(entryName:GetValue() or "")
                    local nameLen = utf8.len(tName) or 0
                    
                    if nameLen < cfg.MinNameLen then
                        surface.PlaySound(cfg.Sounds.Error)
                        LocalPlayer():Notify(NOTIFY_ERROR, "Название слишком короткое! Минимум " .. cfg.MinNameLen .. " символов.", 4)
                        return
                    elseif nameLen > cfg.MaxNameLen then
                        surface.PlaySound(cfg.Sounds.Error)
                        LocalPlayer():Notify(NOTIFY_ERROR, "Название слишком длинное! Максимум " .. cfg.MaxNameLen .. " символов.", 4)
                        return
                    end
                    
                    net.Start("BW_Teams_Create")
                        net.WriteString(tName)
                        net.WriteColor(mixer:GetColor())
                        net.WriteString(entryPass:GetValue() or "")
                    net.SendToServer()
                end
            end
        end

        local function CreateTabBtn(id, title, width, mat)
            local btn = vgui.Create("DButton", navBar)
            btn:Dock(LEFT)
            btn:SetWide(width)
            btn:SetText("")
            btn.Paint = function(s, w, h)
                local isActive = (activeTabID == id)
                if isActive then
                    draw.RoundedBox(0, 0, h-3, w, 3, C.Cyan)
                end
                
                local col = isActive and C.Cyan or (s:IsHovered() and C.White or C.LightGray)
                surface.SetMaterial(mat)
                surface.SetDrawColor(col)
                surface.DrawTexturedRect(w/2 - 50, h/2 - 8, 16, 16)
                draw.SimpleText(title, "Inter18", w/2 - 25, h/2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            btn.DoClick = function() surface.PlaySound(cfg.Sounds.Click) setTab(id) end
        end

        CreateTabBtn("list", "Все банды", frame:GetWide() / 2, icoGroup)
        CreateTabBtn("create", "Создание", frame:GetWide() / 2, icoAdd)

        setTab("list")

        function frame:Refresh()
            setTab(activeTabID)
        end
        BW.Teams.Menu = frame
    end
end