local MODULE = MODULE

MODULE.Name = "ULX-BW"
MODULE.Author = "Brov3r"
MODULE.Require = { "database" }

local CATEGORY_NAME = "BaseWars"

function MODULE:Init()
    if not ULib or not ulx then return end
    self:AddCommands()

    if CLIENT then
        self:AddXGUITab()
    end
end

local function formatNum(val)
    if BW and BW.Utils and BW.Utils.NumWithSep then
        return BW.Utils.NumWithSep(val)
    end
    return tostring(val)
end

local function getStat(ply, funcName, default)
    return (ply[funcName] and ply[funcName](ply)) or default
end

local function CreateHorizontalScrollList(parent)
    local container = vgui.Create("DPanel", parent)
    container:SetPaintBackground(false)

    local list = vgui.Create("DListView", container)
    list:SetMultiSelect(false)

    local hScroll = vgui.Create("DSlider", container)
    hScroll:SetLockY(0.5)
    hScroll:SetTrapInside(true)
    hScroll.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 3, w, h - 6, Color(50, 50, 50, 80))
    end
    hScroll.Knob.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(255, 255, 255, 220))
    end

    function hScroll:TranslateValues(x, y)
        container:InvalidateLayout()
        return x, y
    end

    container.PerformLayout = function(self, w, h)
        if not IsValid(list) or not IsValid(hScroll) then return end
        
        local totalWidth = 0
        for _, col in pairs(list.Columns or {}) do
            totalWidth = totalWidth + (col:GetMinWidth() or 100)
        end

        hScroll:SetSize(w, 14)
        hScroll:SetPos(0, h - 14)

        local maxScrollDistance = totalWidth - w
        if maxScrollDistance <= 0 then
            list:SetSize(w, h)
            list:SetPos(0, 0)
            hScroll:SetVisible(false)
        else
            hScroll:SetVisible(true)
            list:SetSize(totalWidth, h - 16)
            local fraction = hScroll:GetSlideX()
            list:SetPos(-fraction * maxScrollDistance, 0)
        end
    end

    return container, list
end


function MODULE:AddXGUITab()
    local function DynamicInit()
        if not xgui then return end

        local currency = (BW and BW.Config and BW.Config.Economy and BW.Config.Economy.Currency) or "$"

        local STAT_COLUMNS = {
            { name = "Player",      minW = 140, get = function(p) return p:Nick() end },
            { name = "SteamID",     minW = 140, get = function(p) return p:SteamID() end },
            { name = "HP",          minW = 60,  get = function(p) return p:Health() end },
            { name = "Armor",       minW = 60,  get = function(p) return p:Armor() end },
            { name = "Group",       minW = 100, get = function(p) return p:GetUserGroup() end },
            { name = "Money",       minW = 100, get = function(p) return currency .. formatNum(getStat(p, "GetMoney", 0)) end },
            { name = "Lvl",         minW = 50,  get = function(p) return getStat(p, "GetLevel", 1) end },
            { name = "XP",          minW = 120, get = function(p) return formatNum(getStat(p, "GetXP", 0)) .. " / " .. formatNum(getStat(p, "GetMaxXP", 0)) end },
            { name = "Bounty",      minW = 100, get = function(p) return currency .. formatNum(getStat(p, "GetBounty", 0)) end },
            { name = "Reputation",  minW = 80,  get = function(p) return formatNum(getStat(p, "GetReputation", 0)) end },
            { name = "K / D",       minW = 80,  get = function(p) return getStat(p, "GetKills", 0) .. " / " .. getStat(p, "GetDeaths", 0) end },
            { name = "PlayTime",    minW = 100, get = function(p) 
                local pt = getStat(p, "GetPlayTime", 0)
                return pt > 0 and string.format("%d h. %d m.", math.floor(pt / 60), pt % 60) or "0 m."
            end },
            { name = "DonateUntil", minW = 100, get = function(p) 
                local du = getStat(p, "GetDonateUntil", 0)
                if type(du) == "number" and du > 0 then return os.date("%d.%m.%Y", du) end
                if type(du) == "string" and du ~= "" then return du end
                if du == -1 then return "Forever" end
                return "No"
            end },
            { name = "Raid Atk",    minW = 80,  get = function(p) return formatNum(getStat(p, "GetRaidAttacks", 0)) end },
            { name = "Raid Def",    minW = 80,  get = function(p) return formatNum(getStat(p, "GetRaidDefenses", 0)) end }
        }

        -- =========================================================================
        -- UI: Stats Tab
        -- =========================================================================
        local xpanel = vgui.Create("DPanel")
        xpanel:SetPaintBackground(false)

        local topBar = vgui.Create("DPanel", xpanel)
        topBar:Dock(TOP)
        topBar:SetTall(30)
        topBar:DockMargin(5, 5, 5, 5)
        topBar:SetPaintBackground(false)

        local btnRefresh = vgui.Create("DButton", topBar)
        btnRefresh:Dock(LEFT)
        btnRefresh:SetText("Refresh")
        btnRefresh:SetWide(100)
        btnRefresh:SetIcon("icon16/arrow_refresh.png")

        local listContainer, list = CreateHorizontalScrollList(xpanel)
        listContainer:Dock(FILL)
        listContainer:DockMargin(5, 0, 5, 5)

        for _, colData in ipairs(STAT_COLUMNS) do
            local col = list:AddColumn(colData.name)
            col:SetMinWidth(colData.minW)
        end

        local function refreshPlayerStats()
            if not IsValid(list) then return end
            list:Clear()

            for _, ply in ipairs(player.GetAll()) do
                if not IsValid(ply) then continue end
                
                local rowData = {}
                for _, colData in ipairs(STAT_COLUMNS) do
                    table.insert(rowData, colData.get(ply))
                end
                
                local row = list:AddLine(unpack(rowData))
                row.TargetPlayer = ply
            end
            
            listContainer:InvalidateLayout() 
        end

        btnRefresh.DoClick = refreshPlayerStats
        xpanel.UpdateContent = refreshPlayerStats
        refreshPlayerStats()

        xgui.addModule("Stats", xpanel, "icon16/application_view_detail.png", "ulx addmoney")
    end

    if xgui then
        DynamicInit()
    else
        hook.Add("xguiInitialize", "BW_ULX_RegisterStatsTab", DynamicInit)
    end
end

function MODULE:AddCommands()
    local currency = (BW and BW.Config and BW.Config.Economy and BW.Config.Economy.Currency) or "$"

    local function formatNum(val)
        if BW and BW.Utils and BW.Utils.NumWithSep then
            return BW.Utils.NumWithSep(val)
        end
        return tostring(val)
    end

    -- =========================================================================
    -- MONEY
    -- =========================================================================
    
    function ulx.addmoney(calling_ply, target_plys, amt)
        for i = 1, #target_plys do
            local v = target_plys[i]
            if IsValid(v) then
                v:AddMoney(amt)
                ulx.fancyLogAdmin(calling_ply, "#A gave " .. currency .. "#s to #T (Total: " .. currency .. "#s)", formatNum(amt), v, formatNum(v:GetMoney()))
            end
        end
    end
    local addmoney = ulx.command(CATEGORY_NAME, "ulx addmoney", ulx.addmoney, "!addmoney")
    addmoney:addParam{type = ULib.cmds.PlayersArg}
    addmoney:addParam{type = ULib.cmds.NumArg, min = 0, max = 1000000000000, hint = "Money", ULib.cmds.round}
    addmoney:defaultAccess(ULib.ACCESS_ADMIN)
    addmoney:help("Give money to player(s).")

    function ulx.takemoney(calling_ply, target_plys, amt)
        for i = 1, #target_plys do
            local v = target_plys[i]
            if IsValid(v) then
                v:TakeMoney(amt)
                ulx.fancyLogAdmin(calling_ply, "#A took " .. currency .. "#s from #T (Total: " .. currency .. "#s)", formatNum(amt), v, formatNum(v:GetMoney()))
            end
        end
    end
    local takemoney = ulx.command(CATEGORY_NAME, "ulx takemoney", ulx.takemoney, "!takemoney")
    takemoney:addParam{type = ULib.cmds.PlayersArg}
    takemoney:addParam{type = ULib.cmds.NumArg, min = 0, max = 1000000000000, hint = "Money", ULib.cmds.round}
    takemoney:defaultAccess(ULib.ACCESS_ADMIN)
    takemoney:help("Take money from player(s).")

    function ulx.setmoney(calling_ply, target_plys, amt)
        for i = 1, #target_plys do
            local v = target_plys[i]
            if IsValid(v) then
                v:SetMoney(amt)
                ulx.fancyLogAdmin(calling_ply, "#A set money of #T to " .. currency .. "#s (Total: " .. currency .. "#s)", v, formatNum(amt), formatNum(v:GetMoney()))
            end
        end
    end
    local setmoney = ulx.command(CATEGORY_NAME, "ulx setmoney", ulx.setmoney, "!setmoney")
    setmoney:addParam{type = ULib.cmds.PlayersArg}
    setmoney:addParam{type = ULib.cmds.NumArg, min = 0, max = 1000000000000, hint = "Money", ULib.cmds.round}
    setmoney:defaultAccess(ULib.ACCESS_SUPERADMIN)
    setmoney:help("Set player's money.")


    -- =========================================================================
    -- LEVEL
    -- =========================================================================

    function ulx.addlevel(calling_ply, target_plys, amt)
        for i = 1, #target_plys do
            local v = target_plys[i]
            if IsValid(v) then
                v:AddLevel(amt)
                ulx.fancyLogAdmin(calling_ply, "#A added #s level(s) to #T (Current Level: #s)", amt, v, v:GetLevel())
            end
        end
    end
    local addlevel = ulx.command(CATEGORY_NAME, "ulx addlevel", ulx.addlevel, "!addlevel")
    addlevel:addParam{type = ULib.cmds.PlayersArg}
    addlevel:addParam{type = ULib.cmds.NumArg, min = 1, max = 1000, hint = "Levels", ULib.cmds.round}
    addlevel:defaultAccess(ULib.ACCESS_ADMIN)
    addlevel:help("Add levels to player(s).")

    function ulx.takelevel(calling_ply, target_plys, amt)
        for i = 1, #target_plys do
            local v = target_plys[i]
            if IsValid(v) then
                v:TakeLevel(amt)
                ulx.fancyLogAdmin(calling_ply, "#A took #s level(s) from #T (Current Level: #s)", amt, v, v:GetLevel())
            end
        end
    end
    local takelevel = ulx.command(CATEGORY_NAME, "ulx takelevel", ulx.takelevel, "!takelevel")
    takelevel:addParam{type = ULib.cmds.PlayersArg}
    takelevel:addParam{type = ULib.cmds.NumArg, min = 1, max = 1000, hint = "Levels", ULib.cmds.round}
    takelevel:defaultAccess(ULib.ACCESS_ADMIN)
    takelevel:help("Take levels from player(s).")

    function ulx.setlevel(calling_ply, target_plys, amt)
        for i = 1, #target_plys do
            local v = target_plys[i]
            if IsValid(v) then
                v:SetLevel(amt)
                ulx.fancyLogAdmin(calling_ply, "#A set level of #T to #s (Current Level: #s)", v, amt, v:GetLevel())
            end
        end
    end
    local setlevel = ulx.command(CATEGORY_NAME, "ulx setlevel", ulx.setlevel, "!setlevel")
    setlevel:addParam{type = ULib.cmds.PlayersArg}
    setlevel:addParam{type = ULib.cmds.NumArg, min = 1, max = 1000, hint = "Level", ULib.cmds.round}
    setlevel:defaultAccess(ULib.ACCESS_SUPERADMIN)
    setlevel:help("Set player's level.")


    -- =========================================================================
    -- XP
    -- =========================================================================

    function ulx.addxp(calling_ply, target_plys, amt)
        for i = 1, #target_plys do
            local v = target_plys[i]
            if IsValid(v) then
                v:AddXP(amt) -- База данных сама обработает Level Up, если опыт превысит лимит
                ulx.fancyLogAdmin(calling_ply, "#A added #s XP to #T (Current XP: #s/#s)", formatNum(amt), v, formatNum(v:GetXP()), formatNum(v:GetMaxXP()))
            end
        end
    end
    local addxp = ulx.command(CATEGORY_NAME, "ulx addxp", ulx.addxp, "!addxp")
    addxp:addParam{type = ULib.cmds.PlayersArg}
    addxp:addParam{type = ULib.cmds.NumArg, min = 1, max = 100000000, hint = "XP", ULib.cmds.round}
    addxp:defaultAccess(ULib.ACCESS_ADMIN)
    addxp:help("Add XP to player(s).")

    function ulx.takexp(calling_ply, target_plys, amt)
        for i = 1, #target_plys do
            local v = target_plys[i]
            if IsValid(v) then
                v:TakeXP(amt)
                ulx.fancyLogAdmin(calling_ply, "#A took #s XP from #T (Current XP: #s/#s)", formatNum(amt), v, formatNum(v:GetXP()), formatNum(v:GetMaxXP()))
            end
        end
    end
    local takexp = ulx.command(CATEGORY_NAME, "ulx takexp", ulx.takexp, "!takexp")
    takexp:addParam{type = ULib.cmds.PlayersArg}
    takexp:addParam{type = ULib.cmds.NumArg, min = 1, max = 100000000, hint = "XP", ULib.cmds.round}
    takexp:defaultAccess(ULib.ACCESS_ADMIN)
    takexp:help("Take XP from player(s).")

    function ulx.setxp(calling_ply, target_plys, amt)
        for i = 1, #target_plys do
            local v = target_plys[i]
            if IsValid(v) then
                v:SetXP(amt)
                ulx.fancyLogAdmin(calling_ply, "#A set XP of #T to #s (Current XP: #s/#s)", v, formatNum(amt), formatNum(v:GetXP()), formatNum(v:GetMaxXP()))
            end
        end
    end
    local setxp = ulx.command(CATEGORY_NAME, "ulx setxp", ulx.setxp, "!setxp")
    setxp:addParam{type = ULib.cmds.PlayersArg}
    setxp:addParam{type = ULib.cmds.NumArg, min = 0, max = 100000000, hint = "XP", ULib.cmds.round}
    setxp:defaultAccess(ULib.ACCESS_SUPERADMIN)
    setxp:help("Set player's XP.")


    -- =========================================================================
    -- BOUNTY
    -- =========================================================================

    function ulx.addbounty(calling_ply, target_plys, amt)
        for i = 1, #target_plys do
            local v = target_plys[i]
            if IsValid(v) then
                v:AddBounty(amt)
                ulx.fancyLogAdmin(calling_ply, "#A added " .. currency .. "#s bounty to #T (Total Bounty: " .. currency .. "#s)", formatNum(amt), v, formatNum(v:GetBounty()))
            end
        end
    end
    local addbounty = ulx.command(CATEGORY_NAME, "ulx addbounty", ulx.addbounty, "!addbounty")
    addbounty:addParam{type = ULib.cmds.PlayersArg}
    addbounty:addParam{type = ULib.cmds.NumArg, min = 1, max = 1000000000, hint = "Bounty", ULib.cmds.round}
    addbounty:defaultAccess(ULib.ACCESS_ADMIN)
    addbounty:help("Add bounty to player(s).")

    function ulx.setbounty(calling_ply, target_plys, amt)
        for i = 1, #target_plys do
            local v = target_plys[i]
            if IsValid(v) then
                v:SetBounty(amt)
                ulx.fancyLogAdmin(calling_ply, "#A set bounty of #T to " .. currency .. "#s (Total Bounty: " .. currency .. "#s)", v, formatNum(amt), formatNum(v:GetBounty()))
            end
        end
    end
    local setbounty = ulx.command(CATEGORY_NAME, "ulx setbounty", ulx.setbounty, "!setbounty")
    setbounty:addParam{type = ULib.cmds.PlayersArg}
    setbounty:addParam{type = ULib.cmds.NumArg, min = 0, max = 1000000000, hint = "Bounty", ULib.cmds.round}
    setbounty:defaultAccess(ULib.ACCESS_ADMIN)
    setbounty:help("Set player's bounty.")


    -- =========================================================================
    -- REPUTATION
    -- =========================================================================

    function ulx.addrep(calling_ply, target_plys, amt)
        for i = 1, #target_plys do
            local v = target_plys[i]
            if IsValid(v) then
                v:AddReputation(amt)
                ulx.fancyLogAdmin(calling_ply, "#A added #s reputation to #T (Current Rep: #s)", formatNum(amt), v, formatNum(v:GetReputation()))
            end
        end
    end
    local addrep = ulx.command(CATEGORY_NAME, "ulx addrep", ulx.addrep, "!addrep")
    addrep:addParam{type = ULib.cmds.PlayersArg}
    addrep:addParam{type = ULib.cmds.NumArg, min = 1, max = 100, hint = "Reputation", ULib.cmds.round}
    addrep:defaultAccess(ULib.ACCESS_ADMIN)
    addrep:help("Add reputation to player(s).")

    function ulx.takerep(calling_ply, target_plys, amt)
        for i = 1, #target_plys do
            local v = target_plys[i]
            if IsValid(v) then
                v:TakeReputation(amt)
                ulx.fancyLogAdmin(calling_ply, "#A took #s reputation from #T (Current Rep: #s)", formatNum(amt), v, formatNum(v:GetReputation()))
            end
        end
    end
    local takerep = ulx.command(CATEGORY_NAME, "ulx takerep", ulx.takerep, "!takerep")
    takerep:addParam{type = ULib.cmds.PlayersArg}
    takerep:addParam{type = ULib.cmds.NumArg, min = 1, max = 100, hint = "Reputation", ULib.cmds.round}
    takerep:defaultAccess(ULib.ACCESS_ADMIN)
    takerep:help("Take reputation from player(s).")

    function ulx.setrep(calling_ply, target_plys, amt)
        for i = 1, #target_plys do
            local v = target_plys[i]
            if IsValid(v) then
                v:SetReputation(amt)
                ulx.fancyLogAdmin(calling_ply, "#A set reputation of #T to #s (Current Rep: #s)", v, formatNum(amt), formatNum(v:GetReputation()))
            end
        end
    end
    local setrep = ulx.command(CATEGORY_NAME, "ulx setrep", ulx.setrep, "!setrep")
    setrep:addParam{type = ULib.cmds.PlayersArg}
    setrep:addParam{type = ULib.cmds.NumArg, min = -100, max = 100, hint = "Reputation", ULib.cmds.round}
    setrep:defaultAccess(ULib.ACCESS_ADMIN)
    setrep:help("Set player's reputation.")


    -- =========================================================================
    -- PVP (KILLS / DEATHS)
    -- =========================================================================

    function ulx.setkills(calling_ply, target_plys, amt)
        for i = 1, #target_plys do
            local v = target_plys[i]
            if IsValid(v) then
                v:SetKills(amt)
                ulx.fancyLogAdmin(calling_ply, "#A set kills of #T to #s (Total Kills: #s)", v, amt, v:GetKills())
            end
        end
    end
    local setkills = ulx.command(CATEGORY_NAME, "ulx setkills", ulx.setkills, "!setkills")
    setkills:addParam{type = ULib.cmds.PlayersArg}
    setkills:addParam{type = ULib.cmds.NumArg, min = 0, max = 10000, hint = "Kills", ULib.cmds.round}
    setkills:defaultAccess(ULib.ACCESS_ADMIN)
    setkills:help("Set player's kills count.")

    function ulx.setdeaths(calling_ply, target_plys, amt)
        for i = 1, #target_plys do
            local v = target_plys[i]
            if IsValid(v) then
                v:SetDeaths(amt)
                ulx.fancyLogAdmin(calling_ply, "#A set deaths of #T to #s (Total Deaths: #s)", v, amt, v:GetDeaths())
            end
        end
    end
    local setdeaths = ulx.command(CATEGORY_NAME, "ulx setdeaths", ulx.setdeaths, "!setdeaths")
    setdeaths:addParam{type = ULib.cmds.PlayersArg}
    setdeaths:addParam{type = ULib.cmds.NumArg, min = 0, max = 10000, hint = "Deaths", ULib.cmds.round}
    setdeaths:defaultAccess(ULib.ACCESS_ADMIN)
    setdeaths:help("Set player's deaths count.")

    -- =========================================================================
    -- PVP (ADD / TAKE KILLS & DEATHS)
    -- =========================================================================

    function ulx.addkills(calling_ply, target_plys, amt)
        for i = 1, #target_plys do
            local v = target_plys[i]
            if IsValid(v) then
                local current = v:GetKills() or 0
                local new_amt = current + amt
                v:SetKills(new_amt)
                ulx.fancyLogAdmin(calling_ply, "#A added #i kills to #T (Total Kills: #i)", amt, v, new_amt)
            end
        end
    end
    local addkills = ulx.command(CATEGORY_NAME, "ulx addkills", ulx.addkills, "!addkills")
    addkills:addParam{type = ULib.cmds.PlayersArg}
    addkills:addParam{type = ULib.cmds.NumArg, min = 0, max = 10000, hint = "Amount", ULib.cmds.round}
    addkills:defaultAccess(ULib.ACCESS_ADMIN)
    addkills:help("Add kills to a player.")

    function ulx.takekills(calling_ply, target_plys, amt)
        for i = 1, #target_plys do
            local v = target_plys[i]
            if IsValid(v) then
                local current = v:GetKills() or 0
                local new_amt = current - amt
                v:SetKills(new_amt)
                ulx.fancyLogAdmin(calling_ply, "#A took #i kills from #T (Total Kills: #i)", amt, v, new_amt)
            end
        end
    end
    local takekills = ulx.command(CATEGORY_NAME, "ulx takekills", ulx.takekills, "!takekills")
    takekills:addParam{type = ULib.cmds.PlayersArg}
    takekills:addParam{type = ULib.cmds.NumArg, min = 0, max = 10000, hint = "Amount", ULib.cmds.round}
    takekills:defaultAccess(ULib.ACCESS_ADMIN)
    takekills:help("Take kills from a player.")

    function ulx.adddeaths(calling_ply, target_plys, amt)
        for i = 1, #target_plys do
            local v = target_plys[i]
            if IsValid(v) then
                local current = v:GetDeaths() or 0
                local new_amt = current + amt
                v:SetDeaths(new_amt)
                ulx.fancyLogAdmin(calling_ply, "#A added #i deaths to #T (Total Deaths: #i)", amt, v, new_amt)
            end
        end
    end
    local adddeaths = ulx.command(CATEGORY_NAME, "ulx adddeaths", ulx.adddeaths, "!adddeaths")
    adddeaths:addParam{type = ULib.cmds.PlayersArg}
    adddeaths:addParam{type = ULib.cmds.NumArg, min = 0, max = 10000, hint = "Amount", ULib.cmds.round}
    adddeaths:defaultAccess(ULib.ACCESS_ADMIN)
    adddeaths:help("Add deaths to a player.")

    function ulx.takedeaths(calling_ply, target_plys, amt)
        for i = 1, #target_plys do
            local v = target_plys[i]
            if IsValid(v) then
                local current = v:GetDeaths() or 0
                local new_amt = current - amt -- Не даем уйти в минус
                v:SetDeaths(new_amt)
                ulx.fancyLogAdmin(calling_ply, "#A took #i deaths from #T (Total Deaths: #i)", amt, v, new_amt)
            end
        end
    end
    local takedeaths = ulx.command(CATEGORY_NAME, "ulx takedeaths", ulx.takedeaths, "!takedeaths")
    takedeaths:addParam{type = ULib.cmds.PlayersArg}
    takedeaths:addParam{type = ULib.cmds.NumArg, min = 0, max = 10000, hint = "Amount", ULib.cmds.round}
    takedeaths:defaultAccess(ULib.ACCESS_ADMIN)
    takedeaths:help("Take deaths from a player.")
end