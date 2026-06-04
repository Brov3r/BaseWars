MODULE.Name   = "Database"
MODULE.Author = "Brov3r"
MODULE.Realm  = BW.REALM_SHARED

MODULE.Stats = {
    Money    = { default = function() return (BW.Config and BW.Config.StartMoney) or 5000 end, type = "Int" },
    Kills    = { default = 0, type = "Int" },
    Deaths   = { default = 0, type = "Int" },
    Playtime = { default = 0, type = "Int" },
}

local mod = MODULE

function MODULE:Init()
    local PLAYER = FindMetaTable("Player")
    local serverOnly = (BW.Translate and BW.Translate.ServerOnly) or "is Server-only!"

    for key, data in pairs(self.Stats) do
        local nwType = data.type or "Int"
        local getFunc = "GetNW2" .. nwType
        local setFunc = "SetNW2" .. nwType

        PLAYER["Get" .. key] = function(ply)
            local def = type(data.default) == "function" and data.default() or data.default
            return ply[getFunc](ply, key, def)
        end

        PLAYER["Has" .. key] = function(ply, amount)
            return ply["Get" .. key](ply) >= (tonumber(amount) or 0)
        end

        if SERVER then
            PLAYER["Set" .. key] = function(ply, value)
                local oldValue = ply["Get" .. key](ply)
                ply[setFunc](ply, key, value)
                ply:MarkStatDirty(key)
                
                BW.Log("info", 
                    BW.Config.Colors.Cyan, ply:Nick(), 
                    BW.Config.Colors.White, " set ", 
                    BW.Config.Colors.Cyan, key, 
                    BW.Config.Colors.White, ": ", 
                    BW.Config.Colors.Red, tostring(oldValue), 
                    BW.Config.Colors.White, " -> ", 
                    BW.Config.Colors.Green, tostring(value)
                )
            end

            if nwType == "Int" or nwType == "Float" then
                PLAYER["Add" .. key] = function(ply, amount)
                    amount = math.Max(tonumber(amount) or 0, 0)
                    ply["Set" .. key](ply, ply["Get" .. key](ply) + amount)
                end
                
                PLAYER["Take" .. key] = function(ply, amount)
                    amount = math.Max(tonumber(amount) or 0, 0)
                    ply["Set" .. key](ply, math.Max(ply["Get" .. key](ply) - amount, 0))
                end
            end
        else
            PLAYER["Set" .. key] = function() BW.Log("error", "[Client] Set" .. key, serverOnly) end
            PLAYER["Add" .. key] = function() BW.Log("error", "[Client] Add" .. key, serverOnly) end
            PLAYER["Take" .. key] = function() BW.Log("error", "[Client] Take" .. key, serverOnly) end
        end
    end

    if SERVER then self:InitServerDatabase() end
end

if SERVER then
    function MODULE:InitServerDatabase()
        local query = "CREATE TABLE IF NOT EXISTS bw_player_stats (SteamID64 VARCHAR(25) PRIMARY KEY"
        for k, v in pairs(self.Stats) do
            local sqlType = (v.type == "Float" and "REAL") or (v.type == "String" and "TEXT") or "INTEGER"
            query = query .. ", " .. k .. " " .. sqlType
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
            
            local err = sql.Query("UPDATE bw_player_stats SET " .. table.concat(updates, ", ") .. " WHERE SteamID64 = " .. sql.SQLStr(steamID) .. ";")
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

            local data = sql.QueryRow("SELECT * FROM bw_player_stats WHERE SteamID64 = " .. sql.SQLStr(steamID) .. ";")
            
            if data then
                for k, v in pairs(mod.Stats) do
                    local val = data[k]
                    local def = type(v.default) == "function" and v.default() or v.default
                    
                    local finalVal = (val ~= nil) and ((v.type == "Int" or v.type == "Float") and tonumber(val) or val) or def
                    
                    self["SetNW2" .. (v.type or "Int")](self, k, finalVal)
                end
            else
                local cols, vals = {"SteamID64"}, {sql.SQLStr(steamID)}
                for k, v in pairs(mod.Stats) do
                    table.insert(cols, k)
                    local def = type(v.default) == "function" and v.default() or v.default
                    
                    self["SetNW2" .. (v.type or "Int")](self, k, def)
                    
                    local sqlDef = type(def) == "string" and sql.SQLStr(def) or tostring(def or 0)
                    table.insert(vals, sqlDef)
                end
                
                local err = sql.Query("INSERT INTO bw_player_stats (" .. table.concat(cols, ", ") .. ") VALUES (" .. table.concat(vals, ", ") .. ");")
                if err then ErrorNoHaltWithStack("[BW DB] Insert failed for " .. self:Nick() .. ": " .. err) end
            end
        end

        hook.Add("PlayerInitialSpawn", "BW_DB_Load", function(p) 
            if IsValid(p) and not p:IsBot() then p:LoadStats() end 
        end)
        
        hook.Add("PlayerDisconnected", "BW_DB_Save", function(p) 
            if IsValid(p) and not p:IsBot() then p:SaveStats() end 
        end)
        
        hook.Add("ShutDown", "BW_DB_SaveAll", function() 
            for _, p in ipairs(player.GetAll()) do 
                if IsValid(p) and not p:IsBot() then p:SaveStats() end 
            end 
        end)
        
        timer.Create("BW_DB_AutoSave", 60, 0, function() 
            for _, p in ipairs(player.GetAll()) do 
                if IsValid(p) and not p:IsBot() then p:SaveStats() end 
            end 
        end)

        timer.Create("BW_DB_PlaytimeTracker", 60, 0, function()
            for _, p in ipairs(player.GetAll()) do
                if IsValid(p) and not p:IsBot() then
                    p:AddPlaytime(60)
                    p:MarkStatDirty("Playtime")
                end
            end
        end)
    end
end