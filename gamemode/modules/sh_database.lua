local MODULE = MODULE
MODULE.Name = "DataBase"
MODULE.Author = "Brov3r"
MODULE.Require = {}
MODULE.DataBaseName = "bw_accounts"
MODULE.Stats = {
    Money = {default = function() return BW.Config.Economy.StartMoney or 5000 end, type = "Int", min = 0},
    Level = {default = 1, type = "Int", min = 1, max = 1000},
    XP = {default = 0, type = "Int", min = 0},
    RecoveryBalance = {default = 0, type = "Int", min = 0, changeLog = false},
    LifetimeEarned = {default = 0, type = "Int", min = 0, changeLog = false, methods = {has = false}},
    LifetimeSpent = {default = 0, type = "Int", min = 0, changeLog = false, methods = {has = false}},
    RaidAttacks = {default = 0, type = "Int", min = 0},
    RaidDefenses = {default = 0, type = "Int", min = 0},
    Kills = {default = 0, type = "Int", min = 0},
    Deaths = {default = 0, type = "Int", min = 0},
    Bounty = {default = 0, type = "Int", min = 0},
    Reputation = {default = 0, type = "Int", min = -100, max = 100, methods = {has = false}},
    PlayTime = {default = 0, type = "Int", min = 0, changeLog = false},
    CreatedAt = {default = 0, type = "Timestamp", changeLog = false, methods = {set = false, add = false, take = false, has = false}},
    LastSeen = {default = 0, type = "Timestamp", changeLog = false, methods = {set = false, add = false, take = false, has = false}},
    LoginCount = {default = 0, type = "Int", min = 0, changeLog = false, methods = {set = false, add = false, take = false, has = false}},
    DonateUntil = {default = 0, type = "Timestamp", methods = {has = false}}
}

local PLAYER = FindMetaTable("Player")
local function Default(data)
    return isfunction(data.default) and data.default() or data.default
end

local function NWType(data)
    return data.type == "Timestamp" and "Int" or (data.type or "Int")
end

local function SQLType(data)
    return data.type == "String" and "TEXT" or (data.type == "Float" and "REAL" or "INTEGER")
end

local function SQLValue(value)
    return isstring(value) and sql.SQLStr(value) or tostring(value)
end

local function Normalize(key, data, value, ply)
    if data.type == "String" then return tostring(value or "") end
    value = tonumber(value)
    if not BW.Utils.IsFinite(value) then return nil end
    local minimum = isfunction(data.min) and data.min(ply) or data.min
    local maximum = isfunction(data.max) and data.max(ply) or data.max
    if key == "Money" then maximum = math.Clamp(BW.Config.Economy.MaxMoney or 2147483647, 0, 2147483647) end
    if data.type ~= "Float" then
        value = math.floor(value)
        minimum = math.max(minimum or -2147483648, -2147483648)
        maximum = math.min(maximum or 2147483647, 2147483647)
    end
    return math.Clamp(value, minimum or -math.huge, maximum or math.huge)
end

function PLAYER:HasPrivilege()
    if self:IsAdmin() then return true end
    local group = BW.Config.PlayerGroups[self:GetUserGroup()]
    if group and group.Privilege then return true end
    local expiry = self.GetDonateUntil and self:GetDonateUntil() or 0
    return expiry == -1 or expiry > os.time()
end

function PLAYER:GetMaxXP(level)
    return math.floor(500 * math.pow(math.Clamp(level or self:GetLevel(), 1, 1000), 1.5))
end

if SERVER then
    function PLAYER:PostSetXP(_, value)
        if self.BW_UpdatingLevel then return end
        local level = self:GetLevel()
        local maxXP = self:GetMaxXP(level)
        if value < maxXP then return end
        self.BW_UpdatingLevel = true
        while value >= maxXP and level < 1000 do
            value = value - maxXP
            level = level + 1
            maxXP = self:GetMaxXP(level)
        end
        self:SetLevel(level)
        self:SetXP(math.min(value, maxXP - 1), true)
        self.BW_UpdatingLevel = nil
    end
end

function MODULE:Init()
    for key, data in pairs(self.Stats) do
        local getNW, setNW = "GetNW2" .. NWType(data), "SetNW2" .. NWType(data)
        local methods = data.methods or {}
        PLAYER["Get" .. key] = function(ply) return ply[getNW](ply, key, Default(data)) end
        if methods.has ~= false and data.type ~= "String" and data.type ~= "Timestamp" then
            PLAYER["Has" .. key] = function(ply, amount)
                amount = tonumber(amount)
                return BW.Utils.IsFinite(amount) and amount >= 0 and ply["Get" .. key](ply) >= amount
            end
        end
        if SERVER then
            if methods.set ~= false then
                PLAYER["Set" .. key] = function(ply, value, silent)
                    if not ply:IsBot() and not ply.BW_StatsLoaded then return false end
                    value = Normalize(key, data, value, ply)
                    if value == nil then return false end
                    if ply["PreSet" .. key] then
                        local replacement, cancel = ply["PreSet" .. key](ply, value)
                        if cancel then return false end
                        if replacement ~= nil then value = Normalize(key, data, replacement, ply) end
                        if value == nil then return false end
                    end
                    local old = ply["Get" .. key](ply)
                    if old == value then return true end
                    ply[setNW](ply, key, value)
                    ply:MarkStatDirty(key)
                    if key == "Money" then
                        if value > old then ply:AddLifetimeEarned(value - old)
                        else ply:AddLifetimeSpent(old - value) end
                    end
                    if data.changeLog ~= false and silent ~= true then
                        Log("info", ply:Nick(), "[" .. ply:SteamID64() .. "]", key, tostring(old), "->", tostring(value))
                    end
                    if ply["PostSet" .. key] then ply["PostSet" .. key](ply, old, value) end
                    return true
                end
            end
            if methods.add ~= false and data.type ~= "String" and data.type ~= "Timestamp" then
                PLAYER["Add" .. key] = function(ply, amount)
                    amount = tonumber(amount)
                    if not BW.Utils.IsFinite(amount) or amount <= 0 then return false end
                    return ply["Set" .. key](ply, ply["Get" .. key](ply) + amount)
                end
            end
            if methods.take ~= false and data.type ~= "String" and data.type ~= "Timestamp" then
                PLAYER["Take" .. key] = function(ply, amount)
                    amount = tonumber(amount)
                    if not BW.Utils.IsFinite(amount) or amount <= 0 then return false end
                    return ply["Set" .. key](ply, ply["Get" .. key](ply) - amount)
                end
            end
        else
            for _, method in ipairs({"set", "add", "take"}) do
                if methods[method] ~= false then
                    local name = string.upper(string.sub(method, 1, 1)) .. string.sub(method, 2) .. key
                    PLAYER[name] = function() Log("error", name, "is server-only") return false end
                end
            end
        end
    end
    if SERVER then self:InitServerDatabase() end
end

if SERVER then
    local function Query(query)
        local result = sql.Query(query)
        if result == false then ErrorNoHaltWithStack("[BW DB] " .. sql.LastError()) end
        return result
    end

    function MODULE:SyncDatabaseSchema()
        local columns = Query("PRAGMA table_info(" .. self.DataBaseName .. ");")
        if columns == false then return false end
        local existing = {}
        for _, column in ipairs(columns or {}) do existing[column.name] = true end
        for key, data in pairs(self.Stats) do
            assert(key:match("^[%w_]+$"), "Invalid statistic name")
            if not existing[key] then
                local value = Normalize(key, data, Default(data))
                if Query("ALTER TABLE " .. self.DataBaseName .. " ADD COLUMN " .. key .. " " .. SQLType(data) .. " DEFAULT " .. SQLValue(value) .. ";") == false then return false end
            end
        end
        return true
    end

    function MODULE:InitServerDatabase()
        local name = self.DataBaseName
        assert(name:match("^[%w_]+$"), "Invalid database name")
        assert(Query("CREATE TABLE IF NOT EXISTS " .. name .. " (SteamID64 TEXT PRIMARY KEY);") ~= false, "Cannot create account table")
        assert(self:SyncDatabaseSchema(), "Cannot migrate account table")

        function PLAYER:MarkStatDirty(key)
            if not MODULE.Stats[key] then return end
            self.BW_DirtyStats = self.BW_DirtyStats or {}
            self.BW_DirtyStats[key] = true
        end

        -- Deferred clearing lets a failed COMMIT retain all unsaved statistics.
        function PLAYER:SaveStats(deferClear)
            if self:IsBot() then return true end
            if not self.BW_StatsLoaded then return false end
            if not self.BW_DirtyStats or not next(self.BW_DirtyStats) then return true end
            local updates = {}
            for key in pairs(self.BW_DirtyStats) do
                if MODULE.Stats[key] then updates[#updates + 1] = key .. " = " .. SQLValue(self["Get" .. key](self)) end
            end
            if #updates == 0 then return true end
            if Query("UPDATE " .. name .. " SET " .. table.concat(updates, ", ") .. " WHERE SteamID64 = " .. sql.SQLStr(self:SteamID64()) .. ";") == false then return false end
            if not deferClear then self.BW_DirtyStats = {} end
            return true
        end

        function PLAYER:LoadStats()
            if self:IsBot() then return true end
            self.BW_StatsLoaded = false
            local rows = Query("SELECT * FROM " .. name .. " WHERE SteamID64 = " .. sql.SQLStr(self:SteamID64()) .. ";")
            if rows == false then self:Kick("Account database unavailable. Please reconnect later.") return false end
            local row = rows and rows[1]
            local columns, values = {"SteamID64"}, {sql.SQLStr(self:SteamID64())}
            for key, data in pairs(MODULE.Stats) do
                local value = row and row[key] or Default(data)
                if not row and key == "CreatedAt" then value = os.time() end
                if key == "LoginCount" then value = (tonumber(value) or 0) + 1 end
                value = Normalize(key, data, value, self) or Normalize(key, data, Default(data), self)
                self["SetNW2" .. NWType(data)](self, key, value)
                if row then
                    if tostring(value) ~= tostring(row[key]) then self:MarkStatDirty(key) end
                else
                    columns[#columns + 1], values[#values + 1] = key, SQLValue(value)
                end
            end
            if not row and Query("INSERT INTO " .. name .. " (" .. table.concat(columns, ", ") .. ") VALUES (" .. table.concat(values, ", ") .. ");") == false then
                self:Kick("Account database unavailable. Please reconnect later.")
                return false
            end
            self.BW_StatsLoaded = true
            self.BW_PlayTimeStarted = CurTime()
            return true
        end

        local function UpdateSession(ply)
            if not ply.BW_StatsLoaded then return end
            local now = CurTime()
            local started = ply.BW_PlayTimeStarted or now
            local minutes = math.floor((now - started) / 60)
            if minutes > 0 then
                ply:SetPlayTime(ply:GetPlayTime() + minutes, true)
                ply.BW_PlayTimeStarted = started + minutes * 60
            end
            ply:SetNW2Int("LastSeen", os.time())
            ply:MarkStatDirty("LastSeen")
        end

        local function SaveAll()
            if Query("BEGIN;") == false then return end
            local saved, ok = {}, true
            for _, ply in ipairs(player.GetAll()) do
                if not ply:IsBot() and ply.BW_StatsLoaded then
                    UpdateSession(ply)
                    if ply:SaveStats(true) then saved[#saved + 1] = ply else ok = false end
                end
            end
            if not ok then Query("ROLLBACK;") return end
            if Query("COMMIT;") == false then Query("ROLLBACK;") return end
            for _, ply in ipairs(saved) do ply.BW_DirtyStats = {} end
        end

        hook.Add("PlayerInitialSpawn", "BW_DB_Load", function(ply) ply:LoadStats() end)
        hook.Add("PlayerDisconnected", "BW_DB_Save", function(ply)
            if not ply:IsBot() then UpdateSession(ply) ply:SaveStats() end
        end)
        hook.Add("ShutDown", "BW_DB_SaveAll", SaveAll)
        timer.Remove("BW_DB_PlaytimeTracker")
        timer.Create("BW_DB_AutoSave", 60, 0, SaveAll)
    end
end
