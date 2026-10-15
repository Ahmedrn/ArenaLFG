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

function ns.GetPartnerSpecNames(listing)
    local selected, names = listing and listing.targetSpecs, {}
    if type(selected) ~= "table" then return names end
    for _, spec in ipairs(ns.PARTNER_SPECS) do
        if spec.role == listing.targetRole and selected[spec.id] then
            names[#names + 1] = spec.label
        end
    end
    return names
end

function ns.GetPartnerSpecIcons(listing)
    local selected, icons = listing and listing.targetSpecs, {}
    if type(selected) ~= "table" then return icons end
    for _, spec in ipairs(ns.PARTNER_SPECS) do
        if spec.role == listing.targetRole and selected[spec.id] then
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

-- Returns teamName, rating for the player's 2v2 team (nil if none)
function ns.GetMy2v2Team()
    for i = 1, (MAX_ARENA_TEAMS or 3) do
        local name, size, rating = GetArenaTeam(i)
        if name and size == 2 then
            return name, rating
        end
    end
    return nil
end

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

    local oldRole = ns.mine.role
    ns.DetectMine()
    if editing then ns.UI_LoadMine() end

    if ns.mine.posted and oldRole ~= ns.mine.role then
        ns.AddListing(ns.MyListing())
        ns.Broadcast()
    end
end)

-- Pull what the game can tell us. The 2v2 team is authoritative: no team = no team.
function ns.DetectMine()
    local m, info = ns.mine, {}
    m.role = ns.GetSuggestedRole() or "DPS"
    local gs = ns.GetMyGearScore()
    if gs then m.gs = gs; info.gs = true end
    local tname, rating = ns.GetMy2v2Team()
    m.hasTeam = tname and true or false
    m.teamRating = tname and (rating or 0) or 0
    info.team = tname
    return info
end
