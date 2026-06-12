local MODULE = MODULE

MODULE.Name = "Boosters"
MODULE.Author = "Brov3r"
MODULE.Require = {"notify"}

local config = BW.Config
local cols = config.Colors or {}

local activeBoosters = {}

function MODULE:Init()
    self:RegisterBaseEntity()
    self:RegisterCustomBoosters()
    
    if SERVER then
        self:InitServer()
    else
        self:InitClient()
    end
    
    self:RegisterHooks()
end

function MODULE:RegisterBaseEntity()
    local ENT = {}
    ENT.Type = "anim"
    ENT.Base = "base_gmodentity"
    ENT.PrintName = Translate("Booster.BaseBooster", "Unknown")
    ENT.Author = "Brov3r"
    ENT.Spawnable = false

    ENT.BoosterName     = Translate("Booster.BaseBooster", "Unknown")
    ENT.BoosterIcon     = "icon16/pill.png"
    ENT.BoosterColor    = Color(255, 255, 255)
    ENT.BoosterDuration = 30

    function ENT:Initialize()
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        if SERVER then
            self:SetUseType(SIMPLE_USE)
            self:SetModel("models/props_lab/jar01b.mdl")
        end

        if self.BoosterColor then
            self:SetColor(self.BoosterColor)
        end

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
        end
    end

    if SERVER then
        function ENT:Use(activator, caller)
            if not IsValid(activator) or not activator:IsPlayer() or not activator:Alive() then return end
            
            MODULE:ConsumeBooster(activator, self.ClassName)
            self:Remove()
        end
    end

    function ENT:BoosterApply(ply) end
    function ENT:BoosterRemove(ply) end

    scripted_ents.Register(ENT, "bw_booster_base")
end

function MODULE:AddBooster(id, name, icon, color, duration, onApply, onRemove)
    if id == "" then return end

    local BOOST = {}
    BOOST.Type            = "anim"
    BOOST.Base            = "bw_booster_base"
    BOOST.PrintName       = name or Translate("Booster.BaseBooster", "Unknown")
    BOOST.Spawnable       = true

    BOOST.BoosterName     = name or Translate("Booster.BaseBooster", "Unknown")
    BOOST.BoosterIcon     = icon or "icon16/pill.png"
    BOOST.BoosterColor    = color or Color(255, 255, 255)
    BOOST.BoosterDuration = duration or 30

    function BOOST:BoosterApply(ply)
        if onApply then onApply(ply) end
    end

    function BOOST:BoosterRemove(ply, suppressNotify)
        if onRemove then onRemove(ply) end
        
        if IsValid(ply) and ply:Alive() and not suppressNotify then
            ply:Notify(NOTIFY_WARNING, string.format(Translate("Booster.EndText", "The '%s' booster has expired!"), self.BoosterName))
        end
    end
    scripted_ents.Register(BOOST, id)
end

function MODULE:RegisterCustomBoosters()
    self:AddBooster("bw_booster_double_jump", Translate("Booster.DoubleJump", "Double Jump"), "icon16/arrow_up.png", Color(98, 250, 123), 120,
    function(ply)
        ply.BW_HasDoubleJump = true
    end, 
    function(ply)
        ply.BW_HasDoubleJump = false
    end)

    self:AddBooster("bw_booster_regeneration", Translate("Booster.Regeneration", "Regeneration"), "icon16/heart.png", Color(255, 105, 180), 90,
    function(ply)
        ply.BW_HasRegen = true
    end,
    function(ply)
        ply.BW_HasRegen = false
    end)

    self:AddBooster("bw_booster_speed", Translate("Booster.Speed", "Speed Boost"), "icon16/lightning.png", Color(255, 215, 0), 60,
    function(ply)
        if SERVER then
            if not ply.BW_HasSpeed then 
                ply.BW_PreBoosterWalk = ply:GetWalkSpeed()
                ply.BW_PreBoosterRun = ply:GetRunSpeed()
                ply:SetWalkSpeed(ply.BW_PreBoosterWalk * 1.45)
                ply:SetRunSpeed(ply.BW_PreBoosterRun * 1.45)
            end
        end
        ply.BW_HasSpeed = true
    end,
    function(ply)
        if SERVER and IsValid(ply) and ply:Alive() then
            ply:SetWalkSpeed(ply.BW_PreBoosterWalk or 200)
            ply:SetRunSpeed(ply.BW_PreBoosterRun or 400)
        end
        ply.BW_HasSpeed = false
    end)

    self:AddBooster("bw_booster_painkiller", Translate("Booster.Painkiller", "Painkiller"), "icon16/shield.png", Color(100, 149, 237), 120,
    function(ply)
        ply.BW_HasPainkiller = true
    end,
    function(ply)
        ply.BW_HasPainkiller = false
    end)

    self:AddBooster("bw_booster_rage", Translate("Booster.Rage", "Rage"), "icon16/bomb.png", Color(220, 20, 60), 45,
    function(ply)
        ply.BW_HasRage = true
    end,
    function(ply)
        ply.BW_HasRage = false
    end)

    self:AddBooster("bw_booster_nofall", Translate("Booster.NoFall", "Shock absorber"), "icon16/user_suit.png", Color(135, 206, 250), 120,
    function(ply)
        ply.BW_NoFallDamage = true
    end,
    function(ply)
        ply.BW_NoFallDamage = false
    end)

    self:AddBooster("bw_booster_vampire", Translate("Booster.Vampire", "Vampirism"), "icon16/star.png", Color(139, 0, 0), 60,
    function(ply)
        ply.BW_IsVampire = true
    end,
    function(ply)
        ply.BW_IsVampire = false
    end)

    self:AddBooster("bw_booster_armor_regen", Translate("Booster.ArmorRegen", "Armor repair Kit"), "icon16/wrench.png", Color(192, 192, 192), 90,
    function(ply)
        ply.BW_HasArmorRegen = true
    end,
    function(ply)
        ply.BW_HasArmorRegen = false
    end)

    -- VIP
    self:AddBooster("bw_booster_invis", Translate("Booster.Invis", "Invisibility"), "icon16/eye.png", Color(200, 200, 255), 60,
    function(ply)
        local alpha = 25
        
        ply:SetRenderMode(RENDERMODE_TRANSCOLOR)
        ply:SetColor(Color(255, 255, 255, alpha))
        ply:DrawShadow(false)
        ply.BW_IsInvis = true
        ply:SetNWBool("BW_IsInvis", true)
        
        ply:SetMaterial("") 
        
        for _, ent in pairs(ply:GetChildren()) do
            ent:SetRenderMode(RENDERMODE_TRANSCOLOR)
            ent:SetColor(Color(255, 255, 255, alpha))
        end
    end,
    function(ply)
        ply:SetRenderMode(RENDERMODE_NORMAL)
        ply:SetColor(Color(255, 255, 255, 255))
        ply:SetMaterial("")
        ply:DrawShadow(true)
        ply.BW_IsInvis = false
        ply:SetNWBool("BW_IsInvis", false)
        
        for _, ent in pairs(ply:GetChildren()) do
            ent:SetRenderMode(RENDERMODE_NORMAL)
            ent:SetColor(Color(255, 255, 255, 255))
        end
    end)

    self:AddBooster("bw_booster_resurrection", Translate("Booster.Resurrection", "Resurrection"), "icon16/arrow_refresh.png", Color(255, 215, 0), 120,
    function(ply)
        ply.BW_HasResurrection = true
    end,
    function(ply)
        ply.BW_HasResurrection = false
    end)

    self:AddBooster("bw_booster_dash", Translate("Booster.Dash", "Dash"), "icon16/lightning_go.png", Color(255, 69, 0), 60,
    function(ply)
        ply.BW_HasDash = true
    end,
    function(ply)
        ply.BW_HasDash = false
    end)
end

function MODULE:InitServer()
    util.AddNetworkString("BW_UpdateBoosters")
end

function MODULE:ConsumeBooster(ply, class)
    ply.BW_ActiveBoosters = ply.BW_ActiveBoosters or {}
    
    local entData = scripted_ents.GetStored(class)
    if not entData or not entData.t then return end
    local entTable = entData.t

    local existingBooster = nil
    for _, b in ipairs(ply.BW_ActiveBoosters) do
        if b.class == class then
            existingBooster = b
            break
        end
    end

    if existingBooster then
        existingBooster.endTime = CurTime() + entTable.BoosterDuration
        existingBooster.duration = entTable.BoosterDuration

        if entTable.BoosterApply then 
            entTable:BoosterApply(ply) 
        end
        
        if ply.Notify then
            ply:Notify(NOTIFY_SUCCESS, string.format(Translate("Booster.RenewText", "The '%s' booster duration has been refreshed!"), entTable.BoosterName), 3)
        end

        self:SyncBoosters(ply)
        return
    end

    if #ply.BW_ActiveBoosters >= 3 then
        self:ClearBoosters(ply, true)
        ply:Kill()
        if ply.Notify then
            ply:Notify(NOTIFY_WARNING, Translate("Booster.DeathOverdose", "You died of an overdose!"), 5)
        end
        return
    end

    local endTime = CurTime() + entTable.BoosterDuration

    local boosterInstance = {
        class    = class,
        endTime  = endTime,
        duration = entTable.BoosterDuration
    }

    table.insert(ply.BW_ActiveBoosters, boosterInstance)
    
    if entTable.BoosterApply then 
        entTable:BoosterApply(ply) 
    end
    
    if ply.Notify then
        ply:Notify(NOTIFY_SUCCESS, string.format(Translate("Booster.UseText", "You have accepted the booster: %s"), entTable.BoosterName), 3)
    end

    self:SyncBoosters(ply)
end

function MODULE:RemoveBoosterInstance(ply, index)
    local b = ply.BW_ActiveBoosters[index]
    if not b then return end

    local entData = scripted_ents.GetStored(b.class)
    if entData and entData.t and entData.t.BoosterRemove then
        entData.t:BoosterRemove(ply)
    end

    table.remove(ply.BW_ActiveBoosters, index)
    self:SyncBoosters(ply)
end

function MODULE:ClearBoosters(ply, silent)
    if not ply.BW_ActiveBoosters then return end
    
    for i = #ply.BW_ActiveBoosters, 1, -1 do
        local b = ply.BW_ActiveBoosters[i]
        local entData = scripted_ents.GetStored(b.class)
        if entData and entData.t and entData.t.BoosterRemove then
            entData.t:BoosterRemove(ply, silent or false)
        end
    end
    
    ply.BW_ActiveBoosters = {}
    self:SyncBoosters(ply)
end

function MODULE:SyncBoosters(ply)
    net.Start("BW_UpdateBoosters")
    net.WriteUInt(#ply.BW_ActiveBoosters, 4)
    for _, b in ipairs(ply.BW_ActiveBoosters) do
        net.WriteString(b.class)
        net.WriteFloat(b.endTime)
        net.WriteFloat(b.duration)
    end
    net.Send(ply)
end

function MODULE:HasClientBooster(class)
    local ct = CurTime()
    for _, b in ipairs(activeBoosters) do
        if b.class == class and b.endTime > ct then
            return true
        end
    end
    return false
end

function MODULE:InitClient()
    local matCache = {}
    local bgColor = Color(30, 30, 30, 150)

    local polyTable = {
        { x = 0, y = 0 },
        { x = 0, y = 0 },
        { x = 0, y = 0 },
        { x = 0, y = 0 }
    }

    local function GetIconMat(iconPath)
        if not matCache[iconPath] then matCache[iconPath] = Material(iconPath) end
        return matCache[iconPath]
    end

    local function DrawCircleArc(x, y, radius, thickness, progress, color)
        if progress <= 0 then return end
        local startAngle = -90
        local endAngle = startAngle + (360 * progress)
        local step = 5

        surface.SetDrawColor(color)
        draw.NoTexture()

        local lastOuterX, lastOuterY, lastInnerX, lastInnerY
        local currentAngle = startAngle

        while currentAngle <= endAngle do
            local rad = math.rad(currentAngle)
            local cos, sin = math.cos(rad), math.sin(rad)
            local outerX = x + cos * radius
            local outerY = y + sin * radius
            local innerX = x + cos * (radius - thickness)
            local innerY = y + sin * (radius - thickness)

            if lastOuterX then
                polyTable[1].x = lastOuterX
                polyTable[1].y = lastOuterY
                polyTable[2].x = outerX
                polyTable[2].y = outerY
                polyTable[3].x = innerX
                polyTable[3].y = innerY
                polyTable[4].x = lastInnerX
                polyTable[4].y = lastInnerY
                
                surface.DrawPoly(polyTable)
            end

            lastOuterX, lastOuterY, lastInnerX, lastInnerY = outerX, outerY, innerX, innerY
            
            if currentAngle == endAngle then break end
            currentAngle = currentAngle + step
            if currentAngle > endAngle then
                currentAngle = endAngle
            end
        end
    end

    net.Receive("BW_UpdateBoosters", function()
        table.Empty(activeBoosters)
        local count = net.ReadUInt(4)
        for i = 1, count do
            table.insert(activeBoosters, {
                class    = net.ReadString(),
                endTime  = net.ReadFloat(),
                duration = net.ReadFloat()
            })
        end
    end)

    hook.Add("HUDPaint", "BW_Boosters_HUD", function()
        local ct = CurTime()
        for i = #activeBoosters, 1, -1 do
            if activeBoosters[i].endTime <= ct then
                table.remove(activeBoosters, i)
            end
        end

        if #activeBoosters == 0 then return end
        
        local conf     = BW.Config or {}
        local dim      = conf.HUD and conf.HUD.Dimensions or { Avatar = 64, HealthBarW = 200, ArmorBarH = 12 }
        local margin   = conf.HUD and conf.HUD.Margin or 10

        local iconSize = 32
        local padding = 15
  
        local startX = margin * 3 + dim.Avatar + dim.HealthBarW
        local startY = ScrH() - margin - dim.Avatar / 2 - dim.ArmorBarH - 10

        for i, b in ipairs(activeBoosters) do
            local entData = scripted_ents.GetStored(b.class)
            if not entData or not entData.t then continue end
            local entTable = entData.t

            local timeRemaining = b.endTime - ct
            if timeRemaining <= 0 then continue end
            
            local progress = b.duration > 0 and math.Clamp(timeRemaining / b.duration, 0, 1) or 0
            
            local radius = 16
            local thickness = 4
            local x = startX + (i - 1) * (iconSize + padding) + (iconSize / 2)
            local y = startY + (iconSize / 2)

            DrawCircleArc(x, y, radius, thickness, 1, bgColor)
            DrawCircleArc(x, y, radius, thickness, progress, entTable.BoosterColor or color_white)
            
            surface.SetMaterial(GetIconMat(entTable.BoosterIcon))
            surface.SetDrawColor(color_white)
            surface.DrawTexturedRect(x - 8, y - 8, 16, 16)
        end
    end)
end

function MODULE:RegisterHooks()
    hook.Add("KeyPress", "BW_Boosters_DoubleJump", function(ply, key)
        if key == IN_JUMP and not ply:OnGround() and ply:WaterLevel() < 1 then
            local hasBooster = false
            if SERVER then
                hasBooster = ply.BW_HasDoubleJump
            else
                hasBooster = MODULE:HasClientBooster("bw_booster_double_jump")
            end

            if hasBooster and not ply.BW_DoubleJumped then
                ply.BW_DoubleJumped = true
                local vel = ply:GetVelocity()
                local jumpPower = (config.Motion and config.Motion.JumpPower or 200) * 1.8
                ply:SetVelocity(Vector(0, 0, jumpPower - vel.z))
            end
        end

        if key == IN_SPEED and ply.BW_HasDash then
            local curTime = CurTime()
            
            if ply.BW_LastSpeedPress and (curTime - ply.BW_LastSpeedPress) < 0.3 then
                local dashCooldown = ply.BW_DashCooldown or 0
                if curTime < dashCooldown then return end
                
                local force = ply:OnGround() and 3000 or 1500
                ply:SetGroundEntity(NULL)
                ply:SetVelocity(ply:GetForward() * force)
                ply.BW_DashCooldown = curTime + 3
                
                if SERVER then
                    local pos = ply:GetPos()

                    local effect = EffectData()
                    effect:SetOrigin(pos)
                    effect:SetEntity(ply)
                    effect:SetScale(5)
                    
                    util.Effect("TeslaZap", effect, true, true)
                    util.Effect("ManhackSparks", effect, true, true)
                end
                                    
                ply:EmitSound("ambient/wind/wind_snippet2.wav", 75, 150)
            end
            
            ply.BW_LastSpeedPress = curTime
        end
    end)

    if SERVER then
        hook.Add("GetFallDamage", "BW_Boosters_NoFallDamage", function(ply, speed)
            if ply.BW_NoFallDamage then
                return 0
            end
        end)
    end

    hook.Add("OnPlayerHitGround", "BW_Boosters_ResetJump", function(ply)
        ply.BW_DoubleJumped = false
    end)

    if SERVER then
        hook.Add("PlayerDeathThink", "BW_Resurrection_BlockSpawn", function(ply)
            if ply.BW_HasResurrection then
                return false 
            end
        end)
        hook.Add("PlayerDeath", "BW_Boosters_Death", function(ply)
            if ply.BW_HasResurrection then
                
                local deathPos = ply:GetPos()
                local deathAng = ply:EyeAngles()
                
                ply.BW_HasResurrection = false
                
                timer.Simple(1, function()
                    if IsValid(ply) then
                        ply:Spawn()
                        
                        ply:SetPos(deathPos + Vector(0,0,5))
                        ply:SetEyeAngles(deathAng)
                        
                        ply:SetHealth(50)
                        ply:Notify(NOTIFY_INFO, Translate("Booster.ResurrectionUse", "Your second chance is used!"), 5)
                        self:ClearBoosters(ply, true)
                    end
                end)
                
                return true
            end
            
            self:ClearBoosters(ply, true)
            ply.BW_DoubleJumped = false
        end)

        hook.Add("Think", "BW_Boosters_Think", function()
            local ct = CurTime()
            for _, ply in ipairs(player.GetAll()) do
                if ply.BW_ActiveBoosters and #ply.BW_ActiveBoosters > 0 then
                    for i = #ply.BW_ActiveBoosters, 1, -1 do
                        local b = ply.BW_ActiveBoosters[i]
                        if ct >= b.endTime then
                            self:RemoveBoosterInstance(ply, i)
                        end
                    end
                end

                if ply:Alive() and ply.BW_HasRegen then
                    ply.BW_NextRegen = ply.BW_NextRegen or 0
                    if ct >= ply.BW_NextRegen then
                        local maxHp = ply:GetMaxHealth()
                        local curHp = ply:Health()
                        if curHp < maxHp then
                            ply:SetHealth(math.min(maxHp, curHp + 2))
                        end
                        ply.BW_NextRegen = ct + 2
                    end
                end

                if ply:Alive() and ply.BW_HasArmorRegen then
                    ply.BW_NextArmorRegen = ply.BW_NextArmorRegen or 0
                    if ct >= ply.BW_NextArmorRegen then
                        local maxArmor = ply:GetMaxArmor()
                        local curArmor = ply:Armor()
                        if curArmor < maxArmor then
                            ply:SetArmor(math.min(maxArmor, curArmor + 4))
                        end
                        ply.BW_NextArmorRegen = ct + 2
                    end
                end
            end
        end)

        hook.Add("EntityTakeDamage", "BW_Boosters_DamageModifiers", function(target, dmginfo)
            if target:IsPlayer() and target.BW_HasPainkiller then
                dmginfo:ScaleDamage(0.7)
            end

            local attacker = dmginfo:GetAttacker()
            if IsValid(attacker) and attacker:IsPlayer() and attacker.BW_HasRage then
                dmginfo:ScaleDamage(1.3)
            end
            
            if IsValid(attacker) and attacker:IsPlayer() and attacker.BW_IsVampire and target ~= attacker then
                if target:IsPlayer() or target:IsNPC() then
                    local damageDone = dmginfo:GetDamage()
                    local healAmount = math.Round(damageDone * 0.2)
                    
                    if healAmount > 0 and attacker:Alive() then
                        local maxHp = attacker:GetMaxHealth()
                        attacker:SetHealth(math.min(maxHp, attacker:Health() + healAmount))
                    end
                end
            end

            return false 
        end)
    end
end