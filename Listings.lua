local ADDON, ns = ...

----------------------------------------------------------------------
-- Wire format (sent as plain text in the hidden channel):
-- AL1;class;spec;role;gs;hasTeam;teamRating;tier;seasonal;tenGames;note;targetRole;targetSpecs;specId;race
-- ("|" is the chat escape character, so ";" is the separator)
----------------------------------------------------------------------
local SEP = ";"
local function clean(s) return (tostring(s or ""):gsub("[|;]", "/")) end
local function b(v) return v and "1" or "0" end

-- Link detection, shared by synced listings and the Global chat parser.
local URL_TLDS = {
    "com", "net", "org", "gg", "tv", "io", "ly", "gl", "xyz", "info", "shop",
    "store", "site", "link", "club", "online", "ru", "eu", "fr", "de", "cc", "app",
}

function ns.ContainsUrl(text)
    if type(text) ~= "string" or text == "" then return false end
    local s = string.lower(text)
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    s = s:gsub("|T.-|t", ""):gsub("|H.-|h(.-)|h", "%1")
    if s:find("https?:") or s:find("%f[%w]www%s*%.") then return true end
    if s:find("discord%s*%.%s*gg") or s:find("discord%s*%.%s*com")
        or s:find("discordapp") or s:find("discord%s*dot") then return true end
    if s:find("[%[%(%{]%s*dot%s*[%]%)%}]") then return true end -- "[dot]" / "(dot)"
    if s:find("%d+%.%d+%.%d+%.%d+") then return true end         -- IP address
    if s:find("[%w%-]%.%a%a+/%w") then return true end           -- anything.xx/path
    for _, tld in ipairs(URL_TLDS) do
        if s:find("[%w%-]%." .. tld .. "%f[%A]") then return true end
    end
    return false
end

local function NoUrl(text, fallback)
    if ns.ContainsUrl(text) then return fallback end
    return text
end

local function EncodeTargetSpecs(l)
    if l.targetAny then return "ANY" end
    local ids = {}
    for _, spec in ipairs(ns.PARTNER_SPECS) do
        if (l.targetRole == "Comp" or spec.role == l.targetRole) and l.targetSpecs and l.targetSpecs[spec.id] then
            ids[#ids + 1] = spec.id
        end
    end
    return table.concat(ids, ",")
end

function ns.Encode(l)
    return table.concat({
        "AL1", l.class, clean(l.spec), clean(l.role), l.gs or 0,
        b(l.hasTeam), l.teamRating or 0, l.tier or 1,
        b(l.seasonal), b(l.tenGames), clean(l.note),
        l.targetRole or "Any", EncodeTargetSpecs(l), clean(l.specId), clean(l.race),
        ns.NormalizeBracket(l.bracket), clean(l.haveSpec),
    }, SEP)
end

function ns.Decode(msg, sender)
    local parts = {}
    for field in (msg .. SEP):gmatch("(.-)" .. SEP) do parts[#parts + 1] = field end
    if parts[1] ~= "AL1" or #parts < 11 then return nil end
    if not RAID_CLASS_COLORS[parts[2]] then return nil end -- reject junk
    local role = "DPS"
    for _, r in ipairs(ns.ROLES) do if r == parts[4] then role = r end end
    local bracket = ns.NormalizeBracket(parts[16]) -- missing from older clients = 2v2
    local targetRole = "Any"
    for _, r in ipairs(ns.PARTNER_ROLES) do
        if r == parts[12] then targetRole = r end
    end
    if parts[12] == "Comp" and bracket == "3v3" then targetRole = "Comp" end
    local targetSpecs = {}
    local targetAny = targetRole ~= "Any" and targetRole ~= "Comp" and parts[13] == "ANY"
    for id in (parts[13] or ""):gmatch("[^,]+") do
        for _, spec in ipairs(ns.PARTNER_SPECS) do
            if spec.id == id and (spec.role == targetRole or targetRole == "Comp") then
                targetSpecs[id] = true
                break
            end
        end
    end
    return {
        name       = sender,
        class      = parts[2],
        spec       = NoUrl(strsub(parts[3], 1, 20), "Unknown"),
        role       = role,
        gs         = math.min(tonumber(parts[5]) or 0, 9999),
        hasTeam    = parts[6] == "1",
        teamRating = math.min(tonumber(parts[7]) or 0, 3500),
        tier       = math.max(1, math.min(tonumber(parts[8]) or 1, #ns.TIERS)),
        seasonal   = parts[9] == "1",
        tenGames   = parts[10] == "1",
        note       = NoUrl(strsub(parts[11], 1, 60), ""),
        targetRole = targetRole,
        targetAny = targetAny,
        targetSpecs = targetSpecs,
        specId = ns.IsValidSpecId(parts[2], parts[14]) and parts[14] or nil,
        race = ns.NormalizeRace(parts[15]),
        bracket = bracket,
        haveSpec = bracket == "3v3" and ns.IsValidHaveSpec(parts[17]) and parts[17] or nil,
    }
end

----------------------------------------------------------------------
-- Store
----------------------------------------------------------------------
function ns.Changed()
    if ns.RefreshAll then ns.RefreshAll() end
end

local recentAlerts = {}

function ns.CheckPartnerMatch(l)
    if not (ns.DB and ns.DB.matchAlerts) then return end
    if not l or l.name == UnitName("player") then return end
    if ns.InGroup and ns.InGroup() then return end
    if ns.InPvpInstance and ns.InPvpInstance() then return end

    local now = GetTime()
    if recentAlerts[l.name] and now - recentAlerts[l.name] < 600 then
        return
    end

    local mySpec = ns.GetMySpecId and ns.GetMySpecId()
    local myRole = ns.mine and ns.mine.role or (ns.GetSuggestedRole and ns.GetSuggestedRole()) or "DPS"
    local isMatch = false

    if l.targetSpecs and mySpec and l.targetSpecs[mySpec] then
        isMatch = true
    elseif l.targetAny and l.targetRole == myRole then
        isMatch = true
    end

    if isMatch then
        recentAlerts[l.name] = now
        local c = RAID_CLASS_COLORS[l.class] or { r = 1, g = 1, b = 1 }
        local namePart = string.format("|cff%02x%02x%02x%s|r",
            math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255), l.name)
        local sourceTag = (l.source == "global") and "|cff64b5f6[Chat Ad]|r" or "|cff69f0ae[ArenaLFG]|r"
        local who = l.spec and l.spec ~= "Unknown" and l.spec
            or (l.class ~= "UNKNOWN" and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[l.class])
        ns.Print(string.format("%s %s%s is looking for %s!",
            sourceTag, namePart, who and (" (" .. who .. ")") or "",
            ns.GetMySpec and ns.GetMySpec() or "your spec"))
        ns.PlayAlert("match")
        if RaidNotice_AddMessage and RaidWarningFrame then
            RaidNotice_AddMessage(RaidWarningFrame,
                string.format("|cff33ff99[ArenaLFG]|r %s%s wants %s!", l.name, who and (" (" .. who .. ")") or "",
                    ns.GetMySpec and ns.GetMySpec() or "your spec"),
                ChatTypeInfo["RAID_WARNING"])
        end
    end
end

function ns.AddListing(l)
    local previous = ns.listings[l.name]
    l.listedAt = previous and previous.source == l.source and previous.listedAt or GetTime()
    l.seen = GetTime()
    ns.listings[l.name] = l
    ns.CheckPartnerMatch(l)
    ns.Changed()
end

function ns.RemoveListing(name)
    ns.listings[name] = nil
    ns.applied[name] = nil
    ns.Changed()
end

-- Your own data as a listing table (also used when you sign up to someone else's group)
function ns.BuildMine()
    local m = ns.mine
    ns.DetectMine() -- team rating / GS may have changed
    return {
        name = UnitName("player"), class = ns.GetMyClass(), spec = ns.GetMySpec(),
        role = m.role, gs = m.gs,
        hasTeam = m.hasTeam, teamRating = m.hasTeam and m.teamRating or 0,
        tier = m.tier, seasonal = m.seasonal, tenGames = m.tenGames, note = m.note,
        targetRole = m.targetRole, targetAny = m.targetAny, targetSpecs = m.targetSpecs,
        specId = ns.GetMySpecId(),
        race = ns.GetMyRace(),
        bracket = m.bracket, haveSpec = m.haveSpec, comp = m.comp,
    }
end

-- Your own listing (nil if not posted)
function ns.MyListing()
    if not ns.mine.posted then return nil end
    return ns.BuildMine()
end

-- Expire stale listings and applicants
ns.Every(5, function()
    local now, removed = GetTime(), false
    for name, l in pairs(ns.listings) do
        if (now - l.seen) > (l.source == "global" and 120 or ns.EXPIRE) then
            ns.listings[name] = nil
            ns.applied[name] = nil
            removed = true
        end
    end
    for name, l in pairs(ns.applicants) do
        if l.received and (now - l.received) > ns.EXPIRE then
            ns.applicants[name] = nil
            removed = true
        end
    end
    if removed then ns.Changed() end
end)

----------------------------------------------------------------------
-- Filtering / sorting for the Browse tab
----------------------------------------------------------------------
function ns.GetSorted()
    local f, out = ns.DB.filters, {}
    for _, l in pairs(ns.listings) do
        local ok = (l.bracket or ns.DEFAULT_BRACKET) == (ns.viewBracket or ns.DEFAULT_BRACKET)
        if f.role ~= "Any" and l.role ~= f.role then ok = false end
        if f.team == "Has team" and l.teamKnown ~= false and not l.hasTeam then ok = false end
        if f.team == "No team" and l.teamKnown ~= false and l.hasTeam then ok = false end
        if f.seasonal == "Seasonal" and l.seasonal == false then ok = false end
        if f.seasonal == "Non-seasonal" and l.seasonal == true then ok = false end
        if f.tenGames and l.tenGames == false then ok = false end
        if ok and ns.search and ns.search ~= "" then
            local partnerSpecs = table.concat(ns.GetPartnerSpecNames(l), " ")
            local hay = strlower(l.name .. " " .. l.spec .. " " .. (l.note or "") .. " "
                .. l.class .. " " .. partnerSpecs)
            if not hay:find(ns.search, 1, true) then ok = false end
        end
        if ok then out[#out + 1] = l end
    end
    table.sort(out, function(a, c)
        local aIsGlobal = a.source == "global"
        local cIsGlobal = c.source == "global"
        if aIsGlobal ~= cIsGlobal then return not aIsGlobal end
        local aPostedAt = a.listedAt or a.seen or 0
        local cPostedAt = c.listedAt or c.seen or 0
        if aPostedAt ~= cPostedAt then return aPostedAt > cPostedAt end
        return a.name < c.name
    end)
    return out
end

----------------------------------------------------------------------
-- Titles, sign-ups and applicants (retail-style flow)
----------------------------------------------------------------------
ns.appSeq = 0

function ns.ListingTitle(l)
    local preference = ns.PartnerPreference(l)
    if l.note and l.note ~= "" then
        return preference and (l.note .. " - looking for " .. preference) or l.note
    end
    local comp = ns.MatchComp(l)
    if comp and preference then
        return (l.spec or "") .. (l.haveSpec and (" + " .. ns.SpecTokenLabel(l.haveSpec)) or "")
            .. " looking for " .. preference .. " (" .. comp.name .. ")"
    end
    local cls = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[l.class]) or l.class
    return l.spec .. " " .. cls .. " looking for " .. (preference or "a partner")
end

function ns.PartnerPreference(l)
    if l.targetRole and l.targetRole ~= "Any" and l.targetAny then
        return "any " .. strlower(l.targetRole)
    end
    local icons = ns.GetPartnerSpecIcons(l)
    if #icons == 0 then return nil end
    local display = {}
    for _, icon in ipairs(icons) do
        display[#display + 1] = "|TInterface\\Icons\\" .. icon .. ":14:14|t"
    end
    return table.concat(display, " ")
end

local function Whisper(name, text)
    pcall(SendAddonMessage, ns.PREFIX, text, "WHISPER", name)
end

-- I sign up to someone's group: they get my profile
function ns.Apply(l)
    if l.name == UnitName("player") then return end
    ns.applied[l.name] = "pending"
    Whisper(l.name, "AP;" .. ns.Encode(ns.BuildMine()))
    ns.Changed()
end

function ns.CancelApply(l)
    if ns.applied[l.name] == "pending" then Whisper(l.name, "CANCEL") end
    ns.applied[l.name] = nil
    ns.Changed()
end

-- Someone signed up to MY group
function ns.AddApplicant(l)
    ns.appSeq = ns.appSeq + 1
    l.order = ns.appSeq
    l.received = GetTime()
    ns.applicants[l.name] = l
    ns.Changed()
end

function ns.InviteApplicant(name)
    local l = ns.applicants[name]
    if l then
        InviteUnit(name)
        Whisper(name, "INV")
    end
    ns.applicants[name] = nil
    ns.Changed()
end

function ns.DeclineApplicant(name)
    local l = ns.applicants[name]
    if l then Whisper(name, "DEC") end
    ns.applicants[name] = nil
    ns.Changed()
end