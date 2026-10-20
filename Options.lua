local ADDON, ns = ...

-- Interface > AddOns > ArenaLFG, plus a Profiles sub-page. Changes apply
-- immediately, like most addons' option panels.

local uid = 0
local function NextName(prefix) uid = uid + 1; return "ArenaLFGOptions" .. prefix .. uid end

local refreshers = {}
local mainPanel, profilePanel

----------------------------------------------------------------------
-- Widget helpers (stock Blizzard templates only)
----------------------------------------------------------------------
local function AddTooltip(frame, text)
    if not text then return end
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function Header(parent, text, y)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetPoint("TOPLEFT", 16, y)
    fs:SetText(text)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetTexture(1, 1, 1, 0.2)
    line:SetHeight(1)
    line:SetPoint("LEFT", fs, "RIGHT", 8, 0)
    line:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    return fs
end

local function Label(parent, text, x, y, template)
    local fs = parent:CreateFontString(nil, "ARTWORK", template or "GameFontHighlight")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    return fs
end

local function Check(parent, label, tooltip, x, y, get, set)
    local name = NextName("Check")
    local c = CreateFrame("CheckButton", name, parent, "InterfaceOptionsCheckButtonTemplate")
    c:SetPoint("TOPLEFT", x, y)
    _G[name .. "Text"]:SetText(label)
    AddTooltip(c, tooltip)
    c:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        ns.RefreshOptions()
    end)
    refreshers[#refreshers + 1] = function() c:SetChecked(get()) end
    return c
end

local function Button(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetWidth(width); b:SetHeight(22); b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

-- getItems returns { { value = ..., label = ... }, ... }
local function Dropdown(parent, width, getItems, getValue, onPick, emptyText)
    local dd = CreateFrame("Frame", NextName("Dropdown"), parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dd, width)
    function dd:Refresh()
        local value, text = getValue(), nil
        for _, item in ipairs(getItems()) do
            if item.value == value then text = item.label end
        end
        UIDropDownMenu_SetText(dd, text or emptyText or "")
    end
    UIDropDownMenu_Initialize(dd, function(self, level)
        local items = getItems()
        if #items == 0 then
            local info = UIDropDownMenu_CreateInfo()
            info.text = "(none)"
            info.disabled = true
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
            return
        end
        local current = getValue()
        for _, item in ipairs(items) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = item.label
            info.checked = item.value == current
            info.func = function()
                onPick(item.value)
                ns.RefreshOptions()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    refreshers[#refreshers + 1] = function() dd:Refresh() end
    return dd
end

local function SoundItems()
    local items = {}
    for _, sound in ipairs(ns.SOUNDS) do
        items[#items + 1] = { value = sound.key, label = sound.label }
    end
    return items
end

----------------------------------------------------------------------
-- Main page
----------------------------------------------------------------------
local function BuildMainPanel()
    local p = CreateFrame("Frame", "ArenaLFGOptionsPanel", UIParent)
    p.name = "ArenaLFG"

    local title = p:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("ArenaLFG")
    local version = p:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 1)
    version:SetText("v" .. ns.VERSION)
    local profileText = Label(p, "", 16, -40, "GameFontHighlightSmall")
    refreshers[#refreshers + 1] = function()
        profileText:SetText("Current profile: |cffffffff" .. ns.GetProfileName()
            .. "|r  (change it on the Profiles page)")
    end

    -- General
    Header(p, "General", -66)
    Check(p, "Show minimap button", nil, 16, -84,
        function() return not ns.DB.minimap.hide end,
        function(v)
            ns.DB.minimap.hide = not v
            ns.UpdateMinimapButton()
        end)
    Check(p, "Open with PvP window", "Open ArenaLFG beside the PvP window when you open it (H by default).",
        16, -110,
        function() return ns.DB.pvpIntegration end,
        function(v) ns.SetPVPIntegration(v) end)
    Check(p, "Auto-reply in SoloQ", "While your group is listed and you are inside an arena match, answer whispers and party invites with a short busy message.",
        16, -136,
        function() return ns.DB.autoReply end,
        function(v) ns.DB.autoReply = v end)
    Check(p, "Debug messages", "Print sync and chat parsing details in chat. Applies to all profiles.",
        220, -136,
        function() return ns.SV.debug end,
        function(v) ns.DEBUG = v; ns.SV.debug = v end)

    -- Alerts
    Header(p, "Alerts", -170)
    Check(p, "Sound alerts", "Play sounds for sign-ups, invites and partner matches.", 16, -188,
        function() return ns.DB.soundAlerts end,
        function(v)
            ns.DB.soundAlerts = v
            if ns.frame and ns.frame.soundCheck then ns.frame.soundCheck:SetChecked(v) end
        end)
    Check(p, "Partner match alerts",
        "Notify on screen and in chat when a Global chat ad or ArenaLFG group is looking for your spec.",
        16, -214,
        function() return ns.DB.matchAlerts end,
        function(v)
            ns.DB.matchAlerts = v
            if ns.frame and ns.frame.matchCheck then ns.frame.matchCheck:SetChecked(v) end
        end)

    Label(p, "Sign-up sound:", 20, -248)
    local applicantSound = Dropdown(p, 140, SoundItems,
        function() return ns.DB.applicantSound end,
        function(v) ns.DB.applicantSound = v; ns.PreviewSound(v) end)
    applicantSound:SetPoint("TOPLEFT", 150, -240)
    Button(p, "Test", 60, function() ns.PreviewSound(ns.DB.applicantSound) end)
        :SetPoint("TOPLEFT", 335, -242)

    Label(p, "Partner match sound:", 20, -276)
    local matchSound = Dropdown(p, 140, SoundItems,
        function() return ns.DB.matchSound end,
        function(v) ns.DB.matchSound = v; ns.PreviewSound(v) end)
    matchSound:SetPoint("TOPLEFT", 150, -268)
    Button(p, "Test", 60, function() ns.PreviewSound(ns.DB.matchSound) end)
        :SetPoint("TOPLEFT", 335, -270)

    -- Global chat
    Header(p, "Global chat", -306)
    Check(p, "Announce my listed group in Global chat",
        "Post a short ad for your group under your name while it is listed. Server chat rules apply.",
        16, -330,
        function() return ns.DB.announce end,
        function(v)
            if (ns.DB.announce and true or false) ~= v then ns.SetAnnounceEnabled(v) end
        end)

    local sliderName = NextName("Slider")
    local slider = CreateFrame("Slider", sliderName, p, "OptionsSliderTemplate")
    slider:SetWidth(260)
    slider:SetPoint("TOPLEFT", 24, -382)
    slider:SetMinMaxValues(ns.ANNOUNCE_MIN_INTERVAL, ns.ANNOUNCE_MAX_INTERVAL)
    slider:SetValueStep(1)
    _G[sliderName .. "Low"]:SetText(ns.ANNOUNCE_MIN_INTERVAL .. " min")
    _G[sliderName .. "High"]:SetText(ns.ANNOUNCE_MAX_INTERVAL .. " min")
    local sliderText = _G[sliderName .. "Text"]
    local updatingSlider = false
    local function SetSliderLabel(minutes)
        sliderText:SetText("Announce at most every " .. minutes .. " minutes")
    end
    slider:SetScript("OnValueChanged", function(self, value)
        local minutes = math.floor(value + 0.5)
        SetSliderLabel(minutes)
        if updatingSlider then return end
        ns.SetAnnounceInterval(minutes)
    end)
    refreshers[#refreshers + 1] = function()
        updatingSlider = true
        slider:SetValue(ns.DB.announceInterval)
        updatingSlider = false
        SetSliderLabel(ns.DB.announceInterval)
        if ns.DB.announce then slider:Enable() else slider:Disable() end
        sliderText:SetFontObject(ns.DB.announce and GameFontNormal or GameFontDisable)
    end

    local msgLabel = Label(p, "Custom announcement. Empty = automatic ad + group title. Tags: {auto} {title} {bracket}", 24, -416, "GameFontHighlightSmall")
    local box = CreateFrame("EditBox", NextName("Edit"), p, "InputBoxTemplate")
    box:SetAutoFocus(false)
    box:SetMaxLetters(255)
    box:SetWidth(380); box:SetHeight(20)
    box:SetPoint("TOPLEFT", 30, -434)
    local function Commit(self)
        if ns.DB then ns.SetAnnounceMessage(self:GetText()) end
    end
    box:SetScript("OnEnterPressed", function(self) Commit(self); self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus(); ns.RefreshOptions() end)
    box:SetScript("OnEditFocusLost", Commit)
    Button(p, "Clear", 60, function() box:ClearFocus(); ns.SetAnnounceMessage(""); ns.RefreshOptions() end)
        :SetPoint("TOPLEFT", 420, -432)
    refreshers[#refreshers + 1] = function()
        if not box:HasFocus() then box:SetText(ns.DB.announceMessage or "") end
        box:SetCursorPosition(0)
        local on = ns.DB.announce
        msgLabel:SetFontObject(on and GameFontHighlightSmall or GameFontDisableSmall)
        if on then box:Enable() else box:Disable() end
    end

    p.refresh = ns.RefreshOptions
    p.default = function() ns.ResetProfile() end
    p:SetScript("OnShow", ns.RefreshOptions)
    InterfaceOptions_AddCategory(p)
    return p
end

----------------------------------------------------------------------
-- Profiles page
----------------------------------------------------------------------
StaticPopupDialogs["ARENALFG_DELETE_PROFILE"] = {
    text = "Delete the ArenaLFG profile \"%s\"?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self, data)
        if ns.DeleteProfile(data) then
            ns.Print("Deleted profile " .. data .. ".")
            ns.RefreshOptions()
        end
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

StaticPopupDialogs["ARENALFG_RESET_PROFILE"] = {
    text = "Reset the ArenaLFG profile \"%s\" to default settings?",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        ns.ResetProfile()
        ns.Print("Profile " .. ns.GetProfileName() .. " was reset.")
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

local function ProfileItems(excludeCurrent)
    local current, items = ns.GetProfileName(), {}
    for _, name in ipairs(ns.GetProfileNames()) do
        if not (excludeCurrent and name == current) then
            items[#items + 1] = { value = name, label = name }
        end
    end
    return items
end

local function BuildProfilePanel()
    local p = CreateFrame("Frame", "ArenaLFGProfilesPanel", UIParent)
    p.name = "Profiles"
    p.parent = mainPanel.name

    local title = p:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Profiles")
    local desc = Label(p, "ArenaLFG settings are saved in profiles. Characters use the \"Default\" profile"
        .. " unless you choose another one, so several characters can share settings. Your listing details"
        .. " (role, title, partner specs) are always saved per character.", 16, -40, "GameFontHighlightSmall")
    desc:SetWidth(560)

    local current = Label(p, "", 16, -86)
    refreshers[#refreshers + 1] = function()
        current:SetText("Current profile: |cffffd100" .. ns.GetProfileName() .. "|r")
    end

    Label(p, "Use an existing profile:", 16, -118, "GameFontNormalSmall")
    local switch = Dropdown(p, 180, function() return ProfileItems(false) end,
        ns.GetProfileName, function(v) ns.SetProfile(v) end)
    switch:SetPoint("TOPLEFT", 0, -132)

    Label(p, "Create a new profile (starts with default settings):", 16, -172, "GameFontNormalSmall")
    local newName = CreateFrame("EditBox", NextName("Edit"), p, "InputBoxTemplate")
    newName:SetWidth(180); newName:SetHeight(20); newName:SetAutoFocus(false)
    newName:SetMaxLetters(32)
    newName:SetPoint("TOPLEFT", 24, -188)
    local function CreateProfile()
        local name = strtrim(newName:GetText() or "")
        if name == "" then return end
        if ns.SV.profiles[name] then
            ns.Print("A profile named " .. name .. " already exists.")
            return
        end
        if ns.SetProfile(name) then
            newName:SetText("")
            newName:ClearFocus()
            ns.Print("Created and switched to profile " .. name .. ".")
        else
            ns.Print("Profile names must be 1-32 characters and cannot contain '|'.")
        end
    end
    newName:SetScript("OnEnterPressed", CreateProfile)
    newName:SetScript("OnEscapePressed", newName.ClearFocus)
    Button(p, "Create", 80, CreateProfile):SetPoint("LEFT", newName, "RIGHT", 8, 0)

    Label(p, "Copy settings from another profile into the current one:", 16, -226, "GameFontNormalSmall")
    local copy = Dropdown(p, 180, function() return ProfileItems(true) end,
        function() return nil end,
        function(v)
            if ns.CopyProfile(v) then ns.Print("Copied settings from profile " .. v .. ".") end
        end, "Choose a profile")
    copy:SetPoint("TOPLEFT", 0, -240)

    Label(p, "Delete a profile:", 16, -280, "GameFontNormalSmall")
    local delete = Dropdown(p, 180, function() return ProfileItems(true) end,
        function() return nil end,
        function(v)
            local popup = StaticPopup_Show("ARENALFG_DELETE_PROFILE", v)
            if popup then popup.data = v end
        end, "Choose a profile")
    delete:SetPoint("TOPLEFT", 0, -294)

    Button(p, "Reset current profile", 160, function()
        StaticPopup_Show("ARENALFG_RESET_PROFILE", ns.GetProfileName())
    end):SetPoint("TOPLEFT", 20, -340)

    p.refresh = ns.RefreshOptions
    p:SetScript("OnShow", ns.RefreshOptions)
    InterfaceOptions_AddCategory(p)
    return p
end

----------------------------------------------------------------------
-- Public
----------------------------------------------------------------------
function ns.RefreshOptions()
    if not ns.DB then return end
    for _, refresh in ipairs(refreshers) do refresh() end
end

function ns.BuildOptions()
    if mainPanel then return end
    mainPanel = BuildMainPanel()
    profilePanel = BuildProfilePanel()
    ns.RefreshOptions()
end

function ns.OpenOptions()
    if not mainPanel then ns.BuildOptions() end
    -- the first call on 3.3.5 sometimes only opens the frame without selecting the page
    InterfaceOptionsFrame_OpenToCategory(mainPanel)
    InterfaceOptionsFrame_OpenToCategory(mainPanel)
end
