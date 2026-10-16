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
local lastBroadcastAt
local lastRequestAt
local requestResponsePending = false
local joinInProgress = false

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
        if ns.InGroup() or ns.InPvpInstance() then
            if ns.mine.posted then
                ns.Print("You are grouped or in an arena/battleground, so your saved listing was removed.")
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

-- Heartbeat: re-announce your own listing so it does not expire
ns.Every(ns.HEARTBEAT, function()
    if ns.DB and ns.mine.posted then
        local l = ns.MyListing()
        if l then ns.AddListing(l) end
        ns.Broadcast()
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

-- Private messages between players (sign-ups), sent as addon whispers
local af = CreateFrame("Frame")
af:RegisterEvent("CHAT_MSG_ADDON")
af:SetScript("OnEvent", function(self, event, prefix, msg, dist, sender)
    if prefix ~= ns.PREFIX or not msg or sender == UnitName("player") then return end
    if ns.DEBUG then ns.Debug("whisper from " .. tostring(sender) .. ": " .. msg) end
    if strsub(msg, 1, 3) == "AP;" then
        if not (ns.DB and ns.mine and ns.mine.posted) then return end
        local l = ns.Decode(strsub(msg, 4), sender)
        if l then
            ns.AddApplicant(l)
            ns.Print(sender .. " signed up for your group.")
            if not (ns.frame and ns.frame:IsShown()) then
                PlaySound("TellMessage")
            end
        end
    elseif msg == "CANCEL" then
        ns.applicants[sender] = nil
        ns.Changed()
    elseif msg == "INV" then
        if ns.applied[sender] ~= "pending" then return end
        ns.applied[sender] = "invited"
        ns.Print(sender .. " invited you to their group.")
        ns.Changed()
    elseif msg == "DEC" then
        if ns.applied[sender] ~= "pending" then return end
        ns.applied[sender] = "declined"
        ns.Changed()
    end
end)
