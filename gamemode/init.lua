AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
AddCSLuaFile("include.lua")

include("shared.lua")
include("include.lua")

function GM:GetFallDamage(ply, speed)
    return math.max( 0, math.ceil( 0.2418 * speed - 141.75 ) )
end

function GM:PlayerSpawn(ply)
    self.BaseClass.PlayerSpawn(self, ply)
    ply:SetWalkSpeed(BW.Config.Motion.WalkSpeed)
    ply:SetRunSpeed(BW.Config.Motion.RunSpeed)
    ply:SetJumpPower(BW.Config.Motion.JumpPower)  
end

function GM:PlayerLoadout( ply )
	for _, class in ipairs(BW.Config.PlayerLoadout) do
        if not ply:HasWeapon(class) then
            ply:Give(class)
        end
    end

    timer.Simple(0.1, function()
        if IsValid(ply) then
            ply:SelectWeapon("hands")
        end
    end)
    
    return true
end

function GM:PlayerDeath(victim, inflictor, attacker)
   if IsValid(attacker) and attacker:IsPlayer() and attacker ~= victim then
        attacker:AddKills(1)
    end
end

function GM:SetupMove(ply, mv, cmd)
    if BW.Config.Motion.EnableBHop and ply:IsOnGround() and cmd:KeyDown(IN_JUMP) then
        local vel = ply:GetVelocity()
        local jumpPower = BW.Config.Motion.JumpPower or 200

        mv:SetVelocity(Vector(vel.x, vel.y, jumpPower))
        ply:SetGroundEntity(NULL)
        cmd:RemoveKey(IN_JUMP)
    end

    self.BaseClass:SetupMove(ply, mv, cmd)
end