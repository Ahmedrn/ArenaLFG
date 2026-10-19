local ADDON, ns = ...
_G.ArenaLFG = ns -- handy in game: /run print(ArenaLFG.VERSION)

ns.VERSION   = GetAddOnMetadata(ADDON, "Version") or "unknown"
ns.PREFIX    = "ARENALFG"       -- addon message prefix
ns.CHANNEL   = "ArenaLFGSync"   -- hidden sync channel
ns.EXPIRE    = 150            -- seconds without heartbeat before a listing disappears
ns.HEARTBEAT = 60             -- seconds between re-broadcasts of your own listing
ns.LISTING_RESUME_WINDOW = 300 -- keep a saved listing across reloads for up to five minutes
ns.listings  = {}             -- [playerName] = listing table
ns.applied   = {}             -- [leaderName] = "pending" | "invited" | "declined" (groups I signed up to)
ns.applicants = {}            -- [playerName] = listing table (people who signed up to MY group)

ns.ROLES = { "DPS", "Healer", "Tank" }
ns.BRACKETS = { "2v2", "3v3", "DuoQ" }
ns.DEFAULT_BRACKET = "2v2"
-- arena team size that carries the rating for each bracket (DuoQ uses the "Solo Queue" team)
ns.BRACKET_TEAM_SIZE = { ["2v2"] = 2, ["3v3"] = 3, ["DuoQ"] = 5 }

-- Change the bracket the form edits; each bracket keeps its own seeking (role, specs, comp)
function ns.SetMineBracket(bracket)
    local m = ns.mine
    bracket = ns.NormalizeBracket(bracket)
    if m.bracket == bracket then return end
    m.seeks = m.seeks or {}
    local specs = {}
    for id, on in pairs(m.targetSpecs or {}) do specs[id] = on end
    m.seeks[m.bracket] = { role = m.targetRole, any = m.targetAny, specs = specs,
        comp = m.comp, haveSpec = m.haveSpec }
    local saved = m.seeks[bracket]
    m.bracket = bracket
    m.targetRole = saved and saved.role or "Any"
    m.targetAny = saved and saved.any or false
    m.targetSpecs = saved and saved.specs or {}
    m.comp = saved and saved.comp or nil
    m.haveSpec = saved and saved.haveSpec or nil
    ns.SanitizeMine()
end

-- Comp-based seeking only exists in 3v3
function ns.SanitizeMine()
    local m = ns.mine
    m.bracket = ns.NormalizeBracket(m.bracket)
    -- the comp and group choice are remembered; only the derived seeking is dropped
    if m.bracket ~= "3v3" and m.targetRole == "Comp" then
        m.targetRole, m.targetAny = "Any", false
        wipe(m.targetSpecs)
    end
end

-- team the rating comes from, and the short tag used in chat
function ns.TeamLabel(bracket)
    return ns.NormalizeBracket(bracket) == "DuoQ" and "Solo Queue team" or (ns.NormalizeBracket(bracket) .. " team")
end
function ns.NoTeamText(bracket)
    return ns.NormalizeBracket(bracket) == "DuoQ" and "Unrated" or "No team"
end
function ns.BracketTag(bracket)
    return ns.NormalizeBracket(bracket) == "DuoQ" and "duoq" or ns.NormalizeBracket(bracket)
end

function ns.NormalizeBracket(bracket)
    for _, b in ipairs(ns.BRACKETS) do
        if b == bracket then return b end
    end
    return ns.DEFAULT_BRACKET
end
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
-- Account-wide data lives in ArenaLFGDB itself (ns.SV); every setting that can
-- be changed in the options lives in a named profile (ns.DB). Characters pick a
-- profile, "Default" unless they switch.
local defaults = {
    debug = false,
    announceAsked = false,
    announceLastAt = 0,
    characters = {},
    profiles = {},
    profileKeys = {},
    hidden = {}, -- [playerName] = true, players hidden from the list
}

local profileDefaults = {
    globalChannel = "Global",
    announce = false,
    announceInterval = 2, -- minutes between Global announcements
    pvpIntegration = true,
    soundAlerts = true,
    matchAlerts = true,
    autoReply = true, -- whisper back while listed and inside an arena match
    applicantSound = "igPlayerInvite",
    matchSound = "MapPing",
    minimap = { angle = 200, hide = false },
    filters = { role = "Any", team = "Any", seasonal = "Any", tenGames = false },
}
ns.PROFILE_DEFAULTS = profileDefaults
ns.DEFAULT_PROFILE = "Default"
ns.ANNOUNCE_MIN_INTERVAL = 2
ns.ANNOUNCE_MAX_INTERVAL = 30

local mineDefaults = {
    role = "DPS", gs = 0, bracket = "2v2",
    hasTeam = false, teamRating = 0,
    tier = 1, seasonal = false, tenGames = false,
    note = "", targetRole = "Any", targetAny = false, targetSpecs = {}, posted = false,
    seeks = {}, -- seeking choices remembered per bracket
}

-- Stock 3.3.5 sound kits that can be picked for the alerts
ns.SOUNDS = {
    { key = "ReadyCheck", label = "Ready check" },
    { key = "igPlayerInvite", label = "Group invite" },
    { key = "PVPENTERQUEUE", label = "PvP queue" },
    { key = "RaidWarning", label = "Raid warning" },
    { key = "AuctionWindowOpen", label = "Auction bell" },
    { key = "TellMessage", label = "Whisper" },
    { key = "MapPing", label = "Map ping (soft)" },
    { key = "igMainMenuOptionCheckBoxOn", label = "Click (very soft)" },
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

local function CopyTable(src)
    local out = {}
    for k, v in pairs(src) do
        out[k] = type(v) == "table" and CopyTable(v) or v
    end
    return out
end

----------------------------------------------------------------------
-- Profiles
----------------------------------------------------------------------
local function CharacterKey()
    local player, realm = UnitName("player"), GetRealmName()
    if not player or player == "" or not realm or realm == "" then return nil end
    return player .. " - " .. realm
end

-- Settings that used to sit at the top level move into the Default profile
local function MigrateLegacySettings(sv)
    if sv.profilesMigrated then return end
    local profile = sv.profiles[ns.DEFAULT_PROFILE] or {}
    for key in pairs(profileDefaults) do
        if sv[key] ~= nil then
            if profile[key] == nil then profile[key] = sv[key] end
            sv[key] = nil
        end
    end
    sv.alertSound = nil -- replaced by applicantSound / matchSound
    sv.profiles[ns.DEFAULT_PROFILE] = profile
    sv.profilesMigrated = true
end

function ns.GetProfileName()
    local key = CharacterKey()
    return key and ns.SV.profileKeys[key] or ns.DEFAULT_PROFILE
end

function ns.GetProfileNames()
    local names = {}
    for name in pairs(ns.SV.profiles) do names[#names + 1] = name end
    table.sort(names)
    return names
end

local function ApplyProfile()
    if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
    if ns.frame and ns.frame.pvpCheck then
        ns.frame.pvpCheck:SetChecked(ns.DB.pvpIntegration)
        ns.frame.soundCheck:SetChecked(ns.DB.soundAlerts)
        ns.frame.matchCheck:SetChecked(ns.DB.matchAlerts)
    end
    if ns.RefreshOptions then ns.RefreshOptions() end
    ns.Changed()
end

function ns.SetProfile(name)
    if type(name) ~= "string" then return false end
    name = strtrim(name)
    if name == "" or #name > 32 or name:find("|", 1, true) then return false end
    ns.SV.profiles[name] = ns.SV.profiles[name] or {}
    CopyDefaults(profileDefaults, ns.SV.profiles[name])
    local key = CharacterKey()
    if key then ns.SV.profileKeys[key] = name end
    ns.DB = ns.SV.profiles[name]
    ApplyProfile()
    return true
end

function ns.CopyProfile(from)
    local source = ns.SV.profiles[from]
    if not source or source == ns.DB then return false end
    wipe(ns.DB)
    for k, v in pairs(source) do
        ns.DB[k] = type(v) == "table" and CopyTable(v) or v
    end
    CopyDefaults(profileDefaults, ns.DB)
    ApplyProfile()
    return true
end

function ns.DeleteProfile(name)
    if not ns.SV.profiles[name] or name == ns.GetProfileName() then return false end
    ns.SV.profiles[name] = nil
    for key, profile in pairs(ns.SV.profileKeys) do
        if profile == name then ns.SV.profileKeys[key] = nil end
    end
    return true
end

function ns.ResetProfile()
    wipe(ns.DB)
    CopyDefaults(profileDefaults, ns.DB)
    ApplyProfile()
end

----------------------------------------------------------------------
-- Alert sounds
----------------------------------------------------------------------
local function IsKnownSound(key)
    for _, sound in ipairs(ns.SOUNDS) do
        if sound.key == key then return true end
    end
    return false
end

-- Plays regardless of settings; used by the options' Test buttons
function ns.PreviewSound(key)
    if IsKnownSound(key) then pcall(PlaySound, key) end
end

function ns.PlayAlertSound(soundName)
    if not (ns.DB and ns.DB.soundAlerts) then return end
    pcall(PlaySound, soundName or profileDefaults.applicantSound)
end

-- kind is "applicant" (someone signed up to my group) or "match" (a listing
-- looking for my spec)
function ns.PlayAlert(kind)
    if not ns.DB then return end
    local key = kind == "match" and "matchSound" or "applicantSound"
    local sound = ns.DB[key]
    if not IsKnownSound(sound) then sound = profileDefaults[key] end
    ns.PlayAlertSound(sound)
end

local ev = CreateFrame("Frame")
local pendingAnnouncePrompt = false
local forceAnnouncePrompt = false

local function ShowAnnouncePrompt(force)
    if InCombatLockdown() then
        pendingAnnouncePrompt = true
        forceAnnouncePrompt = force or forceAnnouncePrompt
        ev:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    local popup = StaticPopup_Show("ARENALFG_ANNOUNCE_ONBOARDING")
    if popup then
        pendingAnnouncePrompt = false
        forceAnnouncePrompt = false
        ev:UnregisterEvent("PLAYER_REGEN_ENABLED")
        ns.SV.announceAsked = true
        popup:SetWidth(440)
        popup:SetHeight(300)
        local popupText = _G[popup:GetName() .. "Text"]
        if popupText then popupText:SetWidth(390) end
        popup:ClearAllPoints()
        popup:SetPoint("CENTER", UIParent, "CENTER", 0, -80)
    elseif ns.DB and (force or not ns.SV.announceAsked) then
        pendingAnnouncePrompt = true
        ns.After(5, function()
            if pendingAnnouncePrompt and ns.DB
                and (forceAnnouncePrompt or not ns.SV.announceAsked) then
                ShowAnnouncePrompt(forceAnnouncePrompt)
            end
        end)
    end
    return popup
end

ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        ArenaLFGDB = ArenaLFGDB or {}
        local legacyMine = ArenaLFGDB.mine
        CopyDefaults(defaults, ArenaLFGDB)
        ns.SV = ArenaLFGDB
        MigrateLegacySettings(ArenaLFGDB)
        local profileName = ns.GetProfileName()
        ArenaLFGDB.profiles[profileName] = ArenaLFGDB.profiles[profileName] or {}
        ns.DB = ArenaLFGDB.profiles[profileName]
        CopyDefaults(profileDefaults, ns.DB)

        local realm, player = GetRealmName(), UnitName("player")
        local mine
        if not realm or realm == "" or not player or player == "" then
            ns.Print("Could not load character-specific settings: character or realm name is unavailable.")
            mine = type(legacyMine) == "table" and legacyMine or {}
        else
            ArenaLFGDB.characters[realm] = ArenaLFGDB.characters[realm] or {}
            local realmCharacters = ArenaLFGDB.characters[realm]
            if not ArenaLFGDB.characterProfilesMigrated then
                realmCharacters[player] = realmCharacters[player] or {}
                if type(legacyMine) == "table" then
                    realmCharacters[player].mine = legacyMine
                end
                ArenaLFGDB.characterProfilesMigrated = true
            end
            realmCharacters[player] = realmCharacters[player] or {}
            realmCharacters[player].mine = realmCharacters[player].mine or {}
            mine = realmCharacters[player].mine
        end

        CopyDefaults(mineDefaults, mine)
        ns.mine = mine
        ArenaLFGDB.mine = nil
        local postedAt = tonumber(ns.mine.postedAt)
        local listingAge = postedAt and (time() - postedAt)
        if ns.mine.posted and (not listingAge or listingAge < 0 or listingAge > ns.LISTING_RESUME_WINDOW) then
            ns.mine.posted = false
            ns.mine.postedAt = nil
        end
        ns.mine.roleManual = nil
        ns.mine.afkDelisted, ns.mine.afkBracket = nil, nil -- AFK delisting never survives a reload
        ns.DEBUG = ns.SV.debug
        local okRole = false
        for _, r in ipairs(ns.ROLES) do if r == ns.mine.role then okRole = true end end
        if not okRole then ns.mine.role = "DPS" end
        ns.SanitizeMine()
        ns.BuildMinimapButton()
        if ns.BuildOptions then ns.BuildOptions() end
    elseif event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        ns.After(5, ns.Comm_Join) -- channels are not ready right at login
        ns.After(8, function() ns.Comm_EnsureGlobal() end) -- after the server's own auto-join
        ns.After(8, ns.RequestArenaData)
        ns.After(5, function()
            if ns.DB and not ns.SV.announceAsked and ShowAnnouncePrompt() then
                ns.SV.announceAsked = true
            end
        end)
    elseif event == "PLAYER_REGEN_ENABLED" and pendingAnnouncePrompt then
        if ns.DB and (forceAnnouncePrompt or not ns.SV.announceAsked) then
            ShowAnnouncePrompt(forceAnnouncePrompt)
        else
            pendingAnnouncePrompt = false
            forceAnnouncePrompt = false
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        end
    end
end)

StaticPopupDialogs["ARENALFG_ANNOUNCE_ONBOARDING"] = {
    text = "Thanks for installing ArenaLFG!\n\nWant ArenaLFG to announce your group in Global chat when you list it, so players without the addon can find you too?\n\nExample:\nDisc LF Hpal/Rdruid 2v2 951cr Exp: 2200+ (ArenaLFG)\n\n- Posted under your name, at most once every 2 minutes (adjustable in the options), only while your group is listed.\n- Server chat rules apply to you as if you typed it yourself.\n\nChange it anytime in Interface > AddOns > ArenaLFG or with /alfg announce on|off.",
    button1 = "Yes, announce my group",
    button2 = "No thanks",
    OnAccept = function()
        ns.SetAnnounceEnabled(true)
    end,
    OnCancel = function()
        ns.SetAnnounceEnabled(false)
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------
SLASH_ARENALFG1 = "/alfg"
SLASH_ARENALFG2 = "/arenalfg"
SlashCmdList["ARENALFG"] = function(msg)
    local rawMsg = strtrim(msg or "")
    msg = strlower(rawMsg)
    if msg == "" then
        ns.ToggleUI()
    elseif msg == "help" then
        ns.Print("ArenaLFG commands:")
        ns.Print("/alfg or /arenalfg - Toggle the ArenaLFG window.")
        ns.Print("/alfg help - Show this command list.")
        ns.Print("/alfg options - Open the ArenaLFG options.")
        ns.Print("/alfg version - Show the installed ArenaLFG version.")
        ns.Print("/alfg minimap - Show or hide the minimap button.")
        ns.Print("/alfg pvp - Toggle PvP window integration (enabled by default).")
        ns.Print("/alfg me - Show detected character and arena team information.")
        ns.Print("/alfg comm - Show sync channel status and retry joining if disconnected.")
        ns.Print("/alfg global [channel] - Show or set the chat channel to parse (default: Global).")
        ns.Print("/alfg announce on|off - Enable or disable Global group announcements.")
        ns.Print("/alfg announce prompt - Show the announcement consent prompt again.")
        ns.Print("/alfg sound - Toggle audio alerts on/off.")
        ns.Print("/alfg match - Toggle partner match alerts on/off.")
        ns.Print("/alfg sound test - Test play alert sounds.")
        ns.Print("/alfg debug - Toggle debug messages.")
        ns.Print("/alfg clear - Clear the local group list.")
        ns.Print("/alfg hide <name> | unhide <name> | hidden - Manage hidden players.")
    elseif msg == "version" or msg == "ver" or msg == "v" then
        ns.Print("Version " .. ns.VERSION)
    elseif msg == "options" or msg == "config" or msg == "opt" then
        ns.OpenOptions()
    elseif msg == "announce on" then
        ns.SetAnnounceEnabled(true)
    elseif msg == "announce off" then
        ns.SetAnnounceEnabled(false)
    elseif msg == "announce prompt" then
        if ShowAnnouncePrompt(true) == nil and not InCombatLockdown() then
            ns.Print("Could not open the announcement prompt.")
        end
    elseif msg == "announce" then
        ns.Print("Global group announcements are " .. (ns.DB.announce and "enabled" or "disabled")
            .. ". Use /alfg announce on or /alfg announce off to change it.")
    elseif msg == "hidden" then
        local names = {}
        for name in pairs(ns.SV.hidden or {}) do names[#names + 1] = name end
        table.sort(names)
        ns.Print(#names > 0 and ("Hidden players: " .. table.concat(names, ", ")) or "No hidden players.")
    elseif msg:match("^hide%s+") then
        ns.HidePlayer(strtrim(rawMsg:match("^%S+%s+(.+)$") or ""), true)
    elseif msg:match("^unhide%s+") then
        ns.HidePlayer(strtrim(rawMsg:match("^%S+%s+(.+)$") or ""), false)
    elseif msg == "clear" then
        wipe(ns.listings)
        ns.Changed()
    elseif msg == "sound" then
        ns.DB.soundAlerts = not ns.DB.soundAlerts
        if ns.frame and ns.frame.soundCheck then ns.frame.soundCheck:SetChecked(ns.DB.soundAlerts) end
        ns.RefreshOptions()
        ns.Print("Audio alerts " .. (ns.DB.soundAlerts and "enabled" or "disabled") .. ".")
    elseif msg == "match" then
        ns.DB.matchAlerts = not ns.DB.matchAlerts
        if ns.frame and ns.frame.matchCheck then ns.frame.matchCheck:SetChecked(ns.DB.matchAlerts) end
        ns.RefreshOptions()
        ns.Print("Partner match alerts " .. (ns.DB.matchAlerts and "enabled" or "disabled") .. ".")
    elseif msg == "sound test" then
        ns.PlayAlert("applicant")
        ns.Print("Playing test alert sound.")
        if RaidNotice_AddMessage and RaidWarningFrame then
            RaidNotice_AddMessage(RaidWarningFrame,
                "|cff33ff99[ArenaLFG]|r Test alert notification!",
                ChatTypeInfo["RAID_WARNING"])
        end
    elseif msg == "debug" then
        ns.DEBUG = not ns.DEBUG
        ns.SV.debug = ns.DEBUG
        ns.Print("Debug " .. (ns.DEBUG and "on" or "off"))
    elseif msg == "me" then
        ns.Print("class=" .. tostring(ns.GetMyClass()) .. " spec=" .. tostring(ns.GetMySpec())
            .. " gs=" .. tostring(ns.GetMyGearScore()))
        local tname, rating = ns.GetMyTeam(ns.mine.bracket)
        ns.Print(ns.mine.bracket .. " team=" .. tostring(tname) .. " rating=" .. tostring(rating))
        for i = 1, (MAX_ARENA_TEAMS or 3) do
            local n, size, r = GetArenaTeam(i)
            ns.Print("arena slot " .. i .. ": name=" .. tostring(n) .. " size=" .. tostring(size) .. " rating=" .. tostring(r))
        end
    elseif msg == "comm" then
        ns.Comm_Status()
    elseif msg == "global" then
        local channelName = ns.DB.globalChannel
        local globalChannelId = tonumber(GetChannelName(channelName)) or 0
        ns.Print("Global chat parser " .. (ns.GlobalParserLoaded and "loaded" or "NOT loaded")
            .. "; channel: " .. channelName .. " (id " .. globalChannelId .. ").")
    elseif msg:match("^global%s+") then
        local channelName = strtrim(rawMsg:match("^%S+%s+(.+)$") or "")
        if channelName == "" or #channelName > 32 or channelName:find("|", 1, true) then
            ns.Print("Channel name must be 1-32 characters and cannot contain '|'.")
            return
        end
        ns.DB.globalChannel = channelName
        ns.Print("Global chat parser channel set to " .. channelName .. ".")
    elseif msg == "minimap" then
        ns.DB.minimap.hide = not ns.DB.minimap.hide
        ns.UpdateMinimapButton()
        ns.Print("Minimap button " .. (ns.DB.minimap.hide and "hidden" or "shown"))
    elseif msg == "pvp" then
        ns.SetPVPIntegration(not ns.DB.pvpIntegration)
        ns.Print("PvP window integration " .. (ns.DB.pvpIntegration and "enabled" or "disabled") .. ".")
    else
        ns.Print("Unknown command. Type /alfg help to see available commands.")
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

-- A battleground / arena match that was found or is running (the game makes its own group)
function ns.PvpPending()
    for i = 1, (MAX_BATTLEFIELD_QUEUES or 3) do
        local status = GetBattlefieldStatus(i)
        if status == "confirm" or status == "active" then return true end
    end
    return false
end

-- A listing is removed when a group forms; a 3v3 listing may stay up in a party of two
-- (two players looking for the last member). Inside a battleground or arena (queued
-- or SoloQ) the group is made by the game, so the listing is kept.
function ns.GroupBlocksListing()
    if ns.InPvpInstance() or ns.PvpPending() then return false end
    if GetNumRaidMembers() > 0 then return true end
    local others = GetNumPartyMembers()
    if ns.mine and ns.mine.bracket == "3v3" then return others > 1 end
    return others > 0
end

local gf = CreateFrame("Frame")
gf:RegisterEvent("PARTY_MEMBERS_CHANGED")
gf:RegisterEvent("RAID_ROSTER_UPDATE")
gf:RegisterEvent("ZONE_CHANGED_NEW_AREA")
gf:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
local PVP_GRACE = 20 -- the game-made BG / arena group can outlive the instance for a moment
local function CheckGroup()
    if not ns.DB then return end
    if ns.InPvpInstance() or ns.PvpPending() then -- keep listings and sign-ups while in BG / arena (SoloQ)
        ns.lastPvpAt = GetTime()
        return
    end
    local grouped = ns.InGroup()
    if not grouped then return end
    if ns.lastPvpAt then
        local left = PVP_GRACE - (GetTime() - ns.lastPvpAt)
        if left > 0 then
            ns.After(left + 1, CheckGroup)
            return
        end
    end

    if ns.mine.posted and ns.GroupBlocksListing() then
        ns.Print("You are in a group now, your listing was removed (party " .. GetNumPartyMembers()
            .. ", raid " .. GetNumRaidMembers() .. ").")
        ns.RemoveMine()
    end

    -- and cancel any sign-ups I still have pending elsewhere
    for name, status in pairs(ns.applied) do
        if status == "pending" then
            local l = ns.listings[name]
            if l then ns.CancelApply(l) else ns.applied[name] = nil end
        end
    end
end
gf:SetScript("OnEvent", CheckGroup)

-- AFK: a listing is removed while the player is away (the game flags AFK after a few idle
-- minutes, or with /afk) and put back when they return.
local afkFrame = CreateFrame("Frame")
afkFrame:RegisterEvent("PLAYER_FLAGS_CHANGED")
afkFrame:SetScript("OnEvent", function(self, event, unit)
    if unit ~= "player" or not ns.DB then return end
    local m = ns.mine
    if UnitIsAFK("player") then
        if m.posted and not (ns.InPvpInstance() or ns.PvpPending()) then
            m.afkDelisted, m.afkBracket = true, m.bracket
            ns.Print("You are AFK, your listing was removed. It will be restored when you are back.")
            ns.RemoveMine()
        end
    elseif m.afkDelisted then
        local bracket = m.afkBracket
        m.afkDelisted, m.afkBracket = nil, nil
        if m.posted or ns.GroupBlocksListing() then return end
        ns.SetMineBracket(bracket)
        ns.PostMine()
        if m.posted then ns.Print("Welcome back, your listing was restored.") end
    end
end)

-- Quick reload while developing: /rl
SLASH_ARENALFGRL1 = "/rl"
SlashCmdList["ARENALFGRL"] = ReloadUI