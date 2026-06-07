local PANEL = {}

function PANEL:Init()
    self:Dock(FILL)

    local scroll = vgui.Create("DScrollPanel", self)
    scroll:Dock(FILL)

    -- Настройка скроллбара под стиль BaseWars
    local sbar = scroll:GetVBar()
    sbar:SetWide(10)
    sbar.Paint = function(s, w, h) draw.RoundedBox(0, 0, 0, w, h, Color(40, 40, 40, 100)) end
    sbar.btnGrip.Paint = function(s, w, h)
        local color = s:IsHovered() and Color(150, 150, 150) or Color(100, 100, 100)
        draw.RoundedBox(4, 2, 0, w - 4, h, color)
    end
    sbar.btnUp.Paint = function() end
    sbar.btnDown.Paint = function() end

    local propsData = BW.Config and BW.Config.Props
    if not propsData then return end

    local sortedCategories = {}
    for catID in pairs(propsData) do
        table.insert(sortedCategories, catID)
    end

    table.sort(sortedCategories, function(a, b)
        local nameA = Translate("PropsCategory." .. a, a)
        local nameB = Translate("PropsCategory." .. b, b)
        return nameA < nameB
    end)

    for _, categoryID in ipairs(sortedCategories) do
        local models = propsData[categoryID]
        
        local cat = vgui.Create("DCollapsibleCategory", scroll)
        cat:Dock(TOP)
        cat:DockMargin(10, 5, 10, 5)
        
        cat:SetLabel(Translate("PropsCategory." .. categoryID, categoryID))
        cat:SetExpanded(true)
        
        local iconLayout = vgui.Create("DIconLayout", cat)
        iconLayout:SetSpaceX(6)
        iconLayout:SetSpaceY(6)
        iconLayout:SetBorder(8)
        
        cat:SetContents(iconLayout)

        for _, propData in ipairs(models) do
            local modelPath = propData[1]          
            local propHP    = propData.hp or 100 

            if not modelPath then continue end

            local icon = vgui.Create("SpawnIcon", iconLayout)
            icon:SetSize(64, 64)
            icon:SetModel(modelPath)
            
            
            icon.DoClick = function()
                net.Start("BW_SpawnProp")
                    net.WriteString(modelPath)
                net.SendToServer()
                
                surface.PlaySound("ui/buttonclickrelease.wav")
            end
            
            iconLayout:Add(icon)
        end
        
        cat:InvalidateLayout(true)
        cat:SizeToChildren(false, true)
    end
end

vgui.Register("BW_SpawnMenu_Props", PANEL, "EditablePanel")