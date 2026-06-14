if SERVER then
    AddCSLuaFile()
end

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Base Device"
ENT.Spawnable = false

ENT.DeviceCost = 0
ENT.AutoRefund = false
ENT.DefaultMaxHealth = 100

local function GetBWConfig(path_func, default_val)
    if not BW or not BW.Config then return default_val end
    local success, result = pcall(path_func)
    return success and result or default_val
end

local function FormatMoney(amount)
    if BW and BW.Utils and type(BW.Utils.NumWithSep) == "function" then
        return BW.Utils.NumWithSep(amount)
    end
    return amount
end

function ENT:GetTranslatedName()
    if type(Translate) == "function" then
        return Translate("ShopItems." .. self.ID, self.PrintName)
    end
    return self.PrintName
end

function ENT:GetDeviceOwner()
    return self.Owner or self:GetNWEntity("Owner")
end

function ENT:GetRefundData(ply)
    local cost = self.DeviceCost or 0
    if cost <= 0 or not IsValid(ply) or not ply:IsPlayer() then return 0, "$" end

    local userGroup = ply:GetUserGroup()
    
    local sellRatio = GetBWConfig(function() return BW.Config.PlayerGroups[userGroup].SellReturnRatio end, nil)
    if not sellRatio then
        sellRatio = GetBWConfig(function() return BW.Config.Economy.SellReturnRatioDefault end, 0.3)
    end
    
    -- Validate sell ratio to ensure it's between 0 and 1
    sellRatio = math.Clamp(tonumber(sellRatio) or 0.3, 0, 1)

    local currency = GetBWConfig(function() return BW.Config.Economy.Currency end, "$")

    return math.floor(cost * sellRatio), currency
end

if SERVER then

    function ENT:Initialize()
        self:SetMaxHealth(self.DefaultMaxHealth)
        self:SetHealth(self.DefaultMaxHealth)
        
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        
        self:SetTrigger(true)

        if self.AutoRefund then
            self:StartAutoRefund()
        end
    end

    function ENT:StartAutoRefund()
        local refundTime = GetBWConfig(function() return BW.Config.Economy.AutoRefundTime end, 30)
        local timerName = "DeviceAutoRefund_" .. self:EntIndex()

        local owner = self:GetDeviceOwner()
        
        if IsValid(owner) and owner:IsPlayer() then
            local msg = string.format(Translate("Entity.AutoRefunNotify", "You have %s sec. to use '%s', then it will be sold!"), refundTime, self:GetTranslatedName())
            owner:Notify(NOTIFY_WARNING, msg, 5)
        end 

        timer.Create(timerName, refundTime, 1, function()
            if not IsValid(self) or self.IsBeingSold or self.IsBeingRefunded then return end
            
            self.IsBeingRefunded = true
            local currentOwner = self:GetDeviceOwner()

            if IsValid(currentOwner) and currentOwner:IsPlayer() then
                local refundAmount, currency = self:GetRefundData(currentOwner)

                if refundAmount > 0 and type(currentOwner.AddMoney) == "function" then
                    currentOwner:AddMoney(refundAmount)
                    
                    local msg = string.format(Translate("Entity.RefundTime", "Your '%s' has expired and %s%s has been returned!"), self:GetTranslatedName(), currency, FormatMoney(refundAmount))
                    currentOwner:Notify(NOTIFY_SUCCESS, msg, 5)
                end
            end

            self:Remove()
        end)
    end

    function ENT:OnTakeDamage(dmginfo)
        if self.IsDestroyed or self.DefaultMaxHealth <= 0 then return end

        local damage = dmginfo:GetDamage()
        local newHealth = self:Health() - damage
        
        self:SetHealth(math.Clamp(newHealth, 0, self:GetMaxHealth()))
        
        if newHealth <= 0 then
            self.IsDestroyed = true
            self:DoExplosion(dmginfo:GetAttacker())
        end
    end

    function ENT:RefundMoney(ply)
        local refundAmount, currency = self:GetRefundData(ply)
        
        if refundAmount <= 0 or type(ply.AddMoney) ~= "function" then return end

        local rawText = "You have received %s%s for destruction: %s"
        if type(Translate) == "function" then
            rawText = Translate("Entity.RefundDestroy", rawText)
        end
        
        local text = string.format(rawText, currency, FormatMoney(refundAmount), self:GetTranslatedName())

        ply:Notify(NOTIFY_INFO, text, 5)
        ply:AddMoney(refundAmount)
    end

    function ENT:DoExplosion(attacker)
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
        if not SERVER or not IsValid(ent) then return end
        
        local class = ent:GetClass()
        
        if not string.StartWith(class, "bw_module_") or type(ent.GetAmount) ~= "function" then return end
        
        local amount = ent:GetAmount()
        local itemUsed = false
        
        if string.StartWith(class, "bw_module_repair") then
            local currentHp = self:Health()
            local maxHp = self:GetMaxHealth()
            
            if currentHp < maxHp then
                self:SetHealth(maxHp)
                itemUsed = true
            end
        end
        
        if itemUsed then
            ent:Remove()
        end
    end
end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
    end
end