local MODULE = MODULE

MODULE.Name = "Spawnmenu"
MODULE.Author = "Brov3r"
MODULE.Require = SERVER and {"database", "notify", "ownership"} or {"database", "notify"}

local config = BW.Config
if CLIENT then BW.OriginalGetTools = BW.OriginalGetTools or spawnmenu.GetTools end
local shopIndex, propIndex = {}, {}

function MODULE:Init()
    for _, items in pairs(config.Shop or {}) do
        for id, item in pairs(items) do shopIndex[id] = item end
    end
    for _, models in pairs(config.Props or {}) do
        for _, data in ipairs(models) do
            local model = string.lower(data[1])
            if util.IsValidModel(model) then propIndex[model] = data.hp or 100
            elseif SERVER then Log("warn", "Invalid prop model:", model) end
        end
    end
    if SERVER then
        self:InitServer()
    else
        self:InitClient()
    end
end

local function FindShopItem(itemID)
    return shopIndex[itemID]
end

local function FindPropConfig(modelPath)
    local hp = propIndex[string.lower(modelPath)]
    return hp ~= nil, hp or 0
end

function BW.GetFinalPrice(ply, basePrice)
    basePrice = tonumber(basePrice)
    if not BW.Utils.IsFinite(basePrice) then return 0 end
    basePrice = math.Clamp(basePrice, 0, BW.Config.Economy.MaxMoney)
    if not IsValid(ply) then return basePrice end
    
    local rep = math.Clamp((ply.GetReputation and ply:GetReputation()) or 0, -100, 100)
    local discount = math.Clamp(BW.Config.Economy.ReputationDiscount or 0.3, 0, 1)
    
    -- Формула: чем выше репутация, тем ниже цена.
    local multiplier = 1 - (rep / 100 * discount)
    return math.Clamp(math.Round(basePrice * multiplier), 0, BW.Config.Economy.MaxMoney)
end

function MODULE:InitServer()
    util.AddNetworkString("BW_BuyShopItem")
    util.AddNetworkString("BW_SpawnProp")

    net.Receive("BW_SpawnProp", function(len, ply)
        if not BW.Utils.AllowRequest(ply, "spawn_prop", 0.2, 3, len, 260) then return end
        if not IsValid(ply) or not ply:Alive() then return end

        local model = string.lower(net.ReadString())
        if #model > 255 then return end

        local isAllowed, propHP = FindPropConfig(model)
        if not isAllowed then
            Log("error", "Player ", BW.Config.Colors.Cyan, ply:Nick(), BW.Config.Colors.White, " tried to save a forbidden model: ", BW.Config.Colors.Red, tostring(model))
            if ply.Notify then
                ply:Notify(NOTIFY_ERROR, Translate("SpawnMenu.BlockProp", "This item is not allowed to spawn!"), 5)
            end
            return
        end

        if ply.CheckLimit and not ply:CheckLimit("props") then
             return
        end

        local ent = ents.Create("prop_physics")
        if not IsValid(ent) then 
            Log("error", "Couldn't create prop_physics for the model:", BW.Config.Colors.Cyan, model)
            return 
        end

        ent:SetModel(model)

        local tr = ply:GetEyeTrace()
        local spawnPos = tr.HitPos
        local offset = tr.HitNormal * 10
        local isAirSpawn = false

        if spawnPos:DistToSqr(ply:GetShootPos()) > 300^2 then
            spawnPos = ply:GetShootPos() + ply:GetAimVector() * 120
            offset = Vector(0, 0, 0) 
            isAirSpawn = true
        end

        ent:SetPos(spawnPos + offset)
        
        local entAng = ply:GetAngles()
        entAng.p = 0
        entAng.r = 0
        entAng.y = entAng.y + 180
        ent:SetAngles(entAng)

        if not util.IsInWorld(ent:GetPos()) then ent:Remove() return end
        ent:Spawn()
        if not IsValid(ent) then return end
        ent:Activate()

        if not isAirSpawn then
            local mins = ent:OBBMins()
            if mins and mins.z < 0 then
                ent:SetPos(ent:GetPos() - Vector(0, 0, mins.z))
            end
        end

        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
        end

        ent:SetMaxHealth(propHP)
        ent:SetHealth(propHP)

        BW.Ownership.Assign(ply, ent)

        if ply.AddCount then
            ply:AddCount("props", ent)
        end

        if ply.AddCleanup then
            ply:AddCleanup("props", ent)
        end
        
        undo.Create("Prop")
            undo.AddEntity(ent)
            undo.SetPlayer(ply)
        undo.Finish("Prop (" .. (model:match("([^/]+)%.mdl$") or model) .. ")")

        Log("success", "Player ", BW.Config.Colors.Cyan, ply:Nick(), BW.Config.Colors.White, " spawn prop ", BW.Config.Colors.Cyan, model, BW.Config.Colors.White, " with HP: ", BW.Config.Colors.Green, tostring(propHP) .. " HP")
    
        hook.Call("PlayerSpawnedProp", nil, ply, model, ent)
    end)

    net.Receive("BW_BuyShopItem", function(len, ply)
        if not BW.Utils.AllowRequest(ply, "buy_item", 0.25, 2, len, 128) then return end
        if not IsValid(ply) or not ply:Alive() then return end
        if not ply:IsBot() and not ply.BW_StatsLoaded then return end

        local itemID = net.ReadString()
        if #itemID > 120 then return end
        local itemData = FindShopItem(itemID)

        if not itemData then 
            Log("error", string.format("Player %s tried to buy a non-existent ID: %s", ply:Nick(), tostring(itemID)))
            return 
        end

        if itemData.vip then
            local hasVIP = ply:HasPrivilege()

            if not hasVIP then
                if ply.Notify then ply:Notify(NOTIFY_ERROR, Translate("Shop.VIPAlert", "This item requires VIP status!"), 5) end
                return
            end
        end

        if itemData.lvl and itemData.lvl > 0 then
            local hasLevel = (ply.HasLevel and ply:HasLevel(itemData.lvl)) or (not ply.HasLevel)
            if not hasLevel then
                if ply.Notify then ply:Notify(NOTIFY_ERROR, Translate("Shop.LvlAlert", "Your level is too low!"), 5) end
                return
            end
        end

        local basePrice = itemData.price or 0
        local finalPrice = BW.GetFinalPrice(ply, basePrice)

        if basePrice > 0 then
            local hasMoney = (ply.HasMoney and ply:HasMoney(finalPrice)) or false
            if not hasMoney then
                if ply.Notify then ply:Notify(NOTIFY_ERROR, Translate("Shop.MoneyAlert", "Insufficient money!"), 5) end
                return
            end
        end

        if itemData.max and itemData.max > 0 then
            local currentCount = ply:GetNWInt("BW_ItemCount_" .. itemID, 0)
            if currentCount >= itemData.max then
                if ply.Notify then
                    ply:Notify(NOTIFY_ERROR, string.format(Translate("Shop.MaxLimitAlert", "You have reached the limit for this item! (Max: %s)"), tostring(itemData.max)), 5)
                end
                return
            end
        end

        if not ply:CheckLimit("sents") then return end

        local ent = ents.Create(itemData.ent)
        if not IsValid(ent) then

            Log("error", "Failed to create entity class: " .. tostring(itemData.ent) .. " for player " .. ply:Nick())
            if ply.Notify then
                ply:Notify(NOTIFY_ERROR, Translate("Shop.SpawnError","Server error: item entity configuration is invalid!"), 5)
            end
            return 
        end

        ent.DeviceCost = finalPrice or 0

        local tr = ply:GetEyeTrace()
        local spawnPos = tr.HitPos
        local offset = tr.HitNormal * 10
        local isAirSpawn = false

        if spawnPos:DistToSqr(ply:GetShootPos()) > 300^2 then
            spawnPos = ply:GetShootPos() + ply:GetAimVector() * 120
            offset = Vector(0, 0, 0) 
            isAirSpawn = true
        end

        ent:SetPos(spawnPos + offset)
        
        local entAng = ply:GetAngles()
        entAng.p = 0
        entAng.r = 0
        entAng.y = entAng.y + 180
        ent:SetAngles(entAng)

        if itemData.model then
            ent:SetModel(itemData.model)
        end
        BW.Ownership.Assign(ply, ent, itemID)

        if not util.IsInWorld(ent:GetPos()) then ent:Remove() return end
        ent:Spawn()
        if not IsValid(ent) then return end
        ent:Activate()
        if finalPrice > 0 then
            if not ply:HasMoney(finalPrice) then ent:Remove() return end
            ply:TakeMoney(finalPrice)
        end
        ply:AddCount("sents", ent)
        ply:AddCleanup("sents", ent)

        if not isAirSpawn then
            local mins = ent:OBBMins()
            if mins and mins.z < 0 then
                ent:SetPos(ent:GetPos() - Vector(0, 0, mins.z))
            end
        end

        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
        end
        
        if itemData.max and itemData.max > 0 then
            local currentCount = ply:GetNWInt("BW_ItemCount_" .. itemID, 0)
            ply:SetNWInt("BW_ItemCount_" .. itemID, currentCount + 1)

            local ownerID = ply:SteamID64()
            ent:CallOnRemove("BW_ShopLimit_Track", function()
                local owner = player.GetBySteamID64(ownerID)
                if IsValid(owner) then
                    local c = owner:GetNWInt("BW_ItemCount_" .. itemID, 0)
                    owner:SetNWInt("BW_ItemCount_" .. itemID, math.max(0, c - 1))
                end
            end)
        end
        
        Log("success", "Player ", BW.Config.Colors.Cyan, ply:Nick(), BW.Config.Colors.White, " bought ", BW.Config.Colors.Cyan, itemID, BW.Config.Colors.White, " for ", BW.Config.Colors.Cyan, (BW.Config.Economy.Currency or "$") .. finalPrice)
        
        if ply.Notify then
            local itemNameTranslated = Translate("ShopItems." .. itemID, itemID)
            ply:Notify(NOTIFY_SUCCESS or 0, Translate("Shop.BoughtSuccess", "You have successfully purchased:") .. " " .. itemNameTranslated, 5)
        end

        hook.Call("PlayerSpawnedSENT", nil, ply, ent)
    end)
        
    hook.Add("CanTool", "BW_BlockForbiddenTools", function(ply, tr, toolName, tool, button)
        if not config or not config.AllowedTools then return end
        
        if not config.AllowedTools[string.lower(toolName)] then
            return false
        end
        if IsValid(tr.Entity) and not tr.Entity:IsWorld() and not BW.Ownership.CanModify(ply, tr.Entity) then return false end
        if toolName == "stacker_improved" and not ply:CheckLimit("props") then return false end
    end)
    -- UI restrictions are not security boundaries. Block standard Sandbox spawning too.
    for _, event in ipairs({"PlayerSpawnProp", "PlayerSpawnSENT", "PlayerSpawnNPC", "PlayerSpawnVehicle", "PlayerSpawnRagdoll", "PlayerSpawnEffect", "PlayerGiveSWEP", "PlayerSpawnSWEP"}) do
        hook.Add(event, "BW_CustomSpawnOnly", function() return false end)
    end
end

function MODULE:InitClient()
    self:RegisterToolRestriction()
    self:OverrideGetTools()
    self:RegisterSpawnMenuHooks()
end

function MODULE:RegisterToolRestriction()
    cvars.AddChangeCallback("gmod_toolmode", function(convar_name, old_value, new_value)
        if not config or not config.AllowedTools then return end

        local ply = LocalPlayer()
        if not IsValid(ply) or new_value == "" then return end

        local isAllowed = config.AllowedTools[string.lower(new_value)]

        if not isAllowed then
            local toolWeapon = weapons.Get("gmod_tool")
            local firstTool

            if toolWeapon and toolWeapon.Tool then
                local toolList = table.GetKeys(toolWeapon.Tool)
                table.sort(toolList)

                for _, tName in ipairs(toolList) do
                    if config.AllowedTools[string.lower(tName)] then
                        firstTool = tName
                        break
                    end
                end
            end
            
            if firstTool and firstTool ~= new_value then RunConsoleCommand("gmod_toolmode", firstTool) end
        end
    end, "BW_ToolRestriction")
end

function MODULE:FilterTools(source)
    local tools = table.Copy(source or {})
    for tabIndex, tab in pairs(tools) do
        if istable(tab) and istable(tab.Items) then
            local categories = {}
            local categoryKeys = {}
            for key, value in pairs(tab.Items) do
                if isnumber(key) then categoryKeys[#categoryKeys + 1] = key
                else categories[key] = value end
            end
            table.sort(categoryKeys)
            for _, categoryKey in ipairs(categoryKeys) do
                local category = tab.Items[categoryKey]
                if istable(category) then
                    local filtered, keys = {}, {}
                    for key, value in pairs(category) do
                        if isnumber(key) then keys[#keys + 1] = key
                        else filtered[key] = value end
                    end
                    table.sort(keys)
                    for _, key in ipairs(keys) do
                        local item = category[key]
                        if istable(item) then
                            local commandMode = isstring(item.Command) and item.Command:match("^gmod_tool%s+([%w_]+)")
                            local mode = commandMode or (isstring(item.ItemName) and string.lower(item.ItemName))
                            local restricted = tabIndex == 1 or commandMode ~= nil
                            if not restricted or (mode and config.AllowedTools[mode]) then
                                filtered[#filtered + 1] = item
                            end
                        end
                    end
                    if #filtered > 0 then categories[#categories + 1] = filtered end
                end
            end
            tab.Items = categories
        end
    end
    return tools
end

function MODULE:OverrideGetTools()
    spawnmenu.GetTools = function() return MODULE:FilterTools(BW.OriginalGetTools()) end
end

function MODULE:RegisterSpawnMenuHooks()
    hook.Add("OnSpawnMenuOpen", "BW_CustomSpawnMenuSetup", function()
        local tabs = g_SpawnMenu and g_SpawnMenu.CreateMenu
        if not IsValid(tabs) or tabs.BW_Customized then return end
        tabs.BW_Customized = true

        for _, sheet in pairs(tabs.Items) do
            if IsValid(sheet.Tab) then sheet.Tab:Remove() end
            if IsValid(sheet.Panel) then sheet.Panel:Remove() end
        end
        tabs.Items = {}

        local customTabs = {
            {name = Translate("SpawnMenu.PropsTabName", "Props"), class = "BW_SpawnMenu_Props", icon = "icon16/box.png", isDefault = true},
            {name = Translate("SpawnMenu.ShopTabName", "Shop"),   class = "BW_SpawnMenu_Shop",  icon = "icon16/money.png"},
            {name = Translate("SpawnMenu.RulesTabName", "Rules"),   class = "BW_SpawnMenu_Rules",  icon = "icon16/information.png"},
            {name = Translate("SpawnMenu.FAQTabName", "FAQ"),   class = "BW_SpawnMenu_FAQ",  icon = "icon16/star.png"},
        }

        local defaultSheet = nil

        for _, data in ipairs(customTabs) do
            local panel = vgui.Create(data.class, tabs)
            local sheet = tabs:AddSheet(data.name, panel, data.icon)
            
            if data.isDefault then
                defaultSheet = sheet
            end
        end

        if defaultSheet and IsValid(defaultSheet.Tab) then
            tabs:SetActiveTab(defaultSheet.Tab)
        end

        tabs:InvalidateLayout()
    end)
end

local spawnCommands = {
    "gm_spawn",
    "gm_spawnsent",
    "gm_spawnnpc",
    "gm_spawnvehicle",
    "gm_spawnragdoll",
    "gm_give"
}

for _, cmd in ipairs(spawnCommands) do
    concommand.Add(cmd, function(ply, command, args)
        if IsValid(ply) then
            ply:Notify(NOTIFY_WARNING, string.format(Translate("SpawnMenu.CommandDisabled", "The %s command is completely disabled on this server!"), command), 5)
        end
    end)
end
