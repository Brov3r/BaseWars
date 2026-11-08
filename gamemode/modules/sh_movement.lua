local MODULE = MODULE
MODULE.Name = "Movement"
MODULE.Author = "Brov3r"
MODULE.Require = {}

function MODULE:Init()
    -- Bhop input is handled in the client usercmd. Doing the same button
    -- removal in SetupMove on the server made the server clear the jump on
    -- the landing tick, which caused the "stumble" and killed the momentum.
    if CLIENT then
        hook.Add("CreateMove", "BW_AutoBHop", function(cmd)
            local ply = LocalPlayer()
            if not IsValid(ply) or not ply:Alive() then return end
            if not BW.Config.Motion.EnableBHop then return end
            if ply:GetMoveType() ~= MOVETYPE_WALK or ply:WaterLevel() >= 2 then return end

            if not cmd:KeyDown(IN_JUMP) then return end

            if ply:OnGround() then
                -- Make sure the landing command definitely contains jump.
                cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_JUMP))
            else
                -- Clear it in the air so the next ground contact is a fresh press.
                cmd:RemoveKey(IN_JUMP)
            end
        end)
    end

    -- The usercmd jump can still be lost on the exact landing tick. Apply a
    -- real vertical jump impulse on ground contact so friction never gets a
    -- chance to eat the horizontal speed. This hook is predicted, so both
    -- realms apply the same vertical velocity.
    hook.Add("OnPlayerHitGround", "BW_AutoBHop_Landing", function(ply, inWater, onFloater)
        if not IsValid(ply) or not ply:Alive() then return end
        if not BW.Config.Motion.EnableBHop or inWater or onFloater then return end
        if not ply:KeyDown(IN_JUMP) then return end

        local velocity = ply:GetVelocity()
        local jumpPower = math.max(0, tonumber(BW.Config.Motion.JumpPower) or 200)
        if velocity.z < jumpPower then
            ply:SetVelocity(Vector(velocity.x, velocity.y, jumpPower))
        end
    end)
end
