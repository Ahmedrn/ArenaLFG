local ADDON, ns = ...

local CLASS_ALIASES = {
    WARRIOR = { "warrior", "warr" },
    PALADIN = { "paladin", "pala", "pally" },
    HUNTER = { "hunter", "hunt" },
    ROGUE = { "rogue" },
    PRIEST = { "priest" },
    DEATHKNIGHT = { "death knight", "deathknight", "dk" },
    SHAMAN = { "shaman", "sham" },
    MAGE = { "mage" },
    WARLOCK = { "warlock", "lock" },
    DRUID = { "druid", "dudu", "drood" },
}

local CLASS_ORDER = {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
    "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID",
}

local SINGLE_ROLE = {
    HUNTER = "DPS",
    ROGUE = "DPS",
    MAGE = "DPS",
    WARLOCK = "DPS",
}

local CLASS_BY_SPEC_PREFIX = {
    W = "WARRIOR", P = "PALADIN", H = "HUNTER", R = "ROGUE",
    C = "PRIEST", D = "DEATHKNIGHT", S = "SHAMAN", M = "MAGE",
    L = "WARLOCK", U = "DRUID",
}

local SPEC_ALIASES = {
    W1 = { "arms warrior", "arms warr", "arms war", "arms", "awar", "awarr",
        "warrior arms", "warr arms", "war arms" },
    W2 = { "fury warrior", "fury warr", "fury war", "fury", "fwar", "fwarr",
        "warrior fury", "warr fury", "war fury" },
    W3 = { "protection warrior", "protection warr", "prot warrior", "prot warr", "prot war",
        "pwar", "pwarr", "protwar", "warrior prot", "warr prot", "war prot" },

    P1 = { "holy paladin", "holy pala", "holy pal", "holy pally", "hpala", "hpal", "hpally",
        "h pala", "h pal", "holypala", "paladin holy", "pala holy" },
    P2 = { "protection paladin", "prot paladin", "prot pala", "prot pal", "prot pally",
        "ppala", "ppal", "ppally", "protpala", "preg", "paladin prot", "pala prot" },
    P3 = { "retribution paladin", "retribution", "ret paladin", "ret pala", "ret pal", "ret pally",
        "retri paladin", "retri pala", "retri", "ret", "rpala", "rpal", "rpally",
        "paladin ret", "pala ret" },

    H1 = { "beast mastery", "beastmastery", "beast master", "beastmaster",
        "bm hunter", "bm hunt", "bmh", "bm", "hunter bm", "hunt bm" },
    H2 = { "marksmanship", "marksman", "marks hunter", "marks hunt",
        "mm hunter", "mm hunt", "mmh", "mm", "hunter mm", "hunt mm" },
    H3 = { "survival hunter", "survival hunt", "surv hunter", "surv hunt",
        "sv hunter", "sv hunt", "survival", "surv", "hunter surv", "hunt surv" },

    R1 = { "assassination rogue", "assassination", "assassin rogue", "assa rogue", "assas rogue",
        "ass rogue", "assa rog", "assas", "assa", "mutilate rogue", "mutilate", "mut rogue",
        "muti rogue", "muti", "rogue assa", "rog assa" },
    R2 = { "combat rogue", "combat rog", "cbt rogue", "swords rogue", "combat", "rogue combat" },
    R3 = { "subtlety rogue", "subtlety", "subtle rogue", "sub rogue", "sub rog", "sub",
        "hemo rogue", "hemo", "rogue sub", "rog sub" },

    C1 = { "discipline priest", "discipline", "disc priest", "disc pri", "dpriest", "dpri", "dp",
        "d priest", "disc", "priest disc", "pri disc" },
    C2 = { "holy priest", "holy pri", "hpriest", "hpri", "h priest", "holypriest",
        "priest holy", "pri holy" },
    C3 = { "shadow priest", "shadow pri", "spriest", "spr", "sp", "spri", "s priest", "shadowpriest",
        "shadow", "priest shadow", "pri shadow" },

    D1 = { "blood death knight", "blood deathknight", "blood dk", "bdk", "b dk",
        "dk blood", "deathknight blood" },
    D2 = { "frost death knight", "frost deathknight", "frost dk", "fdk", "f dk",
        "dk frost", "deathknight frost" },
    D3 = { "unholy death knight", "unholy deathknight", "unholy dk", "uh dk", "unh dk",
        "udk", "uhdk", "dk unholy", "dk uh", "deathknight unholy", "unholy" },

    S1 = { "elemental shaman", "elemental shammy", "elem shaman", "elem sham", "elem shammy",
        "ele shaman", "ele sham", "ele shammy", "eshaman", "esham", "eshammy", "e sham",
        "elemental", "elem", "ele", "shaman ele", "sham ele" },
    S2 = { "enhancement shaman", "enhancement shammy", "enhance shaman", "enhance sham",
        "enhance shammy", "enh shaman", "enh sham", "enh shammy", "ensham", "enhsham",
        "enhancement", "enhance", "enha", "enh", "shaman enh", "sham enh" },
    S3 = { "restoration shaman", "restoration shammy", "resto shaman", "resto sham", "resto shammy",
        "rshaman", "rsham", "rshamy", "rshammy", "r shaman", "r sham", "r shammy",
        "shaman resto", "sham resto" },

    M1 = { "arcane mage", "arc mage", "amage", "arcane", "mage arcane" },
    M2 = { "fire mage", "firemage", "mage fire" },
    M3 = { "frost mage", "frostmage", "mage frost" },

    L1 = { "affliction warlock", "affliction lock", "affliction", "affli warlock", "affli lock",
        "aff warlock", "aff lock", "afflock", "alock", "affli", "lock aff", "lock affli" },
    L2 = { "demonology warlock", "demonology lock", "demonology", "demo warlock", "demo lock",
        "demolock", "demonlock", "demo", "lock demo" },
    L3 = { "destruction warlock", "destruction lock", "destruction", "destro warlock", "destro lock",
        "destrolock", "dest lock", "destro", "lock destro" },

    U1 = { "balance druid", "moonkin", "boomkin", "boomie", "boomy", "bdruid", "b druid",
        "bdudu", "b dudu", "boomdudu", "druid balance", "balance" },
    U2 = { "feral druid", "feral cat", "cat druid", "kitty druid", "kitty", "fdruid", "f druid",
        "fdudu", "f dudu", "feral dudu", "feraldudu", "druid feral", "feral" },
    U3 = { "restoration druid", "resto druid", "resto du", "rdruid", "r druid", "rdu", "rdru",
        "r dru", "restodruid", "tree druid", "druid resto", "druid tree",
        "rdudu", "r dudu", "resto dudu", "restodudu", "tree dudu", "treedudu",
        "rdrood", "r drood" },
}

local RACE_ALIASES = {
    HUMAN = { "human" },
    ORC = { "orc" },
    DWARF = { "dwarf" },
    NIGHTELF = { "night elf", "nightelf", "nelf" },
    UNDEAD = { "undead", "scourge" },
    TAUREN = { "tauren" },
    GNOME = { "gnome" },
    TROLL = { "troll" },
    BLOODELF = { "blood elf", "bloodelf", "belf" },
    DRAENEI = { "draenei" },
}

local BRACKET_MARKERS = {
    ["2v2"] = { " 2v2 ", " 2s ", " 2 s ", " 2c ", " 2s2 ", " 2c2 " },
    ["3v3"] = { " 3v3 ", " 3s ", " 3 s ", " 3c ", " 3s3 ", " 3c3 " },
    ["DuoQ"] = { " duo ", " duoq ", " duo q ", " duo queue ", " duo soloq ", " soloq duo " },
}
local QUEUE_MARKERS = {}
for _, bracket in ipairs(ns.BRACKETS) do
    for _, marker in ipairs(BRACKET_MARKERS[bracket]) do QUEUE_MARKERS[#QUEUE_MARKERS + 1] = marker end
end
local PREFERENCE_MARKERS = { " pref ", " prefer ", " preferably ", " preference " }
local TEAM_NEGATIONS = {
    "no team", "dont have team", "don't have team",
    "don t have team", "don t have a team", "need team", "lf team",
}
local TEAM_POSITIVES = { "my team", "have team", "have a team", "got team", "got a team" }
local INTENT = {
    "lfg", "lfm", "lf1m", "lf2m", "lf1", "lf",
    "looking for", "need", "seeking", "searching for",
}
local TARGET_ROLE_ALIASES = {
    DPS = { "dps", "damage" },
    Healer = { "healer", "heal", "heals" },
}
local GEAR_SCORE_ESTIMATES = {
    { aliases = { "starter" }, gs = 5600, label = "~5600" },
    { aliases = { "relent", "relentless", "furious" }, gs = 5750, label = "~5750" },
    { aliases = { "bis", "biss", "wrathful", "wf" }, gs = 6000, label = "6000+" },
}
local EXCLUDED_AD_TERMS = {
    "wts", "wtb", "selling", "boost", "carry", "recruiting", "coach", "coaching",
}
local RATING_SUFFIXES = { "xp", "exp", "cr" }

local function Normalize(text)
    text = text or ""
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("|T.-|t", "")
    text = text:gsub("|H.-|h(.-)|h", "%1")
    text = string.lower(text)
    text = text:gsub("(%d+)[%.,](%d+)%s*%+", function(whole, decimal)
        local rating = math.floor(tonumber(whole .. "." .. decimal) * 1000 + 0.5)
        return tostring(rating) .. " xp"
    end)
    for _, suffix in ipairs(RATING_SUFFIXES) do
        text = text:gsub("(%d+)[%.,](%d+)%s*k%s*%+%s*" .. suffix .. "%f[%A]", function(whole, decimal)
            local rating = math.floor(tonumber(whole .. "." .. decimal) * 1000 + 0.5)
            return tostring(rating) .. " " .. suffix
        end)
        text = text:gsub("(%d+)%s*k%s*%+%s*" .. suffix .. "%f[%A]", function(value)
            return tostring(tonumber(value) * 1000) .. " " .. suffix
        end)
        text = text:gsub("(%d+)[%.,](%d+)%s*k?%s*" .. suffix .. "%f[%A]", function(whole, decimal)
            local rating = math.floor(tonumber(whole .. "." .. decimal) * 1000 + 0.5)
            return tostring(rating) .. " " .. suffix
        end)
        text = text:gsub("(%d+)%s*k%s*" .. suffix .. "%f[%A]", function(value)
            return tostring(tonumber(value) * 1000) .. " " .. suffix
        end)
        text = text:gsub("(%d)%s*" .. suffix .. "%f[%A]", "%1 " .. suffix)
    end
    -- "2k+" / "2.2k+" with no rating keyword is an experience requirement, like "2.4+"
    -- above. Only 1k-3k: "6k+" is a gearscore and is left for the GS parser.
    text = text:gsub("%f[%d](%d+)[%.,](%d)%s*k%s*%+", function(whole, decimal)
        local rating = tonumber(whole) * 1000 + tonumber(decimal) * 100
        if rating >= 1000 and rating <= 3000 then return tostring(rating) .. " xp" end
    end)
    text = text:gsub("%f[%d](%d+)%s*k%s*%+", function(whole)
        local rating = tonumber(whole) * 1000
        if rating >= 1000 and rating <= 3000 then return tostring(rating) .. " xp" end
    end)
    -- Remaining "5.6k" / "5k" / "10k" shorthand: expand it before punctuation is
    -- stripped, otherwise "5.6k" becomes "5 6k" and the decimal is lost.
    text = text:gsub("%f[%d](%d+)[%.,](%d)%s*k%f[%A]", function(whole, decimal)
        return tostring(tonumber(whole) * 1000 + tonumber(decimal) * 100)
    end)
    text = text:gsub("%f[%d](%d+)%s*k%f[%A]", function(whole)
        return tostring(tonumber(whole) * 1000)
    end)
    text = text:gsub("(%f[%a]lf[gm]?)([23][svc]?[23]?%f[%A])", "%1 %2")
    text = text:gsub("(%f[%a]need)([23][svc]?[23]?%f[%A])", "%1 %2")
    text = text:gsub("(%d)(%a%a+)", "%1 %2")
    text = text:gsub("2%s*vs?%s*2", "2v2")
        :gsub("2%s*x%s*2", "2v2")
        :gsub("2%s*on%s*2", "2v2")
    text = text:gsub("3%s*vs?%s*3", "3v3")
        :gsub("3%s*x%s*3", "3v3")
        :gsub("3%s*on%s*3", "3v3")
    text = text:gsub("[^%w]", " ")
    text = text:gsub("%s+", " ")
    return " " .. strtrim(text) .. " "
end

local function NormalizeAliasList(aliases)
    for i, alias in ipairs(aliases) do
        aliases[i] = Normalize(alias)
    end
end

local function NormalizeAliasMap(aliasMap)
    for _, aliases in pairs(aliasMap) do
        NormalizeAliasList(aliases)
    end
end

NormalizeAliasMap(CLASS_ALIASES)
NormalizeAliasMap(SPEC_ALIASES)
NormalizeAliasMap(RACE_ALIASES)
NormalizeAliasList(PREFERENCE_MARKERS)
NormalizeAliasList(TEAM_NEGATIONS)
NormalizeAliasList(TEAM_POSITIVES)
NormalizeAliasList(INTENT)
NormalizeAliasMap(TARGET_ROLE_ALIASES)
NormalizeAliasList(EXCLUDED_AD_TERMS)
for _, estimate in ipairs(GEAR_SCORE_ESTIMATES) do
    NormalizeAliasList(estimate.aliases)
end

local NORMALIZED_SPEC_LABELS = {}

local function GetSpecAliases(spec)
    local aliases = SPEC_ALIASES[spec.id]
    if aliases then return aliases end

    aliases = NORMALIZED_SPEC_LABELS[spec.id]
    if not aliases then
        aliases = { Normalize(spec.label) }
        NORMALIZED_SPEC_LABELS[spec.id] = aliases
    end
    return aliases
end

local function HasAlias(text, aliases)
    for _, alias in ipairs(aliases) do
        if text:find(alias, 1, true) then return true end
    end
    return false
end

local function IsGlobalChannel(expectedName, ...)
    if type(expectedName) ~= "string" or expectedName == "" then return false end
    expectedName = string.lower(strtrim(expectedName))
    for i = 1, select("#", ...) do
        local channel = select(i, ...)
        if type(channel) == "string" then
            channel = channel:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            channel = channel:gsub("|H.-|h(.-)|h", "%1")
            channel = strtrim((channel:gsub("^%[", ""):gsub("%]$", "")))
            channel = string.lower(strtrim((channel:gsub("^%d+%.%s*", ""))))
            if channel == expectedName then return true end
        end
    end
    return false
end

local function FindClass(text)
    local foundClass, foundAt
    for _, class in ipairs(CLASS_ORDER) do
        for _, alias in ipairs(CLASS_ALIASES[class]) do
            local position = text:find(alias, 1, true)
            if position and (not foundAt or position < foundAt) then
                foundClass, foundAt = class, position
            end
        end
    end
    return foundClass
end

local function FindSpec(text, class)
    local foundSpec, foundAt
    for _, spec in ipairs(ns.PARTNER_SPECS) do
        local specClass = CLASS_BY_SPEC_PREFIX[strsub(spec.id, 1, 1)]
        if not class or class == specClass then
            for _, alias in ipairs(GetSpecAliases(spec)) do
                local position = text:find(alias, 1, true)
                if position and (not foundAt or position < foundAt) then
                    foundSpec, foundAt = spec, position
                end
            end
        end
    end
    return foundSpec
end

local function WithoutPreferences(text)
    local stop
    for _, marker in ipairs(PREFERENCE_MARKERS) do
        local position = text:find(marker, 1, true)
        if position and (not stop or position < stop) then stop = position end
    end
    return stop and text:sub(1, stop) or text
end

local function ValidRating(rating)
    return rating and rating >= 800 and rating <= 3500 and rating or nil
end

local function ParseExperienceTier(text)
    local rating = ValidRating(tonumber(text:match(" (%d+) xp ")))
        or ValidRating(tonumber(text:match(" (%d+) exp ")))
        or ValidRating(tonumber(text:match(" (%d+) experience ")))
        or ValidRating(tonumber(text:match(" xp (%d+) ")))
        or ValidRating(tonumber(text:match(" exp (%d+) ")))
        or ValidRating(tonumber(text:match(" experience (%d+) ")))
    if not rating then return nil end
    if rating < 1500 then return 2 end
    if rating < 1800 then return 3 end
    if rating < 2000 then return 4 end
    if rating < 2200 then return 5 end
    if rating < 2400 then return 6 end
    return 7
end

local function ParseTeamRating(text)
    return ValidRating(tonumber(text:match(" (%d+) cr ")))
        or ValidRating(tonumber(text:match(" (%d+) current rating ")))
end

-- Gearscore has to be told apart from ratings and experience (up to ~3000), so a
-- number with no "gs" next to it must be 4500 or more. Next to "gs" it may be lower.
local function ParseNumericGearScore(text)
    if not text then return end
    local marked = text:match(" (%d%d%d%d) gs ")
        or text:match(" gs (%d%d%d%d) ")
        or text:match(" gearscore (%d%d%d%d) ")
        or text:match(" (%d%d%d%d) gearscore ")
    local value = tonumber(marked)
    if value and value >= 3000 and value <= 6900 then
        return value, tostring(value)
    end
    for number in text:gmatch("%f[%d]%d%d%d%d%f[%D]") do
        value = tonumber(number)
        if value >= 4500 and value <= 6900 then
            return value, tostring(value)
        end
    end
end

local function ParseEstimatedGearScore(text)
    if not text then return end
    local foundEstimate, foundAt
    for _, estimate in ipairs(GEAR_SCORE_ESTIMATES) do
        for _, alias in ipairs(estimate.aliases) do
            local position = text:find(alias, 1, true)
            if position and (not foundAt or position < foundAt) then
                foundEstimate, foundAt = estimate, position
            end
        end
    end
    if foundEstimate then return foundEstimate.gs, foundEstimate.label end
end

local function HasOwnTeam(text)
    if HasAlias(text, TEAM_NEGATIONS) then return false end
    return HasAlias(text, TEAM_POSITIVES)
end

local function FindRace(text)
    for race, aliases in pairs(RACE_ALIASES) do
        if HasAlias(text, aliases) then return race end
    end
end

local function HasIntent(text)
    return HasAlias(text, INTENT)
end

local function FindIntentPosition(text)
    local first
    for _, alias in ipairs(INTENT) do
        local position = text:find(alias, 1, true)
        if position and (not first or position < first) then first = position end
    end
    return first
end

local function FindTargetRole(text)
    local intentPosition = FindIntentPosition(text)
    if not intentPosition then return nil end

    local requestedText = " " .. text:sub(intentPosition)
    local foundRole, foundAt
    for role, aliases in pairs(TARGET_ROLE_ALIASES) do
        for _, alias in ipairs(aliases) do
            local position = requestedText:find(alias, 1, true)
            if position and (not foundAt or position < foundAt) then
                foundRole, foundAt = role, position
            end
        end
    end
    return foundRole
end

local function FindRequestedSpecs(text)
    local start, markerFound
    for _, marker in ipairs(PREFERENCE_MARKERS) do
        local position = text:find(marker, 1, true)
        if position and (not start or position < start) then
            start, markerFound = position + #marker, true
        end
    end
    if not markerFound then
        local intentPosition = FindIntentPosition(text)
        if not intentPosition then return nil, nil end
        start = intentPosition
    end

    local requestedText = " " .. text:sub(start)
    local firstSpec = FindSpec(requestedText)
    if not firstSpec then return nil, nil end

    local specs, selectedRole = {}, firstSpec.role
    for _, spec in ipairs(ns.PARTNER_SPECS) do
        if spec.role == selectedRole and HasAlias(requestedText, GetSpecAliases(spec)) then
            specs[spec.id] = true
        end
    end
    return selectedRole, specs
end

local function FindQueuePosition(text)
    local first, firstLength
    for _, marker in ipairs(QUEUE_MARKERS) do
        local position = text:find(marker, 1, true)
        if position and (not first or position < first) then
            first, firstLength = position, #marker
        end
    end
    return first, firstLength
end

-- Bracket named by the earliest marker; nil when the ad names none
local function FindBracket(text)
    local bracket, first
    for _, name in ipairs(ns.BRACKETS) do
        for _, marker in ipairs(BRACKET_MARKERS[name]) do
            local position = text:find(marker, 1, true)
            if position and (not first or position < first) then bracket, first = name, position end
        end
    end
    return bracket
end

local function HasQueueMarker(text)
    for _, marker in ipairs(QUEUE_MARKERS) do
        if text:find(marker, 1, true) then return true end
    end
    return false
end

local function FindOwnerDetails(text, classHint)
    text = WithoutPreferences(text)
    local intentPosition = FindIntentPosition(text)
    local queuePosition, queueLength = FindQueuePosition(text)
    local ownerEnd = intentPosition or queuePosition
    local ownerText = ownerEnd and (text:sub(1, ownerEnd) .. " ") or text
    local class = classHint or FindClass(ownerText)
    local spec = FindSpec(ownerText, class)

    if not spec then
        if queuePosition then
            local afterQueue = " " .. text:sub(queuePosition + queueLength)
            local afterQueueClass = classHint or FindClass(afterQueue)
            local afterQueueSpec = FindSpec(afterQueue, afterQueueClass)
            if afterQueueSpec then
                ownerText = afterQueue
                class = afterQueueClass
                spec = afterQueueSpec
            end
        end
    end
    if spec and not class then class = CLASS_BY_SPEC_PREFIX[strsub(spec.id, 1, 1)] end
    return class, spec, ownerText
end

local function GetPlayerDetails(guid)
    if type(guid) ~= "string" or guid == "" or type(GetPlayerInfoByGUID) ~= "function" then
        return nil, nil
    end

    local _, class, _, race = GetPlayerInfoByGUID(guid)
    if not CLASS_ALIASES[class] then class = nil end
    return class, ns.NormalizeRace(race)
end

function ns.ParseGlobalListing(message, sender, channel, channelName, channelNumber, guid)
    if type(message) ~= "string"
        or type(sender) ~= "string" or sender == "" or sender == UnitName("player") then
        return false
    end
    if not IsGlobalChannel(ns.DB and ns.DB.globalChannel or "Global", channel, channelName) then
        return false
    end

    -- Ads that contain a link (discord invites, websites, boosting services) are ignored
    if ns.ContainsUrl and ns.ContainsUrl(message) then return false end

    local prev = ns.listings[sender]
    if prev and prev.source == "global" and prev.chatText == message then
        prev.seen = GetTime()
        return true
    end

    local text = Normalize(message)
    if HasAlias(text, EXCLUDED_AD_TERMS) then return false end
    local bracket = FindBracket(text)
    local mentions2v2 = bracket ~= nil -- any bracket marker
    local hasIntent = HasIntent(text)
    if not hasIntent and not mentions2v2 then return false end
    -- "duo" alone is common chat; only count it as an ad when the sender is looking for someone
    if bracket == "DuoQ" and not hasIntent then return false end
    bracket = bracket or "2v2"

    local preferredRole, targetSpecs
    if not mentions2v2 then
        preferredRole, targetSpecs = FindRequestedSpecs(text)
        if not targetSpecs or not next(targetSpecs) then return false end
    end

    if ns.DEBUG and mentions2v2 and hasIntent then
        ns.Debug("possible " .. bracket .. " ad from " .. sender .. " (channelString="
            .. tostring(channel) .. ", channelName=" .. tostring(channelName)
            .. ", channelNumber=" .. tostring(channelNumber)
            .. ", guid=" .. tostring(guid) .. ")")
    end

    local previous = ns.listings[sender]
    if previous and previous.source ~= "global" then return false end

    local playerClass, playerRace = GetPlayerDetails(guid)
    local class, spec, ownerText = FindOwnerDetails(text, playerClass)
    class = class or "UNKNOWN"
    local race = playerRace or FindRace(ownerText)
    local ownDetails = WithoutPreferences(text)
    local intentPosition = FindIntentPosition(ownDetails)
    local senderStats = intentPosition and (ownDetails:sub(1, intentPosition) .. " ") or ownDetails
    if not targetSpecs then
        preferredRole, targetSpecs = FindRequestedSpecs(text)
    end
    local targetRole = preferredRole or FindTargetRole(ownDetails) or "Any"
    local hasTargetSpecs = targetSpecs and next(targetSpecs) ~= nil or false
    local teamRating = ParseTeamRating(senderStats) or ParseTeamRating(text)
    local hasTeam = teamRating ~= nil or HasOwnTeam(ownDetails)
    local tier = ParseExperienceTier(text)
    local gs, gsEstimate = ParseNumericGearScore(senderStats)
    if not gs then gs, gsEstimate = ParseEstimatedGearScore(senderStats) end
    if not gs then gs, gsEstimate = ParseNumericGearScore(text) end
    if not gs then gs, gsEstimate = ParseEstimatedGearScore(text) end

    local displayMessage = message:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    displayMessage = displayMessage:gsub("|T.-|t", ""):gsub("|H.-|h(.-)|h", "%1")
    displayMessage = strtrim((displayMessage:gsub("%s+", " ")))
    displayMessage = strsub((displayMessage:gsub("|", "")), 1, 90)

    ns.AddListing({
        name = sender,
        class = class,
        spec = spec and spec.label or "Unknown",
        specId = spec and spec.id or nil,
        race = race,
        role = spec and spec.role or SINGLE_ROLE[class] or "Unknown",
        gs = gs or 0,
        gsEstimate = gsEstimate,
        hasTeam = hasTeam,
        teamKnown = hasTeam,
        teamRating = math.min(teamRating or 0, 3500),
        tier = tier,
        seasonal = nil,
        tenGames = nil,
        note = displayMessage,
        targetRole = targetRole,
        targetAny = targetRole ~= "Any" and not hasTargetSpecs,
        targetSpecs = targetSpecs or {},
        bracket = bracket,
        source = "global",
        chatText = message,
    })
    if ns.DEBUG then
        ns.Debug("parsed Global ad from " .. sender .. ": class=" .. class
            .. ", spec=" .. (spec and spec.label or "Unknown")
            .. ", race=" .. (race or "Unknown")
            .. ", experience=" .. (ns.TIERS[tier] or "Unknown")
            .. ", hasTeam=" .. tostring(hasTeam)
            .. ", teamRating=" .. tostring(teamRating or "Unknown")
            .. ", guid=" .. tostring(guid))
    end
    return true
end

ns.GlobalParserLoaded = true

local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_CHANNEL")
frame:SetScript("OnEvent", function(self, event, message, sender, language,
    channelString, target, flags, zoneChannelID, channelNumber, channelName,
    unused, lineID, guid)
    local ok, err = pcall(ns.ParseGlobalListing, message, sender, channelString,
        channelName, channelNumber, guid)
    if not ok and ns.DEBUG then ns.Debug("global parser: " .. tostring(err)) end
end)