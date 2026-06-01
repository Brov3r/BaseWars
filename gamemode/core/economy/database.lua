local STATS = {
    Money    = { default = function() return (BW.Config and BW.Config.StartMoney) or 5000 end, type = "Int" },
    Kills    = { default = 0, type = "Int" },
    Deaths   = { default = 0, type = "Int" },
    Playtime = { default = 0, type = "Int" },
}

local PLAYER = FindMetaTable("Player")

for key, data in pairs(STATS) do
    local nwType = data.type or "Int"
    local getFunc = "GetNW2" .. nwType
    local setFunc = "SetNW2" .. nwType

    PLAYER["Get" .. key] = function(self)
        local def = type(data.default) == "function" and data.default() or data.default
        return self[getFunc](self, key, def)
    end

    if SERVER then
        PLAYER["Set" .. key] = function(self, value)
            self[setFunc](self, key, value)
            self:MarkStatDirty(key)
        end

        if nwType == "Int" or nwType == "Float" then
            PLAYER["Add" .. key] = function(self, amount)
                amount = math.Max(tonumber(amount) or 0, 0)
                self["Set" .. key](self, self["Get" .. key](self) + amount)
            end

            PLAYER["Take" .. key] = function(self, amount)
                amount = math.Max(tonumber(amount) or 0, 0) 
                local current = self["Get" .. key](self)
                self["Set" .. key](self, math.Max(current - amount, 0))
            end

            PLAYER["Has" .. key] = function(self, amount)
                return self["Get" .. key](self) >= (tonumber(amount) or 0)
            end
        end
    else
        PLAYER["Set" .. key] = function(self, value)
            if BW.Log then BW.Log("error", "[Client] Set" .. key .. " is Server Only!") end
        end
        if nwType == "Int" or nwType == "Float" then
            PLAYER["Add" .. key] = function(self, amount)
                if BW.Log then BW.Log("error", "[Client] Add" .. key .. " is Server Only!") end
            end
            PLAYER["Take" .. key] = function(self, amount)
                if BW.Log then BW.Log("error", "[Client] Take" .. key .. " is Server Only!") end
            end
            PLAYER["Has" .. key] = function(self, amount)
                return self["Get" .. key](self) >= (tonumber(amount) or 0)
            end
        end
    end
end

if SERVER then
    local function InitDB()
        local query = "CREATE TABLE IF NOT EXISTS bw_player_stats (SteamID64 VARCHAR(25) PRIMARY KEY"
        for k, v in pairs(STATS) do
            local sqlType = "INTEGER"
            if v.type == "Float" then sqlType = "REAL"
            elseif v.type == "String" then sqlType = "TEXT" end
            query = query .. ", " .. k .. " " .. sqlType
        end
        query = query .. ");"
        sql.Query(query)
    end
    hook.Add("Initialize", "BW_Database_Init", InitDB)

    function PLAYER:MarkStatDirty(key)
        self.BW_DirtyStats = self.BW_DirtyStats or {}
        self.BW_DirtyStats[key] = true
    end

    function PLAYER:SaveStats()
        if not self.BW_DirtyStats or table.IsEmpty(self.BW_DirtyStats) then return end
        
        local steamID = self:SteamID64()
        if not steamID then return end

        local updates = {}
        for k, _ in pairs(self.BW_DirtyStats) do
            local val = self["Get" .. k](self)
            local safeVal = type(val) == "string" and sql.SQLStr(val) or tonumber(val)
            table.insert(updates, k .. " = " .. safeVal)
        end

        local query = "UPDATE bw_player_stats SET " .. table.concat(updates, ", ") .. " WHERE SteamID64 = " .. sql.SQLStr(steamID) .. ";"
        sql.Query(query)

        table.Empty(self.BW_DirtyStats)
    end

    function PLAYER:LoadStats()
        local steamID = self:SteamID64()
        if not steamID then return end

        local data = sql.QueryRow("SELECT * FROM bw_player_stats WHERE SteamID64 = " .. sql.SQLStr(steamID) .. ";")
        
        if data then
            for k, v in pairs(STATS) do
                if data[k] ~= nil then
                    local val = data[k]
                    if v.type == "Int" then val = tonumber(val) or 0
                    elseif v.type == "Float" then val = tonumber(val) or 0.0 end
                    
                    self["SetNW2" .. (v.type or "Int")](self, k, val)
                end
            end
        else
            local cols = {"SteamID64"}
            local vals = {sql.SQLStr(steamID)}

            for k, v in pairs(STATS) do
                table.insert(cols, k)
                local def = type(v.default) == "function" and v.default() or v.default
                
                self["SetNW2" .. (v.type or "Int")](self, k, def)
                table.insert(vals, type(def) == "string" and sql.SQLStr(def) or tonumber(def))
            end

            sql.Query("INSERT INTO bw_player_stats (" .. table.concat(cols, ", ") .. ") VALUES (" .. table.concat(vals, ", ") .. ");")
        end
    end

    hook.Add("PlayerInitialSpawn", "BW_Database_Load", function(ply)
        ply:LoadStats()
    end)

    hook.Add("PlayerDisconnected", "BW_Database_SaveOnDisconnect", function(ply)
        ply:SaveStats()
    end)

    hook.Add("ShutDown", "BW_Database_SaveAll", function()
        for _, ply in ipairs(player.GetAll()) do
            ply:SaveStats()
        end
    end)

    timer.Create("BW_Database_BackgroundSave", 60, 0, function()
        for _, ply in ipairs(player.GetAll()) do
            ply:SaveStats()
        end
    end)
end