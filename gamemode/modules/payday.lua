MODULE.Name   = "PayDay"
MODULE.Author = "Brov3r"
MODULE.Realm  = BW.REALM_SERVER

function MODULE:Init()
    local interval = math.max(tonumber(BW.Config.PayDayInterval) or 300, 30)
    
    timer.Create("BW_PayDay", interval, 0, function()
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and not ply:IsBot() then
                self:GivePayDay(ply)
            end
        end
    end)
end

function MODULE:GetPayDayMultiplier(ply)
    if not IsValid(ply) then return 1 end
    
    local userGroup = ply:GetUserGroup()
    local groupConfig = BW.Config.PlayerGroups and BW.Config.PlayerGroups[userGroup] or BW.Config.PlayerGroup and BW.Config.PlayerGroup[userGroup]
    
    if groupConfig and groupConfig.PayDayMultiplier then
        return tonumber(groupConfig.PayDayMultiplier) or 1
    end
    
    return 1
end

function MODULE:GivePayDay(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local minPay = math.floor(tonumber(BW.Config.PayDayDefaultMin) or 100)
    local maxPay = math.floor(tonumber(BW.Config.PayDayDefaultMax) or 500)
    
    if minPay > maxPay then minPay, maxPay = maxPay, minPay end

    local basePay = math.random(minPay, maxPay)
    local multiplier = self:GetPayDayMultiplier(ply)
    local finalPay = math.floor(basePay * multiplier)

    ply:AddMoney(finalPay)

    local translateText = (BW.Translate and BW.Translate.PayDay) or "Salary! You have received $%s!"
    local text = string.format(translateText, BW.Utils.StringNumber(finalPay))

    ply:Notify(NOTIFY_SUCCESS, text, 5)
end