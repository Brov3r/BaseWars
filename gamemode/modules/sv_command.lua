local MODULE = MODULE
MODULE.Name = "Command"
MODULE.Author = "Brov3r"
MODULE.Require = {"database", "notify", "ownership"}

MODULE.Commands = MODULE.Commands or {}
MODULE.Cooldowns = MODULE.Cooldowns or {}

function MODULE:CanRunCommand(ply, cmdName)
    local cmdData = self.Commands[cmdName]
    if not cmdData then return false end

    if not IsValid(ply) then return true end

    if cmdData.adminOnly and not ply:IsAdmin() then
        ply:Notify(NOTIFY_ERROR, Translate("Command.NoPermission", "You don't have the rights to use this command."), 5)
        return false
    end

    if cmdData.cooldown > 0 then
        local sid = ply:SteamID64()
        
        self.Cooldowns[sid] = self.Cooldowns[sid] or {}

        local expireTime = self.Cooldowns[sid][cmdName] or 0
        if CurTime() < expireTime then
            local timeLeft = math.ceil(expireTime - CurTime())
            ply:Notify(NOTIFY_ERROR, string.format(Translate("Command.Cooldown", "Wait %s sec. before using it again."), timeLeft), 5)
            return false
        end

        self.Cooldowns[sid][cmdName] = CurTime() + cmdData.cooldown
    end

    return true
end

function MODULE:AddCommand(cmdName, callback, description, adminOnly, cooldown)
    local name = string.lower(cmdName)
    
    self.Commands[name] = {
        callback = callback,
        description = description or "No description",
        adminOnly = adminOnly or false,
        cooldown = cooldown or 0
    }

    concommand.Add(name, function(ply, cmd, args, fullStr)
        if not self:CanRunCommand(ply, name) then return end
        
        callback(ply, args)
    end, nil, description)
end

function MODULE:Init()
    self.LoadoutCheck = {}
    for _, class in ipairs(BW.Config.PlayerLoadout) do self.LoadoutCheck[class] = true end
    hook.Add("PlayerSay", "BW_ChatCommands", function(ply, text)
        local args = string.Explode(" ", text)
        local cmdName = string.lower(string.sub(args[1], 2))
        
        if string.sub(args[1], 1, 1) == "/" and self.Commands[cmdName] then
            if not self:CanRunCommand(ply, cmdName) then return "" end
            
            local cmdData = self.Commands[cmdName]
            table.remove(args, 1)
            cmdData.callback(ply, args)
            return ""
        end
    end)

    hook.Add("PlayerDisconnected", "BW_ClearCooldowns", function(ply)
        local sid = ply:SteamID64()
        if sid then
            self.Cooldowns[sid] = nil
        end
    end)

    self:RegisterDefaultCommands()
end

function MODULE:RegisterDefaultCommands()
    self:AddCommand("sell", function(ply, args)
        if not IsValid(ply) or not ply:Alive() then return end

        local tr = ply:GetEyeTrace()
        local ent = tr.Entity

        if not IsValid(ent) or ent:IsPlayer() or ent:IsNPC() or ent:IsWorld() then
            ply:Notify(NOTIFY_ERROR, Translate("Command.Sell.Invalid", "Look at a valid object to sell!"), 5)
            return
        end

        if ply:GetShootPos():DistToSqr(ent:GetPos()) > 250^2 then
            ply:Notify(NOTIFY_ERROR, Translate("Command.Sell.TooFar", "You are too far away from the object!"), 5)
            return
        end

        -- First ownership check
        local owner = BW.Ownership.GetOwner(ent)
        local isOwner = owner == ply
        
        if not isOwner then
            ply:Notify(NOTIFY_ERROR, Translate("Command.Sell.NotYour", "This object does not belong to you!"), 5)
            return
        end

        if ent.IsBeingSold then return end
        ent.IsBeingSold = true

        local cost = ent.DeviceCost or 0
        if cost <= 0 then
            ply:Notify(NOTIFY_ERROR, Translate("Command.Sell.NoValue", "This item has no value and cannot be sold."), 5)
            ent.IsBeingSold = nil
            return
        end

        -- Verify entity still exists and player still owns it before processing
        if not IsValid(ent) then return end
        owner = BW.Ownership.GetOwner(ent)
        isOwner = owner == ply
        
        if not isOwner then
            ply:Notify(NOTIFY_ERROR, Translate("Command.Sell.NotYour", "This object does not belong to you!"), 5)
            ent.IsBeingSold = nil
            return
        end

        local maxHealth = ent:GetMaxHealth()
        local currentHealth = ent:Health()
        local healthRatio = (maxHealth > 0) and math.Clamp(currentHealth / maxHealth, 0, 1) or 1

        local userGroup = ply:GetUserGroup()
        local groupConfig = BW and BW.Config and BW.Config.PlayerGroups and BW.Config.PlayerGroups[userGroup]
        
        local sellRatio = groupConfig and groupConfig.SellReturnRatio 
            or (BW and BW.Config and BW.Config.Economy and BW.Config.Economy.SellReturnRatioDefault) 
            or 0.3

        local refundAmount = math.floor(cost * healthRatio * math.Clamp(sellRatio, 0, 1))
        if ply:GetMoney() + refundAmount > BW.Config.Economy.MaxMoney then
            ent.IsBeingSold = nil
            ply:Notify(NOTIFY_ERROR, Translate("Command.BalanceLimit", "Your balance limit would be exceeded."), 5)
            return
        end

        if refundAmount > 0 and ply.AddMoney then
            ply:AddMoney(refundAmount)
        end

        local entName = ent.PrintName or ent:GetClass()
        if ent.GetTranslatedName then entName = ent:GetTranslatedName() end

        local currency = (BW and BW.Config and BW.Config.Economy.Currency) or "$"
        local formattedAmount = (BW and BW.Utils and BW.Utils.NumWithSep) and BW.Utils.NumWithSep(refundAmount) or refundAmount

        local successMsg = string.format(Translate("Command.Sell.Success", "You successfully sold %s for %s%s!"), entName, currency, formattedAmount)

        ply:Notify(NOTIFY_SUCCESS, successMsg, 5)
        
        -- Final check before removing
        if IsValid(ent) then
            ent:Remove()
        end
    end, "Sell the object you are looking at", false, 1)

    self:AddCommand("botsay", function(ply, args)
        local text = table.concat(args, " ")
        if text == "" then return end

        for _, bot in ipairs(player.GetBots()) do
            bot:Say(text)
        end
    end, "Forces all bots to say a message", true, 0)
    
    self:AddCommand("drop", function(ply, args)
        if not IsValid(ply) or not ply:Alive() then return end
        local activeWep = ply:GetActiveWeapon()
        if not IsValid(activeWep) then return end
        
        local wepClass = activeWep:GetClass()
        if not wepClass or wepClass == "" then return end
        
        if self.LoadoutCheck[wepClass] then
            ply:Notify(NOTIFY_ERROR, Translate("Command.Drop.Error", "You can't throw away this weapon!"), 5)
            return
        end

        local ammoType = activeWep:GetPrimaryAmmoType()
        local reserve = ammoType >= 0 and math.max(0, ply:GetAmmoCount(ammoType)) or 0
        local ammoCount = reserve + math.max(0, activeWep:Clip1())

        local ent = ents.Create("spawned_weapon")
        if not IsValid(ent) then return end

        local tr = ply:GetEyeTrace()
        local pos = (tr.StartPos:DistToSqr(tr.HitPos) > 40000) and (ply:GetShootPos() + ply:GetAimVector() * 80) or (tr.HitPos + tr.HitNormal * 15)
        
        ent:SetPos(pos)
        ent:SetWeaponClass(wepClass)
        ent:Spawn()
        if not IsValid(ent) then return end
        ent:SetAmmoCount(ammoCount)
        
        -- Only strip weapon after entity is created and spawned
        ply:StripWeapon(wepClass)
        
        if ammoType >= 0 and reserve > 0 then
            ply:RemoveAmmo(reserve, ammoType)
        end

        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:ApplyForceCenter(ply:GetAimVector() * 300)
        end
    end, "Throw the weapon on the floor", false, 3)

   self:AddCommand("dropmoney", function(ply, args)
        if not IsValid(ply) or not ply:Alive() or (not ply:IsBot() and not ply.BW_StatsLoaded) then return end
        local amount = tonumber(args[1])
        
        if not BW.Utils.IsFinite(amount) or amount <= 0 or amount > BW.Config.Economy.MaxMoney then
            ply:Notify(NOTIFY_ERROR, Translate("Command.DropMoney.Hint", "Usage: /dropmoney [amount]"), 5)
            return
        end
        
        -- Ensure amount is an integer
        amount = math.floor(amount)
        if amount <= 0 then
            ply:Notify(NOTIFY_ERROR, Translate("Command.DropMoney.Hint", "Usage: /dropmoney [amount]"), 5)
            return
        end

        if not ply:HasMoney(amount) then
            ply:Notify(NOTIFY_ERROR, Translate("Command.DropMoney.NoMoney", "You don't have enough money!"), 5)
            return
        end

        local ent = ents.Create("spawned_money")
        if not IsValid(ent) then return end

        ent:SetAmount(amount)
        
        local tr = ply:GetEyeTrace()
        local pos = (tr.StartPos:DistToSqr(tr.HitPos) > 40000) and (ply:GetShootPos() + ply:GetAimVector() * 80) or (tr.HitPos + tr.HitNormal * 15)
        ent:SetPos(pos)
        ent:Spawn()
        if not IsValid(ent) then return end
        ent:Activate()
        
        -- Only take money after entity is created and spawned
        ply:TakeMoney(amount)

        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:ApplyForceCenter(ply:GetAimVector() * 200 + Vector(0, 0, 100))
        end

        ply:Notify(NOTIFY_SUCCESS, string.format(Translate("Command.DropMoney.Success", "You've thrown away %s%s!"),BW.Config.Economy.Currency, amount), 5)
    end, "Throw the money on the floor", false, 5)
end
