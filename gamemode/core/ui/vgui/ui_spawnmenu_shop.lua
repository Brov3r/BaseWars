local PANEL = {}

function PANEL:Init()
    self:Dock(FILL)
end

function PANEL:Paint(w, h)
    
end

vgui.Register("BW_SpawnMenu_Shop", PANEL, "EditablePanel")