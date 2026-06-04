BW.REALM_SERVER = 1
BW.REALM_CLIENT = 2
BW.REALM_SHARED = 3

BW.Modules = BW.Modules or {}

local string_sub      = string.sub
local string_match    = string.match
local debug_traceback = debug.traceback
local ipairs          = ipairs
local Log             = BW.Log
local cols            = BW.Config.Colors

local MODULES_PATH    = engine.ActiveGamemode() .. "/gamemode/modules/"

-- Base module
local MODULE_BASE = {}
MODULE_BASE.__index = MODULE_BASE

function MODULE_BASE:New(defaultName, defaultRealm)
    local instance = setmetatable({}, self)
    instance.Name = defaultName or "Unknown"
    instance.Realm = defaultRealm or BW.REALM_SHARED
    return instance
end

function MODULE_BASE:Initialize()
    if self.Init then self:Init() end
end

-- Loader
local Loader = {}

local function SafeInclude(filePath)
    return xpcall(include, debug_traceback, filePath)
end

local function RegisterModuleInstance(modObject, wasLoaded)
    if not modObject or not modObject.Name then return end
    
    if not wasLoaded then return end
    
    BW.Modules[modObject.Name] = modObject
    Log("info", cols.White, "Module ", cols.Cyan, modObject.Name, cols.White, " registered successfully.")
    
    modObject:Initialize()
end

local function ProcessModuleFile(filePath, realmType)
    if realmType == BW.REALM_SERVER then
        if SERVER then 
            SafeInclude(filePath)
            return true
        end
    elseif realmType == BW.REALM_CLIENT then
        if SERVER then 
            AddCSLuaFile(filePath)
            return false
        end
        if CLIENT then 
            SafeInclude(filePath)
            return true
        end
    elseif realmType == BW.REALM_SHARED then
        if SERVER then AddCSLuaFile(filePath) end
        SafeInclude(filePath)
        return true
    end
    return false
end

local function GetRealmFromFile(filePath, defaultRealm)
    local content = file.Read(filePath, "LUA")
    if not content then return defaultRealm end
    
    local match = string_match(content, "MODULE%.Realm%s*=%s*BW%.REALM_([A-Z]+)")
    
    if match == "SERVER" then return BW.REALM_SERVER
    elseif match == "CLIENT" then return BW.REALM_CLIENT
    elseif match == "SHARED" then return BW.REALM_SHARED
    end
    
    local numMatch = string_match(content, "MODULE%.Realm%s*=%s*(%d)")
    if numMatch then return tonumber(numMatch) end
    
    return defaultRealm
end

function Loader:ScanAndLoad()
    local files, dirs = file.Find(MODULES_PATH .. "*", "LUA")
    
    -- Single file
    for _, fileName in ipairs(files) do
        if string_sub(fileName, -4) ~= ".lua" then continue end
        
        local modName = string_sub(fileName, 1, -5)
        local filePath = MODULES_PATH .. fileName
        
        local realm = GetRealmFromFile(filePath, BW.REALM_SHARED)
        
        local oldModule = _G.MODULE
        _G.MODULE = MODULE_BASE:New(modName, realm)
        
        local wasLoaded = ProcessModuleFile(filePath, realm)
        
        RegisterModuleInstance(_G.MODULE, wasLoaded)
        _G.MODULE = oldModule
    end

    -- Folder
    for _, dirName in ipairs(dirs) do
        if string_sub(dirName, 1, 1) == "." then continue end
        
        local innerPath = MODULES_PATH .. dirName .. "/"
        local innerFiles = file.Find(innerPath .. "*.lua", "LUA")
        
        local oldModule = _G.MODULE
        _G.MODULE = MODULE_BASE:New(dirName, BW.REALM_SHARED)
        
        local anyLoaded = false
        
        for _, f in ipairs(innerFiles) do
            if f == "init.lua" or f == "sh_init.lua" then
                local initPath = innerPath .. f
                local initRealm = GetRealmFromFile(initPath, BW.REALM_SHARED)
                
                if ProcessModuleFile(initPath, initRealm) then
                    anyLoaded = true
                end
                break
            end
        end

        for _, f in ipairs(innerFiles) do
            if f == "init.lua" or f == "sh_init.lua" then continue end
            
            local filePath = innerPath .. f
            local fileRealm = GetRealmFromFile(filePath, _G.MODULE.Realm)
            
            if ProcessModuleFile(filePath, fileRealm) then
                anyLoaded = true
            end
        end
        
        RegisterModuleInstance(_G.MODULE, anyLoaded)
        _G.MODULE = oldModule
    end
end

function Loader:Run()
    local startTime = SysTime()
    
    local function getEnvName()
        if CLIENT then
            return "Client"
        end
        return "Server"
    end
    Log("info", "Starting initialization of modules (" .. getEnvName() .. "-Side)...")
    self:ScanAndLoad()
    
    local count = table.Count(BW.Modules)
    local duration = math.Round(SysTime() - startTime, 5)
    
    Log("success", "Loaded ", cols.Cyan, count, cols.White, " modules in ", cols.Yellow, duration, cols.White, " seconds.")
end

BW.ModuleLoader = Loader
BW.ModuleLoader:Run()