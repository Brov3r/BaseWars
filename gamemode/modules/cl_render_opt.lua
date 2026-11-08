local MODULE = MODULE

MODULE.Name = "Render Optimization"
MODULE.Author = "Brov3r"
MODULE.Require = {}

local cfg = BW.Config.Render or {}
local fogCfg = BW.Config.Fog or {}

local function Num(value, default, min, max)
    value = tonumber(value)
    if not BW.Utils.IsFinite(value) then value = default end
    return math.Clamp(value, min, max)
end

local function SetInt(name, value)
    value = math.floor(value)
    local cv = GetConVar(name)
    if cv then
        local ok = pcall(function() cv:SetInt(value) end)
        if ok and cv:GetInt() == value then return end
    end
    RunConsoleCommand(name, tostring(value))
end

local function Apply()
    if cfg.Enabled == false then return end

    local fogEnd = Num(fogCfg.End, 2500, 500, 30000)
    local farZ = Num(cfg.FarZ, fogEnd + 700, 1000, 30000)
    local maxRenderable = Num(cfg.MaxRenderableDistance, fogEnd + 300, 500, 30000)

    SetInt("r_farz", farZ)
    SetInt("cl_maxrenderable_dist", maxRenderable)
    if cfg.Disable3DSky ~= false then
        SetInt("r_3dsky", 0)
    end
end

function MODULE:Init()
    timer.Simple(0, Apply)
    concommand.Add("bw_render_opt", Apply)
end
