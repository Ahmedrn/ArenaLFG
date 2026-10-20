local ADDON, ns = ...

-- 3.3.5 has no addon-message type for custom channels, so listings travel as
-- plain text messages in a custom channel. Its traffic is filtered locally;
-- other players in the channel can still see the messages.
--   "AL1;..."  a listing      "ALrm"  listing removed      "ALreq"  please re-announce

local chanId = 0
local lower = string.lower
local REQUEST_COOLDOWN = 10
local JOIN_MAX_ATTEMPTS = 3
local JOIN_RETRY_DELAY = 5
local SPEC_ABBREVIATIONS = {
    W1 = "Awar", W2 = "Fwar", W3 = "Pwar",
    P1 = "Hpal", P2 = "Prot", P3 = "Ret",
    H1 = "BM", H2 = "MM", H3 = "SV",
    R1 = "Assa", R2 = "Combat", R3 = "Sub",
    C1 = "Disc", C2 = "Hpriest", C3 = "SPriest",
    D1 = "Blood", D2 = "Frost", D3 = "UH",
    S1 = "Ele", S2 = "Enha", S3 = "Rsham",
    M1 = "Arc", M2 = "Fire", M3 = "Frost",
    L1 = "Affli", L2 = "Demo", L3 = "Destro",
    U1 = "Boomkin", U2 = "Feral", U3 = "Rdruid",
}
ns.SPEC_ABBREVIATIONS = SPEC_ABBREVIATIONS
local lastBroadcastAt
local lastRequestAt
local requestResponsePending = false
local joinInProgress = false

local function AnnounceIntervalMinutes()
    local minutes = tonumber(ns.DB and ns.DB.announceInterval) or ns.ANNOUNCE_MIN_INTERVAL
    return math.max(ns.ANNOUNCE_MIN_INTERVAL, math.min(math.floor(minutes), ns.ANNOUNCE_MAX_INTERVAL))
end

function ns.SetAnnounceInterval(minutes)
    if not ns.DB then return end
    ns.DB.announceInterval = math.floor(tonumber(minutes) or ns.ANNOUNCE_MIN_INTERVAL)
    ns.DB.announceInterval = AnnounceIntervalMinutes()
    ns.Changed()
end

local function RefreshChannelId()
    chanId = tonumber((GetChannelName(ns.CHANNEL))) or 0
    return chanId
end

function ns.Comm_IsJoined() return RefreshChannelId() > 0 end

function ns.Comm_Status()
    RefreshChannelId()
    ns.Print("Sync channel '" .. ns.CHANNEL .. "' id: " .. tostring(chanId)
        .. (chanId > 0 and " (joined)" or " (NOT joined)"))
    if chanId <= 0 then
        ns.Print("Retrying the sync channel join.")
        ns.Comm_Join()
    end
end

local function IsOurChannel(channelString)
    return type(channelString) == "string"
        and lower(channelString):find(lower(ns.CHANNEL), 1, true)
end

-- Hide the channel's messages and join/leave notices from chat windows
local function ChatFilter(self, event, ...)
    if event == "CHAT_MSG_CHANNEL" then
        local _, _, _, channelString = ...
        if IsOurChannel(channelString) then return true end
    else
        for i = 1, select("#", ...) do
            if IsOurChannel(select(i, ...)) then return true end
        end
    end
end
ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", ChatFilter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL_NOTICE", ChatFilter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL_NOTICE_USER", ChatFilter)

local function Send(text)
    if RefreshChannelId() <= 0 then return false end
    SendChatMessage(text, "CHANNEL", nil, chanId)
    return true
end

local function CompleteJoin()
    joinInProgress = false
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local cf = _G["ChatFrame" .. i]
        if cf then ChatFrame_RemoveChannel(cf, ns.CHANNEL) end
    end
    if ns.DEBUG then ns.Debug("joined sync channel, id " .. chanId) end
    ns.Comm_Request() -- ask others to announce themselves
    if ns.DB then
        if ns.GroupBlocksListing() then
            if ns.mine.posted then
                ns.Print("You are grouped, so your saved listing was removed.")
                ns.RemoveMine()
            else
                ns.BroadcastRemove()
            end
        elseif ns.mine.posted then
            ns.AddListing(ns.MyListing())
            ns.Broadcast()
        end
    end
    ns.Changed() -- refresh the sync status shown in the UI
end

local function TryJoin(attempt)
    if RefreshChannelId() > 0 then
        CompleteJoin()
        return
    end
    JoinChannelByName(ns.CHANNEL)
    ns.After(2, function()
        if RefreshChannelId() > 0 then
            CompleteJoin()
        elseif attempt < JOIN_MAX_ATTEMPTS then
            ns.After(JOIN_RETRY_DELAY, function() TryJoin(attempt + 1) end)
        else
            joinInProgress = false
            ns.Print("Could not join the sync channel (listings stay local).")
        end
    end)
end

function ns.Comm_Join()
    if RefreshChannelId() > 0 then
        if not joinInProgress then CompleteJoin() end
        return
    end
    if joinInProgress then return end

    joinInProgress = true
    TryJoin(1)
end

-- Global is a normal, visible channel: join it only if the server has not already
-- put the player in it (never hidden or removed from chat windows).
function ns.Comm_EnsureGlobal(attempt)
    attempt = attempt or 1
    local name = ns.DB and ns.DB.globalChannel or "Global"
    if (tonumber((GetChannelName(name))) or 0) > 0 then return end
    JoinChannelByName(name)
    ChatFrame_AddChannel(DEFAULT_CHAT_FRAME, name)
    if attempt < JOIN_MAX_ATTEMPTS then
        ns.After(JOIN_RETRY_DELAY, function() ns.Comm_EnsureGlobal(attempt + 1) end)
    end
end

function ns.Broadcast()
    local l = ns.MyListing()
    if not l then return end
    local ok, sent = pcall(Send, ns.Encode(l))
    if ok and sent then
        lastBroadcastAt = GetTime()
        ns.mine.postedAt = time()
    end
    if ns.DEBUG then ns.Debug("sent listing: " .. tostring(ok and sent)) end
end

function ns.BroadcastRemove()
    pcall(Send, "ALrm")
end

function ns.SetAnnounceEnabled(enabled)
    if not ns.DB then return end
    ns.SV.announceAsked = true
    ns.DB.announce = enabled and true or false
    local minutes = AnnounceIntervalMinutes()
    ns.Print("Global group announcements " .. (ns.DB.announce and "enabled" or "disabled")
        .. (ns.DB.announce and (". Your group will be announced while listed, at most once every "
            .. minutes .. " minutes.") or "."))
    if ns.DB.announce then ns.TryAnnounceMine() end
    if ns.RefreshOptions then ns.RefreshOptions() end
    ns.Changed()
end

local function BuildAnnouncement()
    local listing = ns.MyListing()
    if not listing then return nil end

    local specId = ns.GetMySpecId()
    local spec = ns.GetMySpec()
    local class = UnitClass("player")
    local owner = SPEC_ABBREVIATIONS[specId]
        or ((spec and spec ~= "None" and (spec .. " ") or "") .. (class or ""))
    if owner == "" then owner = "arena player" end

    local targets, separator = {}, "/"
    local comp = listing.targetRole == "Comp" and ns.FindComp(listing.comp)
    if comp then
        -- every remaining slot of the comp is needed, so join with "+"
        separator = "+"
        if listing.haveSpec then
            owner = owner .. "+" .. (SPEC_ABBREVIATIONS[listing.haveSpec] or ns.SpecTokenLabel(listing.haveSpec))
        end
        for _, slot in ipairs(ns.CompRemainingSlots(comp, specId, listing.haveSpec)) do
            targets[#targets + 1] = SPEC_ABBREVIATIONS[slot] or ns.SpecTokenLabel(slot)
        end
    elseif type(listing.targetSpecs) == "table" then
        for _, partnerSpec in ipairs(ns.PARTNER_SPECS) do
            if partnerSpec.role == listing.targetRole and listing.targetSpecs[partnerSpec.id] then
                targets[#targets + 1] = SPEC_ABBREVIATIONS[partnerSpec.id] or partnerSpec.label
            end
        end
    end
    local lookingFor
    if #targets > 0 and #targets <= 2 then
        lookingFor = table.concat(targets, separator)
    elseif listing.targetRole and listing.targetRole ~= "Any" then
        lookingFor = listing.targetRole
    else
        lookingFor = "partner"
    end

    local rating = ""
    if listing.hasTeam and listing.teamRating and listing.teamRating > 0 then
        rating = " " .. tostring(listing.teamRating) .. "cr"
    end
    local experience = listing.tier and ns.TIERS[listing.tier]
    if experience then
        rating = rating .. " Exp: " .. experience
    end
    return owner .. " LF " .. lookingFor .. " " .. ns.BracketTag(listing.bracket) .. rating .. " (ArenaLFG)"
end

-- Without a custom template the ad is the generated one plus the listing's group title.
-- A template may use {auto} (generated ad), {title} (group title) and {bracket} (2v2/3v3/duoq),
-- so it stays right when the listing's bracket changes. Chat messages are limited to 255 characters.
local function AnnouncementText()
    local auto = BuildAnnouncement()
    if not auto then return nil end
    local listing = ns.MyListing()
    local title = listing and listing.note and strtrim(listing.note) or ""
    local template = ns.DB and ns.DB.announceMessage
    template = type(template) == "string" and strtrim(template) or ""
    if template == "" then template = "{auto} - {title}" end -- same as the profile default

    local values = { auto = auto, title = title, bracket = ns.BracketTag(listing.bracket) }
    local text = template:gsub("{(%a+)}", function(key) return values[key] end)
    text = text:gsub("^%s*%-%s*", ""):gsub("%s*%-%s*$", ""):gsub("%s%s+", " ")
    return strsub(strtrim(text), 1, 255)
end

function ns.SetAnnounceMessage(text)
    if not ns.DB then return end
    ns.DB.announceMessage = strsub(strtrim(tostring(text or "")), 1, 255) -- empty = default template
    ns.Changed()
end

function ns.TryAnnounceMine()
    if not (ns.DB and ns.DB.announce and ns.mine and ns.mine.posted) then return false end
    if ns.GroupBlocksListing() or ns.InPvpInstance() then return false end

    local now = time()
    local lastAnnounceAt = tonumber(ns.SV.announceLastAt) or 0
    if now - lastAnnounceAt < AnnounceIntervalMinutes() * 60 then return false end

    local channelName = ns.DB and ns.DB.globalChannel
    if type(channelName) ~= "string" or channelName == "" then
        return false
    end
    local channelId = tonumber((GetChannelName(channelName))) or 0
    if channelId <= 0 then return false end

    local message = AnnouncementText()
    if not message then return false end
    local ok, err = pcall(SendChatMessage, message, "CHANNEL", nil, channelId)
    if not ok then
        ns.SV.announceLastAt = now
        ns.Print("Could not announce your group: " .. tostring(err))
        ns.Changed()
        return false
    end
    ns.SV.announceLastAt = now
    ns.Changed()
    return true
end

function ns.GetAnnounceStatus()
    if not (ns.DB and ns.DB.announce) then
        return "Global announcements off"
    end
    if not (ns.mine and ns.mine.posted) then
        return "Global announcement: list your group first"
    end
    if ns.GroupBlocksListing() or ns.InPvpInstance() then
        return "Global announcement paused while grouped or in PvP"
    end

    local channelName = ns.DB.globalChannel
    if type(channelName) ~= "string" or channelName == ""
        or (tonumber((GetChannelName(channelName))) or 0) <= 0 then
        return "Join " .. tostring(channelName or "Global") .. " to announce"
    end

    local remaining = AnnounceIntervalMinutes() * 60 - (time() - (tonumber(ns.SV.announceLastAt) or 0))
    if remaining <= 0 then
        return "Global post ready (within 30 sec)"
    end
    return "Next Global post in about " .. math.ceil(remaining / 60) .. " min"
end

ns.Every(30, function()
    ns.TryAnnounceMine()
end)

-- Heartbeat: re-announce your own listing so it does not expire
ns.Every(ns.HEARTBEAT, function()
    if ns.DB and ns.mine.posted then
        local l = ns.MyListing()
        if l then ns.AddListing(l) end
        ns.Broadcast()
    end
end)

-- Auto-reply: while listed and inside an arena match (SoloQ), tell whoever whispers or
-- invites that you are busy, so they know to wait (once per player every 5 minutes).
local AUTO_REPLY_TAG = "[ArenaLFG]"
local AUTO_REPLY = AUTO_REPLY_TAG .. " Auto-reply: I'm in a SoloQ arena match right now, I'll answer when it ends."
local autoReplied = {}

local function ShouldAutoReply()
    if not (ns.DB and ns.DB.autoReply and ns.mine and ns.mine.posted) then return false end
    local inInstance, instanceType = IsInInstance()
    return inInstance and instanceType == "arena"
end

local function AutoReply(name)
    if type(name) ~= "string" or name == "" or name == UnitName("player") then return end
    local now = GetTime()
    if autoReplied[name] and now - autoReplied[name] < 300 then return end
    autoReplied[name] = now
    pcall(SendChatMessage, AUTO_REPLY, "WHISPER", nil, name)
end

local replyFrame = CreateFrame("Frame")
replyFrame:RegisterEvent("CHAT_MSG_WHISPER")
replyFrame:RegisterEvent("PARTY_INVITE_REQUEST")
replyFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
    if not ShouldAutoReply() then return end
    if event == "CHAT_MSG_WHISPER" then
        if strsub(arg1 or "", 1, #AUTO_REPLY_TAG) == AUTO_REPLY_TAG then return end -- never answer an auto-reply
        AutoReply(arg2)
    else
        AutoReply(arg1) -- inviter
    end
end)

local function QueueRequestResponse()
    if requestResponsePending or not (ns.DB and ns.mine.posted) then return end

    requestResponsePending = true
    local remainingCooldown = lastBroadcastAt
        and math.max(0, REQUEST_COOLDOWN - (GetTime() - lastBroadcastAt)) or 0
    ns.After(remainingCooldown + math.random() * 5, function()
        requestResponsePending = false
        if ns.DB and ns.mine.posted
            and (not lastBroadcastAt or GetTime() - lastBroadcastAt >= REQUEST_COOLDOWN) then
            ns.Broadcast()
        end
    end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_CHANNEL")
f:SetScript("OnEvent", function(self, event, msg, sender, lang, channelString)
    if not IsOurChannel(channelString) or not msg then return end
    if ns.DEBUG then ns.Debug("recv from " .. tostring(sender) .. ": " .. msg) end
    if msg == "ALrm" then
        ns.applied[sender] = nil
        ns.RemoveListing(sender)
    elseif msg == "ALreq" then
        QueueRequestResponse()
    elseif strsub(msg, 1, 4) == "AL1;" then
        local prev = ns.listings[sender]
        if prev and prev.wire == msg then
            prev.seen = GetTime()
            return
        end
        local l = ns.Decode(msg, sender)
        if l then
            l.wire = msg
            ns.AddListing(l)
            ns.CheckVersion(l.version)
        end
    end
end)

-- Ask everyone to re-announce their listing (refresh button)
function ns.Comm_Request()
    local now = GetTime()
    if lastRequestAt and now - lastRequestAt < REQUEST_COOLDOWN then
        return false, math.ceil(REQUEST_COOLDOWN - (now - lastRequestAt))
    end
    local ok, sent = pcall(Send, "ALreq")
    if not ok or not sent then return false end
    lastRequestAt = now
    return true
end

function ns.Comm_GetCooldown()
    local now = GetTime()
    if lastRequestAt and now - lastRequestAt < REQUEST_COOLDOWN then
        return math.ceil(REQUEST_COOLDOWN - (now - lastRequestAt))
    end
    return 0
end

-- Private messages between players (sign-ups), sent as addon whispers
local af = CreateFrame("Frame")
af:RegisterEvent("CHAT_MSG_ADDON")
af:SetScript("OnEvent", function(self, event, prefix, msg, dist, sender)
    if prefix ~= ns.PREFIX or not msg or sender == UnitName("player") then return end
    if ns.DEBUG then ns.Debug("whisper from " .. tostring(sender) .. ": " .. msg) end
    if strsub(msg, 1, 3) == "AP;" then
        if not (ns.DB and ns.mine and ns.mine.posted) then return end
        local l = ns.Decode(strsub(msg, 4), sender)
        if l and not ns.IsHidden(sender) then
            ns.AddApplicant(l)
            ns.Print(sender .. " signed up for your group.")
            ns.PlayAlert("applicant")
            if RaidNotice_AddMessage and RaidWarningFrame then
                RaidNotice_AddMessage(RaidWarningFrame,
                    "|cff33ff99[ArenaLFG]|r " .. sender .. " signed up for your group!",
                    ChatTypeInfo["RAID_WARNING"])
            end
        end
    elseif msg == "CANCEL" then
        ns.applicants[sender] = nil
        ns.Changed()
    elseif msg == "INV" then
        if ns.applied[sender] ~= "pending" then return end
        ns.applied[sender] = "invited"
        ns.Print(sender .. " invited you to their group!")
        ns.PlayAlertSound("PVPTHROUGHQUEUE")
        if RaidNotice_AddMessage and RaidWarningFrame then
            RaidNotice_AddMessage(RaidWarningFrame,
                "|cff33ff99[ArenaLFG]|r " .. sender .. " invited you to their group!",
                ChatTypeInfo["RAID_WARNING"])
        end
        ns.Changed()
    elseif msg == "DEC" then
        if ns.applied[sender] ~= "pending" then return end
        ns.applied[sender] = "declined"
        ns.Print(sender .. " declined your sign-up.")
        ns.Changed()
    end
end)
