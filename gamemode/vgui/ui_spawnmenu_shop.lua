local ITEM_PANEL = {}

function ITEM_PANEL:Init()
    self:SetSize(70, 70)
    self:SetText("") 
    
    self.ModelPanel = vgui.Create("SpawnIcon", self)
    self.ModelPanel:Dock(FILL)
    self.ModelPanel:DockMargin(4, 4, 4, 4) 
    self.ModelPanel:SetMouseInputEnabled(false)
end

function ITEM_PANEL:SetItemData(id, data)
    self.ItemName = Translate("ShopItems." .. id, id)
    self.ItemID = id
    self.ItemData = data
    
    if data.model then
        self.ModelPanel:SetModel(data.model)
    end
end

function ITEM_PANEL:OnCursorEntered()
    if IsValid(BW_ShopTooltip) then BW_ShopTooltip:Remove() end
    if not self.ItemData then return end
    
    local data = self.ItemData
    local c = BW.Config.Colors
    
    local tip = vgui.Create("DPanel")
    tip:SetDrawOnTop(true)
    tip:SetMouseInputEnabled(false)
    
    local labels = {}
    
    local lblName = vgui.Create("DLabel", tip)
    lblName:SetText(self.ItemName)
    lblName:SetFont("Inter14")
    lblName:SetTextColor(c.White or color_white)
    lblName:SizeToContents()
    table.insert(labels, lblName)
    
    if data.desc then
        local lblDesc = vgui.Create("DLabel", tip)
        lblDesc:SetText(Translate(data.desc, data.desc))
        lblDesc:SetFont("Inter12")
        lblDesc:SetTextColor(c.LightGray or Color(200, 200, 200))
        lblDesc:SetWrap(true)
        lblDesc:SetWide(200)
        lblDesc:SizeToContentsY()
        table.insert(labels, lblDesc)
    end
    
    local basePrice = data.price or 0
    local finalPrice = BW.GetFinalPrice(LocalPlayer(), basePrice)
    local finalPriceText = BW.Utils and BW.Utils.CompactNum(BW.GetFinalPrice(LocalPlayer(), basePrice)) or finalPrice
    local currency = (BW.Config and BW.Config.Economy and BW.Config.Economy.Currency) or "$"

    if basePrice ~= finalPrice then
        local lblPrice = vgui.Create("DLabel", tip)
        lblPrice:SetText(Translate("Shop.Price", "Price:").. " " .. currency .. finalPriceText)
        lblPrice:SetFont("Inter12")
        lblPrice:SetTextColor(c.Success or Color(100, 255, 100))
        lblPrice:SizeToContents()
        table.insert(labels, lblPrice)
    end
    
    if data.lvl and data.lvl > 0 then
        local lblLvl = vgui.Create("DLabel", tip)
        lblLvl:SetText(Translate("Shop.Level", "Level:").." " .. data.lvl)
        lblLvl:SetFont("Inter12")
        lblLvl:SetTextColor(c.Info or Color(100, 180, 255))
        lblLvl:SizeToContents()
        table.insert(labels, lblLvl)
    end

    if data.max and data.max > 0 then
        local lblMax = vgui.Create("DLabel", tip)
        lblMax:SetText(Translate("Shop.Max", "Max:").. " " .. data.max)
        lblMax:SetFont("Inter12")
        lblMax:SetTextColor(c.Info or Color(255, 193, 7))
        lblMax:SizeToContents()
        table.insert(labels, lblMax)
    end

    if data.vip then
        local lblVip = vgui.Create("DLabel", tip)
        lblVip:SetText(Translate("Shop.VIP", "★ VIP ONLY ★"))
        lblVip:SetFont("Inter12")
        lblVip:SetTextColor(c.Amber or Color(255, 193, 7))
        lblVip:SizeToContents()
        table.insert(labels, lblVip)
    end
    
    
    local padding = 10
    local currentY = padding
    local maxWidth = 160 
    
    for _, lbl in ipairs(labels) do
        if lbl:GetWide() > maxWidth then
            maxWidth = lbl:GetWide()
        end
    end
    
    if data.desc then
        maxWidth = 220 
        for _, lbl in ipairs(labels) do
            if lbl:GetWrap() then 
                lbl:SetWide(maxWidth - (padding * 2)) 
                lbl:SizeToContentsY() 
            end
        end
    end
    
    for _, lbl in ipairs(labels) do
        lbl:SetPos(padding, currentY)
        currentY = currentY + lbl:GetTall() + 4
    end
    
    tip:SetSize(maxWidth + (padding * 2), currentY - 4 + padding)
    
    tip.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(20, 20, 20, 245))
        surface.SetDrawColor(75, 75, 75, 150)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    
    function tip:Think()
        if not IsValid(self.Owner) or not self.Owner:IsHovered() then
            self:Remove()
            return
        end
        
        local mx, my = gui.MouseX(), gui.MouseY()
        local scrW, scrH = ScrW(), ScrH()
        
        local x = mx + 15
        local y = my + 15
        
        if x + self:GetWide() > scrW then x = mx - self:GetWide() - 15 end
        if y + self:GetTall() > scrH then y = scrH - self:GetTall() - 10 end
        
        self:SetPos(x, y)
    end
    
    tip.Owner = self
    BW_ShopTooltip = tip
end

function ITEM_PANEL:OnCursorExited()
    if IsValid(BW_ShopTooltip) and BW_ShopTooltip.Owner == self then
        BW_ShopTooltip:Remove()
    end
end

function ITEM_PANEL:OnRemove()
    if IsValid(BW_ShopTooltip) and BW_ShopTooltip.Owner == self then
        BW_ShopTooltip:Remove()
    end
end
function ITEM_PANEL:Paint(w, h)
    if not self.ItemData then return end 

    local ply = LocalPlayer()
    local price = self.ItemData.price or 0
    local finalPrice = BW.GetFinalPrice(ply, price)
    local lvl = self.ItemData.lvl or 0
    local vip = self.ItemData.vip or false

    local hasPrivilege = (ply.HasPrivilege and ply:HasPrivilege()) or false
    local hasLevel = (ply.HasLevel and ply:HasLevel(lvl)) or (not ply.HasLevel)
    local myMoney = (ply.GetMoney and ply:GetMoney())
    
    local c = BW.Config.Colors
    local DrawCol = c.ShopAvailable

    if vip and not hasPrivilege then
        DrawCol = c.VipGold
    elseif not hasLevel then
        DrawCol = c.ShopLocked
    elseif finalPrice <= 0 then
        DrawCol = c.Transparent
    elseif myMoney then
        if finalPrice >= myMoney * 2 then
            DrawCol = c.ShopLocked
        elseif finalPrice > myMoney then
            DrawCol = c.ShopNoMoney
        elseif finalPrice < myMoney / 100 then
            DrawCol = c.ShopCheap
        end
    else
        local hasMoney = (ply.HasMoney and ply:HasMoney(finalPrice)) or false
        if not hasMoney then DrawCol = c.ShopNoMoney end
    end

    draw.RoundedBox(4, 0, 0, w, h, DrawCol)
end

function ITEM_PANEL:PaintOver(w, h)
    if not self.ItemData then return end

    local ply = LocalPlayer()
    local price = self.ItemData.price or 0
    local finalPrice = BW.GetFinalPrice(LocalPlayer(), price)
    local lvl = self.ItemData.lvl or 0
    local vip = self.ItemData.vip or false
    
    local hasPrivilege = (ply.HasPrivilege and ply:HasPrivilege()) or false
    local hasLevel = (ply.HasLevel and ply:HasLevel(lvl)) or (not ply.HasLevel)
    
    local c = BW.Config.Colors
    local clr_white = c.White or color_white

    if vip and not hasPrivilege then
        surface.SetDrawColor(c.VipGold.r, c.VipGold.g, c.VipGold.b, 100)
        surface.DrawRect(0, 0, w, h)

        draw.SimpleText("VIP", "Inter20", w / 2, h / 2, c.TextShade, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("VIP", "Inter20", w / 2 - 2, h / 2 - 2, clr_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        return
    end

    if not hasLevel then
        surface.SetDrawColor(0, 0, 0, 100)
        surface.DrawRect(0, 0, w, h)

        local lvlText = "LVL " .. lvl
        draw.SimpleText(lvlText, "Inter16", w / 2, h / 2, c.TextShade, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(lvlText, "Inter16", w / 2 - 2, h / 2 - 2, clr_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        return
    end

    local name = self.ItemName or "Unknown"
    local truncName = BW.Utils.TruncateText and BW.Utils.TruncateText(name, "Inter12", 64) or name

    draw.SimpleText(truncName, "Inter12", w / 2 + 2, 4, c.TextShade, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    draw.SimpleText(truncName, "Inter12", w / 2, 2, clr_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

    if price > 0 then
        local currency = (BW.Config and BW.Config.Economy and BW.Config.Economy.Currency) or "$"
        
        local finalPriceText = BW.Utils and BW.Utils.CompactNum(finalPrice) or finalPrice
        local priceText = currency .. finalPriceText
        draw.SimpleText(priceText, "Inter14", w / 2 + 2, h - 2, c.TextShade, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
        draw.SimpleText(priceText, "Inter14", w / 2, h - 4, clr_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
    end

    if self:IsHovered() then
        surface.SetDrawColor(255, 255, 255, 40)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
end

function ITEM_PANEL:DoClick()
    if not self.ItemData then return end
    
    local ply = LocalPlayer()
    local price = self.ItemData.price or 0
    local finalPrice = BW.GetFinalPrice(ply, price)
    local lvl = self.ItemData.lvl or 0
    local vip = self.ItemData.vip or false
    local maxLimit = self.ItemData.max or 0
    
    local hasPrivilege = (ply.HasPrivilege and ply:HasPrivilege()) or false
    local hasLevel = (ply.HasLevel and ply:HasLevel(lvl)) or (not ply.HasLevel)
    local hasMoney = (ply.HasMoney and ply:HasMoney(finalPrice)) or false

    if vip and not hasPrivilege then
        if ply.Notify then ply:Notify(NOTIFY_ERROR, Translate("Shop.VIPAlert", "This item is only available for VIP!"), 5) end
        return
    end

    if not hasLevel then
        if ply.Notify then ply:Notify(NOTIFY_ERROR,  Translate("Shop.LvlAlert", "Insufficient level!"), 5) end
        return
    end

    if maxLimit > 0 then
        local currentCount = ply:GetNWInt("BW_ItemCount_" .. self.ItemID, 0)
        
        if currentCount >= maxLimit then
            if ply.Notify then 
                ply:Notify(NOTIFY_ERROR, string.format(Translate("Shop.MaxLimitAlert", "You have reached the limit for this item! (Max: %s)"), tostring(maxLimit)), 5) 
            end
            return 
        end
    end

    if not hasMoney then
        if ply.Notify then ply:Notify(NOTIFY_ERROR,  Translate("Shop.MoneyAlert", "Insufficient money!"), 5) end
        return
    end

    net.Start("BW_BuyShopItem")
        net.WriteString(self.ItemID)
    net.SendToServer()
    
    surface.PlaySound("buttons/button14.wav")
end

vgui.Register("BW_ShopItem", ITEM_PANEL, "DButton")

local PANEL = {}

function PANEL:Init()
    self:Dock(FILL)
    
    self.Scroll = vgui.Create("DScrollPanel", self)
    self.Scroll:Dock(FILL)
    
    local sbar = self.Scroll:GetVBar()
    sbar:SetWide(10)
    sbar.Paint = function(s, w, h) draw.RoundedBox(0, 0, 0, w, h, Color(40, 40, 40, 100)) end
    sbar.btnGrip.Paint = function(s, w, h)
        local color = s:IsHovered() and Color(150, 150, 150) or Color(100, 100, 100)
        draw.RoundedBox(4, 2, 0, w - 4, h, color)
    end
    sbar.btnUp.Paint = function() end
    sbar.btnDown.Paint = function() end

    self:BuildShop()
end

function PANEL:BuildShop()
    self.Scroll:Clear()
    
    local shopData = BW.Config and BW.Config.Shop
    if not shopData then return end
    
    local sortedCategories = {}
    for catID in pairs(shopData) do
        table.insert(sortedCategories, catID)
    end
    
    table.sort(sortedCategories, function(a, b)
        return Translate("ShopCategory." .. a, a) < Translate("ShopCategory." .. b, b)
    end)
    
    for _, categoryID in ipairs(sortedCategories) do
        local items = shopData[categoryID]
        
        local cat = vgui.Create("DCollapsibleCategory", self.Scroll)
        cat:Dock(TOP)
        cat:DockMargin(10, 0, 10, 8)
        cat:SetLabel(Translate("ShopCategory." .. categoryID, categoryID))
        
        local list = vgui.Create("DIconLayout", cat)
        list:SetSpaceX(5)
        list:SetSpaceY(5)
        list:SetBorder(5)
        cat:SetContents(list)
        
        local sortedItems = {}
        for itemID, itemData in pairs(items) do
            table.insert(sortedItems, {
                id = itemID,
                data = itemData,
                price = itemData.price or 0
            })
        end

        table.sort(sortedItems, function(a, b)
            return a.price < b.price
        end)
        
        for _, itemInfo in ipairs(sortedItems) do
            local item = list:Add("BW_ShopItem")
            item:SetItemData(itemInfo.id, itemInfo.data)
        end
        
        cat:InvalidateLayout(true)
        cat:SizeToChildren(false, true)
    end
end

vgui.Register("BW_SpawnMenu_Shop", PANEL, "EditablePanel")