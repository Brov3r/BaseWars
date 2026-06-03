AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
AddCSLuaFile("include.lua")

include("shared.lua")
include("include.lua")

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
            ply:SelectWeapon("weapon_physgun")
        end
    end)
    
    return true
end

function GM:PlayerDeath(victim, inflictor, attacker)
   if IsValid(attacker) and attacker:IsPlayer() and attacker ~= victim then
        attacker:AddKills(1)
    end
end