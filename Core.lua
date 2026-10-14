local ADDON, ns = ...
_G.ArenaLFG = ns -- handy in game: /run print(ArenaLFG.VERSION)

ns.VERSION   = "0.1"
ns.PREFIX    = "ARENALFG"       -- addon message prefix
ns.CHANNEL   = "ArenaLFGSync"   -- hidden sync channel
ns.EXPIRE    = 150            -- seconds without heartbeat before a listing disappears
ns.HEARTBEAT = 60             -- seconds between re-broadcasts of your own listing
ns.listings  = {}             -- [playerName] = listing table
ns.applied   = {}             -- [leaderName] = "pending" | "invited" | "declined" (groups I signed up to)
ns.applicants = {}            -- [playerName] = listing table (people who signed up to MY group)

ns.ROLES = { "DPS", "Healer", "Tank" }
ns.TIERS = { "New to arena", "Casual (< 1500)", "1500+", "1800+", "2000+", "2200+", "2400+" }

----------------------------------------------------------------------
-- Printing / debug
----------------------------------------------------------------------
function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99ArenaLFG:|r " .. tostring(msg))
end

function ns.Debug(msg)
    if ns.DEBUG then
        DEFAULT_CHAT_FRAME:AddMessage("|cff888888ArenaLFG dbg: " .. tostring(msg) .. "|r")
    end
end

----------------------------------------------------------------------
-- Tiny timer helper (3.3.5 has no C_Timer)
----------------------------------------------------------------------
local timers = {}
local timerFrame = CreateFrame("Frame")
timerFrame:SetScript("OnUpdate", function(self, elapsed)
    for i = #timers, 1, -1 do
        local t = timers[i]
        t.left = t.left - elapsed
        if t.left <= 0 then
            table.remove(timers, i)
            if t.every then
                t.left = t.every
                table.insert(timers, t)
            end
            t.fn()
        end
    end
end)

function ns.After(sec, fn)  table.insert(timers, { left = sec, fn = fn }) end
function ns.Every(sec, fn)  table.insert(timers, { left = sec, every = sec, fn = fn }) end

----------------------------------------------------------------------
-- Saved variables
----------------------------------------------------------------------
local defaults = {
    debug = false,
    minimap = { angle = 200, hide = false },
    mine = {
        role = "DPS", gs = 0,
        hasTeam = false, teamRating = 0,
        tier = 1, seasonal = false, tenGames = false,
        note = "", posted = false,
    },
    filters = { role = "Any", team = "Any", seasonal = "Any", tenGames = false },
}

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        ArenaLFGDB = ArenaLFGDB or {}
        CopyDefaults(defaults, ArenaLFGDB)
        ns.DB = ArenaLFGDB
        ns.DEBUG = ArenaLFGDB.debug
        local okRole = false
        for _, r in ipairs(ns.ROLES) do if r == ArenaLFGDB.mine.role then okRole = true end end
        if not okRole then ArenaLFGDB.mine.role = "DPS" end
        ns.BuildMinimapButton()
    elseif event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        ns.After(5, ns.Comm_Join) -- channels are not ready right at login
        ns.After(8, ns.RequestArenaData)
    end
end)

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------
SLASH_ARENALFG1 = "/alfg"
SLASH_ARENALFG2 = "/arenalfg"
SlashCmdList["ARENALFG"] = function(msg)
    msg = strlower(strtrim(msg or ""))
    if msg == "" then
        ns.ToggleUI()
    elseif msg == "clear" then
        wipe(ns.listings)
        ns.Changed()
    elseif msg == "debug" then
        ns.DEBUG = not ns.DEBUG
        ns.DB.debug = ns.DEBUG
        ns.Print("Debug " .. (ns.DEBUG and "on" or "off"))
    elseif msg == "me" then
        ns.Print("class=" .. tostring(ns.GetMyClass()) .. " spec=" .. tostring(ns.GetMySpec())
            .. " gs=" .. tostring(ns.GetMyGearScore()))
        local tname, rating = ns.GetMy2v2Team()
        ns.Print("2v2 team=" .. tostring(tname) .. " rating=" .. tostring(rating))
        for i = 1, (MAX_ARENA_TEAMS or 3) do
            local n, size, r = GetArenaTeam(i)
            ns.Print("arena slot " .. i .. ": name=" .. tostring(n) .. " size=" .. tostring(size) .. " rating=" .. tostring(r))
        end
    elseif msg == "comm" then
        ns.Comm_Status()
    elseif msg == "minimap" then
        ns.DB.minimap.hide = not ns.DB.minimap.hide
        ns.UpdateMinimapButton()
        ns.Print("Minimap button " .. (ns.DB.minimap.hide and "hidden" or "shown"))
    else
        ns.Print("/alfg (toggle) | fake | fakeapp | clear | debug | me | comm | minimap")
    end
end

----------------------------------------------------------------------
-- Auto-delist when a group forms
----------------------------------------------------------------------
function ns.InGroup()
    return (GetNumPartyMembers() > 0) or (GetNumRaidMembers() > 0)
end

function ns.InPvpInstance()
    local inInstance, instanceType = IsInInstance()
    return inInstance and (instanceType == "arena" or instanceType == "pvp")
end

local gf = CreateFrame("Frame")
gf:RegisterEvent("PARTY_MEMBERS_CHANGED")
gf:RegisterEvent("RAID_ROSTER_UPDATE")
gf:RegisterEvent("ZONE_CHANGED_NEW_AREA")
gf:SetScript("OnEvent", function()
    if not ns.DB then return end
    local grouped = ns.InGroup()
    local inPvpInstance = ns.InPvpInstance()
    if not grouped and not inPvpInstance then return end

    if ns.DB.mine.posted then
        ns.Print(grouped and "You are in a group now, your listing was removed."
            or "You entered an arena or battleground, your listing was removed.")
        ns.RemoveMine()
    end

    if not grouped then return end
    -- and cancel any sign-ups I still have pending elsewhere
    for name, status in pairs(ns.applied) do
        if status == "pending" then
            local l = ns.listings[name]
            if l then ns.CancelApply(l) else ns.applied[name] = nil end
        end
    end
end)

-- Quick reload while developing: /rl
SLASH_ARENALFGRL1 = "/rl"
SlashCmdList["ARENALFGRL"] = ReloadUI