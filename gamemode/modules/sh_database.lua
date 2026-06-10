local MODULE = MODULE

MODULE.Name = "DataBase"
MODULE.Author = "Brov3r"
MODULE.Require = {}

MODULE.DataBaseName = "bw_accounts"
MODULE.Stats = {
    -- === Economy ===
    Money			= { default = function() return (BW.Config and BW.Config.Economy and BW.Config.Economy.StartMoney) or 5000 end, type = "Int", min = 0 },
	Level			= { default = 1, type = "Int", max = 100, min = 0 },
	XP				= { default = 0, type = "Int", min = 0 },
	RecoveryBalance = { default = 0, type = "Int", changeLog = false, min = 0 },
	LifetimeEarned  = { default = 0, type = "Int", methods = { has = false }, changeLog = false, min = 0 },
	LifetimeSpent   = { default = 0, type = "Int", methods = { has = false }, changeLog = false, min = 0 },

	-- === Raid ===
	RaidAttacks		= { default = 0, type = "Int", min = 0 },
	RaidDefenses	= { default = 0, type = "Int", min = 0 },

	-- === PVP ===
	Kills			= { default = 0, type = "Int", min = 0 },
	Deaths			= { default = 0, type = "Int", min = 0 },
	Bounty			= { default = 0, type = "Int", min = 0 },

	-- === Social ===
	Reputation		= { default = 0, type = "Int", max = 100, min = -100, methods = { has = false } },
		
	-- === Account ===
	PlayTime		= { default = 0, type = "Int", changeLog = false, min = 0 },
	CreatedAt		= { default = 0, type = "Timestamp", methods = { set = false, add = false, take = false, has = false }, changeLog = false },
	LastSeen		= { default = 0, type = "Timestamp", methods = { set = false, add = false, take = false, has = false }, changeLog = false },
	LoginCount		= { default = 0, type = "Int", methods = { set = false, add = false, take = false, has = false }, changeLog = false, min = 0 },
	DonateUntil		= { default = 0, type = "Timestamp", methods = { has = false } }
}

local PLAYER = FindMetaTable("Player")

-- CUSTOM OVERRIDE
function PLAYER:HasPrivilege()
    if self:IsAdmin() or self:IsSuperAdmin() then return true end
    local groupData = BW.Config and BW.Config.PlayerGroups and BW.Config.PlayerGroups[self:GetUserGroup()]
    return groupData and groupData.Privilege == true or false
end

function PLAYER:GetMaxXP(inputLevel)
    local level = inputLevel or self:GetLevel()
    return math.floor(500 * math.pow(level, 1.5))
end

if SERVER then
    function PLAYER:PostSetXP(oldValue, newValue)
        local maxXP = self:GetMaxXP()
        if newValue >= maxXP then
            local level = self:GetLevel()
            local remainder = newValue
            
            while remainder >= maxXP do
                remainder = remainder - maxXP
                level = level + 1
                
                maxXP = self:GetMaxXP(level)
            end
            
            self:SetLevel(level)
            self:SetXP(remainder, true)
        end
    end
end

local function GetNWType(statType)
    if statType == "Timestamp" then return "Int" end
    return statType or "Int"
end

local function GetSQLType(statType)
    if statType == "Float" then return "REAL" end
    if statType == "String" then return "TEXT" end
    return "INTEGER"
end

function MODULE:Init()
    for key, data in pairs(self.Stats) do
        local statType = data.type or "Int"
        local nwType = GetNWType(statType)
        local getFunc = "GetNW2" .. nwType
        local setFunc = "SetNW2" .. nwType
        local methods = data.methods or {}
		local changeLog = (data.changeLog ~= nil) and data.changeLog or true

        -- [GET]
        if methods.get ~= false then
            PLAYER["Get" .. key] = function(ply)
                local def = type(data.default) == "function" and data.default() or data.default
                return ply[getFunc](ply, key, def)
            end
        end

        -- [HAS]
        if methods.has ~= false and (statType == "Int" or statType == "Float") then
            PLAYER["Has" .. key] = function(ply, amount)
                return ply["Get" .. key](ply) >= (tonumber(amount) or 0)
            end
        end

        -- [SET / ADD / TAKE] (SERVER ONLY)
        if SERVER then
            if methods.set ~= false then
                PLAYER["Set" .. key] = function(ply, value, silent)
                    if statType == "Int" or statType == "Float" then
                        value = tonumber(value) or 0

                        local minVal = data.min
                        local maxVal = data.max

                        if type(maxVal) == "function" then maxVal = maxVal(ply) end
                        if type(minVal) == "function" then minVal = minVal(ply) end

                        if minVal or maxVal then
                            value = math.Clamp(value, minVal or -9007199254740991, maxVal or 9007199254740991)
                        end
                    end

                    if ply["PreSet" .. key] then
                        local overrideVal, cancel = ply["PreSet" .. key](ply, value)
                        if cancel then return end
                        if overrideVal ~= nil then value = overrideVal end
                    end

                    local oldValue = ply["Get" .. key](ply)
                    if oldValue == value then return end

                    ply[setFunc](ply, key, value)
                    ply:MarkStatDirty(key)
                    
                    if changeLog and not silent then
                        Log("info", 
                            BW.Config and BW.Config.Colors and BW.Config.Colors.Cyan or Color(0,255,255), ply:Nick(), 
                            color_white, " set ", 
                            BW.Config and BW.Config.Colors and BW.Config.Colors.Cyan or Color(0,255,255), key, 
                            color_white, ": ", 
                            BW.Config and BW.Config.Colors and BW.Config.Colors.Error or Color(255,0,0), tostring(oldValue), 
                            color_white, " -> ", 
                            BW.Config and BW.Config.Colors and BW.Config.Colors.Success or Color(0,255,0), tostring(value)
                        )
                    end

                    if ply["PostSet" .. key] then
                        ply["PostSet" .. key](ply, oldValue, value)
                    end
                end
            end

            if methods.add ~= false and (statType == "Int" or statType == "Float") then
                PLAYER["Add" .. key] = function(ply, amount)
                    amount = tonumber(amount) or 0
                    if amount <= 0 then return end
                    if ply["Set" .. key] then
                        ply["Set" .. key](ply, ply["Get" .. key](ply) + amount)
                    else
                        local val = ply["Get" .. key](ply) + amount
                        ply[setFunc](ply, key, val)
                        ply:MarkStatDirty(key)
                    end
                end
            end

            if methods.take ~= false and (statType == "Int" or statType == "Float") then
                PLAYER["Take" .. key] = function(ply, amount)
                    amount = tonumber(amount) or 0
                    if amount <= 0 then return end
                    if ply["Set" .. key] then
                        ply["Set" .. key](ply, ply["Get" .. key](ply) - amount, 0)
                    else
                        local val = ply["Get" .. key](ply) - amount
                        ply[setFunc](ply, key, val)
                        ply:MarkStatDirty(key)
                    end
                end
            end
        else
            if methods.set ~= false then PLAYER["Set" .. key] = function() Log("error", "[Client] Set" .. key, " is Server-only!") end end
            if methods.add ~= false then PLAYER["Add" .. key] = function() Log("error", "[Client] Add" .. key, " is Server-only!") end end
            if methods.take ~= false then PLAYER["Take" .. key] = function() Log("error", "[Client] Take" .. key, " is Server-only!") end end
        end
    end

    if SERVER then self:InitServerDatabase() end
end

if SERVER then
	function MODULE:SyncDatabaseSchema()
		local tblName = self.DataBaseName
		local currentColumns = sql.Query("PRAGMA table_info(" .. tblName .. ");") or {}
		local existingCols = {}
		
		for _, col in ipairs(currentColumns) do
			existingCols[col.name] = true
		end

		for key, data in pairs(self.Stats) do
			if not existingCols[key] then
				local sqlType = GetSQLType(data.type)
				local query = string.format("ALTER TABLE %s ADD COLUMN %s %s DEFAULT %s;", 
					tblName, 
					key, 
					sqlType, 
					(type(data.default) == "function" and data.default()) or data.default or 0
				)
				
				local err = sql.Query(query)
				if not err then
					Log("success", "Database: Added missing column '" .. key .. "' to " .. tblName)
				else
					Log("error", "Database: Failed to add column '" .. key .. "': " .. err)
				end
			end
		end
	end

    function MODULE:InitServerDatabase()
		local tblName = self.DataBaseName
        local query = "CREATE TABLE IF NOT EXISTS " .. tblName .. " (SteamID64 VARCHAR(25) PRIMARY KEY"
        
		self:SyncDatabaseSchema()
        
        for k, v in pairs(self.Stats) do
            query = query .. ", " .. k .. " " .. GetSQLType(v.type)
        end
        
        local err = sql.Query(query .. ");")
        if err then ErrorNoHaltWithStack("[BW DB] Table creation failed: " .. err) end

        local PLAYER = FindMetaTable("Player")

        function PLAYER:MarkStatDirty(key)
            self.BW_DirtyStats = self.BW_DirtyStats or {}
            self.BW_DirtyStats[key] = true
        end

        function PLAYER:SaveStats()
            if self:IsBot() then return end
            if not self.BW_DirtyStats or next(self.BW_DirtyStats) == nil then return end
            
            local steamID = self:SteamID64()
            if not steamID or steamID == "BOT" then return end

            local updates = {}
            for k, _ in pairs(self.BW_DirtyStats) do
                local val = self["Get" .. k](self)
                local sqlVal = type(val) == "string" and sql.SQLStr(val) or tostring(val or 0)
                table.insert(updates, k .. " = " .. sqlVal)
            end
            
            local err = sql.Query("UPDATE " .. tblName .. " SET " .. table.concat(updates, ", ") .. " WHERE SteamID64 = " .. sql.SQLStr(steamID) .. ";")
            if err then
                ErrorNoHaltWithStack("[BW DB] Save failed for " .. self:Nick() .. ": " .. err)
            else
                self.BW_DirtyStats = {}
            end
        end

        function PLAYER:LoadStats()
            if self:IsBot() then return end
            
            local steamID = self:SteamID64()
            if not steamID or steamID == "BOT" then return end

            local data = sql.QueryRow("SELECT * FROM " .. tblName .. " WHERE SteamID64 = " .. sql.SQLStr(steamID) .. ";")
            local now = os.time()
            
            if data then
                for k, v in pairs(MODULE.Stats) do
                    local val = data[k]
                    local def = type(v.default) == "function" and v.default() or v.default
                    local finalVal = (val ~= nil) and ((v.type == "Int" or v.type == "Float" or v.type == "Timestamp") and tonumber(val) or val) or def
                    
                    self["SetNW2" .. GetNWType(v.type)](self, k, finalVal)
                end
                
                local currentLogins = self:GetLoginCount()
                self:SetNW2Int("LoginCount", currentLogins + 1)
                self:MarkStatDirty("LoginCount")
            else
                local cols, vals = {"SteamID64"}, {sql.SQLStr(steamID)}
                
                for k, v in pairs(MODULE.Stats) do
                    table.insert(cols, k)
                    
                    local def = type(v.default) == "function" and v.default() or v.default
                    
                    if k == "CreatedAt" then def = now end
                    if k == "LoginCount" then def = 1 end

                    self["SetNW2" .. GetNWType(v.type)](self, k, def)
                    
                    local sqlDef = type(def) == "string" and sql.SQLStr(def) or tostring(def or 0)
                    table.insert(vals, sqlDef)
                end
                
                local err = sql.Query("INSERT INTO " .. tblName .. " (" .. table.concat(cols, ", ") .. ") VALUES (" .. table.concat(vals, ", ") .. ");")
                if err then ErrorNoHaltWithStack("[BW DB] Insert failed for " .. self:Nick() .. ": " .. err) end
            end
        end

        hook.Add("PlayerInitialSpawn", "BW_DB_Load", function(p) 
            if IsValid(p) and not p:IsBot() then p:LoadStats() end 
        end)
        
        hook.Add("PlayerDisconnected", "BW_DB_Save", function(p) 
            if IsValid(p) and not p:IsBot() then
                p:SetNW2Int("LastSeen", os.time())
                p:MarkStatDirty("LastSeen")
                
                p:SaveStats() 
            end 
        end)
        
        hook.Add("ShutDown", "BW_DB_SaveAll", function() 
            sql.Begin()
            for _, p in ipairs(player.GetAll()) do 
                if IsValid(p) and not p:IsBot() then 
                    p:SetNW2Int("LastSeen", os.time())
                    p:MarkStatDirty("LastSeen")
                    p:SaveStats() 
                end 
            end 
            sql.Commit()
        end)
        
        timer.Create("BW_DB_AutoSave", 60, 0, function() 
            for _, p in ipairs(player.GetAll()) do 
                if IsValid(p) and not p:IsBot() then p:SaveStats() end 
            end 
        end)

        timer.Create("BW_DB_PlaytimeTracker", 60, 0, function()
            for _, p in ipairs(player.GetAll()) do
                if IsValid(p) and not p:IsBot() then
                    if p.AddPlayTime then
                        p:SetPlayTime(p:GetPlayTime() + 1, true)
                    else
                        local current = p:GetPlayTime()
                        p:SetNW2Int("PlayTime", current + 1)
                        p:MarkStatDirty("PlayTime")
                    end
                end
            end
        end)
    end
end