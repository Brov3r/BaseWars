BW.REALM_SERVER = 1
BW.REALM_CLIENT = 2
BW.REALM_SHARED = 3

BW.Modules = BW.Modules or {}

local string_sub      = string.sub
local debug_traceback = debug.traceback
local ipairs          = ipairs
local pairs           = pairs
local table_insert    = table.insert
local cols            = BW.Config.Colors

local MODULES_PATH    = engine.ActiveGamemode() .. "/gamemode/modules/"

local MODULE_BASE = {}
MODULE_BASE.__index = MODULE_BASE

function MODULE_BASE:New(id, realm)
    local instance = setmetatable({}, self)
    instance.ID = id
    instance.Name = id
    instance.Realm = realm
    instance.Require = {}
    return instance
end

function MODULE_BASE:Initialize()
    if self.Init then 
        local success, err = pcall(self.Init, self)
        if not success then
            Log("error", cols.Red, "[Loader] ", cols.White, "Init error in module ", cols.Cyan, self.Name, cols.White, ":\n", err)
        end
    end
end

-- Loader
local Loader = {}

local function SafeInclude(filePath)
    return xpcall(include, debug_traceback, filePath)
end

local function GetModuleInfo(fileName)
    local nameNoExt = string_sub(fileName, 1, -5)
    local prefix = string_sub(nameNoExt, 1, 3)
    
    local realm = BW.REALM_SHARED
    local id = nameNoExt
    
    if prefix == "sv_" then
        realm = BW.REALM_SERVER
        id = string_sub(nameNoExt, 4)
    elseif prefix == "cl_" then
        realm = BW.REALM_CLIENT
        id = string_sub(nameNoExt, 4)
    elseif prefix == "sh_" then
        realm = BW.REALM_SHARED
        id = string_sub(nameNoExt, 4)
    end
    
    return id, realm
end

local function ProcessModuleFile(filePath, realm)
    if realm == BW.REALM_CLIENT or realm == BW.REALM_SHARED then
        if SERVER then AddCSLuaFile(filePath) end
    end
    
    if (realm == BW.REALM_SERVER and CLIENT) or (realm == BW.REALM_CLIENT and SERVER) then
        return true 
    end
    
    local success, err = SafeInclude(filePath)
    if not success then
        Log("error", cols.Red, "[Loader] Execution error in ", filePath, ":\n", err)
        return false
    end
    
    return true
end

function Loader:ScanAndLoad()
    local files = file.Find(MODULES_PATH .. "*.lua", "LUA")
    
    for _, fileName in ipairs(files) do
        local id, realm = GetModuleInfo(fileName)
        local filePath = MODULES_PATH .. fileName
        
        local oldModule = _G.MODULE
        _G.MODULE = MODULE_BASE:New(id, realm)
        
        if ProcessModuleFile(filePath, realm) then
            BW.Modules[id] = _G.MODULE
        end
        
        _G.MODULE = oldModule
    end
    
    local sorted = {}
    local visited = {}
    local visiting = {}
    
    local function visitNode(modID)
        if visiting[modID] then
            Log("error", cols.Red, "[Loader] Circular dependency detected involving: ", modID)
            return
        end
        if visited[modID] then return end
        
        visiting[modID] = true
        local mod = BW.Modules[modID]
        
        if mod and mod.Require then
            for _, reqID in ipairs(mod.Require) do
                if BW.Modules[reqID] then
                    visitNode(reqID)
                else
                    Log("error", cols.Red, "[Loader] Missing dependency '", reqID, "' for module '", modID, "'")
                end
            end
        end
        
        visiting[modID] = nil
        visited[modID] = true
        table_insert(sorted, modID)
    end
    
    for id, _ in pairs(BW.Modules) do
        visitNode(id)
    end
    
    local initCount = 0
    for _, modID in ipairs(sorted) do
        local mod = BW.Modules[modID]
        
        if (SERVER and mod.Realm ~= BW.REALM_CLIENT) or (CLIENT and mod.Realm ~= BW.REALM_SERVER) then
            mod:Initialize()
            initCount = initCount + 1
            Log("info", cols.White, "Module ", cols.Cyan, mod.Name, cols.White, " initialized.")
        end
    end
    
    return initCount
end

function Loader:Run()
    local startTime = SysTime()
    local envName = CLIENT and "Client" or "Server"
    
    Log("info", "Starting initialization of modules (" .. envName .. "-Side)...")
    
    local initCount = self:ScanAndLoad()
    local duration = math.Round(SysTime() - startTime, 5)
    
    Log("success", "Initialized ", cols.Cyan, initCount, cols.White, " modules in ", cols.Yellow, duration, cols.White, " seconds.")
end

BW.ModuleLoader = Loader
BW.ModuleLoader:Run()