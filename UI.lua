local ADDON, ns = ...

local ROW_H, ROWS = 38, 8
local APP_H, APP_ROWS = 26, 8
local CLASS_TEX = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local menuFrame = CreateFrame("Frame", "ArenaLFGMenuFrame", UIParent, "UIDropDownMenuTemplate")
local UpdateLeft -- forward declaration

local ROLE_TEXT = {
    DPS    = "|cffff6060DPS|r",
    Healer = "|cff40ff40Healer|r",
    Tank   = "|cff60a0ffTank|r",
}

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
    p:SetBackdropColor(0, 0, 0, 0.6)
    p:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    return p
end

local function SetClassIcon(tex, class)
    tex:SetTexture(CLASS_TEX)
    local tc = CLASS_ICON_TCOORDS[class]
    if tc then tex:SetTexCoord(unpack(tc)) end
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
    GameTooltip:AddLine(l.name .. " - " .. l.spec .. " " .. l.role, c.r, c.g, c.b)
    GameTooltip:AddLine("Experience: " .. (ns.TIERS[l.tier] or "?"), 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Gearscore: " .. (l.gs > 0 and l.gs or "not set"), 0.8, 0.8, 0.8)
    if l.hasTeam then
        GameTooltip:AddLine("Has a 2v2 team, rating " .. l.teamRating, 0.2, 1, 0.2)
    else
        GameTooltip:AddLine("No team yet", 0.8, 0.8, 0.8)
    end
    if l.seasonal then GameTooltip:AddLine("Seasonal character", 0, 0.8, 1) end
    if l.tenGames then GameTooltip:AddLine("Only wants 10 games (arena points)", 1, 0.82, 0) end
    GameTooltip:AddLine("Left-click: select. Right-click: menu.", 0.5, 0.5, 0.5)
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
    row:SetWidth(408); row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -64 - (i - 1) * ROW_H)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    row.sel = row:CreateTexture(nil, "BACKGROUND")
    row.sel:SetAllPoints()
    row.sel:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row.sel:SetBlendMode("ADD")
    row.sel:SetVertexColor(1, 0.82, 0)
    row.sel:SetAlpha(0.5)
    row.sel:Hide()

    row.line = row:CreateTexture(nil, "BORDER")
    row.line:SetHeight(1)
    row.line:SetPoint("BOTTOMLEFT"); row.line:SetPoint("BOTTOMRIGHT")
    row.line:SetTexture(1, 1, 1, 0.08)

    row.title = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.title:SetPoint("TOPLEFT", 8, -5); row.title:SetWidth(300); row.title:SetHeight(14)
    row.title:SetJustifyH("LEFT")

    row.sub = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.sub:SetPoint("TOPLEFT", 8, -21); row.sub:SetWidth(300); row.sub:SetHeight(12)
    row.sub:SetJustifyH("LEFT")
    row.sub:SetTextColor(0.65, 0.65, 0.65)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetWidth(24); row.icon:SetHeight(24)
    row.icon:SetPoint("TOPRIGHT", -6, -7)

    row.role = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.role:SetPoint("TOPRIGHT", -36, -6); row.role:SetWidth(60); row.role:SetHeight(12)
    row.role:SetJustifyH("RIGHT")

    row.status = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.status:SetPoint("TOPRIGHT", -36, -21); row.status:SetWidth(80); row.status:SetHeight(12)
    row.status:SetJustifyH("RIGHT")

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
    local offset = FauxScrollFrame_GetOffset(f.scroll)
    local me = UnitName("player")
    for i = 1, ROWS do
        local row, l = f.rows[i], list[i + offset]
        if l then
            row.data = l
            SetClassIcon(row.icon, l.class)
            row.title:SetText(ns.ListingTitle(l))
            local sub = "Arena (2v2)   " .. (l.hasTeam and ("Team " .. l.teamRating) or "No team")
            if l.gs > 0 then sub = sub .. "   GS " .. l.gs end
            if l.seasonal then sub = sub .. "   Seasonal" end
            if l.tenGames then sub = sub .. "   10 games" end
            row.sub:SetText(sub)
            row.role:SetText(ROLE_TEXT[l.role] or l.role)
            if l.name == me then
                row.status:SetText("|cff00ff00Your group|r")
            else
                row.status:SetText(STATUS_TEXT[ns.applied[l.name]] or "")
            end
            if ns.selected == l.name then row.sel:Show() else row.sel:Hide() end
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
end

----------------------------------------------------------------------
-- Left side, view 1: my group (banner + applicants), like retail
----------------------------------------------------------------------
local function BuildGroupView(parent, f)
    local g = CreateFrame("Frame", nil, parent)
    g:SetAllPoints(parent)
    local w = {}
    f.groupW = w

    local ban = CreateFrame("Frame", nil, g)
    ban:SetPoint("TOPLEFT", 8, -8)
    ban:SetWidth(276); ban:SetHeight(76)
    ban:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    ban:SetBackdropColor(0.2, 0.12, 0, 0.9)

    w.title = ban:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    w.title:SetPoint("TOPLEFT", 8, -8); w.title:SetWidth(222); w.title:SetHeight(28)
    w.title:SetJustifyH("LEFT"); w.title:SetJustifyV("TOP")
    w.sub = ban:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    w.sub:SetPoint("TOPLEFT", 8, -40); w.sub:SetWidth(260); w.sub:SetJustifyH("LEFT")
    w.info = ban:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    w.info:SetPoint("TOPLEFT", 8, -55); w.info:SetWidth(260); w.info:SetJustifyH("LEFT")
    w.icon = ban:CreateTexture(nil, "ARTWORK")
    w.icon:SetWidth(30); w.icon:SetHeight(30)
    w.icon:SetPoint("TOPRIGHT", -8, -8)

    -- column headers
    local function Col(text, x)
        local fs = g:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", x, -92); fs:SetText(text)
    end
    Col("Name", 14); Col("Role", 112); Col("GS", 164)

    w.rows = {}
    for i = 1, APP_ROWS do
        local r = CreateFrame("Frame", nil, g)
        r:SetWidth(276); r:SetHeight(APP_H)
        r:SetPoint("TOPLEFT", g, "TOPLEFT", 8, -108 - (i - 1) * APP_H)
        local function FS(x, width)
            local fs = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            fs:SetPoint("LEFT", x, 0); fs:SetWidth(width); fs:SetHeight(12)
            fs:SetJustifyH("LEFT")
            return fs
        end
        r.name = FS(6, 96)
        r.role = FS(104, 50)
        r.gs   = FS(156, 38)
        r.invite = MakeButton(r, "Invite", 48, 20)
        r.invite:SetPoint("LEFT", 196, 0)
        r.decline = MakeButton(r, "X", 22, 20)
        r.decline:SetPoint("LEFT", 248, 0)
        r.invite:SetScript("OnClick", function() if r.who then ns.InviteApplicant(r.who) end end)
        r.decline:SetScript("OnClick", function() if r.who then ns.DeclineApplicant(r.who) end end)
        r:Hide()
        w.rows[i] = r
    end

    w.empty = g:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    w.empty:SetPoint("TOP", g, "TOP", 0, -150)
    w.empty:SetText("No sign-ups yet.")

    w.sync = g:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    w.sync:SetPoint("BOTTOMLEFT", 12, 42)

    w.delist = MakeButton(g, "Delist My Group", 150, 24)
    w.delist:SetPoint("BOTTOMLEFT", 8, 10)
    w.delist:SetScript("OnClick", function() ns.RemoveMine() end)
    w.edit = MakeButton(g, "Edit", 100, 24)
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

    w.title:SetText(ns.ListingTitle(me))
    w.sub:SetText("Arena (2v2)   " .. (ns.TIERS[me.tier] or ""))
    local info = (me.hasTeam and ("Team " .. me.teamRating) or "No team") .. "   GS " .. (me.gs > 0 and me.gs or "-")
    if me.seasonal then info = info .. "   Seasonal" end
    if me.tenGames then info = info .. "   10 games" end
    w.info:SetText(info)
    SetClassIcon(w.icon, me.class)

    local list = {}
    for _, l in pairs(ns.applicants) do list[#list + 1] = l end
    table.sort(list, function(a, b) return (a.order or 0) < (b.order or 0) end)
    for i = 1, APP_ROWS do
        local r, l = w.rows[i], list[i]
        if l then
            local c = RAID_CLASS_COLORS[l.class] or { r = 1, g = 1, b = 1 }
            r.who = l.name
            r.name:SetText(l.name)
            r.name:SetTextColor(c.r, c.g, c.b)
            r.role:SetText(ROLE_TEXT[l.role] or l.role)
            r.gs:SetText(l.gs > 0 and l.gs or "-")
            r:Show()
        else
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
    if not ns.frame then return end
    RefreshList()
    RefreshGroupView()
end

----------------------------------------------------------------------
-- Left side, view 2: list / edit my group (the form)
----------------------------------------------------------------------
local function BuildFormView(parent, f)
    local p = CreateFrame("Frame", nil, parent)
    p:SetAllPoints(parent)
    local m = ns.DB.mine
    local w = {}
    f.mineWidgets = w

    MakeLabel(p, "List your group", 12, -10)
    w.char = MakeLabel(p, "", 12, -32, "GameFontHighlight")
    w.char:SetWidth(266); w.char:SetJustifyH("LEFT")

    MakeLabel(p, "Role", 12, -62)
    w.role = MakeMenuButton(p, 120,
        function() return ns.ROLES end,
        function() return m.role end,
        function(v) m.role = v end)
    w.role:SetPoint("TOPLEFT", 100, -58)

    MakeLabel(p, "Gearscore", 12, -92)
    w.gs = MakeEdit(p, 70, true, 5)
    w.gs:SetPoint("TOPLEFT", 108, -88)

    w.team = MakeCheck(p, "I have a 2v2 team")
    w.team:SetPoint("TOPLEFT", 6, -114)
    w.team:Disable() -- read from the game, not editable
    w.rating = MakeLabel(p, "", 172, -122, "GameFontHighlight")

    w.detect = MakeLabel(p, "", 12, -146, "GameFontNormalSmall")
    w.detect:SetWidth(266); w.detect:SetJustifyH("LEFT")

    MakeLabel(p, "Experience", 12, -184)
    w.tier = MakeMenuButton(p, 150,
        function() return ns.TIERS end,
        function() return ns.TIERS[m.tier] end,
        function(v)
            for i, t in ipairs(ns.TIERS) do if t == v then m.tier = i end end
        end)
    w.tier:SetPoint("TOPLEFT", 100, -180)

    w.seasonal = MakeCheck(p, "Seasonal character", function(on) m.seasonal = on end)
    w.seasonal:SetPoint("TOPLEFT", 6, -208)
    w.ten = MakeCheck(p, "10 games only (arena points)", function(on) m.tenGames = on end)
    w.ten:SetPoint("TOPLEFT", 6, -234)

    MakeLabel(p, "Group title (optional)", 12, -270)
    w.note = MakeEdit(p, 256, false, 60)
    w.note:SetPoint("TOPLEFT", 16, -290)

    w.post = MakeButton(p, "List Group", 124, 24)
    w.post:SetPoint("TOPLEFT", 12, -324)
    w.post:SetScript("OnClick", function() ns.PostMine() end)
    w.back = MakeButton(p, "Back", 124, 24)
    w.back:SetPoint("LEFT", w.post, "RIGHT", 6, 0)
    w.back:SetScript("OnClick", function() ns.SaveMine(); f.editing = false; UpdateLeft() end)

    w.hint = MakeLabel(p, "Your role, gearscore and team are also what group leaders see when you sign up to their group.", 12, -356, "GameFontDisableSmall")
    w.hint:SetWidth(266); w.hint:SetJustifyH("LEFT")

    return p
end

function ns.UI_LoadMine()
    local f = ns.frame
    if not f then return end
    local m, w = ns.DB.mine, f.mineWidgets
    local info = ns.DetectMine()

    local c = RAID_CLASS_COLORS[ns.GetMyClass()] or { r = 1, g = 1, b = 1 }
    w.char:SetText(UnitName("player") .. "  -  " .. (UnitClass("player")) .. ", " .. ns.GetMySpec())
    w.char:SetTextColor(c.r, c.g, c.b)
    w.role:Refresh(); w.tier:Refresh()
    w.gs:SetText(m.gs > 0 and m.gs or "")
    w.team:SetChecked(m.hasTeam)
    w.rating:SetText(m.hasTeam and ("Rating: " .. m.teamRating) or "")
    w.seasonal:SetChecked(m.seasonal)
    w.ten:SetChecked(m.tenGames)
    w.note:SetText(m.note or "")

    local txt = (info.team and ("2v2 team \"" .. info.team .. "\" found") or "No 2v2 team found on this character")
        .. (info.gs and "; gearscore read from your GearScore addon." or "; no GearScore addon, enter your GS by hand.")
    w.detect:SetText((info.team and "|cff00ff00" or "|cff999999") .. txt .. "|r")

    w.post:SetText(m.posted and "Update Listing" or "List Group")
    if m.posted then w.back:Show(); w.hint:Hide() else w.back:Hide(); w.hint:Show() end
end

function ns.SaveMine()
    local f = ns.frame
    if not f then return end
    local m, w = ns.DB.mine, f.mineWidgets
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
    if ns.DB.mine.posted and not f.editing then
        f.mine:Hide()
        f.groupView:Show()
        RefreshGroupView()
    else
        f.groupView:Hide()
        f.mine:Show()
        ns.UI_LoadMine()
    end
end

function ns.PostMine()
    ns.SaveMine()
    ns.DB.mine.posted = true
    ns.frame.editing = false
    ns.AddListing(ns.MyListing())
    UpdateLeft()          -- update the UI first, so a sync problem can never leave it stale
    ns.Broadcast()
end

function ns.EditMine()
    if not ns.frame then return end
    ns.frame.editing = true
    ns.frame:Show()
    UpdateLeft()
end

function ns.RemoveMine()
    ns.DB.mine.posted = false
    for name, l in pairs(ns.applicants) do
        if not l.fake then pcall(SendAddonMessage, ns.PREFIX, "DEC", "WHISPER", name) end
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
    f:SetWidth(780); f:SetHeight(480)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
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
    local right = MakePanel(f, 444, 418)
    right:SetPoint("TOPLEFT", 318, -44)
    f.right = right

    MakeLabel(right, "Arena 2v2 groups", 12, -12)

    local refresh = CreateFrame("Button", nil, right)
    refresh:SetWidth(24); refresh:SetHeight(24)
    refresh:SetPoint("TOPRIGHT", -10, -8)
    refresh:SetNormalTexture("Interface\\Buttons\\UI-RefreshButton")
    refresh:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    refresh:SetScript("OnClick", function() ns.Comm_Request(); ns.RefreshAll() end)
    refresh:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Refresh")
        GameTooltip:AddLine("Asks other players to announce their groups again.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    refresh:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Search box with placeholder
    local search = MakeEdit(right, 280, false, 40)
    search:SetPoint("TOPLEFT", 14, -34)
    local ph = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ph:SetPoint("LEFT", 2, 0)
    ph:SetText("Search name, spec or title")
    local function UpdatePlaceholder(self)
        if self:GetText() == "" and not self:HasFocus() then ph:Show() else ph:Hide() end
    end
    search:SetScript("OnTextChanged", function(self)
        ns.search = strlower(self:GetText() or "")
        UpdatePlaceholder(self)
        RefreshList()
    end)
    search:SetScript("OnEditFocusGained", function(self) ph:Hide() end)
    search:SetScript("OnEditFocusLost", UpdatePlaceholder)

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
    f.rows = {}
    for i = 1, ROWS do f.rows[i] = BuildRow(right, i) end

    f.count = right:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    f.count:SetPoint("BOTTOMLEFT", 14, 18)

    f.signup = MakeButton(right, "Sign Up", 150, 24)
    f.signup:SetPoint("BOTTOMRIGHT", -12, 12)
    f.signup:SetScript("OnClick", function()
        local l = ns.selected and ns.listings[ns.selected]
        if not l then return end
        if ns.applied[l.name] == "pending" then ns.CancelApply(l) else ns.Apply(l) end
    end)

    f:SetScript("OnShow", function()
        ns.RequestArenaData()
        UpdateLeft()
        ns.RefreshAll()
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
