if SERVER then
    AddCSLuaFile()
end

SWEP.Base           = "weapon_base"
SWEP.PrintName      = "Blowtorch"
SWEP.Author         = "Brov3r"

SWEP.Slot           = 5
SWEP.SlotPos        = 1
SWEP.DrawAmmo       = false
SWEP.DrawCrosshair  = true

SWEP.ViewModel      = "models/weapons/c_irifle.mdl"
SWEP.WorldModel     = "models/weapons/w_irifle.mdl"
SWEP.UseHands       = true

SWEP.HoldType       = "pistol" 

SWEP.Primary.ClipSize     = -1
SWEP.Primary.DefaultClip  = -1
SWEP.Primary.Automatic    = true
SWEP.Primary.Ammo         = "none"
SWEP.Primary.Delay        = 0.25
SWEP.Primary.Range        = 50
SWEP.Primary.MinDmg       = 1
SWEP.Primary.MaxDmg       = 5

SWEP.Secondary.ClipSize   = -1
SWEP.Secondary.DefaultClip= -1
SWEP.Secondary.Automatic  = false
SWEP.Secondary.Ammo       = "none"

local SOUND_SPARK = Sound("ambient/energy/spark6.wav")

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
    
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local shootPos = owner:GetShootPos()
    local aimDir = owner:GetAimVector()

    local tr = util.TraceLine({
        start = shootPos,
        endpos = shootPos + aimDir * self.Primary.Range,
        filter = owner
    })

    if IsFirstTimePredicted() then
        self:EmitSound(SOUND_SPARK, 65, math.random(80, 120), 1, CHAN_WEAPON)
    end

    if tr.Hit then
        if SERVER then
            local effectdata = EffectData()
            effectdata:SetOrigin(tr.HitPos)
            effectdata:SetNormal(tr.HitNormal)
            effectdata:SetMagnitude(2)
            effectdata:SetScale(1)
            util.Effect("MetalSparks", effectdata)
        end

        local tracerdata = EffectData()
        tracerdata:SetOrigin(tr.HitPos)
        tracerdata:SetStart(shootPos)
        tracerdata:SetEntity(self)
        tracerdata:SetAttachment(1)
        util.Effect("ToolTracer", tracerdata)
    end

    if SERVER and IsValid(tr.Entity) then
        local ent = tr.Entity
        
        if ent:GetClass() == "prop_physics" or ent.Base == "base_gmodentity" then
            local dmginfo = DamageInfo()
            dmginfo:SetAttacker(owner)
            dmginfo:SetInflictor(self)
            
            local randomDmg = math.Rand(self.Primary.MinDmg, self.Primary.MaxDmg)
            dmginfo:SetDamage(randomDmg)
            
            dmginfo:SetDamageType(DMG_BURN)
            dmginfo:SetDamagePosition(tr.HitPos)
            dmginfo:SetDamageForce(aimDir * 10)

            ent:TakeDamageInfo(dmginfo)
        end
    end
end

function SWEP:SecondaryAttack()
end

function SWEP:Deploy()
    self:SendWeaponAnim(ACT_VM_DRAW)
    return true
end