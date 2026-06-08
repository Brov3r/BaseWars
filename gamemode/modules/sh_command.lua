local MODULE = MODULE
MODULE.Name = "Command"
MODULE.Author = "Brov3r"
MODULE.Require = {"database", "notify"}

MODULE.Commands = MODULE.Commands or {}

function MODULE:AddCommand(cmdName, callback, description, adminOnly)
    local name = string.lower(cmdName)
    
    self.Commands[name] = {
        callback = callback,
        description = description or "No description",
        adminOnly = adminOnly or false
    }

    concommand.Add(name, function(ply, cmd, args, fullStr)
        if adminOnly and IsValid(ply) and not ply:IsAdmin() then
            if IsValid(ply) then ply:Notify(NOTIFY_ERROR, Translate("Command.NoPermission", "You don't have the rights to use this command."), 5) end
            return
        end
        callback(ply, args)
    end, nil, description)
end

function MODULE:Init()
    hook.Add("PlayerSay", "BW_ChatCommands", function(ply, text)
        local args = string.Explode(" ", text)
        local cmdName = string.lower(string.sub(args[1], 2))
        
        if string.sub(args[1], 1, 1) == "/" and self.Commands[cmdName] then
            local cmdData = self.Commands[cmdName]
            
            if cmdData.adminOnly and not ply:IsAdmin() then
				ply:Notify(NOTIFY_ERROR, Translate("Command.NoPermission", "You don't have the rights to use this command."), 5)
                return ""
            end
            
            table.remove(args, 1)
            cmdData.callback(ply, args)
            return ""
        end
    end)

    self:RegisterDefaultCommands()
end

function MODULE:RegisterDefaultCommands()
	self:AddCommand("botsay", function(ply, args)
        local text = table.concat(args, " ")
        if text == "" then return end

        for _, bot in ipairs(player.GetBots()) do
            bot:Say(text)
        end
    end, "Forces all bots to say a message", true)
	
	self:AddCommand("drop", function(ply, args)
		local activeWep = ply:GetActiveWeapon()

		if not IsValid(activeWep) then return end
		
		local wepClass = activeWep:GetClass()
		
		local LoadoutCheck = {}
		for _, class in ipairs(BW.Config.PlayerLoadout) do
			LoadoutCheck[class] = true
		end

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
	end, "Throw the weapon on the floor", false)

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
	end, "Throw the money on the floor", false)
end