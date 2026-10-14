local ADDON, ns = ...

----------------------------------------------------------------------
-- Wire format (sent as plain text in the hidden channel):
-- AL1;class;spec;role;gs;hasTeam;teamRating;tier;seasonal;tenGames;note
-- ("|" is the chat escape character, so ";" is the separator)
----------------------------------------------------------------------
local SEP = ";"
local function clean(s) return (tostring(s or ""):gsub("[|;]", "/")) end
local function b(v) return v and "1" or "0" end

function ns.Encode(l)
    return table.concat({
        "AL1", l.class, clean(l.spec), clean(l.role), l.gs or 0,
        b(l.hasTeam), l.teamRating or 0, l.tier or 1,
        b(l.seasonal), b(l.tenGames), clean(l.note),
    }, SEP)
end

function ns.Decode(msg, sender)
    local parts = {}
    for field in (msg .. SEP):gmatch("(.-)" .. SEP) do parts[#parts + 1] = field end
    if parts[1] ~= "AL1" or #parts < 11 then return nil end
    if not RAID_CLASS_COLORS[parts[2]] then return nil end -- reject junk
    local role = "DPS"
    for _, r in ipairs(ns.ROLES) do if r == parts[4] then role = r end end
    return {
        name       = sender,
        class      = parts[2],
        spec       = strsub(parts[3], 1, 20),
        role       = role,
        gs         = math.min(tonumber(parts[5]) or 0, 9999),
        hasTeam    = parts[6] == "1",
        teamRating = math.min(tonumber(parts[7]) or 0, 3500),
        tier       = math.max(1, math.min(tonumber(parts[8]) or 1, #ns.TIERS)),
        seasonal   = parts[9] == "1",
        tenGames   = parts[10] == "1",
        note       = strsub(parts[11], 1, 60),
    }
end

----------------------------------------------------------------------
-- Store
----------------------------------------------------------------------
function ns.Changed()
    if ns.RefreshAll then ns.RefreshAll() end
end

function ns.AddListing(l)
    l.seen = GetTime()
    ns.listings[l.name] = l
    ns.Changed()
end

function ns.RemoveListing(name)
    ns.listings[name] = nil
    ns.Changed()
end

-- Your own data as a listing table (also used when you sign up to someone else's group)
function ns.BuildMine()
    local m = ns.DB.mine
    ns.DetectMine() -- team rating / GS may have changed
    return {
        name = UnitName("player"), class = ns.GetMyClass(), spec = ns.GetMySpec(),
        role = m.role, gs = m.gs,
        hasTeam = m.hasTeam, teamRating = m.hasTeam and m.teamRating or 0,
        tier = m.tier, seasonal = m.seasonal, tenGames = m.tenGames, note = m.note,
    }
end

-- Your own listing (nil if not posted)
function ns.MyListing()
    if not ns.DB.mine.posted then return nil end
    return ns.BuildMine()
end

-- Expire stale listings (fake ones stay)
ns.Every(5, function()
    local now, removed = GetTime(), false
    for name, l in pairs(ns.listings) do
        if not l.fake and (now - l.seen) > ns.EXPIRE then
            ns.listings[name] = nil
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
        local ok = true
        if f.role ~= "Any" and l.role ~= f.role then ok = false end
        if f.team == "Has team" and not l.hasTeam then ok = false end
        if f.team == "No team" and l.hasTeam then ok = false end
        if f.seasonal == "Seasonal" and not l.seasonal then ok = false end
        if f.seasonal == "Non-seasonal" and l.seasonal then ok = false end
        if f.tenGames and not l.tenGames then ok = false end
        if ok and ns.search and ns.search ~= "" then
            local hay = strlower(l.name .. " " .. l.spec .. " " .. (l.note or "") .. " " .. l.class)
            if not hay:find(ns.search, 1, true) then ok = false end
        end
        if ok then out[#out + 1] = l end
    end
    table.sort(out, function(a, c)
        if a.teamRating ~= c.teamRating then return a.teamRating > c.teamRating end
        return a.name < c.name
    end)
    return out
end

----------------------------------------------------------------------
-- Titles, sign-ups and applicants (retail-style flow)
----------------------------------------------------------------------
ns.appSeq = 0

function ns.ListingTitle(l)
    if l.note and l.note ~= "" then return l.note end
    local cls = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[l.class]) or l.class
    return "2v2 " .. l.spec .. " " .. cls .. " looking for a partner"
end

local function Whisper(name, text)
    pcall(SendAddonMessage, ns.PREFIX, text, "WHISPER", name)
end

-- I sign up to someone's group: they get my profile
function ns.Apply(l)
    if l.name == UnitName("player") then return end
    ns.applied[l.name] = "pending"
    if l.fake then
        ns.Print("Test group: sign-up simulated locally, nothing was sent.")
    else
        Whisper(l.name, "AP;" .. ns.Encode(ns.BuildMine()))
    end
    ns.Changed()
end

function ns.CancelApply(l)
    if ns.applied[l.name] == "pending" and not l.fake then Whisper(l.name, "CANCEL") end
    ns.applied[l.name] = nil
    ns.Changed()
end

-- Someone signed up to MY group
function ns.AddApplicant(l)
    ns.appSeq = ns.appSeq + 1
    l.order = ns.appSeq
    ns.applicants[l.name] = l
    ns.Changed()
end

function ns.InviteApplicant(name)
    local l = ns.applicants[name]
    if l and not l.fake then
        InviteUnit(name)
        Whisper(name, "INV")
    end
    ns.applicants[name] = nil
    ns.Changed()
end

function ns.DeclineApplicant(name)
    local l = ns.applicants[name]
    if l and not l.fake then Whisper(name, "DEC") end
    ns.applicants[name] = nil
    ns.Changed()
end