--[[
    BobberBuddy - Fishing Log
    Every fish (and anything else) you've ever pulled out of the water, how many,
    and where. Only counts loot from your own fishing casts - never bought,
    traded, mailed or quest items.

    Open with /bb log, the Log button on the tracker, or ctrl-click the minimap button.
]]

BobberBuddy = BobberBuddy or {}
local BB = BobberBuddy
local C = BB.compat

local ROW_HEIGHT = 34
local SORTS = {
    { label = "Most caught", key = "count" },
    { label = "Name",        key = "name" },
    { label = "Recent",      key = "recent" },
}

---------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------
-- Builds { name, itemID, count, zones = { {zone, count}, ... }, first, last } for every catch
local function BuildEntries()
    local data = BB.db.fishData
    local byName = {}
    for name, count in pairs(data.lifetime) do
        byName[name] = {
            name = name, count = count, zones = {},
            itemID = BB:GetFishItemID(name),
            first = data.firstCaught[name], last = data.lastCaught[name],
        }
    end
    for zone, fishes in pairs(data.zoneData) do
        for name, count in pairs(fishes) do
            local entry = byName[name]
            if entry then table.insert(entry.zones, { zone = zone, count = count }) end
        end
    end

    local list = {}
    for _, entry in pairs(byName) do
        table.sort(entry.zones, function(a, b) return a.count > b.count end)
        table.insert(list, entry)
    end
    return list
end

local function Matches(entry, filter)
    if filter == "" then return true end
    if entry.name:lower():find(filter, 1, true) then return true end
    for _, z in ipairs(entry.zones) do
        if z.zone:lower():find(filter, 1, true) then return true end
    end
    return false
end

local function ZoneSummary(entry)
    local parts = {}
    for i, z in ipairs(entry.zones) do
        if i > 3 then
            parts[#parts + 1] = "+" .. (#entry.zones - 3) .. " more"
            break
        end
        parts[#parts + 1] = z.zone .. " (" .. z.count .. ")"
    end
    return table.concat(parts, ", ")
end

---------------------------------------------------------------------------
-- Rows
---------------------------------------------------------------------------
local function CreateLogRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(360, ROW_HEIGHT)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("LEFT", 2, 0)
    row.icon = icon

    local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -1)
    name:SetPoint("RIGHT", row, "RIGHT", -60, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    row.name = name

    local zones = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    zones:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 8, 1)
    zones:SetPoint("RIGHT", row, "RIGHT", -60, 0)
    zones:SetJustifyH("LEFT")
    zones:SetWordWrap(false)
    row.zones = zones

    local count = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    count:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.count = count

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.08)

    row:SetScript("OnEnter", function(self)
        local e = self.entry
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if e.itemID then GameTooltip:SetItemByID(e.itemID) else GameTooltip:SetText(e.name) end
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Caught in total:", e.count, 0.5, 0.8, 1, 1, 1, 1)
        for _, z in ipairs(e.zones) do
            GameTooltip:AddDoubleLine("   " .. z.zone, z.count, 1, 0.82, 0, 1, 1, 1)
        end
        if e.first then
            GameTooltip:AddDoubleLine("First caught:", date("%b %d, %Y", e.first), 0.5, 0.8, 1, 1, 1, 1)
        end
        if e.last then
            GameTooltip:AddDoubleLine("Last caught:", date("%b %d, %Y %H:%M", e.last), 0.5, 0.8, 1, 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:SetScript("OnClick", function(self)
        local link = self.entry.itemID and select(2, C.GetItemInfo(self.entry.itemID))
        if link and HandleModifiedItemClick then HandleModifiedItemClick(link) end
    end)
    return row
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
function BB:CreateFishingLog()
    local frame = CreateFrame("Frame", "BobberBuddyLogFrame", UIParent, "BackdropTemplate")
    frame:SetSize(420, 460)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    frame:Hide()
    table.insert(UISpecialFrames, "BobberBuddyLogFrame") -- Escape closes it

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -16)
    title:SetText("Fishing Log")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)

    local summary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    summary:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    frame.summary = summary

    -- Time spent fishing (hover for a breakdown by zone)
    local timeLine = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timeLine:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -3)
    frame.timeLine = timeLine

    local timeHover = CreateFrame("Frame", nil, frame)
    timeHover:SetAllPoints(timeLine)
    timeHover:SetScript("OnEnter", function(hover)
        GameTooltip:SetOwner(hover, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Time spent fishing")
        local zones = {}
        for zone, seconds in pairs(BB.db.stats.zoneTime) do
            zones[#zones + 1] = { zone = zone, seconds = seconds }
        end
        table.sort(zones, function(a, b) return a.seconds > b.seconds end)
        for _, z in ipairs(zones) do
            GameTooltip:AddDoubleLine(z.zone, SecondsToTime(z.seconds), 1, 0.82, 0, 1, 1, 1)
        end
        if #zones == 0 then
            GameTooltip:AddLine("Time by zone is recorded from version 2.6 onwards.", 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
    end)
    timeHover:SetScript("OnLeave", GameTooltip_Hide)

    -- Search (fish or zone name)
    local search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    search:SetSize(200, 20)
    search:SetPoint("TOPLEFT", timeLine, "BOTTOMLEFT", 6, -10)
    search:SetAutoFocus(false)
    local hint = search:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    hint:SetPoint("LEFT", 2, 0)
    hint:SetText("Search fish or zone...")
    search:SetScript("OnTextChanged", function(box)
        hint:SetShown(box:GetText() == "")
        BB:UpdateFishingLog()
    end)
    search:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(box) box:ClearFocus() end)
    frame.search = search

    -- Sort toggle
    frame.sortIndex = 1
    local sortButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    sortButton:SetSize(150, 22)
    sortButton:SetPoint("LEFT", search, "RIGHT", 16, 0)
    sortButton:SetScript("OnClick", function()
        frame.sortIndex = frame.sortIndex % #SORTS + 1
        BB:UpdateFishingLog()
    end)
    frame.sortButton = sortButton

    -- List
    local scroll = CreateFrame("ScrollFrame", "BobberBuddyLogScroll", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -100)
    scroll:SetPoint("BOTTOMRIGHT", -34, 16)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(360, 100)
    scroll:SetScrollChild(content)
    frame.content = content
    frame.rows = {}

    local empty = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    empty:SetPoint("TOP", 0, -40)
    empty:SetWidth(320)
    empty:SetTextColor(0.7, 0.7, 0.7)
    frame.empty = empty

    frame:SetScript("OnShow", function() BB:UpdateFishingLog() end)
    self.logFrame = frame
end

function BB:UpdateFishingLog()
    local frame = self.logFrame
    if not frame or not frame:IsShown() then return end

    local all = BuildEntries()
    local zoneSet, total = {}, 0
    for _, e in ipairs(all) do
        total = total + e.count
        for _, z in ipairs(e.zones) do zoneSet[z.zone] = true end
    end
    local zoneCount = 0
    for _ in pairs(zoneSet) do zoneCount = zoneCount + 1 end
    frame.summary:SetText(#all .. " different catches  |  " .. total .. " caught  |  " .. zoneCount .. " zones")

    local seconds = self:GetTimeSpentFishing()
    local perHour = seconds >= 60 and string.format("%.0f", total * 3600 / seconds) or "--"
    frame.timeLine:SetText("Time fishing: " .. (seconds > 0 and SecondsToTime(seconds) or "none yet") ..
        "  |  " .. (self.db.stats.fishingCasts or 0) .. " casts  |  " .. perHour .. " catches/hr")

    -- Filter and sort
    local filter = strtrim(frame.search:GetText() or ""):lower()
    local list = {}
    for _, e in ipairs(all) do
        if Matches(e, filter) then list[#list + 1] = e end
    end
    local sort = SORTS[frame.sortIndex]
    frame.sortButton:SetText("Sort: " .. sort.label)
    table.sort(list, function(a, b)
        if sort.key == "name" then return a.name < b.name end
        if sort.key == "recent" and (a.last or 0) ~= (b.last or 0) then return (a.last or 0) > (b.last or 0) end
        if a.count ~= b.count then return a.count > b.count end
        return a.name < b.name
    end)

    -- Rows
    for _, row in ipairs(frame.rows) do row:Hide() end
    for i, e in ipairs(list) do
        frame.rows[i] = frame.rows[i] or CreateLogRow(frame.content)
        local row = frame.rows[i]
        row.entry = e
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row.icon:SetTexture((e.itemID and select(5, C.GetItemInfoInstant(e.itemID))) or 134400)
        local quality = e.itemID and select(3, C.GetItemInfo(e.itemID))
        local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
        row.name:SetTextColor(color and color.r or 1, color and color.g or 1, color and color.b or 1)
        row.name:SetText(e.name)
        row.zones:SetText(ZoneSummary(e))
        row.count:SetText(e.count)
        row:Show()
    end
    frame.content:SetHeight(math.max(#list * ROW_HEIGHT, 100))

    if #all == 0 then
        frame.empty:SetText("Nothing caught yet.\nEverything you fish up will be logged here, with where you caught it.")
    elseif #list == 0 then
        frame.empty:SetText("Nothing matches \"" .. filter .. "\".")
    end
    frame.empty:SetShown(#list == 0)
end

function BB:ToggleFishingLog()
    if not self.logFrame then self:CreateFishingLog() end
    self.logFrame:SetShown(not self.logFrame:IsShown())
end
