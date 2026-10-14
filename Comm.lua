local ADDON, ns = ...

-- 3.3.5 has no addon-message type for custom channels, so listings travel as
-- plain text messages in a custom channel. Its traffic is filtered locally;
-- other players in the channel can still see the messages.
--   "AL1;..."  a listing      "ALrm"  listing removed      "ALreq"  please re-announce

local chanId = 0
local lower = string.lower
local REQUEST_COOLDOWN = 10
local lastBroadcastAt
local lastRequestAt
local requestResponsePending = false

local function RefreshChannelId()
    chanId = tonumber((GetChannelName(ns.CHANNEL))) or 0
    return chanId
end

function ns.Comm_IsJoined() return RefreshChannelId() > 0 end

function ns.Comm_Status()
    RefreshChannelId()
    ns.Print("Sync channel '" .. ns.CHANNEL .. "' id: " .. tostring(chanId)
        .. (chanId > 0 and " (joined)" or " (NOT joined)"))
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

function ns.Comm_Join()
    JoinChannelByName(ns.CHANNEL)
    ns.After(2, function()
        RefreshChannelId()
        if chanId > 0 then
            for i = 1, (NUM_CHAT_WINDOWS or 10) do
                local cf = _G["ChatFrame" .. i]
                if cf then ChatFrame_RemoveChannel(cf, ns.CHANNEL) end
            end
            ns.Debug("joined sync channel, id " .. chanId)
            ns.Comm_Request() -- ask others to announce themselves
            if ns.DB and ns.DB.mine.posted then
                ns.AddListing(ns.MyListing())
                ns.Broadcast()
            end
            ns.Changed() -- refresh the sync status shown in the UI
        else
            ns.Print("Could not join the sync channel (listings stay local).")
        end
    end)
end

function ns.Broadcast()
    local l = ns.MyListing()
    if not l then return end
    local ok, sent = pcall(Send, ns.Encode(l))
    if ok and sent then lastBroadcastAt = GetTime() end
    ns.Debug("sent listing: " .. tostring(ok and sent))
end

function ns.BroadcastRemove()
    pcall(Send, "ALrm")
end

-- Heartbeat: re-announce your own listing so it does not expire
ns.Every(ns.HEARTBEAT, function()
    if ns.DB and ns.DB.mine.posted then
        local l = ns.MyListing()
        if l then ns.AddListing(l) end
        ns.Broadcast()
    end
end)

local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_CHANNEL")
f:SetScript("OnEvent", function(self, event, msg, sender, lang, channelString)
    if not IsOurChannel(channelString) or not msg then return end
    ns.Debug("recv from " .. tostring(sender) .. ": " .. msg)
    if msg == "ALrm" then
        ns.applied[sender] = nil
        ns.RemoveListing(sender)
    elseif msg == "ALreq" then
        if ns.DB and ns.DB.mine.posted and not requestResponsePending
            and (not lastBroadcastAt or GetTime() - lastBroadcastAt >= REQUEST_COOLDOWN) then
            requestResponsePending = true
            ns.After(math.random() * 5, function()
                requestResponsePending = false
                if ns.DB and ns.DB.mine.posted
                    and (not lastBroadcastAt or GetTime() - lastBroadcastAt >= REQUEST_COOLDOWN) then
                    ns.Broadcast()
                end
            end)
        end
    elseif strsub(msg, 1, 4) == "AL1;" then
        local l = ns.Decode(msg, sender)
        if l then ns.AddListing(l) end
    end
end)

-- Ask everyone to re-announce their listing (refresh button)
function ns.Comm_Request()
    local now = GetTime()
    if lastRequestAt and now - lastRequestAt < REQUEST_COOLDOWN then return false end
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
    ns.Debug("whisper from " .. tostring(sender) .. ": " .. msg)
    if strsub(msg, 1, 3) == "AP;" then
        if not (ns.DB and ns.DB.mine.posted) then return end
        local l = ns.Decode(strsub(msg, 4), sender)
        if l then
            ns.AddApplicant(l)
            ns.Print(sender .. " signed up for your group.")
            PlaySound("TellMessage")
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
