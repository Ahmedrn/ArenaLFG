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
    DRUID = { "druid" },
}

local CLASS_ORDER = {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
    "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID",
}

local CLASS_BY_SPEC_PREFIX = {
    W = "WARRIOR", P = "PALADIN", H = "HUNTER", R = "ROGUE",
    C = "PRIEST", D = "DEATHKNIGHT", S = "SHAMAN", M = "MAGE",
    L = "WARLOCK", U = "DRUID",
}

local SPEC_ALIASES = {
    W1 = { "arms warrior", "arms warr", "arms" },
    W2 = { "fury warrior", "fury warr", "fury" },
    W3 = { "protection warrior", "prot warrior", "prot warr" },
    P1 = { "holy paladin", "holy pala", "hpala" },
    P2 = { "protection paladin", "prot paladin", "prot pala" },
    P3 = { "retribution paladin", "ret paladin", "ret pala", "ret" },
    H1 = { "beast mastery", "bm hunter", "bm hunt" },
    H2 = { "marksmanship", "mm hunter", "mm hunt", "mm" },
    H3 = { "survival hunter", "surv hunter", "surv hunt" },
    R1 = { "assassination rogue", "assa rogue", "assa" },
    R2 = { "combat rogue", "combat" },
    R3 = { "subtlety rogue", "sub rogue", "sub" },
    C1 = { "discipline priest", "disc priest", "disc" },
    C2 = { "holy priest" },
    C3 = { "shadow priest" },
    D1 = { "blood death knight", "blood dk" },
    D2 = { "frost death knight", "frost dk" },
    D3 = { "unholy death knight", "unholy dk" },
    S1 = { "elemental shaman", "elem shaman", "ele shaman", "elem sham", "ele sham", "ele" },
    S2 = { "enhancement shaman", "enhance shaman", "enh shaman", "enh" },
    S3 = { "restoration shaman", "resto shaman", "resto sham" },
    M1 = { "arcane mage" },
    M2 = { "fire mage" },
    M3 = { "frost mage" },
    L1 = { "affliction warlock", "affli lock", "affli" },
    L2 = { "demonology warlock", "demo lock", "demo" },
    L3 = { "destruction warlock", "destro lock", "destro" },
    U1 = { "balance druid", "boomkin" },
    U2 = { "feral druid", "feral" },
    U3 = { "restoration druid", "resto druid" },
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

local function Normalize(text)
    text = string.lower(text or "")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("|T.-|t", "")
    text = text:gsub("|H.-|h(.-)|h", "%1")
    text = text:gsub("2v%s*2", "2v2")
    text = text:gsub("[^%w]", " ")
    text = text:gsub("%s+", " ")
    return " " .. strtrim(text) .. " "
end

local function HasAlias(text, aliases)
    for _, alias in ipairs(aliases) do
        if text:find(Normalize(alias), 1, true) then return true end
    end
    return false
end

local function IsGlobalChannel(...)
    for i = 1, select("#", ...) do
        local channel = select(i, ...)
        if type(channel) == "string" then
            channel = channel:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            channel = channel:gsub("|H.-|h(.-)|h", "%1")
            channel = strtrim(channel:gsub("^%[", ""):gsub("%]$", ""))
            channel = string.lower(strtrim(channel:gsub("^%d+%.%s*", "")))
            if channel == "global" or channel:match("^global[%s%d%-]") then
                return true
            end
        end
    end
    return false
end

local function FindClass(text)
    local foundClass, foundAt
    for _, class in ipairs(CLASS_ORDER) do
        for _, alias in ipairs(CLASS_ALIASES[class]) do
            local position = text:find(Normalize(alias), 1, true)
            if position and (not foundAt or position < foundAt) then
                foundClass, foundAt = class, position
            end
        end
    end
    return foundClass
end

local function FindSpec(text, class)
    for _, spec in ipairs(ns.PARTNER_SPECS) do
        local specClass = CLASS_BY_SPEC_PREFIX[strsub(spec.id, 1, 1)]
        if (not class or class == specClass) and HasAlias(text, SPEC_ALIASES[spec.id] or { spec.label }) then
            return spec
        end
    end
end

local function FindRace(text)
    for race, aliases in pairs(RACE_ALIASES) do
        if HasAlias(text, aliases) then return race end
    end
end

local function HasIntent(text)
    return HasAlias(text, { "lfg", "lf", "looking for", "need", "seeking", "searching for" })
end

local function FindIntentPosition(text)
    local first
    for _, alias in ipairs({ "lfg", "lf", "looking for", "need", "seeking", "searching for" }) do
        local position = text:find(Normalize(alias), 1, true)
        if position and (not first or position < first) then first = position end
    end
    return first
end

local function FindQueuePosition(text)
    local first, firstLength
    for _, marker in ipairs({ " 2v2 ", " 2s ", " 2 s " }) do
        local position = text:find(marker, 1, true)
        if position and (not first or position < first) then
            first, firstLength = position, #marker
        end
    end
    return first, firstLength
end

local function FindOwnerDetails(text, classHint)
    local intentPosition = FindIntentPosition(text)
    local ownerText = intentPosition and text:sub(1, intentPosition - 1) or ""
    local class = classHint or FindClass(ownerText)
    local spec = FindSpec(ownerText, class)

    if not spec then
        local queuePosition, queueLength = FindQueuePosition(text)
        if queuePosition then
            local afterQueue = text:sub(queuePosition + queueLength)
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
    local text = type(message) == "string" and Normalize(message) or ""
    local mentions2s = text:find(" 2v2 ", 1, true)
        or text:find(" 2s ", 1, true) or text:find(" 2 s ", 1, true)
    local hasIntent = HasIntent(text)
    local isGlobal = IsGlobalChannel(channel, channelName)

    if mentions2s and hasIntent then
        ns.Debug("possible 2v2 ad from " .. tostring(sender) .. " (channelString="
            .. tostring(channel) .. ", channelName=" .. tostring(channelName)
            .. ", channelNumber=" .. tostring(channelNumber)
            .. ", guid=" .. tostring(guid) .. ")")
    end
    if not isGlobal then
        return false
    end
    if type(message) ~= "string"
        or type(sender) ~= "string" or sender == "" or sender == UnitName("player") then
        return false
    end

    if not mentions2s or not hasIntent then
        return false
    end

    local previous = ns.listings[sender]
    if previous and previous.source ~= "global" then return false end

    local playerClass, playerRace = GetPlayerDetails(guid)
    local class, spec, ownerText = FindOwnerDetails(text, playerClass)
    class = class or "UNKNOWN"
    local race = playerRace or FindRace(ownerText)

    local displayMessage = message:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    displayMessage = displayMessage:gsub("|T.-|t", ""):gsub("|H.-|h(.-)|h", "%1")
    displayMessage = strtrim(displayMessage:gsub("%s+", " "))

    ns.AddListing({
        name = sender,
        class = class,
        spec = spec and spec.label or "Unknown",
        specId = spec and spec.id or nil,
        race = race,
        role = spec and spec.role or "Unknown",
        gs = 0,
        hasTeam = false,
        teamKnown = false,
        teamRating = 0,
        tier = nil,
        seasonal = nil,
        tenGames = nil,
        note = displayMessage,
        source = "global",
    })
    ns.Debug("parsed Global ad from " .. sender .. ": class=" .. class
        .. ", spec=" .. (spec and spec.label or "Unknown")
        .. ", race=" .. (race or "Unknown")
        .. ", guid=" .. tostring(guid))
    return true
end

ns.GlobalParserLoaded = true

local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_CHANNEL")
frame:SetScript("OnEvent", function(self, event, message, sender, language,
    channelString, target, flags, zoneChannelID, channelNumber, channelName,
    unused, lineID, guid)
    ns.ParseGlobalListing(message, sender, channelString, channelName, channelNumber, guid)
end)
