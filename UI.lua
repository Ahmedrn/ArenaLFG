local ADDON, ns = ...

local ROW_H, ROWS = 38, 8
local FACTION_SIZE = 26
local FACTION_TEXT_X = 39
local FACTION_COORDS = {
    Alliance = { 0, 0.6, 0, 0.6 },
    Horde = { 0, 0.6, 0, 0.6 },
}
local APP_H, APP_ROWS = 26, 8
local CLASS_TEX = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local menuFrame = CreateFrame("Frame", "ArenaLFGMenuFrame", UIParent, "UIDropDownMenuTemplate")
local UpdateLeft -- forward declaration
local activeMultiMenuButton

local function IsFocusWithin(frame)
    local focus = GetMouseFocus()
    while focus do
        if focus == frame or focus == DropDownList1 or focus == DropDownList2 then return true end
        focus = focus:GetParent()
    end
    return false
end

local ROLE_TEXT = {
    DPS    = "|cffff6060DPS|r",
    Healer = "|cff40ff40Healer|r",
    Tank   = "|cff60a0ffTank|r",
}

-- Unknown roles (e.g. from chat ads) are left blank
local function RoleText(role)
    return ROLE_TEXT[role] or ""
end

local ROLE_ICONS = {
    Tank   = { 0, 19/64, 22/64, 41/64 },
    Healer = { 20/64, 39/64, 1/64, 20/64 },
    DPS    = { 20/64, 39/64, 22/64, 41/64 },
}

local function GetRoleCoords(role)
    if GetTexCoordsForRoleSmallCircle then
        local r = (role == "DPS" and "DAMAGER") or (role == "Tank" and "TANK") or (role == "Healer" and "HEALER")
        if r then
            local ok, left, right, top, bottom = pcall(GetTexCoordsForRoleSmallCircle, r)
            if ok and left then return left, right, top, bottom end
        end
    end
    local c = ROLE_ICONS[role]
    if c then return c[1], c[2], c[3], c[4] end
end

local function SetRoleIcon(tex, role)
    if not tex then return false end
    if not role or role == "Any" or role == "Unknown" then
        tex:Hide()
        return false
    end
    local l, r, t, b = GetRoleCoords(role)
    if l then
        tex:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
        tex:SetTexCoord(l, r, t, b)
        tex:Show()
        return true
    else
        tex:Hide()
        return false
    end
end

local function GetRoleMarkup(role)
    local l, r, t, b = GetRoleCoords(role)
    if l then
        local left = math.floor(l * 64)
        local right = math.floor(r * 64)
        local top = math.floor(t * 64)
        local bottom = math.floor(b * 64)
        return string.format("|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:%d:%d:%d:%d|t ", left, right, top, bottom)
    end
    return ""
end

local uid = 0
local function NextName(prefix) uid = uid + 1; return "ArenaLFG" .. prefix .. uid end

----------------------------------------------------------------------
-- Small widget helpers (stock Blizzard templates only)
----------------------------------------------------------------------
local function MakePanel(parent, w, h)
    local p = CreateFrame("Frame", nil, parent)
    p:SetWidth(w); p:SetHeight(h)
    p:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    p:SetBackdropColor(0.04, 0.04, 0.06, 0.94)
    p:SetBackdropBorderColor(0.35, 0.38, 0.45, 0.85)
    return p
end

local function SetClassIcon(tex, class)
    local tc = CLASS_ICON_TCOORDS[class]
    if not tc then
        tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        return
    end
    tex:SetTexture(CLASS_TEX)
    tex:SetTexCoord(unpack(tc))
end

local function SetSpecIcon(tex, class)
    local specIcon = ns.GetMySpecIcon()
    if specIcon then
        tex:SetTexture("Interface\\Icons\\" .. specIcon)
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    else
        SetClassIcon(tex, class)
    end
end

local function SetListingSpecIcon(tex, listing)
    local specIcon = ns.GetSpecIcon(listing.class, listing.specId)
    if specIcon then
        tex:SetTexture("Interface\\Icons\\" .. specIcon)
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    else
        SetClassIcon(tex, listing.class)
    end
end

local function FactionRaceMarkup(race)
    local raceIcon = ns.GetRaceIcon(race)
    local raceMarkup = raceIcon and ("|TInterface\\Icons\\" .. raceIcon .. ":14:14|t ") or ""
    return raceMarkup
end

-- Button that opens a stock dropdown menu; text shows the current value
local function MakeMenuButton(parent, width, getValues, getText, onPick)
    local btn = CreateFrame("Button", NextName("Menu"), parent, "UIPanelButtonTemplate")
    btn:SetWidth(width); btn:SetHeight(22)
    function btn:Refresh() self:SetText(getText()) end
    btn:SetScript("OnClick", function(self)
        local menu = {}
        for _, v in ipairs(getValues()) do
            tinsert(menu, { text = v, notCheckable = true,
                func = function() onPick(v); self:Refresh() end })
        end
        EasyMenu(menu, menuFrame, self, 0, 0, "MENU")
    end)
    btn:Refresh()
    return btn
end

local function MakeMultiMenuButton(parent, width, getValues, isSelected, onToggle, getText)
    local btn = CreateFrame("Button", NextName("MultiMenu"), parent, "UIPanelButtonTemplate")
    btn:SetWidth(width); btn:SetHeight(22)
    function btn:Refresh()
        self:SetText(getText())
        if #getValues() > 0 then
            self:Enable()
        else
            self:Disable()
        end
    end
    btn:SetScript("OnClick", function(self)
        if activeMultiMenuButton == self then
            activeMultiMenuButton = nil
            self:SetScript("OnUpdate", nil)
            CloseDropDownMenus()
            return
        end
        local menu = {}
        for _, item in ipairs(getValues()) do
            local entry = {
                text = item.label,
                checked = isSelected(item.id),
                isNotRadio = true,
                keepShownOnClick = true,
                func = function()
                    onToggle(item.id)
                    self:Refresh()
                end,
            }
            if item.icon then
                entry.icon = "Interface\\Icons\\" .. item.icon
            end
            menu[#menu + 1] = entry
        end
        EasyMenu(menu, menuFrame, self, 0, 0, "MENU")
        activeMultiMenuButton = self
        self:SetScript("OnUpdate", function(button, elapsed)
            if IsFocusWithin(button) then
                button.outsideTime = 0
            else
                button.outsideTime = (button.outsideTime or 0) + elapsed
                if button.outsideTime >= 0.15 then
                    activeMultiMenuButton = nil
                    button.outsideTime = 0
                    button:SetScript("OnUpdate", nil)
                    CloseDropDownMenus()
                end
            end
        end)
    end)
    btn:Refresh()
    return btn
end

local function MakeCheck(parent, label, onClick)
    local name = NextName("Check")
    local c = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    _G[name .. "Text"]:SetText(label)
    c:SetScript("OnClick", function(self)
        if onClick then onClick(self:GetChecked() and true or false) end
    end)
    return c
end

local function MakeEdit(parent, width, numeric, maxLetters)
    local e = CreateFrame("EditBox", NextName("Edit"), parent, "InputBoxTemplate")
    e:SetWidth(width); e:SetHeight(20); e:SetAutoFocus(false)
    if numeric then e:SetNumeric(true) end
    if maxLetters then e:SetMaxLetters(maxLetters) end
    e:SetScript("OnEscapePressed", e.ClearFocus)
    e:SetScript("OnEnterPressed", e.ClearFocus)
    return e
end

local function MakeLabel(parent, text, x, y, template)
    local fs = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

local function MakeButton(parent, text, width, height)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetWidth(width); b:SetHeight(height or 24); b:SetText(text)
    return b
end

----------------------------------------------------------------------
-- Right side: group list
----------------------------------------------------------------------
local function ShowTooltip(row)
    local l = row.data
    if not l then return end
    local c = RAID_CLASS_COLORS[l.class] or { r = 1, g = 1, b = 1 }
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(ns.ListingTitle(l), 1, 0.82, 0, true)
    local roleMarkup = GetRoleMarkup(l.role)
    local who = {}
    if l.spec and l.spec ~= "Unknown" then who[#who + 1] = l.spec end
    if ROLE_TEXT[l.role] then who[#who + 1] = l.role end
    GameTooltip:AddLine(roleMarkup .. l.name .. (#who > 0 and ("  -  " .. table.concat(who, " ")) or ""),
        c.r, c.g, c.b)
    if l.source == "global" then
        GameTooltip:AddLine("Parsed from chat; details may be incomplete.", 0.7, 0.7, 0.7, true)
    end
    local raceName = ns.GetRaceName(l.race)
    if raceName then GameTooltip:AddDoubleLine("Race", raceName, 0.7, 0.7, 0.7, 1, 1, 1) end
    local partnerSpecs = ns.GetPartnerSpecNames(l)
    if #partnerSpecs > 0 then
        GameTooltip:AddLine("Looking for: |cff80d8ff" .. table.concat(partnerSpecs, ", ") .. "|r", 0.7, 0.9, 1, true)
    end
    GameTooltip:AddDoubleLine("Experience", ns.TIERS[l.tier] or "?", 0.7, 0.7, 0.7, 1, 1, 1)
    local gearScore = l.gsEstimate
        and (l.gsEstimate .. " (chat est.)")
        or (l.gs > 0 and tostring(l.gs) or "not set")
    GameTooltip:AddDoubleLine("Gearscore", gearScore, 0.7, 0.7, 0.7, 0.3, 1, 0.3)
    if l.teamKnown == false then
        GameTooltip:AddLine("Team status not detected from chat", 0.6, 0.6, 0.6)
    elseif l.hasTeam and l.teamRating > 0 then
        GameTooltip:AddDoubleLine(ns.TeamLabel(l.bracket), "Rating " .. l.teamRating, 0.7, 0.7, 0.7, 1, 0.82, 0)
    elseif l.hasTeam then
        GameTooltip:AddLine("Has a " .. ns.TeamLabel(l.bracket) .. " (rating not stated)", 0.2, 1, 0.2)
    else
        GameTooltip:AddLine("No " .. ns.TeamLabel(l.bracket) .. " yet", 0.6, 0.6, 0.6)
    end
    if l.seasonal then GameTooltip:AddLine("Seasonal character", 0, 0.85, 1) end
    if l.tenGames then GameTooltip:AddLine("Only wants 10 games (arena points)", 1, 0.82, 0) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cff888888Left-click: select   |   Right-click: options|r", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

local function RowClick(row, button)
    local l = row.data
    if not l then return end
    if button == "LeftButton" then
        ns.selected = l.name
        ns.RefreshAll()
        return
    end
    if l.name == UnitName("player") then
        EasyMenu({
            { text = l.name .. " (you)", isTitle = true, notCheckable = true },
            { text = "Edit group", notCheckable = true, func = function() ns.EditMine() end },
            { text = "Delist my group", notCheckable = true, func = function() ns.RemoveMine() end },
            { text = "Cancel", notCheckable = true },
        }, menuFrame, "cursor", 0, 0, "MENU")
    else
        EasyMenu({
            { text = l.name, isTitle = true, notCheckable = true },
            { text = "Whisper", notCheckable = true, func = function() ChatFrame_SendTell(l.name) end },
            { text = "Invite to group", notCheckable = true, func = function() InviteUnit(l.name) end },
            { text = "Cancel", notCheckable = true },
        }, menuFrame, "cursor", 0, 0, "MENU")
    end
end

local function BuildRow(parent, i)
    local row = CreateFrame("Button", nil, parent)
    row:SetWidth(508); row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -64 - (i - 1) * ROW_H)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetTexture(1, 1, 1, (i % 2 == 0) and 0.025 or 0.055)

    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    local hl = row:GetHighlightTexture()
    if hl then
        hl:SetVertexColor(1, 1, 1)
        hl:SetAlpha(0.12)
    end

    row.sel = row:CreateTexture(nil, "BACKGROUND")
    row.sel:SetAllPoints()
    row.sel:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row.sel:SetBlendMode("ADD")
    row.sel:SetVertexColor(0.2, 0.45, 0.85)
    row.sel:SetAlpha(0.25)
    row.sel:Hide()

    row.selIndicator = row:CreateTexture(nil, "OVERLAY")
    row.selIndicator:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.selIndicator:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.selIndicator:SetWidth(3)
    row.selIndicator:SetTexture(1, 0.82, 0, 0.95)
    row.selIndicator:Hide()

    row.line = row:CreateTexture(nil, "BORDER")
    row.line:SetHeight(1)
    row.line:SetPoint("BOTTOMLEFT", 2, 0); row.line:SetPoint("BOTTOMRIGHT", -2, 0)
    row.line:SetTexture(1, 1, 1, 0.06)

    row.faction = row:CreateTexture(nil, "OVERLAY")
    row.faction:SetWidth(FACTION_SIZE); row.faction:SetHeight(FACTION_SIZE)
    row.faction:SetPoint("LEFT", row, "LEFT", 4, 0)

    row.title = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.title:SetPoint("TOPLEFT", 8, -5); row.title:SetWidth(330); row.title:SetHeight(14)
    row.title:SetJustifyH("LEFT")

    row.sub = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.sub:SetPoint("TOPLEFT", 8, -21); row.sub:SetWidth(300); row.sub:SetHeight(12)
    row.sub:SetJustifyH("LEFT")
    row.sub:SetTextColor(0.65, 0.65, 0.65)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetWidth(26); row.icon:SetHeight(26)
    row.icon:SetPoint("TOPRIGHT", -6, -6)

    row.iconBorder = row:CreateTexture(nil, "BORDER")
    row.iconBorder:SetPoint("TOPLEFT", row.icon, -1, 1)
    row.iconBorder:SetPoint("BOTTOMRIGHT", row.icon, 1, -1)
    row.iconBorder:SetTexture(0, 0, 0, 0.8)

    row.roleIcon = row:CreateTexture(nil, "ARTWORK")
    row.roleIcon:SetWidth(16); row.roleIcon:SetHeight(16)
    row.roleIcon:SetPoint("TOPRIGHT", -36, -6)

    row.role = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.role:SetPoint("RIGHT", row.roleIcon, "LEFT", -4, 0); row.role:SetWidth(50); row.role:SetHeight(14)
    row.role:SetJustifyH("RIGHT")

    row.status = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.status:SetPoint("TOPRIGHT", -36, -22); row.status:SetWidth(85); row.status:SetHeight(12)
    row.status:SetJustifyH("RIGHT")

    row.age = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.age:SetPoint("RIGHT", row.status, "LEFT", -8, 0); row.age:SetWidth(75); row.age:SetHeight(12)
    row.age:SetJustifyH("RIGHT")
    row.age:SetTextColor(0.65, 0.65, 0.65)

    row:SetScript("OnEnter", ShowTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", RowClick)
    return row
end

local STATUS_TEXT = {
    pending  = "|cffffff00Pending|r",
    invited  = "|cff00ff00Invited|r",
    declined = "|cffff4040Declined|r",
}

local function UpdateSignUp()
    local b = ns.frame.signup
    local l = ns.selected and ns.listings[ns.selected]
    if not l or l.name == UnitName("player") then
        b:SetText("Sign Up"); b:Disable()
        return
    end
    if l.source == "global" then
        b:SetText("Whisper")
        b:Enable()
        return
    end
    local st = ns.applied[l.name]
    if st == "pending" then b:SetText("Cancel Sign-Up"); b:Enable()
    elseif st == "invited" then b:SetText("Invited"); b:Disable()
    elseif st == "declined" then b:SetText("Declined"); b:Disable()
    else b:SetText("Sign Up"); b:Enable() end
end

local function FilterActive()
    local f = ns.DB.filters
    return f.role ~= "Any" or f.team ~= "Any" or f.seasonal ~= "Any" or f.tenGames
end

local function RefreshList()
    local f = ns.frame
    if not f then return end
    local list = ns.GetSorted()
    FauxScrollFrame_Update(f.scroll, #list, ROWS, ROW_H)
    f.scrollBar:Show()
    local offset = FauxScrollFrame_GetOffset(f.scroll)
    local me = UnitName("player")
    for i = 1, ROWS do
        local row, l = f.rows[i], list[i + offset]
        if l then
            row.data = l
            SetListingSpecIcon(row.icon, l)
            SetRoleIcon(row.roleIcon, l.role)
            local faction = ns.GetFaction(l.race)
            local textX = 8
            if faction and FACTION_COORDS[faction] then
                local tc = FACTION_COORDS[faction]
                row.faction:SetTexture("Interface\\TargetingFrame\\UI-PVP-" .. faction)
                row.faction:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
                row.faction:Show()
                textX = FACTION_TEXT_X
            else
                row.faction:Hide()
            end
            row.title:ClearAllPoints()
            row.title:SetPoint("TOPLEFT", textX, -5)
            row.title:SetWidth(330 - textX)
            row.sub:ClearAllPoints()
            row.sub:SetPoint("TOPLEFT", textX, -21)
            row.sub:SetWidth(300 - textX)
            local c = RAID_CLASS_COLORS[l.class] or { r = 1, g = 1, b = 1 }
            local namePart = string.format("|cff%02x%02x%02x%s|r",
                math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255), l.name)
            local listingTitle = ns.ListingTitle(l)
            row.title:SetText(FactionRaceMarkup(l.race) .. namePart .. "  |cffffffff" .. listingTitle .. "|r")

            local parts = {}
            if l.teamKnown == false then
                parts[#parts + 1] = "|cff888888Team ?|r"
            elseif l.hasTeam and l.teamRating > 0 then
                parts[#parts + 1] = "|cffffd100Team " .. l.teamRating .. "|r"
            elseif l.hasTeam then
                parts[#parts + 1] = "|cffffd100Has team|r"
            else
                parts[#parts + 1] = "|cff777777No team|r"
            end

            if l.gs > 0 then
                parts[#parts + 1] = "|cff55ff55GS " .. (l.gsEstimate or l.gs) .. "|r"
            end

            parts[#parts + 1] = "|cffaaaaaaExp:|r |cffcccccc" .. (ns.TIERS[l.tier] or "?") .. "|r"

            if l.seasonal then
                parts[#parts + 1] = "|cff00e5ff[Seasonal]|r"
            end
            if l.tenGames then
                parts[#parts + 1] = "|cffffaa00[10 Games]|r"
            end
            row.sub:SetText(table.concat(parts, "  "))

            local age = math.max(0, GetTime() - (l.listedAt or l.seen or GetTime()))
            local minutes = math.floor(age / 60)
            row.age:SetText(minutes == 0 and "just now"
                or (minutes == 1 and "1 min ago" or minutes .. " min ago"))
            row.role:SetText(RoleText(l.role))
            if l.name == me then
                row.status:SetText("|cff69f0ae[Your Group]|r")
            elseif l.source == "global" then
                row.status:SetText("|cff64b5f6[Chat Ad]|r")
            else
                local st = ns.applied[l.name]
                if st == "pending" then
                    row.status:SetText("|cffffd54f[Pending]|r")
                elseif st == "invited" then
                    row.status:SetText("|cff81c784[Invited]|r")
                elseif st == "declined" then
                    row.status:SetText("|cffe57373[Declined]|r")
                else
                    row.status:SetText("")
                end
            end
            if ns.selected == l.name then
                row.sel:Show()
                row.selIndicator:Show()
            else
                row.sel:Hide()
                row.selIndicator:Hide()
            end
            row:Show()
        else
            row.data = nil
            row:Hide()
        end
    end
    f.count:SetText(#list .. " group(s)")
    f.filterBtn:SetText(FilterActive() and "Filter *" or "Filter")
    UpdateSignUp()
end

local function OpenFilterMenu(anchor)
    local flt = ns.DB.filters
    local function title(t) return { text = t, isTitle = true, notCheckable = true } end
    local function opt(text, field, value)
        return { text = text, checked = (flt[field] == value),
            func = function() flt[field] = value; ns.RefreshAll() end }
    end
    local menu = { title("Role"), opt("Any", "role", "Any") }
    for _, r in ipairs(ns.ROLES) do tinsert(menu, opt(r, "role", r)) end
    tinsert(menu, title("Team"))
    tinsert(menu, opt("Any", "team", "Any"))
    tinsert(menu, opt("Has a team", "team", "Has team"))
    tinsert(menu, opt("No team", "team", "No team"))
    tinsert(menu, title("Character"))
    tinsert(menu, opt("Any", "seasonal", "Any"))
    tinsert(menu, opt("Seasonal", "seasonal", "Seasonal"))
    tinsert(menu, opt("Non-seasonal", "seasonal", "Non-seasonal"))
    tinsert(menu, title("Other"))
    tinsert(menu, { text = "10 games only", checked = flt.tenGames,
        func = function() flt.tenGames = not flt.tenGames; ns.RefreshAll() end })
    tinsert(menu, { text = "Reset filters", notCheckable = true, func = function()
        flt.role = "Any"; flt.team = "Any"; flt.seasonal = "Any"; flt.tenGames = false
        ns.RefreshAll()
    end })
    EasyMenu(menu, menuFrame, anchor, 0, 0, "MENU")
    anchor:SetScript("OnUpdate", function(button, elapsed)
        if IsFocusWithin(button) then
            button.outsideTime = 0
        else
            button.outsideTime = (button.outsideTime or 0) + elapsed
            if button.outsideTime >= 0.15 then
                button.outsideTime = 0
                button:SetScript("OnUpdate", nil)
                CloseDropDownMenus()
            end
        end
    end)
end

----------------------------------------------------------------------
-- Left side, view 1: my group (banner + applicants), like retail
----------------------------------------------------------------------
function ns.OpenShareMenu(anchor)
    local inParty = (GetNumPartyMembers() > 0) or (GetNumRaidMembers() > 0)
    local inInstance, instanceType = IsInInstance()
    local isArena = inInstance and (instanceType == "arena" or instanceType == "pvp")
    local channelName = ns.DB and ns.DB.globalChannel or "Global"
    local channelId = tonumber((GetChannelName(channelName))) or 0
    local targetName = UnitIsPlayer("target") and UnitName("target")

    if not (isArena or inParty) and not (targetName and targetName ~= UnitName("player")) then
        if channelId > 0 then
            ChatFrame_OpenChat("/" .. channelId .. " Know an arena partner? Tell them about ArenaLFG: https://warperia.com/addon-wotlk/arenalfg/")
        else
            ns.Print("Join your configured Global channel before sharing ArenaLFG.")
        end
        return
    end

    local menu = {
        { text = "Share ArenaLFG", isTitle = true, notCheckable = true },
    }

    if isArena or inParty then
        local label = isArena and "Party / Arena (SoloQ)" or "Party / Group"
        tinsert(menu, {
            text = label,
            notCheckable = true,
            func = function()
                ChatFrame_OpenChat("/p Looking for an arena partner? Get the ArenaLFG addon: https://warperia.com/addon-wotlk/arenalfg/")
            end,
        })
    end

    if channelId > 0 then
        tinsert(menu, {
            text = "Global (" .. channelName .. ")",
            notCheckable = true,
            func = function()
                ChatFrame_OpenChat("/" .. channelId .. " Know an arena partner? Tell them about ArenaLFG: https://warperia.com/addon-wotlk/arenalfg/")
            end,
        })
    end

    if targetName and targetName ~= UnitName("player") then
        tinsert(menu, {
            text = "Whisper " .. targetName,
            notCheckable = true,
            func = function()
                ChatFrame_OpenChat("/w " .. targetName .. " Know an arena partner? Check out ArenaLFG: https://warperia.com/addon-wotlk/arenalfg/")
            end,
        })
    end

    tinsert(menu, { text = "Cancel", notCheckable = true })
    EasyMenu(menu, menuFrame, anchor or "cursor", 0, 0, "MENU")
end

local function BuildGroupView(parent, f)
    local g = CreateFrame("Frame", nil, parent)
    g:SetAllPoints(parent)
    local w = {}
    f.groupW = w

    local ban = CreateFrame("Frame", nil, g)
    ban:SetPoint("TOPLEFT", 8, -8)
    ban:SetWidth(276); ban:SetHeight(92)
    ban:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    ban:SetBackdropColor(0.06, 0.08, 0.12, 0.95)
    ban:SetBackdropBorderColor(0.4, 0.45, 0.55, 0.85)

    w.name = ban:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    w.name:SetPoint("TOPLEFT", 8, -8); w.name:SetWidth(150); w.name:SetHeight(14)
    w.name:SetJustifyH("LEFT")

    w.icon = ban:CreateTexture(nil, "ARTWORK")
    w.icon:SetWidth(24); w.icon:SetHeight(24)
    w.icon:SetPoint("TOPRIGHT", -8, -8)

    w.iconBorder = ban:CreateTexture(nil, "BORDER")
    w.iconBorder:SetPoint("TOPLEFT", w.icon, -1, 1)
    w.iconBorder:SetPoint("BOTTOMRIGHT", w.icon, 1, -1)
    w.iconBorder:SetTexture(0, 0, 0, 0.8)

    w.roleIcon = ban:CreateTexture(nil, "ARTWORK")
    w.roleIcon:SetWidth(16); w.roleIcon:SetHeight(16)
    w.roleIcon:SetPoint("TOPRIGHT", -36, -8)

    w.role = ban:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    w.role:SetPoint("RIGHT", w.roleIcon, "LEFT", -4, 0); w.role:SetWidth(50); w.role:SetHeight(12)
    w.role:SetJustifyH("RIGHT")

    w.title = ban:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    w.title:SetPoint("TOPLEFT", 8, -27); w.title:SetWidth(258); w.title:SetHeight(14)
    w.title:SetJustifyH("LEFT")

    w.sub = ban:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    w.sub:SetPoint("TOPLEFT", 8, -46); w.sub:SetWidth(260); w.sub:SetHeight(12)
    w.sub:SetJustifyH("LEFT")

    w.info = ban:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    w.info:SetPoint("TOPLEFT", 8, -62); w.info:SetWidth(260); w.info:SetHeight(12)
    w.info:SetJustifyH("LEFT")

    w.announceStatus = ban:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    w.announceStatus:SetPoint("TOPLEFT", 8, -78); w.announceStatus:SetWidth(258); w.announceStatus:SetHeight(12)
    w.announceStatus:SetJustifyH("LEFT")

    -- column headers
    local function Col(text, x)
        local fs = g:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", x, -108); fs:SetText(text)
    end
    Col("Applicant", 12); Col("Role", 112); Col("GS", 160)

    w.rows = {}
    for i = 1, APP_ROWS do
        local r = CreateFrame("Frame", nil, g)
        r:SetWidth(276); r:SetHeight(APP_H)
        r:SetPoint("TOPLEFT", g, "TOPLEFT", 8, -124 - (i - 1) * APP_H)

        r.bg = r:CreateTexture(nil, "BACKGROUND")
        r.bg:SetAllPoints()
        r.bg:SetTexture(1, 1, 1, (i % 2 == 0) and 0.025 or 0.05)

        r.specIcon = r:CreateTexture(nil, "ARTWORK")
        r.specIcon:SetWidth(18); r.specIcon:SetHeight(18)
        r.specIcon:SetPoint("LEFT", 4, 0)
        r.specIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        local function FS(x, width)
            local fs = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            fs:SetPoint("LEFT", x, 0); fs:SetWidth(width); fs:SetHeight(12)
            fs:SetJustifyH("LEFT")
            return fs
        end
        r.name = FS(26, 72)

        r.roleIcon = r:CreateTexture(nil, "ARTWORK")
        r.roleIcon:SetWidth(14); r.roleIcon:SetHeight(14)
        r.roleIcon:SetPoint("LEFT", 100, 0)

        r.role = FS(116, 40)
        r.gs   = FS(160, 36)
        r.invite = MakeButton(r, "Invite", 44, 20)
        r.invite:SetPoint("LEFT", 198, 0)
        r.invite:SetText("|cff55ff55Invite|r")
        r.decline = MakeButton(r, "X", 22, 20)
        r.decline:SetPoint("LEFT", 246, 0)
        r.decline:SetText("|cffff5555X|r")
        r.invite:SetScript("OnClick", function() if r.who then ns.InviteApplicant(r.who) end end)
        r.decline:SetScript("OnClick", function() if r.who then ns.DeclineApplicant(r.who) end end)

        r:EnableMouse(true)
        r:SetScript("OnEnter", function(self)
            if not self.applicantData then return end
            local a = self.applicantData
            local c = RAID_CLASS_COLORS[a.class] or { r = 1, g = 1, b = 1 }
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(a.name, c.r, c.g, c.b)
            local roleMarkup = GetRoleMarkup(a.role)
            local spec = a.spec ~= "Unknown" and a.spec or ""
            GameTooltip:AddLine(roleMarkup .. strtrim(spec .. " " .. (ROLE_TEXT[a.role] and a.role or "")),
                0.9, 0.9, 0.9)
            if a.gs and a.gs > 0 then
                GameTooltip:AddDoubleLine("GearScore", tostring(a.gs), 0.7, 0.7, 0.7, 0.3, 1, 0.3)
            end
            if a.teamRating and a.teamRating > 0 then
                GameTooltip:AddDoubleLine(ns.TeamLabel(a.bracket), tostring(a.teamRating), 0.7, 0.7, 0.7, 1, 0.82, 0)
            end
            if a.tier and ns.TIERS[a.tier] then
                GameTooltip:AddDoubleLine("Experience", ns.TIERS[a.tier], 0.7, 0.7, 0.7, 1, 1, 1)
            end
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)

        r:Hide()
        w.rows[i] = r
    end

    w.empty = g:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    w.empty:SetPoint("TOP", g, "TOP", 0, -166)
    w.empty:SetText("No sign-ups yet.")

    w.sync = g:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    w.sync:SetPoint("BOTTOMLEFT", 12, 42)

    w.delist = MakeButton(g, "Delist My Group", 112, 24)
    w.delist:SetPoint("BOTTOMLEFT", 8, 10)
    w.delist:SetScript("OnClick", function() ns.RemoveMine() end)
    w.edit = MakeButton(g, "Edit", 64, 24)
    w.edit:SetPoint("BOTTOMRIGHT", -8, 10)
    w.edit:SetScript("OnClick", function() ns.EditMine() end)

    return g
end

local function RefreshGroupView()
    local f = ns.frame
    if not f or not f.groupView:IsShown() then return end
    local w = f.groupW
    local me = ns.MyListing()
    if not me then return end

    local c = RAID_CLASS_COLORS[me.class] or { r = 1, g = 1, b = 1 }
    w.name:SetText(FactionRaceMarkup(me.race) .. string.format("|cff%02x%02x%02x%s|r",
        math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255), me.name))
    SetRoleIcon(w.roleIcon, me.role)
    w.role:SetText(RoleText(me.role))
    w.title:SetText(ns.ListingTitle(me))
    w.sub:SetText("|cffaaaaaaExp:|r |cffcccccc" .. (ns.TIERS[me.tier] or "?") .. "|r   "
        .. (me.hasTeam and ("|cffffd100Team " .. me.teamRating .. "|r") or "|cff777777No team|r"))
    local info = { "|cffffffff" .. me.bracket .. "|r" }
    if me.gs > 0 then info[#info + 1] = "|cff55ff55GS " .. me.gs .. "|r" end
    if me.seasonal then info[#info + 1] = "|cff00e5ffSeasonal|r" end
    if me.tenGames then info[#info + 1] = "|cffffaa0010 Games|r" end
    local ownListing = ns.listings[me.name]
    local listedAt = ownListing and ownListing.listedAt
    local age = listedAt and math.max(0, GetTime() - listedAt) or 0
    local minutes = math.floor(age / 60)
    info[#info + 1] = "|cff888888" .. (minutes == 0 and "just now"
        or (minutes == 1 and "1 min ago" or minutes .. " min ago")) .. "|r"
    w.info:SetText(table.concat(info, "   "))
    w.announceStatus:SetText(ns.GetAnnounceStatus and ns.GetAnnounceStatus() or "")
    SetSpecIcon(w.icon, me.class)

    local list = {}
    for _, l in pairs(ns.applicants) do list[#list + 1] = l end
    table.sort(list, function(a, b) return (a.order or 0) < (b.order or 0) end)
    for i = 1, APP_ROWS do
        local r, l = w.rows[i], list[i]
        if l then
            r.applicantData = l
            local c = RAID_CLASS_COLORS[l.class] or { r = 1, g = 1, b = 1 }
            r.who = l.name
            r.name:SetText(l.name)
            r.name:SetTextColor(c.r, c.g, c.b)
            SetListingSpecIcon(r.specIcon, l)
            SetRoleIcon(r.roleIcon, l.role)
            r.role:SetText(RoleText(l.role))
            r.gs:SetText(l.gs > 0 and ("|cff55ff55" .. l.gs .. "|r") or "|cff777777-|r")
            r:Show()
        else
            r.applicantData = nil
            r.who = nil
            r:Hide()
        end
    end
    if #list == 0 then w.empty:Show() else w.empty:Hide() end
    if ns.Comm_IsJoined() then
        w.sync:SetText("|cff00ff00Visible to other ArenaLFG users.|r")
    else
        w.sync:SetText("|cffffff00Not synced (sync channel not joined).|r")
    end
end

function ns.RefreshAll()
    if not ns.frame or not ns.frame:IsShown() then return end
    RefreshList()
    RefreshGroupView()
end

ns.Every(60, function()
    if ns.frame and ns.frame:IsShown() then
        RefreshList()
        RefreshGroupView()
    end
end)

----------------------------------------------------------------------
-- Left side, view 2: list / edit my group (the form)
----------------------------------------------------------------------
local function BuildFormView(parent, f)
    local p = CreateFrame("Frame", nil, parent)
    p:SetAllPoints(parent)
    local m = ns.mine
    local w = {}
    f.mineWidgets = w

    w.header = MakeLabel(p, "List your group", 12, -10)
    w.char = MakeLabel(p, "", 12, -32, "GameFontHighlight")
    w.char:SetWidth(266); w.char:SetJustifyH("LEFT")

    MakeLabel(p, "Detected role", 12, -62)
    w.detectedRoleIcon = p:CreateTexture(nil, "ARTWORK")
    w.detectedRoleIcon:SetWidth(16); w.detectedRoleIcon:SetHeight(16)
    w.detectedRoleIcon:SetPoint("TOPLEFT", 100, -60)
    w.detectedRole = p:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    w.detectedRole:SetPoint("LEFT", w.detectedRoleIcon, "RIGHT", 4, 0)

    MakeLabel(p, "Seeking", 12, -92)
    w.targetRole = MakeMenuButton(p, 86,
        function() return ns.PARTNER_ROLES end,
        function() return m.targetRole end,
        function(v)
            m.targetRole = v
            if v == "Any" then m.targetAny = false end
            w.targetSpecs:Refresh()
        end)
    w.targetRole:SetPoint("TOPLEFT", 100, -88)
    w.targetSpecs = MakeMultiMenuButton(p, 100,
        function()
            local specs = {}
            for _, spec in ipairs(ns.PARTNER_SPECS) do
                if spec.role == m.targetRole then specs[#specs + 1] = spec end
            end
            if m.targetRole ~= "Any" then
                table.insert(specs, 1, { id = "ANY", label = "Any spec" })
            end
            return specs
        end,
        function(id)
            if id == "ANY" then return m.targetAny end
            return not m.targetAny and m.targetSpecs[id] and true or false
        end,
        function(id)
            if id == "ANY" then
                m.targetAny = not m.targetAny
                if m.targetAny then wipe(m.targetSpecs) end
            else
                m.targetAny = false
                if m.targetSpecs[id] then m.targetSpecs[id] = nil
                else m.targetSpecs[id] = true end
            end
        end,
        function()
            if m.targetRole == "Any" then return "Choose role" end
            if m.targetAny then return "Any spec" end
            local count = #ns.GetPartnerSpecNames({ targetRole = m.targetRole, targetSpecs = m.targetSpecs })
            return count > 0 and ("Specs (" .. count .. ")") or "Select specs"
        end)
    w.targetSpecs:SetPoint("TOPLEFT", 188, -88)

    MakeLabel(p, "Gearscore", 12, -122)
    w.gs = MakeEdit(p, 70, true, 5)
    w.gs:SetPoint("TOPLEFT", 108, -118)

    w.team = MakeCheck(p, "I have a 2v2 team")
    w.team:SetPoint("TOPLEFT", 6, -144)
    w.team:Disable() -- read from the game, not editable
    w.rating = p:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    w.rating:SetPoint("LEFT", _G[w.team:GetName() .. "Text"], "RIGHT", 8, 0)

    w.detect = p:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    w.detect:SetPoint("TOPLEFT", 12, -174)
    w.detect:SetWidth(268); w.detect:SetHeight(34)
    w.detect:SetJustifyH("LEFT"); w.detect:SetJustifyV("TOP")

    MakeLabel(p, "Experience", 12, -212)
    w.tier = MakeMenuButton(p, 150,
        function() return ns.TIERS end,
        function() return ns.TIERS[m.tier] end,
        function(v)
            for i, t in ipairs(ns.TIERS) do if t == v then m.tier = i end end
        end)
    w.tier:SetPoint("TOPLEFT", 100, -208)

    w.seasonal = MakeCheck(p, "Seasonal character", function(on) m.seasonal = on end)
    w.seasonal:SetPoint("TOPLEFT", 6, -236)
    w.ten = MakeCheck(p, "10 games only (arena points)", function(on) m.tenGames = on end)
    w.ten:SetPoint("TOPLEFT", 6, -262)

    MakeLabel(p, "Group title / comp (optional)", 12, -298)
    w.note = MakeEdit(p, 256, false, 60)
    w.note:SetPoint("TOPLEFT", 16, -318)

    w.post = MakeButton(p, "List Group", 124, 24)
    w.post:SetPoint("TOPLEFT", 12, -352)
    w.post:SetScript("OnClick", function() ns.PostMine() end)
    w.back = MakeButton(p, "Back", 124, 24)
    w.back:SetPoint("LEFT", w.post, "RIGHT", 6, 0)
    w.back:SetScript("OnClick", function() ns.SaveMine(); f.editing = false; UpdateLeft() end)

    return p
end

function ns.UI_LoadMine()
    local f = ns.frame
    if not f then return end
    local m, w = ns.mine, f.mineWidgets
    local info = ns.DetectMine()

    local c = RAID_CLASS_COLORS[ns.GetMyClass()] or { r = 1, g = 1, b = 1 }
    w.char:SetText(UnitName("player") .. "  -  " .. (UnitClass("player")) .. ", " .. ns.GetMySpec())
    w.char:SetTextColor(c.r, c.g, c.b)
    SetRoleIcon(w.detectedRoleIcon, m.role)
    w.detectedRole:SetText(ROLE_TEXT[m.role] or m.role)
    w.tier:Refresh(); w.targetRole:Refresh(); w.targetSpecs:Refresh()
    w.gs:SetText(m.gs > 0 and m.gs or "")
    w.gs:EnableMouse(not info.gs)
    w.gs:EnableKeyboard(not info.gs)
    if info.gs then
        w.gs:ClearFocus()
        w.gs:SetTextColor(0.5, 0.5, 0.5)
    else
        w.gs:SetTextColor(1, 1, 1)
    end
    w.header:SetText("List your group (" .. m.bracket .. ")")
    _G[w.team:GetName() .. "Text"]:SetText("I have a " .. ns.TeamLabel(m.bracket))
    w.team:SetChecked(m.hasTeam)
    w.rating:SetText(m.hasTeam and ("|cffffd100(Rating: " .. m.teamRating .. ")|r") or "")
    w.seasonal:SetChecked(m.seasonal)
    w.ten:SetChecked(m.tenGames)
    w.note:SetText(m.note or "")

    local txt = (info.team and (ns.TeamLabel(m.bracket) .. " \"" .. info.team .. "\" found") or ("No " .. ns.TeamLabel(m.bracket) .. " found on this character"))
        .. (info.gs and "; gearscore read from your GearScore addon."
            or "; GearScore API unavailable; gearscore is self-reported.")
    w.detect:SetText((info.team and "|cff00ff00" or "|cff999999") .. txt .. "|r")

    w.post:SetText(m.posted and "Update Listing" or "List Group")
    if m.posted then w.back:Show() else w.back:Hide() end
end

function ns.SaveMine()
    local f = ns.frame
    if not f then return end
    local m, w = ns.mine, f.mineWidgets
    m.gs = tonumber(w.gs:GetText()) or 0
    m.note = (w.note:GetText():gsub("|", "/"))
end

----------------------------------------------------------------------
-- State changes
----------------------------------------------------------------------
-- Show the group view when listed (and not editing), the form otherwise
function UpdateLeft()
    local f = ns.frame
    if not f then return end
    if ns.mine.posted and not f.editing then
        f.mine:Hide()
        f.groupView:Show()
        RefreshGroupView()
    else
        f.groupView:Hide()
        f.mine:Show()
        ns.UI_LoadMine()
    end
end

-- Switch the browser tab; with no listing posted the form follows the tab
function ns.SetViewBracket(bracket)
    local f = ns.frame
    ns.viewBracket = ns.NormalizeBracket(bracket)
    if not ns.mine.posted then
        if f and f.mine:IsShown() then ns.SaveMine() end
        ns.mine.bracket = ns.viewBracket
    end
    ns.selected = nil
    if f then
        for b, tab in pairs(f.tabs) do
            if b == ns.viewBracket then tab:LockHighlight() else tab:UnlockHighlight() end
        end
        UpdateLeft()
    end
    ns.Changed()
end

function ns.PostMine()
    if ns.InGroup() then
        ns.Print("You are already in a group. Leave it before listing your group.")
        return
    end
    ns.SaveMine()
    if ns.mine.targetRole ~= "Any" and not ns.mine.targetAny
        and #ns.GetPartnerSpecNames(ns.mine) == 0 then
        ns.Print("Select at least one preferred partner spec, choose Any spec, or set Seeking to Any.")
        return
    end
    ns.mine.posted = true
    ns.mine.postedAt = time()
    ns.frame.editing = false
    ns.AddListing(ns.MyListing())
    UpdateLeft()          -- update the UI first, so a sync problem can never leave it stale
    ns.Broadcast()
    ns.TryAnnounceMine()
end

function ns.EditMine()
    if not ns.frame then return end
    ns.frame.editing = true
    ns.frame:Show()
    UpdateLeft()
end

function ns.RemoveMine()
    ns.mine.posted = false
    ns.mine.postedAt = nil
    for name in pairs(ns.applicants) do
        pcall(SendAddonMessage, ns.PREFIX, "DEC", "WHISPER", name)
    end
    wipe(ns.applicants)
    ns.RemoveListing(UnitName("player"))
    ns.BroadcastRemove()
    if ns.frame then
        ns.frame.editing = false
        UpdateLeft()
    end
end

----------------------------------------------------------------------
-- Main window
----------------------------------------------------------------------
function ns.BuildUI()
    local f = CreateFrame("Frame", "ArenaLFGFrame", UIParent)
    f:Hide()
    f:SetWidth(880); f:SetHeight(510)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:SetBackdropColor(0.07, 0.07, 0.09, 0.98)
    f:SetMovable(true); f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    tinsert(UISpecialFrames, "ArenaLFGFrame") -- closes with Esc
    ns.frame = f

    local header = f:CreateTexture(nil, "ARTWORK")
    header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    header:SetWidth(300); header:SetHeight(64)
    header:SetPoint("TOP", 0, 12)
    local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOP", header, "TOP", 0, -14)
    title:SetText("ArenaLFG")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    -- Left panel: my group
    local left = MakePanel(f, 292, 418)
    left:SetPoint("TOPLEFT", 18, -44)
    f.left = left
    f.mine = BuildFormView(left, f)
    f.groupView = BuildGroupView(left, f)
    f.mine:Hide(); f.groupView:Hide()

    -- Right panel: groups
    local right = MakePanel(f, 544, 418)
    right:SetPoint("TOPLEFT", 318, -44)
    f.right = right

    f.tabs = {}
    for i, bracket in ipairs(ns.BRACKETS) do
        local tab = MakeButton(right, bracket, 66, 22)
        tab:SetPoint("TOPLEFT", 10 + (i - 1) * 70, -8)
        tab:SetScript("OnClick", function() ns.SetViewBracket(bracket) end)
        f.tabs[bracket] = tab
    end
    local share = MakeButton(f, "Share ArenaLFG", 110, 20)
    share:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 24, 18)
    share:SetScript("OnClick", function(self) ns.OpenShareMenu(self) end)

    local options = MakeButton(f, "Options", 70, 20)
    options:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -24, 18)
    options:SetScript("OnClick", function() ns.OpenOptions() end)

    local version = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    version:SetPoint("RIGHT", options, "LEFT", -8, 0)
    version:SetText("v" .. ns.VERSION)

    local listedHeader = MakeLabel(right, "Listed", 216, -55, "GameFontDisableSmall")
    listedHeader:SetWidth(80)
    listedHeader:SetJustifyH("RIGHT")

    local refresh = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
    refresh:SetWidth(64); refresh:SetHeight(22)
    refresh:SetPoint("TOPRIGHT", -10, -8)
    refresh:SetText("Refresh")
    refresh:SetScript("OnClick", function()
        local sent, wait = ns.Comm_Request()
        if sent then
            ns.RefreshAll()
        elseif wait then
            ns.Print("Please wait " .. wait .. " seconds before refreshing again.")
        else
            ns.Print("Not connected to the sync channel. Run /alfg comm to retry joining.")
        end
    end)
    refresh:SetScript("OnUpdate", function(self, elapsed)
        self.tick = (self.tick or 0) + elapsed
        if self.tick < 0.4 then return end
        self.tick = 0
        local cd = ns.Comm_GetCooldown and ns.Comm_GetCooldown() or 0
        if cd > 0 then
            self:SetText(cd .. "s")
            self:Disable()
        else
            if self:GetText() ~= "Refresh" then
                self:SetText("Refresh")
                self:Enable()
            end
        end
    end)
    refresh:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Refresh listings")
        local cd = ns.Comm_GetCooldown and ns.Comm_GetCooldown() or 0
        if cd > 0 then
            GameTooltip:AddLine("Cooldown: " .. cd .. "s", 1, 0.8, 0)
        else
            GameTooltip:AddLine("Query channel for active listings", 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)
    refresh:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Search box with placeholder & clear button
    local search = MakeEdit(right, 355, false, 40)
    search:SetPoint("TOPLEFT", 14, -34)
    local ph = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ph:SetPoint("LEFT", 4, 0)
    ph:SetText("Search name, spec or title...")

    local clearBtn = CreateFrame("Button", nil, search)
    clearBtn:SetWidth(16); clearBtn:SetHeight(16)
    clearBtn:SetPoint("RIGHT", search, "RIGHT", -4, 0)
    local clearText = clearBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    clearText:SetPoint("CENTER", 0, 0)
    clearText:SetText("|cffaaaaaaX|r")
    clearBtn:SetScript("OnEnter", function() clearText:SetText("|cffff5555X|r") end)
    clearBtn:SetScript("OnLeave", function() clearText:SetText("|cffaaaaaaX|r") end)
    clearBtn:SetScript("OnClick", function()
        search:SetText("")
        search:ClearFocus()
        ns.search = ""
        clearBtn:Hide()
        ph:Show()
        RefreshList()
    end)
    clearBtn:Hide()

    local function UpdateSearchState(self)
        local txt = self:GetText() or ""
        if txt == "" then
            clearBtn:Hide()
            if not self:HasFocus() then ph:Show() else ph:Hide() end
        else
            clearBtn:Show()
            ph:Hide()
        end
    end
    search:SetScript("OnTextChanged", function(self)
        ns.search = strlower(self:GetText() or "")
        UpdateSearchState(self)
        RefreshList()
    end)
    search:SetScript("OnEditFocusGained", function(self) ph:Hide() end)
    search:SetScript("OnEditFocusLost", UpdateSearchState)

    f.filterBtn = MakeButton(right, "Filter", 90, 22)
    f.filterBtn:SetPoint("LEFT", search, "RIGHT", 8, 0)
    f.filterBtn:SetScript("OnClick", function(self) OpenFilterMenu(self) end)

    -- Scrolling list
    local sf = CreateFrame("ScrollFrame", "ArenaLFGScroll", right, "FauxScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", right, "TOPLEFT", 8, -64)
    sf:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", -28, 44)
    sf:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, RefreshList)
    end)
    f.scroll = sf
    f.scrollBar = _G["ArenaLFGScrollScrollBar"]
    f.rows = {}
    for i = 1, ROWS do f.rows[i] = BuildRow(right, i) end

    f.count = right:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    f.count:SetPoint("BOTTOMLEFT", 14, 18)

    f.signup = MakeButton(right, "Sign Up", 150, 24)
    f.signup:SetPoint("BOTTOMRIGHT", -12, 12)
    f.signup:SetScript("OnClick", function()
        local l = ns.selected and ns.listings[ns.selected]
        if not l then return end
        if l.source == "global" then
            ChatFrame_SendTell(l.name)
        elseif ns.applied[l.name] == "pending" then
            ns.CancelApply(l)
        else
            ns.Apply(l)
        end
    end)

    f:SetScript("OnShow", function()
        f:SetFrameStrata("DIALOG")
        f:SetToplevel(true)
        f:Raise()
        ns.RequestArenaData()
        ns.SetViewBracket(ns.viewBracket or ns.mine.bracket)
    end)
    f:SetScript("OnHide", function()
        if f.mine:IsShown() then ns.SaveMine() end -- do not lose unsaved edits
    end)
    return f
end

function ns.ToggleUI()
    if not ns.frame then ns.BuildUI() end
    if ns.frame:IsShown() then ns.frame:Hide() else ns.frame:Show() end
end

function ns.ShowUIAtPVP()
    if not ns.frame then ns.BuildUI() end

    local anchor = PVPParentFrame
    if not anchor or not anchor:IsVisible() then anchor = PVPFrame end
    if not anchor or not anchor:IsVisible() then
        ns.frame:Hide()
        return
    end

    local f = ns.frame
    local anchorLeft, anchorRight, anchorTop = anchor:GetLeft(), anchor:GetRight(), anchor:GetTop()
    if not anchorLeft or not anchorRight or not anchorTop then
        f:ClearAllPoints()
        f:SetPoint("CENTER")
        f:Show()
        return
    end

    local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
    local width, height = f:GetWidth(), f:GetHeight()
    local gap = 12
    local leftSpace = anchorLeft
    local rightSpace = screenWidth - anchorRight
    local x
    if rightSpace >= width + gap or rightSpace >= leftSpace then
        x = anchorRight + gap
    else
        x = anchorLeft - width - gap
    end
    x = math.max(0, math.min(x, screenWidth - width))

    local y = screenHeight - anchorTop
    y = math.max(0, math.min(y, screenHeight - height))

    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, -y)
    f:Show()
end

local pvpToggleHooked, pvpDetailsHooked = false, false
local pvpOpenedArenaLFG = false

function ns.SetPVPIntegration(enabled)
    ns.DB.pvpIntegration = enabled and true or false
    if ns.frame and ns.frame.pvpCheck then
        ns.frame.pvpCheck:SetChecked(ns.DB.pvpIntegration)
    end
    if ns.DB.pvpIntegration then
        local anchor = PVPParentFrame
        if not anchor or not anchor:IsVisible() then anchor = PVPFrame end
        if anchor and anchor:IsVisible() then
            ns.ShowUIAtPVP()
            pvpOpenedArenaLFG = ns.frame and ns.frame:IsShown() or false
        end
    elseif pvpOpenedArenaLFG and ns.frame then
        ns.frame:Hide()
        pvpOpenedArenaLFG = false
    end
end

local function InstallPVPFrameHooks()
    if not pvpToggleHooked and type(TogglePVPFrame) == "function" then
        hooksecurefunc("TogglePVPFrame", function()
            if not (ns.DB and ns.DB.pvpIntegration) then return end
            local anchor = PVPParentFrame
            if not anchor or not anchor:IsVisible() then anchor = PVPFrame end
            if anchor and anchor:IsVisible() then
                ns.ShowUIAtPVP()
                pvpOpenedArenaLFG = ns.frame and ns.frame:IsShown() or false
            elseif pvpOpenedArenaLFG and ns.frame then
                ns.frame:Hide()
                pvpOpenedArenaLFG = false
            end
        end)
        pvpToggleHooked = true
    end

    if not pvpDetailsHooked and PVPTeamDetails then
        hooksecurefunc(PVPTeamDetails, "Show", function(details)
            if not (ns.DB and ns.DB.pvpIntegration) or not ns.frame or not ns.frame:IsShown() then return end
            details:SetFrameStrata(ns.frame:GetFrameStrata())
            details:SetFrameLevel(math.max(details:GetFrameLevel(), ns.frame:GetFrameLevel() + 1))
        end)
        pvpDetailsHooked = true
    end

    return pvpToggleHooked and pvpDetailsHooked
end

local pvpHookFrame = CreateFrame("Frame")
pvpHookFrame:RegisterEvent("ADDON_LOADED")
pvpHookFrame:RegisterEvent("PLAYER_LOGIN")
pvpHookFrame:SetScript("OnEvent", function(self)
    if InstallPVPFrameHooks() then self:UnregisterAllEvents() end
end)
if InstallPVPFrameHooks() then pvpHookFrame:UnregisterAllEvents() end
