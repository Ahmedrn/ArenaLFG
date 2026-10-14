local ADDON, ns = ...

function ns.GetMyClass()
    return select(2, UnitClass("player")) -- token, e.g. "HUNTER"
end

-- Spec = talent tree with the most points
function ns.GetMySpec()
    local best, bestPoints = nil, 0
    for i = 1, GetNumTalentTabs() do
        local name, _, points = GetTalentTabInfo(i)
        if points and points > bestPoints then
            best, bestPoints = name, points
        end
    end
    return best or "None"
end

-- Soft dependency: only used if a GearScore addon is installed.
-- Function name taken from the original GearScore addon; verify it in its source.
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
f:SetScript("OnEvent", function()
    if ns.frame and ns.frame.mine and ns.frame.mine:IsShown() then ns.SaveMine(); ns.UI_LoadMine() end
end)

-- Pull what the game can tell us. The 2v2 team is authoritative: no team = no team.
function ns.DetectMine()
    local m, info = ns.DB.mine, {}
    local gs = ns.GetMyGearScore()
    if gs then m.gs = gs; info.gs = true end
    local tname, rating = ns.GetMy2v2Team()
    m.hasTeam = tname and true or false
    m.teamRating = tname and (rating or 0) or 0
    info.team = tname
    return info
end
