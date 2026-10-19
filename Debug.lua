local ADDON, ns = ...

-- TEMPORARY test helpers, remove this file and its line in ArenaLFG.toc before release.
--   /alfg fake         add fake applicants (needs a posted listing) and fake listings
--   /alfg fake clear   remove them again

local APPLICANTS = {
    -- name, class, specId, spec, role, gs, rating, tier, race
    { "Fakewar", "WARRIOR", "W1", "Arms", "DPS", 6120, 2150, 6, "ORC" },
    { "Fakeheal", "PALADIN", "P1", "Holy", "Healer", 5890, 1710, 4, "HUMAN" },
    { "Fakerogue", "ROGUE", "R3", "Subtlety", "DPS", 5400, 0, 2, "BLOODELF" },
    { "Fakedruid", "DRUID", "U3", "Restoration", "Healer", 6010, 2010, 5, "NIGHTELF" },
    { "Fakelock", "WARLOCK", "L3", "Destruction", "DPS", 5750, 1560, 3, "UNDEAD" },
    { "Fakedk", "DEATHKNIGHT", "D3", "Unholy", "DPS", 0, 2380, 7, "TROLL" },
}

local LISTINGS = {
    -- name, class, specId, spec, role, gs, rating, tier, race, relation
    { "Fakefriend", "MAGE", "M3", "Frost", "DPS", 5900, 1850, 5, "GNOME", "friend" },
    { "Fakeguild", "PRIEST", "C1", "Discipline", "Healer", 5700, 1620, 4, "DRAENEI", "guild" },
    { "Fakedeclined", "HUNTER", "H2", "Marksmanship", "DPS", 6100, 2200, 6, "TAUREN", "declined" },
    { "Fakestranger", "SHAMAN", "S3", "Restoration", "Healer", 5500, 0, 2, "DWARF", nil },
}

local function Make(row, bracket)
    local name, class, specId, spec, role, gs, rating, tier, race = unpack(row)
    return {
        name = name, class = class, specId = specId, spec = spec, role = role, gs = gs,
        hasTeam = rating > 0, teamRating = rating, tier = tier, race = race,
        seasonal = false, tenGames = false, note = "", bracket = bracket,
        targetRole = "Any", targetAny = false, targetSpecs = {}, fake = true,
    }
end

local function Clear()
    for name, l in pairs(ns.listings) do
        if l.fake then ns.listings[name] = nil; ns.applied[name] = nil end
    end
    for name, l in pairs(ns.applicants) do
        if l.fake then ns.applicants[name] = nil end
    end
    ns.fakeSocial = nil
    ns.Changed()
end

function ns.FakeData(msg)
    if msg == "fake clear" then
        Clear()
        ns.Print("Fake test data removed.")
        return
    end
    Clear()
    ns.fakeSocial = { friends = {}, guildies = {} }
    for _, bracket in ipairs(ns.BRACKETS) do
        for i, row in ipairs(LISTINGS) do
            local l = Make(row, bracket)
            l.name = row[1] .. (bracket == "2v2" and "" or (bracket == "3v3" and "3" or "D"))
            local relation = row[10]
            if relation == "friend" then ns.fakeSocial.friends[l.name] = true end
            if relation == "guild" then ns.fakeSocial.guildies[l.name] = true end
            if relation == "declined" then ns.applied[l.name] = "declined" end
            l.targetRole = (i % 2 == 0) and "Healer" or "Any"
            ns.AddListing(l)
        end
    end
    for name in pairs(ns.fakeSocial.friends) do ns.friends[name] = true end
    for name in pairs(ns.fakeSocial.guildies) do ns.guildies[name] = true end
    if ns.mine.posted then
        for _, row in ipairs(APPLICANTS) do ns.AddApplicant(Make(row, ns.mine.bracket)) end
    else
        ns.Print("List your group to see the fake applicants.")
    end
    ns.Print("Fake test data added (/alfg fake clear removes it).")
    ns.Changed()
end
