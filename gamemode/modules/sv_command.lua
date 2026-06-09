local MODULE = MODULE
MODULE.Name = "Command"
MODULE.Author = "Brov3r"
MODULE.Require = {"database", "notify"}

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
	if not sql.TableExists("bw_reports") then
        sql.Query([[
            CREATE TABLE bw_reports (
                id INTEGER PRIMARY KEY,
                steamid TEXT,
                name TEXT,
                text TEXT,
                timestamp INTEGER
            )
        ]])
    end

    local LoadoutCheck = {}
    if BW and BW.Config and BW.Config.PlayerLoadout then
        for _, class in ipairs(BW.Config.PlayerLoadout) do
            LoadoutCheck[class] = true
        end
    end

	self:AddCommand("report", function(ply, args)
        local reportText = table.concat(args, " ")
        
        if reportText == "" or string.Trim(reportText) == "" then
            ply:Notify(NOTIFY_ERROR, Translate("Command.Report.Hint", "Usage: /report [your message]"), 5)
            return
        end

        if string.len(reportText) > 500 then
            ply:Notify(NOTIFY_ERROR, Translate("Command.Report.TooLong", "Your report is too long! Max 500 characters."), 5)
            return
        end

        local safeText = sql.SQLStr(reportText)
        local safeSteamID = sql.SQLStr(ply:SteamID())
        local safeName = sql.SQLStr(ply:Nick())
        local timestamp = os.time()

        local query = string.format(
            "INSERT INTO bw_reports (steamid, name, text, timestamp) VALUES (%s, %s, %s, %d)",
            safeSteamID, safeName, safeText, timestamp
        )
        
        local result = sql.Query(query)

        if result == false then
            ply:Notify(NOTIFY_ERROR, Translate("Command.Report.DbError", "An error occurred while sending the report. Try again later."), 5)
            Log("error", "[Report System] Failed to save report to DB! SQL Error: " .. (sql.LastError() or "unknown") .. "\n")
            return
        end

        ply:Notify(NOTIFY_SUCCESS, Translate("Command.Report.Success", "Your report has been successfully sent to the administrators!"), 5)
		Log("Player", ply:Nick(), "(", ply:SteamID(), ")", "sent a report:", reportText)

        for _, admin in ipairs(player.GetAll()) do
            if admin:IsAdmin() or admin:IsSuperAdmin() then
                local text = string.format(Translate("Command.Report.AdminMsg", "<#5FF05F>[REPORT] <#FFA500>Player <#00FFFF>%s <#FFA500>(<#00FFFF>%s<#FFA500>) sent a report: <#00FFFF>%s"), ply:Nick(), ply:SteamID(), reportText)
				
				net.Start("BW_CustomChat_Message")
                net.WriteEntity(nil)
                net.WriteString(text)
                net.WriteBool(false)
                net.WriteBool(false )
                net.Send(admin)
            end
        end

    end, "Send a report or feedback to administrators", false, 60)

    self:AddCommand("botsay", function(ply, args)
        local text = table.concat(args, " ")
        if text == "" then return end

        for _, bot in ipairs(player.GetBots()) do
            bot:Say(text)
        end
    end, "Forces all bots to say a message", true, 0)
    
    self:AddCommand("drop", function(ply, args)
        local activeWep = ply:GetActiveWeapon()
        if not IsValid(activeWep) then return end
        
        local wepClass = activeWep:GetClass()

        if LoadoutCheck[wepClass] then
            ply:Notify(NOTIFY_ERROR, Translate("Command.Drop.Error", "You can't throw away this weapon!"), 5)
            return
        end

        local ammo = ply:GetAmmoCount(activeWep:GetPrimaryAmmoType())

        local ent = ents.Create("spawned_weapon")
        if not IsValid(ent) then return end

        local tr = ply:GetEyeTrace()
        local pos = (tr.StartPos:DistToSqr(tr.HitPos) > 40000) and (ply:GetShootPos() + ply:GetAimVector() * 80) or (tr.HitPos + tr.HitNormal * 15)
        ent:SetPos(pos)
        ent:Spawn()
        
        ent:SetWeaponClass(wepClass)
        ent:SetAmmoCount(ammo)

        local ammoType = activeWep:GetPrimaryAmmoType()
        if ammoType ~= -1 then
            ply:RemoveAmmo(ammo, ammoType)
        end
        ply:StripWeapon(wepClass)

        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:ApplyForceCenter(ply:GetAimVector() * 300)
        end

        ply:Notify(NOTIFY_SUCCESS, string.format(Translate("Command.Drop.Success", "You've thrown away %s!"), Translate("Weapons."..wepClass, Translate(wepClass, activeWep:GetPrintName()))), 5)
    end, "Throw the weapon on the floor", false, 3)

   self:AddCommand("dropmoney", function(ply, args)
        local amount = tonumber(args[1])
        
        if not amount or amount <= 0 then
            ply:Notify(NOTIFY_ERROR, Translate("Command.DropMoney.Hint", "Usage: /dropmoney [amount]"), 5)
            return
        end

        if not ply:HasMoney(amount) then
            ply:Notify(NOTIFY_ERROR, Translate("Command.DropMoney.NoMoney", "You don't have enough money!"), 5)
            return
        end

        ply:TakeMoney(amount)

        local ent = ents.Create("spawned_money")
        if not IsValid(ent) then return end

        ent:SetAmount(amount)
        
        local tr = ply:GetEyeTrace()
        local pos = (tr.StartPos:DistToSqr(tr.HitPos) > 40000) and (ply:GetShootPos() + ply:GetAimVector() * 80) or (tr.HitPos + tr.HitNormal * 15)
        ent:SetPos(pos)
        ent:Spawn()
        ent:Activate()

        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:ApplyForceCenter(ply:GetAimVector() * 200 + Vector(0, 0, 100))
        end

        ply:Notify(NOTIFY_SUCCESS, string.format(Translate("Command.DropMoney.Success", "You've thrown away %s%s!"),BW.Config.Economy.Currency, amount), 5)
    end, "Throw the money on the floor", false, 5)
end