local ADDON, ns = ...

local RADIUS = 80
local btn

local function UpdatePosition()
    local a = math.rad(ns.DB.minimap.angle)
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * RADIUS, math.sin(a) * RADIUS)
end

function ns.UpdateMinimapButton()
    if not btn then return end
    UpdatePosition()
    -- with another Skom's addon, the shared Skom's button (launcher.lua) replaces this one
    local shared = _G.SkomsLauncher and _G.SkomsLauncher.active
    if ns.DB.minimap.hide or shared then btn:Hide() else btn:Show() end
end

-- While dragging: compute the angle between the minimap center and the cursor
local function OnDragUpdate()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    ns.DB.minimap.angle = math.deg(math.atan2(cy - my, cx - mx))
    UpdatePosition()
end

function ns.BuildMinimapButton()
    if btn then return end
    btn = CreateFrame("Button", "ArenaLFGMinimapButton", Minimap)
    btn:SetWidth(31); btn:SetHeight(31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetWidth(20); icon:SetHeight(20)
    icon:SetPoint("TOPLEFT", 7, -5)
    icon:SetTexture("Interface\\Icons\\Achievement_Arena_2v2_1")
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetWidth(53); border:SetHeight(53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    btn:SetScript("OnClick", function(self, button)
        if button == "RightButton" then ns.OpenOptions() else ns.ToggleUI() end
    end)
    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", OnDragUpdate)
        GameTooltip:Hide()
    end)
    btn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddDoubleLine("ArenaLFG", "v" .. ns.VERSION, 1, 0.82, 0, 0.6, 0.6, 0.6)
        local n = 0
        for _ in pairs(ns.listings) do n = n + 1 end
        GameTooltip:AddLine(n .. " listing(s)", 1, 1, 1)
        GameTooltip:AddLine("Click: open / close", 0.6, 0.6, 0.6)
        GameTooltip:AddLine("Right-click: options", 0.6, 0.6, 0.6)
        GameTooltip:AddLine("Drag: move button", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    UpdatePosition()
    ns.UpdateMinimapButton()
end
