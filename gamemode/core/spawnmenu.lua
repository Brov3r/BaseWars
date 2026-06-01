hook.Add("OnSpawnMenuOpen", "BW_CustomSpawnMenuSetup", function()
    local tabs = g_SpawnMenu.CreateMenu
    if not IsValid(tabs) then return end

    -- 2. НАСТРОЙКА ВКЛАДОК (выполняется один раз)
    if tabs.BW_Customized then return end
    tabs.BW_Customized = true

    -- Скрываем старые вкладки
    for _, sheet in pairs(tabs.Items) do
        if IsValid(sheet.Tab) then sheet.Tab:SetVisible(false) end
        if IsValid(sheet.Panel) then sheet.Panel:SetVisible(false) end
    end
    tabs.Items = {}
    
    local BW_CustomProps = {
        { name = "Деревянный ящик", model = "models/props_junk/wood_crate001a.mdl" },
        { name = "Бочка",          model = "models/props_junk/metalgascan.mdl" },
        { name = "Стул",           model = "models/props_chairs/chair_office01.mdl" },
        { name = "Конус",          model = "models/props_junk/trafficcone001a.mdl" }
    }

    -- Создаем вкладку с пропами
    local PropsContainer = vgui.Create("DScrollPanel", tabs)
    local iconLayout = vgui.Create("DIconLayout", PropsContainer)
    iconLayout:Dock(TOP)
    iconLayout:SetSpaceX(5)
    iconLayout:SetSpaceY(5)
    iconLayout:SetBorder(10)

    for _, prop in ipairs(BW_CustomProps) do
        local icon = vgui.Create("SpawnIcon", iconLayout)
        icon:SetSize(64, 64)
        icon:SetModel(prop.model)
        icon:SetTooltip(prop.name)
        icon.Paint = function(s, w, h) derma.SkinHook("Paint", "Panel", s, w, h) end
        icon.DoClick = function()
            RunConsoleCommand("gm_spawn", prop.model)
            surface.PlaySound("ui/buttonclickrelease.wav")
        end
        iconLayout:Add(icon)
    end

    local propsTab = tabs:AddSheet(BW.Translate.SpawnMenu.PropsTabName or "Props", PropsContainer, "icon16/box.png")

    -- Создаем вкладку магазина
    local ShopContainer = vgui.Create("DPanel", tabs)
    function ShopContainer:Paint(w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(30, 30, 30))
        draw.SimpleText("МАГАЗИН", "DermaLarge", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    tabs:AddSheet(BW.Translate.SpawnMenu.ShopTabName or "Shop", ShopContainer, "icon16/money.png")

    -- Переключаем на вкладку пропов
    if propsTab and IsValid(propsTab.Tab) then
        tabs:SetActiveTab(propsTab.Tab)
    end

    tabs:InvalidateLayout()
end)