local MODULE = MODULE
MODULE.Name = "Movement"
MODULE.Author = "Brov3r"
MODULE.Require = {}

function MODULE:Init()
    hook.Add("SetupMove", "BW_AutoBHop", function(ply, move)
        if not BW.Config.Motion.EnableBHop or not ply:Alive() then return end
        if ply:GetMoveType() ~= MOVETYPE_WALK or ply:WaterLevel() >= 2 then return end
        -- Let Source handle the actual jump identically on both prediction realms.
        if move:KeyDown(IN_JUMP) and not ply:OnGround() then
            move:SetButtons(bit.band(move:GetButtons(), bit.bnot(IN_JUMP)))
        end
    end)
end
