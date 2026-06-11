local MODULE = MODULE

MODULE.Name = "Map Zone"
MODULE.Author = "Brov3r"
MODULE.Require = {}

local MIN_Z = -400
local MAX_Z = 1500
local DAMAGE_MULT = 0.2

function MODULE:Init()
    timer.Create("HeightDamageCheck", 0.5, 0, function()
        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) or not ply:Alive() then continue end

            local z = ply:GetPos().z
            local inDanger = false
            local damage = 0

            if z > MAX_Z then
                inDanger = true
                damage = (z - MAX_Z) * DAMAGE_MULT
            elseif z < MIN_Z then
                inDanger = true
                damage = (MIN_Z - z) / 2 * DAMAGE_MULT
            end

            if inDanger then
                if not ply._InHeightDanger then
                    ply._InHeightDanger = true
                    ply:Notify(NOTIFY_WARNING, Translate("MapZone.DangerZone", "You have entered an infected area!"), 5)
                end
                
                if damage > 0 then
                    ply:TakeDamage(damage, game.GetWorld(), game.GetWorld())
                end
            else
                ply._InHeightDanger = false
            end
        end
    end)
end