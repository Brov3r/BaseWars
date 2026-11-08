local MODULE = MODULE
MODULE.Name = "Map Cleanup"
MODULE.Author = "Brov3r"
MODULE.Require = {}

local doorClasses = {"func_door", "func_door_rotating", "prop_door_rotating"}
local glassClasses = {"func_breakable_surf", "func_breakable", "func_physbox", "func_physbox_multiplayer"}

function MODULE:RemoveMapDoors()
    if not BW.Config.Map or not BW.Config.Map.RemoveDoors then return end
    local removed = 0
    for _, class in ipairs(doorClasses) do
        for _, door in ipairs(ents.FindByClass(class)) do
            -- Do not remove doors created by players or other gameplay systems.
            if IsValid(door) and door:CreatedByMap() then
                door:Remove()
                removed = removed + 1
            end
        end
    end
    if removed > 0 then Log("info", "Removed map doors:", removed) end
end

function MODULE:RemoveMapGlass()
    if not BW.Config.Map or not BW.Config.Map.RemoveGlass then return end
    local removed = 0
    for _, class in ipairs(glassClasses) do
        for _, ent in ipairs(ents.FindByClass(class)) do
            if IsValid(ent) and ent:CreatedByMap() then
                local isGlass = class == "func_breakable_surf"
                if not isGlass then
                    local material = ent:GetInternalVariable("m_Material")
                    if material == nil then material = ent:GetKeyValues().material end
                    material = tonumber(material)
                    -- Source breakable material enum: glass and unbreakable glass.
                    isGlass = material == 0 or material == 7
                end
                if isGlass then
                    ent:Remove()
                    removed = removed + 1
                end
            end
        end
    end
    if removed > 0 then Log("info", "Removed map glass:", removed) end
end

function MODULE:Init()
    for _, event in ipairs({"InitPostEntity", "PostCleanupMap"}) do
        -- Remove hooks left by the former standalone modules on refresh.
        hook.Remove(event, "BW_RemoveMapDoors")
        hook.Remove(event, "BW_RemoveMapGlass")
        hook.Add(event, "BW_MapCleanup", function()
            self:RemoveMapDoors()
            self:RemoveMapGlass()
        end)
    end
end
