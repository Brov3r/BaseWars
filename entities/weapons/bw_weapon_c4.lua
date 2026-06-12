if SERVER then
    AddCSLuaFile()
end

game.AddAmmoType({name = "bw_c4", maxcarry = 5})

SWEP.Base           = "weapon_base"
SWEP.PrintName      = "C4 Explosive"
SWEP.Author         = "Brov3r"
SWEP.ViewModel      = "models/weapons/v_c4.mdl"
SWEP.WorldModel     = "models/weapons/w_c4.mdl"
SWEP.UseHands       = true
SWEP.Spawnable      = true
SWEP.HoldType       = "slam"
SWEP.Slot			= 5
SWEP.SlotPos 		= 5

SWEP.Primary.Ammo         = "bw_c4"
SWEP.Primary.ClipSize     = -1
SWEP.Primary.Delay     	  = 4
SWEP.Primary.DefaultClip  = 1
SWEP.Primary.Automatic    = false

SWEP.Secondary.Ammo       = ""
SWEP.Secondary.ClipSize   = -1
SWEP.Secondary.DefaultClip = 0
SWEP.Secondary.Automatic  = false

SWEP.TimerOptions = {10, 30, 60, 120}
SWEP.TimerIndex = 1

function SWEP:PrimaryAttack()
    local ply = self:GetOwner()
    
    if ply:GetAmmoCount(self.Primary.Ammo) <= 0 then return end

    local tr = ply:GetEyeTrace()
	
	if not tr.Hit or tr.Entity:IsPlayer() or tr.HitPos:DistToSqr(ply:GetShootPos()) > 2500 then return end

    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
    self:SendWeaponAnim(ACT_SLAM_STICKWALL_ATTACH)
    self:EmitSound("weapons/c4/c4_plant.wav", 75, 100)

    if SERVER then
        local c4 = ents.Create("bw_c4_planted")
        if IsValid(c4) then
            c4:SetPos(tr.HitPos + tr.HitNormal * 2)
            c4:SetAngles(tr.HitNormal:Angle() + Angle(-90, 0, 180))
            c4:SetOwner(ply)
            c4.DetonateTime = CurTime() + self.TimerOptions[self.TimerIndex]
            c4:Spawn()

            local phys = c4:GetPhysicsObject()
            if IsValid(phys) then
                phys:EnableMotion(false)
            end

            local weld = constraint.Weld(c4, tr.Entity, 0, 0, 0, true)
        end

        self:TakePrimaryAmmo(1)
        
        if ply:GetAmmoCount(self.Primary.Ammo) < 1 then
            timer.Simple(0.2, function()
                if IsValid(ply) then ply:StripWeapon(self:GetClass()) end
            end)
        end
    end
end

function SWEP:SecondaryAttack()
    self.TimerIndex = (self.TimerIndex % #self.TimerOptions) + 1
    
    if SERVER then
        self:GetOwner():PrintMessage(HUD_PRINTCENTER, self.TimerOptions[self.TimerIndex] .. "s")
        self:EmitSound("buttons/lightswitch2.wav", 60, 150)
    end
    
    self:SetNextSecondaryFire(CurTime() + 0.3)
end