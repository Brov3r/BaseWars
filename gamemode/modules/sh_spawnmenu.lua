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

function MODULE:InitServer()
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
        if not IsValid(tabs) then return end

        if tabs.BW_Customized then return end
        tabs.BW_Customized = true

        for _, sheet in pairs(tabs.Items) do
            if IsValid(sheet.Tab) then sheet.Tab:SetVisible(false) end
            if IsValid(sheet.Panel) then sheet.Panel:SetVisible(false) end
        end
        tabs.Items = {}

        local propsPanel = vgui.Create("BW_SpawnMenu_Props", tabs)
        local shopPanel = vgui.Create("BW_SpawnMenu_Shop", tabs)

        local propsTabName = Translate("SpawnMenu.PropsTabName", "Props")
        local shopTabName = Translate("SpawnMenu.ShopTabName", "Shop")

        local propsSheet = tabs:AddSheet(propsTabName, propsPanel, "icon16/box.png")
        tabs:AddSheet(shopTabName, shopPanel, "icon16/money.png")

        if propsSheet and IsValid(propsSheet.Tab) then
            tabs:SetActiveTab(propsSheet.Tab)
        end

        tabs:InvalidateLayout()
    end)
end