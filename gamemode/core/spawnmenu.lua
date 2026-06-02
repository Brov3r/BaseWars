local oldGetTools = spawnmenu.GetTools

-- hook.Add("InitPostEntity", "BW_ForceOverrideActivateTool", function()
--     local oldActivateTool = spawnmenu.ActivateTool

--     spawnmenu.ActivateTool = function(tool, menu_only)
--         -- Если это уже наша функция, просто пропускаем
--         -- (проверка на уникальный признак, например, наличие переменной)
        
--         local isAllowed = (BW and BW.Config and BW.Config.AllowedTools[tool])

--         if not isAllowed then
--             print("[BW_DEBUG] Блокировка активации: " .. tostring(tool))
--             -- Переключаем на сварку
--             oldActivateTool("weld", menu_only)
--             return
--         end

--         oldActivateTool(tool, menu_only)
--     end
-- end)

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
                        local isAllowed = (BW and BW.Config and BW.Config.AllowedTools[itemName])
                        
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

hook.Add("CanTool", "BW_BlockForbiddenTools", function(ply, tr, toolName, tool, button)
    if not (BW and BW.Config and BW.Config.AllowedTools[toolName]) then
        return false
    end
end)

hook.Add("OnSpawnMenuOpen", "BW_CustomSpawnMenuSetup", function()
    local tabs = g_SpawnMenu.CreateMenu
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

    local propsTabName = BW.Translate.SpawnMenu.PropsTabName or "Props"
    local shopTabName = BW.Translate.SpawnMenu.ShopTabName or "Shop"

    local propsSheet = tabs:AddSheet(propsTabName, propsPanel, "icon16/box.png")
    tabs:AddSheet(shopTabName, shopPanel, "icon16/money.png")

    if propsSheet and IsValid(propsSheet.Tab) then
        tabs:SetActiveTab(propsSheet.Tab)
    end

    tabs:InvalidateLayout()
end)