local STATS = {
    Money    = { order = 1, default = function() return (BW.Config and BW.Config.StartMoney) or 5000 end, share = false },
    Kills    = { order = 2, default = 0, share = true },
    Deaths   = { order = 3, default = 0, share = true },
    Playtime = { order = 4, default = 0, share = false },
}

local STAT_KEYS = {}
for k, _ in pairs(STATS) do
    table.insert(STAT_KEYS, k)
end

table.sort(STAT_KEYS, function(a, b)
    return (STATS[a].order or 0) < (STATS[b].order or 0)
end)

local SHARED_STAT_KEYS = {}
for _, k in ipairs(STAT_KEYS) do
    if STATS[k].share then
        table.insert(SHARED_STAT_KEYS, k)
    end
end

local PLAYER = FindMetaTable("Player")

if SERVER then
    util.AddNetworkString("SyncPlayerStats")
    util.AddNetworkString("SyncPlayerStat")
    util.AddNetworkString("PlayerReady")
    util.AddNetworkString("RequestPublicStats")
    util.AddNetworkString("SendPublicStats")

    local columns = { "sid TEXT PRIMARY KEY" }
    for _, k in ipairs(STAT_KEYS) do
        local v = STATS[k]
        local def = 0
        if type(v.default) ~= "function" then def = v.default end
        columns[#columns + 1] = k .. " INTEGER DEFAULT " .. def
    end
    sql.Query("CREATE TABLE IF NOT EXISTS basewars_db (" .. table.concat(columns, ", ") .. ")")

    local ServerCache = {}

    local function Load(ply)
        if not IsValid(ply) then return end
        local sid = ply:SteamID64()
        if ServerCache[sid] then return ServerCache[sid] end

        local row = sql.QueryRow("SELECT * FROM basewars_db WHERE sid = " .. sql.SQLStr(sid))
        local data = {}

        if row then
            for _, k in ipairs(STAT_KEYS) do
                local val = tonumber(row[k])
                if val == nil then
                    val = (type(STATS[k].default) == "function" and STATS[k].default() or STATS[k].default)
                end
                data[k] = val
            end
        else
            for _, k in ipairs(STAT_KEYS) do
                data[k] = (type(STATS[k].default) == "function" and STATS[k].default() or STATS[k].default)
            end
            local cols, vals = { "sid" }, { sql.SQLStr(sid) }
            for _, k in ipairs(STAT_KEYS) do
                cols[#cols + 1] = k
                vals[#vals + 1] = math.floor(data[k])
            end
            sql.Query("INSERT INTO basewars_db (" .. table.concat(cols, ",") .. ") VALUES (" .. table.concat(vals, ",") .. ")")
        end

        ServerCache[sid] = data
        return data
    end

    local function SyncPartial(ply, key, target)
        local d = Load(ply)
        if not d then return end
        net.Start("SyncPlayerStat")
            net.WriteEntity(ply)
            net.WriteString(key)
            net.WriteUInt64(math.floor(d[key] or 0))
        
        if target then
            net.Send(target)
        elseif STATS[key] and STATS[key].share then
            net.Broadcast()
        else
            net.Send(ply)
        end
    end

    local function SyncAll(ply, target)
        local d = Load(ply)
        if not d then return end
        net.Start("SyncPlayerStats")
            net.WriteEntity(ply)
            net.WriteUInt(#STAT_KEYS, 8)
            for _, k in ipairs(STAT_KEYS) do
                net.WriteUInt64(math.floor(d[k] or 0))
            end
        net.Send(target or ply)
    end

    local function Save(ply)
        if not IsValid(ply) then return end
        local sid = ply:SteamID64() or ply:SteamID()
        local d = ServerCache[sid]
        if not d then return end
        local cols, vals = { "sid" }, { sql.SQLStr(sid) }
        for _, k in ipairs(STAT_KEYS) do
            cols[#cols + 1] = k
            vals[#vals + 1] = math.floor(d[k] or 0)
        end
        sql.Query("REPLACE INTO basewars_db (" .. table.concat(cols, ",") .. ") VALUES (" .. table.concat(vals, ",") .. ")")
    end

    for _, k in ipairs(STAT_KEYS) do
        local key = k

        PLAYER["Get" .. key] = function(self)
            local d = Load(self)
            return d and d[key] or 0
        end

        PLAYER["Set" .. key] = function(self, val)
            local d = Load(self)
            if not d then return end
            local oldVal = d[key] or 0
            local newVal = math.floor(val)
            if oldVal == newVal then return end
            d[key] = newVal
            SyncPartial(self, key)
            if BW.Log then
                BW.Log(string.format("[DB] %s (%s) | %s: %s -> %s", self:Nick(), self:SteamID(), key, tostring(oldVal), tostring(newVal)))
            end
        end

        PLAYER["Add" .. key] = function(self, amount)
            amount = math.max(tonumber(amount) or 0, 0)
            self["Set" .. key](self, self["Get" .. key](self) + amount)
        end

        PLAYER["Take" .. key] = function(self, amount)
            amount = math.max(tonumber(amount) or 0, 0)
            self["Set" .. key](self, math.max(self["Get" .. key](self) - amount, 0))
        end
    end

    function PLAYER:SaveStats() Save(self) end

    hook.Add("PlayerInitialSpawn", "DB_Load", function(ply) Load(ply) end)
    hook.Add("PlayerDisconnected", "DB_Save", function(ply) Save(ply) ServerCache[ply:SteamID64()] = nil end)
    hook.Add("ShutDown", "DB_SaveAll", function() for _, p in ipairs(player.GetAll()) do if IsValid(p) then Save(p) end end end)

    timer.Create("DB_Playtime", 60, 0, function()
        for _, p in ipairs(player.GetAll()) do if IsValid(p) then p:AddPlaytime(60) end end
    end)

    timer.Create("DB_AutoSave", 120, 0, function()
        for _, p in ipairs(player.GetAll()) do if IsValid(p) then Save(p) end end
    end)

    local function WritePublicStats(ply)
        local d = Load(ply)
        if not d then return end
        net.WriteEntity(ply)
        net.WriteUInt(#SHARED_STAT_KEYS, 8)
        for _, k in ipairs(SHARED_STAT_KEYS) do
            net.WriteUInt64(math.floor(d[k] or 0))
        end
    end

    net.Receive("RequestPublicStats", function(len, ply)
        if not IsValid(ply) then return end
        local num = net.ReadUInt(8)
        local targets = {}
        for i = 1, num do
            local ent = net.ReadEntity()
            if IsValid(ent) and ent:IsPlayer() then
                targets[#targets + 1] = ent
            end
        end
        
        net.Start("SendPublicStats")
            net.WriteUInt(#targets, 8)
            for _, tgt in ipairs(targets) do
                WritePublicStats(tgt)
            end
        net.Send(ply)
    end)

    net.Receive("PlayerReady", function(len, ply)
        if not IsValid(ply) then return end
        
        SyncAll(ply) 
        
        local allPlayers = player.GetAll()
    
        net.Start("SendPublicStats")
            net.WriteUInt(#allPlayers, 8)
            for _, tgt in ipairs(allPlayers) do
                WritePublicStats(tgt)
            end
        net.Send(ply)

        net.Start("SendPublicStats")
            net.WriteUInt(1, 8)
            WritePublicStats(ply)
        net.Broadcast() 
    end)

else -- CLIENT
    local ClientCache = {}
    local PendingRequests = {}

    net.Receive("SyncPlayerStats", function()
        local ply = net.ReadEntity()
        if not IsValid(ply) then return end
        local sid = ply:SteamID64()
        local count = net.ReadUInt(8)
        ClientCache[sid] = ClientCache[sid] or {}
        for i = 1, count do
            local val = net.ReadUInt64()
            local key = STAT_KEYS[i]
            if key then ClientCache[sid][key] = val end
        end
    end)

    net.Receive("SyncPlayerStat", function()
        local ply = net.ReadEntity()
        if not IsValid(ply) then return end
        local sid = ply:SteamID64()
        local key = net.ReadString()
        local val = net.ReadUInt64()
        ClientCache[sid] = ClientCache[sid] or {}
        ClientCache[sid][key] = val
    end)

    net.Receive("SendPublicStats", function()
        local num = net.ReadUInt(8)
        for i = 1, num do
            local ply = net.ReadEntity()
            if not IsValid(ply) then continue end
            local sid = ply:SteamID64()
            local count = net.ReadUInt(8)
            ClientCache[sid] = ClientCache[sid] or {}
            
            for j = 1, count do
                local val = net.ReadUInt64()
                local key = SHARED_STAT_KEYS[j]
                if key then
                    ClientCache[sid][key] = val
                end
            end
            PendingRequests[sid] = nil 
        end
    end)

    timer.Simple(0, function()
        if IsValid(LocalPlayer()) then
            net.Start("PlayerReady")
            net.SendToServer()
        end
    end)

    hook.Add("InitPostEntity", "DB_ClientReady", function()
        if IsValid(LocalPlayer()) then
            net.Start("PlayerReady")
            net.SendToServer()
        end
    end)

    for _, k in ipairs(STAT_KEYS) do
        local key = k
        PLAYER["Get" .. key] = function(self)
            if not IsValid(self) then return 0 end
            
            local sid = self:SteamID64()
            local d = ClientCache[sid]

            if self == LocalPlayer() or (d and d[key] ~= nil) then
                return d and d[key] or 0
            end

            if not PendingRequests[sid] or PendingRequests[sid] < CurTime() then
                PendingRequests[sid] = CurTime() + 5

                net.Start("RequestPublicStats")
                    net.WriteUInt(1, 8)
                    net.WriteEntity(self)
                net.SendToServer()
            end

            return 0
        end
        
        PLAYER["Set" .. key] = function() if BW.Log then BW.Log("error", "[Client] Set" .. key .. " Server Only") end end
        PLAYER["Add" .. key] = function() if BW.Log then BW.Log("error", "[Client] Add" .. key .. " Server Only") end end
        PLAYER["Take" .. key] = function() if BW.Log then BW.Log("error", "[Client] Take" .. key .. " Server Only") end end
    end
end