local PANEL = {}

function PANEL:Init()
    self:Dock(FILL)

    local scroll = vgui.Create("DScrollPanel", self)
    scroll:Dock(FILL)

    local iconLayout = vgui.Create("DIconLayout", scroll)
    iconLayout:Dock(TOP)
    iconLayout:SetSpaceX(5)
    iconLayout:SetSpaceY(5)
    iconLayout:SetBorder(10)

    for _, prop in ipairs(BW.Config.Props) do
        local icon = vgui.Create("SpawnIcon", iconLayout)
        icon:SetSize(64, 64)
        icon:SetModel(prop)
        icon.DoClick = function()
            RunConsoleCommand("gm_spawn", prop)
            surface.PlaySound("ui/buttonclickrelease.wav")
        end
        iconLayout:Add(icon)
    end
end

vgui.Register("BW_SpawnMenu_Props", PANEL, "EditablePanel")