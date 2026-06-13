local MODULE = MODULE

MODULE.Name = "Spawnmenu"
MODULE.Author = "Brov3r"
MODULE.Require = { "database", "notify"}

local config = BW.Config
local oldGetTools = CLIENT and spawnmenu.GetTools or nil

function MODULE:Init()
    if SERVER then
        self:InitServer()
    else
        self:InitClient()
    end
end

local function FindShopItem(itemID)
    if not BW.Config or not BW.Config.Shop then return nil end
    
    for categoryID, items in pairs(BW.Config.Shop) do
        if items[itemID] then
            return items[itemID]
        end
    end
    return nil
end

local function FindPropConfig(modelPath)
    if not BW.Config or not BW.Config.Props then return false, 0 end
    
    local cleanedPath = string.lower(modelPath)
    
    for category, models in pairs(BW.Config.Props) do
        for _, propData in ipairs(models) do
            if propData[1] and string.lower(propData[1]) == cleanedPath then
                return true, (propData.hp or 100)
            end
        end
    end
    
    return false, 0
end

function BW.GetFinalPrice(ply, basePrice)
    if not IsValid(ply) then return basePrice end
    
    local rep = (ply.GetReputation and ply:GetReputation()) or 0
    local discount = (BW.Config and BW.Config.Economy and BW.Config.Economy.ReputationDiscount) or 0.3
    
    -- Формула: чем выше репутация, тем ниже цена.
    local multiplier = 1 - (rep / 100 * discount)
    return math.Round(basePrice * multiplier)
end

function MODULE:InitServer()
    util.AddNetworkString("BW_BuyShopItem")
    util.AddNetworkString("BW_SpawnProp")

    net.Receive("BW_SpawnProp", function(len, ply)
        if not IsValid(ply) or not ply:Alive() then return end

        local model = net.ReadString()

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

        ent:Spawn()
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

        if ent.SetPlayer then ent:SetPlayer(ply) end
        if ent.SetCPPIOwner then ent:SetCPPIOwner(ply) end
        ent.Owner = ply
        ent:SetNWEntity("Owner", ply)

        if ply.AddCount then
            ply:AddCount("props", ent)
        end

        if ply.AddCleanup then
            ply:AddCleanup("props", ent)
        end
        
        undo.Create("Prop")
            undo.AddEntity(ent)
            undo.SetPlayer(ply)
        undo.Finish("Prop (" .. model:match("([^/]+)%.mdl$") .. ")")

        Log("success", "Player ", BW.Config.Colors.Cyan, ply:Nick(), BW.Config.Colors.White, " spawn prop ", BW.Config.Colors.Cyan, model, BW.Config.Colors.White, " with HP: ", BW.Config.Colors.Green, tostring(propHP) .. " HP")
    
        hook.Call("PlayerSpawnedProp", nil, ply, model, ent)
    end)

    net.Receive("BW_BuyShopItem", function(len, ply)
        if not IsValid(ply) or not ply:Alive() then return end

        local itemID = net.ReadString()
        local itemData = FindShopItem(itemID)

        if not itemData then 
            Log("error", string.format("Player %s tried to buy a non-existent ID: %s", ply:Nick(), tostring(itemID)))
            return 
        end

        if itemData.vip then
            local userGroup = ply:GetUserGroup()
            local groupConfig = BW.Config.PlayerGroups[userGroup]
            local hasVIP = groupConfig and groupConfig.Privilege == true

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

        local moneyTaken = false
        if finalPrice > 0 and ply.TakeMoney then
            ply:TakeMoney(finalPrice)
            moneyTaken = true
        end

        local ent = ents.Create(itemData.ent)
        if not IsValid(ent) then
            if moneyTaken and ply.AddMoney then ply:AddMoney(finalPrice) end

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
        if ent.SetPlayer then ent:SetPlayer(ply) end
        if ent.SetCPPIOwner then ent:SetCPPIOwner(ply) end
        ent.Owner = ply
        ent:SetNWEntity("Owner", ply)

        ent:Spawn()
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
        
        if itemData.max and itemData.max > 0 then
            local currentCount = ply:GetNWInt("BW_ItemCount_" .. itemID, 0)
            ply:SetNWInt("BW_ItemCount_" .. itemID, currentCount + 1)

            ent:CallOnRemove("BW_ShopLimit_Track", function()
                if IsValid(ply) then
                    local c = ply:GetNWInt("BW_ItemCount_" .. itemID, 0)
                    ply:SetNWInt("BW_ItemCount_" .. itemID, math.max(0, c - 1))
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
    end)
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
            local firstTool = "physgun"

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
            
            RunConsoleCommand("gmod_toolmode", firstTool)
        end
    end, "BW_ToolRestriction")
end

function MODULE:OverrideGetTools()
    spawnmenu.GetTools = function()
        local tools = oldGetTools()
        if not tools then return nil end

        for tabIndex, tab in pairs(tools) do
            if tabIndex ~= 1 then continue end

            if istable(tab) and tab.Items then
                for catName, category in pairs(tab.Items) do
                    for key, item in pairs(category) do
                        if type(key) == "number" and istable(item) then
                            local itemName = item.ItemName or "NO_NAME"
                            local isAllowed = config and config.AllowedTools and config.AllowedTools[string.lower(itemName)]
                            
                            if not isAllowed then
                                category[key] = nil
                            end
                        end
                    end

                    local hasTools = false
                    for key, item in pairs(category) do
                        if type(key) == "number" and istable(item) then
                            hasTools = true
                            break
                        end
                    end
                    
                    if not hasTools then
                        tab.Items[catName] = nil
                    end
                end
            end
        end
        
        if IsValid(g_SpawnMenu) and IsValid(g_SpawnMenu.ToolMenu) then
            g_SpawnMenu.ToolMenu:InvalidateLayout(true)
        end
        
        return tools
    end
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