local ADDON, ns = ...

ns.PARTNER_ROLES = { "Any", "DPS", "Healer", "Tank" }
ns.RACES = {
    HUMAN = { label = "Human", icon = "Achievement_Character_Human_Male" },
    ORC = { label = "Orc", icon = "Achievement_Character_Orc_Male" },
    DWARF = { label = "Dwarf", icon = "Achievement_Character_Dwarf_Male" },
    NIGHTELF = { label = "Night Elf", icon = "Achievement_Character_NightElf_Male" },
    UNDEAD = { label = "Undead", icon = "Achievement_Character_Undead_Male" },
    TAUREN = { label = "Tauren", icon = "Achievement_Character_Tauren_Male" },
    GNOME = { label = "Gnome", icon = "Achievement_Character_Gnome_Male" },
    TROLL = { label = "Troll", icon = "Achievement_Character_Troll_Male" },
    BLOODELF = { label = "Blood Elf", icon = "Achievement_Character_BloodElf_Male" },
    DRAENEI = { label = "Draenei", icon = "Achievement_Character_Draenei_Male" },
}

function ns.NormalizeRace(race)
    if type(race) ~= "string" then return nil end
    local token = strupper(race:gsub("[^%a]", ""))
    if token == "SCOURGE" then token = "UNDEAD" end
    return ns.RACES[token] and token or nil
end

function ns.GetMyRace()
    local _, race = UnitRace("player")
    return ns.NormalizeRace(race)
end

function ns.GetRaceIcon(race)
    local token = ns.NormalizeRace(race)
    local info = token and ns.RACES[token]
    return info and info.icon
end

function ns.GetRaceName(race)
    local token = ns.NormalizeRace(race)
    local info = token and ns.RACES[token]
    return info and info.label
end

function ns.GetFaction(race)
    local token = ns.NormalizeRace(race)
    if token == "HUMAN" or token == "DWARF" or token == "NIGHTELF"
        or token == "GNOME" or token == "DRAENEI" then
        return "Alliance"
    end
    if token == "ORC" or token == "UNDEAD" or token == "TAUREN"
        or token == "TROLL" or token == "BLOODELF" then
        return "Horde"
    end
end

ns.PARTNER_SPECS = {
    { id = "W1", role = "DPS", label = "Arms Warrior", icon = "Ability_Warrior_SavageBlow" },
    { id = "W2", role = "DPS", label = "Fury Warrior", icon = "Ability_Warrior_InnerRage" },
    { id = "W3", role = "Tank", label = "Protection Warrior", icon = "Ability_Warrior_DefensiveStance" },
    { id = "P1", role = "Healer", label = "Holy Paladin", icon = "Spell_Holy_HolyBolt" },
    { id = "P2", role = "Tank", label = "Protection Paladin", icon = "Spell_Holy_DevotionAura" },
    { id = "P3", role = "DPS", label = "Retribution Paladin", icon = "Spell_Holy_AuraOfLight" },
    { id = "H1", role = "DPS", label = "Beast Mastery Hunter", icon = "Ability_Hunter_BeastTaming" },
    { id = "H2", role = "DPS", label = "Marksmanship Hunter", icon = "Ability_Marksmanship" },
    { id = "H3", role = "DPS", label = "Survival Hunter", icon = "Ability_Hunter_SwiftStrike" },
    { id = "R1", role = "DPS", label = "Assassination Rogue", icon = "Ability_Rogue_DeadlyBrew" },
    { id = "R2", role = "DPS", label = "Combat Rogue", icon = "Ability_BackStab" },
    { id = "R3", role = "DPS", label = "Subtlety Rogue", icon = "Ability_Stealth" },
    { id = "C1", role = "Healer", label = "Discipline Priest", icon = "Spell_Holy_PowerWordShield" },
    { id = "C2", role = "Healer", label = "Holy Priest", icon = "Spell_Holy_GuardianSpirit" },
    { id = "C3", role = "DPS", label = "Shadow Priest", icon = "Spell_Shadow_ShadowWordPain" },
    { id = "D1", role = "Tank", label = "Blood Death Knight", icon = "Spell_Deathknight_BloodPresence" },
    { id = "D2", role = "DPS", label = "Frost Death Knight", icon = "Spell_Deathknight_FrostPresence" },
    { id = "D3", role = "DPS", label = "Unholy Death Knight", icon = "Spell_Deathknight_UnholyPresence" },
    { id = "S1", role = "DPS", label = "Elemental Shaman", icon = "Spell_Nature_Lightning" },
    { id = "S2", role = "DPS", label = "Enhancement Shaman", icon = "Spell_Shaman_ImprovedStormstrike" },
    { id = "S3", role = "Healer", label = "Restoration Shaman", icon = "Spell_Nature_MagicImmunity" },
    { id = "M1", role = "DPS", label = "Arcane Mage", icon = "Spell_Arcane_Blast" },
    { id = "M2", role = "DPS", label = "Fire Mage", icon = "Spell_Fire_FireBolt02" },
    { id = "M3", role = "DPS", label = "Frost Mage", icon = "Spell_Frost_FrostBolt02" },
    { id = "L1", role = "DPS", label = "Affliction Warlock", icon = "Spell_Shadow_DeathCoil" },
    { id = "L2", role = "DPS", label = "Demonology Warlock", icon = "Spell_Shadow_Metamorphosis" },
    { id = "L3", role = "DPS", label = "Destruction Warlock", icon = "Spell_Shadow_RainOfFire" },
    { id = "U1", role = "DPS", label = "Balance Druid", icon = "Spell_Nature_StarFall" },
    { id = "U2", role = "DPS", label = "Feral Druid", icon = "Ability_Druid_CatForm" },
    { id = "U3", role = "Healer", label = "Restoration Druid", icon = "Spell_Nature_HealingTouch" },
}

-- A 3v3 listing seeking a comp has targetRole "Comp": its specs may be of any role
function ns.GetPartnerSpecNames(listing)
    local selected, names = listing and listing.targetSpecs, {}
    if type(selected) ~= "table" then return names end
    for _, spec in ipairs(ns.PARTNER_SPECS) do
        if (listing.targetRole == "Comp" or spec.role == listing.targetRole) and selected[spec.id] then
            names[#names + 1] = spec.label
        end
    end
    return names
end

function ns.GetPartnerSpecIcons(listing)
    local selected, icons = listing and listing.targetSpecs, {}
    if type(selected) ~= "table" then return icons end
    for _, spec in ipairs(ns.PARTNER_SPECS) do
        if (listing.targetRole == "Comp" or spec.role == listing.targetRole) and selected[spec.id] then
            icons[#icons + 1] = spec.icon
        end
    end
    return icons
end

local SPEC_PREFIX_BY_CLASS = {
    WARRIOR = "W",
    PALADIN = "P",
    HUNTER = "H",
    ROGUE = "R",
    PRIEST = "C",
    DEATHKNIGHT = "D",
    SHAMAN = "S",
    MAGE = "M",
    WARLOCK = "L",
    DRUID = "U",
}

function ns.GetMyClass()
    return select(2, UnitClass("player")) -- token, e.g. "HUNTER"
end

function ns.IsValidSpecId(class, specId)
    local prefix = SPEC_PREFIX_BY_CLASS[class]
    if not prefix or type(specId) ~= "string" or strsub(specId, 1, 1) ~= prefix then return nil end
    for _, spec in ipairs(ns.PARTNER_SPECS) do
        if spec.id == specId then return true end
    end
    return false
end

function ns.GetSpecIcon(class, specId)
    if not ns.IsValidSpecId(class, specId) then return nil end
    for _, spec in ipairs(ns.PARTNER_SPECS) do
        if spec.id == specId then return spec.icon end
    end
    return nil
end

----------------------------------------------------------------------
-- 3v3 comps. A slot is a spec id ("W1") or "X*" for any spec of that class.
----------------------------------------------------------------------
local COMP_DATA = {
    { "Thunder Cleave", "W1", "S1", "P1" }, { "TSG", "W1", "D3", "P1" },
    { "LSP", "L*", "S1", "P1" }, { "PHP", "P3", "H2", "C1" },
    { "Shatterplay", "M3", "C3", "P1" }, { "RMP", "R3", "M3", "C1" },
    { "PHD", "D3", "H2", "P1" }, { "Jungle Cleave", "U2", "H2", "C1" },
    { "MLS", "M3", "L3", "S3" }, { "Shadowplay", "L1", "C3", "S3" },
    { "Vanguards Cleave", "D3", "P3", "C1" }, { "RPD", "R3", "C3", "U3" },
    { "Turbo Cleave", "W1", "S2", "P1" }, { "Thug Cleave", "R3", "H2", "C1" },
    { "Scooby Doo", "R3", "P3", "C1" }, { "Shadowcleave", "D3", "L1", "P1" },
    { "Beast Cleave", "H1", "S2", "P1" }, { "God Cleave", "S1", "U1", "P1" },
    { "LSD", "L3", "S1", "U3" }, { "African Turtle Cleave", "W3", "H2", "P1" },
    { "Kittycleave", "W1", "U2", "P1" }, { "RLS", "R3", "L1", "S3" },
    { "RLP", "R3", "L3", "P1" }, { "WLD", "L1", "W1", "U3" },
    { "MLP", "M3", "L3", "P1" }, { "FMP", "U2", "M3", "C1" },
}
ns.COMPS = {}
for _, c in ipairs(COMP_DATA) do
    ns.COMPS[#ns.COMPS + 1] = { name = c[1], slots = { c[2], c[3], c[4] } }
end

local function IsWildcard(token) return strsub(token, 2, 2) == "*" end
local function SlotHas(slot, id)
    return slot == id or (IsWildcard(slot) and strsub(slot, 1, 1) == strsub(id, 1, 1) and not IsWildcard(id))
end

function ns.FindComp(name)
    for _, c in ipairs(ns.COMPS) do
        if c.name == name then return c end
    end
end

function ns.CompsForSpec(specId)
    local out = {}
    if not specId then return out end
    for _, c in ipairs(ns.COMPS) do
        for _, slot in ipairs(c.slots) do
            if SlotHas(slot, specId) then out[#out + 1] = c; break end
        end
    end
    return out
end

-- Slots of the comp still to fill once my spec (and my partner's, if I have one) are placed
function ns.CompRemainingSlots(comp, mySpec, haveSpec)
    local taken = {}
    local function take(id)
        if not id then return end
        for i, slot in ipairs(comp.slots) do
            if not taken[i] and SlotHas(slot, id) then taken[i] = true; return end
        end
    end
    take(mySpec); take(haveSpec)
    local out = {}
    for i, slot in ipairs(comp.slots) do
        if not taken[i] then out[#out + 1] = slot end
    end
    return out
end

-- "Warlock" for a class wildcard, otherwise the spec name
function ns.SpecTokenLabel(token)
    if IsWildcard(token) then
        for class, prefix in pairs(SPEC_PREFIX_BY_CLASS) do
            if prefix == strsub(token, 1, 1) then
                return LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] or class
            end
        end
        return token
    end
    for _, spec in ipairs(ns.PARTNER_SPECS) do
        if spec.id == token then return spec.label end
    end
    return token
end

function ns.IsValidHaveSpec(token)
    if type(token) ~= "string" then return false end
    for _, spec in ipairs(ns.PARTNER_SPECS) do
        if spec.id == token then return true end
    end
    if IsWildcard(token) then
        for _, prefix in pairs(SPEC_PREFIX_BY_CLASS) do
            if prefix == strsub(token, 1, 1) then return true end
        end
    end
    return false
end

local function AddSlotSpecs(set, slot)
    for _, spec in ipairs(ns.PARTNER_SPECS) do
        if SlotHas(slot, spec.id) then set[spec.id] = true end
    end
end

-- Fill m.targetSpecs from the chosen comp (m.comp) and group (m.haveSpec)
function ns.ApplyComp(m)
    local comp = ns.FindComp(m.comp)
    local mySpec = ns.GetMySpecId()
    if comp then
        local fits = false
        for _, slot in ipairs(comp.slots) do
            if mySpec and SlotHas(slot, mySpec) then fits = true end
        end
        if not fits then comp = nil end
    end
    if not comp then
        m.comp, m.haveSpec = nil, nil
        if m.targetRole == "Comp" then m.targetRole = "Any"; wipe(m.targetSpecs) end
        return
    end
    local valid = false
    for _, slot in ipairs(ns.CompRemainingSlots(comp, mySpec, nil)) do
        if slot == m.haveSpec then valid = true end
    end
    if not valid then m.haveSpec = nil end
    m.targetRole, m.targetAny = "Comp", false
    wipe(m.targetSpecs)
    for _, slot in ipairs(ns.CompRemainingSlots(comp, mySpec, m.haveSpec)) do
        AddSlotSpecs(m.targetSpecs, slot)
    end
end

-- Which comp a received 3v3 listing is after (for display); nil if none fits
function ns.MatchComp(l)
    if l.bracket ~= "3v3" or l.targetRole ~= "Comp" or not l.specId then return nil end
    for _, c in ipairs(ns.COMPS) do
        local fits = false
        for _, slot in ipairs(c.slots) do
            if SlotHas(slot, l.specId) then fits = true end
        end
        if fits then
            local needs = {}
            for _, slot in ipairs(ns.CompRemainingSlots(c, l.specId, l.haveSpec)) do
                AddSlotSpecs(needs, slot)
            end
            local same = true
            for id in pairs(needs) do
                if not (l.targetSpecs and l.targetSpecs[id]) then same = false end
            end
            for id in pairs(l.targetSpecs or {}) do
                if not needs[id] then same = false end
            end
            if same then return c end
        end
    end
end

local ROLE_BY_TALENT_TAB = {
    WARRIOR = { "DPS", "DPS", "Tank" },
    PALADIN = { "Healer", "Tank", "DPS" },
    HUNTER = { "DPS", "DPS", "DPS" },
    ROGUE = { "DPS", "DPS", "DPS" },
    PRIEST = { "Healer", "Healer", "DPS" },
    DEATHKNIGHT = { "Tank", "DPS", "DPS" },
    SHAMAN = { "DPS", "DPS", "Healer" },
    MAGE = { "DPS", "DPS", "DPS" },
    WARLOCK = { "DPS", "DPS", "DPS" },
    DRUID = { "DPS", "DPS", "Healer" },
}

local function GetPrimaryTalentTab()
    local best, bestPoints = nil, 0
    for i = 1, GetNumTalentTabs() do
        local _, _, points = GetTalentTabInfo(i)
        if points and points > bestPoints then
            best, bestPoints = i, points
        end
    end
    return best
end

function ns.GetMySpecId()
    local prefix = SPEC_PREFIX_BY_CLASS[ns.GetMyClass()]
    local tab = GetPrimaryTalentTab()
    if not prefix or not tab then return nil end
    return prefix .. tab
end

function ns.GetMySpecIcon()
    return ns.GetSpecIcon(ns.GetMyClass(), ns.GetMySpecId())
end

-- Spec = talent tree with the most points
function ns.GetMySpec()
    local tab = GetPrimaryTalentTab()
    if tab then
        local name = GetTalentTabInfo(tab)
        return name or "None"
    end
    return "None"
end

function ns.GetSuggestedRole()
    local class = ns.GetMyClass()
    local tab = GetPrimaryTalentTab()
    local classRoles = ROLE_BY_TALENT_TAB[class]
    return classRoles and tab and classRoles[tab] or nil
end

-- GearScore_GetScore(name, unit) returns the score first and item level second.
-- Verified against the installed GearScoreLite 1.84 API.
function ns.GetMyGearScore()
    if type(GearScore_GetScore) == "function" then
        local ok, gs = pcall(GearScore_GetScore, UnitName("player"), "player")
        if ok and tonumber(gs) and tonumber(gs) > 0 then
            return math.floor(tonumber(gs))
        end
    end
    return nil
end

-- Returns teamName, rating for the player's arena team of the bracket's size (nil if none)
function ns.GetMyTeam(bracket)
    local wanted = ns.BRACKET_TEAM_SIZE[ns.NormalizeBracket(bracket)]
    for i = 1, (MAX_ARENA_TEAMS or 3) do
        local name, size, rating = GetArenaTeam(i)
        if name and size == wanted then
            return name, rating
        end
    end
    return nil
end

function ns.GetMy2v2Team() return ns.GetMyTeam("2v2") end

-- Ask the server for arena team data (it is not always loaded at login)
function ns.RequestArenaData()
    for i = 1, (MAX_ARENA_TEAMS or 3) do
        pcall(ArenaTeamRoster, i)
    end
end

-- Refresh the form when arena team data arrives
local f = CreateFrame("Frame")
f:RegisterEvent("ARENA_TEAM_UPDATE")
f:RegisterEvent("ARENA_TEAM_ROSTER_UPDATE")
f:RegisterEvent("PLAYER_TALENT_UPDATE")
f:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
f:SetScript("OnEvent", function()
    if not ns.DB then return end
    local editing = ns.frame and ns.frame.mine and ns.frame.mine:IsShown()
    if editing then ns.SaveMine() end

    local oldRole, oldTeam, oldRating = ns.mine.role, ns.mine.hasTeam, ns.mine.teamRating
    ns.DetectMine()
    if editing then ns.UI_LoadMine() end

    -- a new role or a new team / rating (joining a team, a game played) must reach the others without a relist
    if ns.mine.posted and (oldRole ~= ns.mine.role or oldTeam ~= ns.mine.hasTeam or oldRating ~= ns.mine.teamRating) then
        ns.AddListing(ns.MyListing())
        ns.Broadcast()
    end
end)

-- The game does not send new team ratings by itself after a match: ask again when leaving an arena (the rating
-- is final a moment later), and every minute while listed.
local wasInArena = false
local zone = CreateFrame("Frame")
zone:RegisterEvent("PLAYER_ENTERING_WORLD")
zone:RegisterEvent("ZONE_CHANGED_NEW_AREA")
zone:SetScript("OnEvent", function()
    local _, kind = IsInInstance()
    local inArena = kind == "arena"
    if wasInArena and not inArena then
        ns.After(3, ns.RequestArenaData)
        ns.After(15, ns.RequestArenaData)
    end
    wasInArena = inArena
end)
ns.Every(60, function()
    if ns.DB and ns.mine and ns.mine.posted then ns.RequestArenaData() end
end)

-- Pull what the game can tell us. The team of the selected bracket is authoritative: no team = no team.
function ns.DetectMine()
    local m, info = ns.mine, {}
    m.role = ns.GetSuggestedRole() or "DPS"
    local gs = ns.GetMyGearScore()
    if gs then m.gs = gs; info.gs = true end
    local tname, rating = ns.GetMyTeam(m.bracket)
    m.hasTeam = tname and true or false
    m.teamRating = tname and (rating or 0) or 0
    info.team = tname
    return info
end
