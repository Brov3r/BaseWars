local function GetPayDayMultiplier(ply)
    if not IsValid(ply) then return 1 end
    return BW.Config.PayDayMultiplier[ply:GetUserGroup()] or 1
end

local function GivePayDay(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local basePay = math.random(BW.Config.PayDayDefaultMin, BW.Config.PayDayDefaultMax)
    local multiplier = GetPayDayMultiplier(ply)
    local finalPay = math.floor(basePay * multiplier)

    ply:AddMoney(finalPay)

    local translateText = BW.Translate.PayDay or "Salary! You have received $%s!"
    local text = string.format(translateText, BW.Utils.StringMoney(finalPay))
    ply:Notify(NOTIFY_SUCCESS, text, 5)
end

timer.Create("BW_PayDay", BW.Config.PayDayInterval, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            GivePayDay(ply)
        end
    end
end)