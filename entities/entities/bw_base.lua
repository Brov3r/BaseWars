if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Base Device"
ENT.Author = "Brov3r"
ENT.Spawnable = false

ENT.DeviceCost = 0
ENT.AutoRefund = false
ENT.DefaultMaxHealth = 100
ENT.DefaultModel = "models/items/battery.mdl"
ENT.TriggerOnTouch = true

local DEFAULT_MODEL = "models/items/battery.mdl"

local function GetBWConfig(path_func, default_val)
    if not BW or not BW.Config then return default_val end
    local success, result = pcall(path_func)
    return success and result or default_val
end

local function ToFiniteNumber(value, default)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then
        return default
    end
    return value
end

local function StartsWith(text, prefix)
    return isstring(text) and string.sub(text, 1, #prefix) == prefix
end

local function FormatMoney(amount)
    if BW and BW.Utils and type(BW.Utils.NumWithSep) == "function" then
        return BW.Utils.NumWithSep(amount)
    end
    return amount
end

function ENT:GetTranslatedName()
    local id = self.ID
    if isstring(id) and id ~= "" and type(Translate) == "function" then
        return Translate("ShopItems." .. id, self.PrintName or id)
    end
    return self.PrintName or (self.GetClass and self:GetClass()) or "Device"
end

function ENT:GetDeviceOwner()
    local owner = self.Owner
    if not IsValid(owner) then
        owner = self:GetNWEntity("Owner")
    end
    if not IsValid(owner) and BW and BW.Ownership and type(BW.Ownership.GetOwner) == "function" then
        local success, result = pcall(BW.Ownership.GetOwner, self)
        if success then owner = result end
    end
    return owner
end

function ENT:GetRefundData(ply)
    local cost = ToFiniteNumber(self.DeviceCost, 0)
    if cost <= 0 or not IsValid(ply) or not ply:IsPlayer() then
        return 0, GetBWConfig(function() return BW.Config.Economy.Currency end, "$")
    end

    local userGroup = ply:GetUserGroup()

    local sellRatio = GetBWConfig(function() return BW.Config.PlayerGroups[userGroup].SellReturnRatio end, nil)
    if not sellRatio then
        sellRatio = GetBWConfig(function() return BW.Config.Economy.SellReturnRatioDefault end, 0.3)
    end

    -- Never allow bad configuration values to create money out of thin air.
    sellRatio = math.Clamp(ToFiniteNumber(sellRatio, 0.3), 0, 1)

    local currency = GetBWConfig(function() return BW.Config.Economy.Currency end, "$")

    return math.floor(cost * sellRatio), currency
end

if SERVER then

    function ENT:Initialize()
        local model = self.Model
        if not isstring(model) or model == "" then
            model = self.DefaultModel or DEFAULT_MODEL
        end

        if util and type(util.IsValidModel) == "function" and not util.IsValidModel(model) then
            model = self.DefaultModel or DEFAULT_MODEL
        end

        local currentModel = self:GetModel()
        if not isstring(currentModel) or currentModel == "" or currentModel == "models/error.mdl" then
            self:SetModel(model)
        end

        local maxHealth = math.max(0, ToFiniteNumber(self.DefaultMaxHealth, 100))
        self:SetMaxHealth(maxHealth)
        self:SetHealth(maxHealth)

        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)

        -- Touch is only needed by devices that consume physical modules.
        self:SetTrigger(self.TriggerOnTouch ~= false)

        if self.AutoRefund then
            self:StartAutoRefund()
        end
    end

    function ENT:StartAutoRefund()
        local refundTime = math.max(1, ToFiniteNumber(
            GetBWConfig(function() return BW.Config.Economy.AutoRefundTime end, 30),
            30
        ))
        local timerName = "DeviceAutoRefund_" .. self:EntIndex()

        timer.Remove(timerName)

        local owner = self:GetDeviceOwner()
        if IsValid(owner) and owner:IsPlayer() and type(owner.Notify) == "function" then
            local msg = string.format(
                Translate("Entity.AutoRefunNotify", "You have %s sec. to use '%s', then it will be sold!"),
                refundTime,
                self:GetTranslatedName()
            )
            owner:Notify(NOTIFY_WARNING, msg, 5)
        end

        timer.Create(timerName, refundTime, 1, function()
            if not IsValid(self) or self.IsBeingSold or self.IsBeingRefunded or self.IsDestroyed then return end

            self.IsBeingRefunded = true
            local currentOwner = self:GetDeviceOwner()

            if IsValid(currentOwner) and currentOwner:IsPlayer() then
                local refundAmount, currency = self:GetRefundData(currentOwner)

                if refundAmount > 0 and type(currentOwner.AddMoney) == "function" then
                    currentOwner:AddMoney(refundAmount)

                    local msg = string.format(
                        Translate("Entity.RefundTime", "Your '%s' has expired and %s%s has been returned!"),
                        self:GetTranslatedName(),
                        currency,
                        FormatMoney(refundAmount)
                    )
                    if type(currentOwner.Notify) == "function" then
                        currentOwner:Notify(NOTIFY_SUCCESS, msg, 5)
                    end
                end
            end

            self:Remove()
        end)
    end

    function ENT:OnTakeDamage(dmginfo)
        if self.IsDestroyed or ToFiniteNumber(self.DefaultMaxHealth, 0) <= 0 then return end
        if not dmginfo or type(dmginfo.GetDamage) ~= "function" then return end

        local damage = ToFiniteNumber(dmginfo:GetDamage(), 0)
        if damage <= 0 then return end

        local currentHealth = ToFiniteNumber(self:Health(), 0)
        local newHealth = math.max(0, currentHealth - damage)

        self:SetHealth(math.Clamp(newHealth, 0, self:GetMaxHealth()))

        if newHealth <= 0 then
            self.IsDestroyed = true
            local attacker = type(dmginfo.GetAttacker) == "function" and dmginfo:GetAttacker() or nil
            self:DoExplosion(attacker)
        end
    end

    function ENT:RefundMoney(ply)
        if self.Refunded then return end

        local refundAmount, currency = self:GetRefundData(ply)

        if refundAmount <= 0 or not IsValid(ply) or type(ply.AddMoney) ~= "function" then return end

        self.Refunded = true

        local rawText = "You have received %s%s for destruction: %s"
        if type(Translate) == "function" then
            rawText = Translate("Entity.RefundDestroy", rawText)
        end

        local text = string.format(rawText, currency, FormatMoney(refundAmount), self:GetTranslatedName())

        if type(ply.Notify) == "function" then
            ply:Notify(NOTIFY_INFO, text, 5)
        end
        ply:AddMoney(refundAmount)
    end

    function ENT:DoExplosion(attacker)
        if self.IsExploding then return end
        self.IsExploding = true

        local pos = self:GetPos()

        local effect = EffectData()
        effect:SetOrigin(pos)
        effect:SetScale(1)
        util.Effect("Explosion", effect)

        util.BlastDamage(self, IsValid(attacker) and attacker or self, pos, 200, 25)

        if IsValid(attacker) and attacker:IsPlayer() then
            self:RefundMoney(attacker)
        end

        self:Remove()
    end

    function ENT:OnRemove()
        timer.Remove("DeviceAutoRefund_" .. self:EntIndex())
    end

    function ENT:Touch(ent)
        if not IsValid(ent) then return end

        local class = ent:GetClass()
        local isModule = ent.IsBWModule == true
            or (StartsWith(class, "bw_module_") and type(ent.UseOn) == "function")

        if not isModule or type(ent.UseOn) ~= "function" then return end

        -- The module owns its effect. The base device only asks whether the
        -- module was consumed, so adding a new module never requires touching
        -- this entity.
        local success, consumed = pcall(ent.UseOn, ent, self)
        if success and consumed then
            ent:Remove()
        end
    end
end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
    end
end
