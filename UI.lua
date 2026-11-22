--[[
    BobberBuddy - UI Module
    The session tracker window: fishing skill, session stats and this session's catches.
    Built from Blizzard's own window template and fonts so it looks like the rest of the game.
]]

BobberBuddy = BobberBuddy or {}
local BB = BobberBuddy

local WIDTH, HEIGHT = 260, 420
local PAD = 12          -- space inside the inset
local ROW_HEIGHT = 18
local BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"

local function Text(parent, font)
    return parent:CreateFontString(nil, "OVERLAY", font)
end

-- Gold section heading, like the ones in the character and profession windows
local function SectionLabel(parent, text)
    local fs = Text(parent, "GameFontNormal")
    fs:SetText(text)
    return fs
end

-- Compact durations: "45s", "12m 05s", "1h 07m"
function BB.FormatDuration(seconds)
    seconds = math.max(math.floor(seconds or 0), 0)
    local h, m, s = math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60
    if h > 0 then return string.format("%dh %02dm", h, m) end
    if m > 0 then return string.format("%dm %02ds", m, s) end
    return s .. "s"
end

-- Hover tooltip. Adds to (doesn't replace) existing hover scripts, and keeps the window
-- draggable from this area.
local function Tooltip(frame, title, body)
    frame:EnableMouse(true)
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(title)
        GameTooltip:AddLine(body, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", GameTooltip_Hide)
    if not frame:IsObjectType("Button") then
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function() BB.ui.trackerFrame:StartMoving() end)
        frame:SetScript("OnDragStop", function()
            BB.ui.trackerFrame:StopMovingOrSizing()
            BB:SaveTrackerPosition()
        end)
    end
end

-- Standard red Blizzard button
local function PanelButton(parent, label, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetHeight(22)
    button:SetText(label)
    button:SetScript("OnClick", onClick)
    return button
end

-- One "Label:   value" stat cell - gold label, white value, like the character window
local function StatCell(parent, label, width)
    local cell = CreateFrame("Frame", nil, parent)
    cell:SetSize(width, 16)
    local l = Text(cell, "GameFontNormalSmall")
    l:SetPoint("LEFT")
    l:SetText(label)
    local v = Text(cell, "GameFontHighlightSmall")
    v:SetPoint("RIGHT")
    v:SetJustifyH("RIGHT")
    cell.value = v
    return cell
end

function BB:InitUI()
    self.ui = {}
    self:CreateTrackerFrame()
    self:UpdateTrackerVisibility()
end

function BB:CreateTrackerFrame()
    local ui = self.ui
    -- Blizzard's standard window: title bar, close button and a dark inset panel
    local frame = CreateFrame("Frame", "BobberBuddyTrackerFrame", UIParent, "BasicFrameTemplateWithInset")
    ui.trackerFrame = frame
    frame:SetSize(WIDTH, HEIGHT)

    -- Saved position is {point, relativePoint, x, y}, always relative to UIParent
    local position = self:GetSetting("trackerPosition")
    if type(position) == "table" and #position == 4 then
        frame:SetPoint(position[1], UIParent, position[2], position[3], position[4])
    else
        frame:SetPoint("RIGHT", UIParent, "RIGHT", -50, 0)
    end
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        BB:SaveTrackerPosition()
    end)
    frame:SetScript("OnHide", function()
        -- Closing with Escape or the close button should stay closed (but not Alt+Z hiding the UI)
        if UIParent:IsShown() and BB:GetSetting("showTracker") then
            BB:SetSetting("showTracker", false)
        end
    end)

    -- Title in the title bar
    local title = Text(frame, "GameFontHighlight")
    if frame.TitleBg then
        title:SetPoint("CENTER", frame.TitleBg, "CENTER", 0, 0)
    else
        title:SetPoint("TOP", 0, -5)
    end
    title:SetText("Bobber Buddy")

    -- Everything else sits in this area: below the title bar, above the buttons. We lay out
    -- against our own frame because the template's inset is named differently between clients.
    local inset = CreateFrame("Frame", nil, frame)
    inset:SetPoint("TOPLEFT", 4, -26)
    inset:SetPoint("BOTTOMRIGHT", -6, 36)
    local innerWidth = WIDTH - 2 * (PAD + 6)

    -- Fit the template's dark inset background (whatever it's called) to the same area
    local insetBg = frame.Inset or frame.InsetBg
    if insetBg then
        insetBg:ClearAllPoints()
        insetBg:SetPoint("TOPLEFT", inset, "TOPLEFT")
        insetBg:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT")
    end

    local zone = Text(frame, "GameFontHighlightSmall")
    zone:SetPoint("TOP", inset, "TOP", 0, -8)
    zone:SetTextColor(0.8, 0.8, 0.8)
    ui.zoneText = zone

    -- Fishing skill: heading, a skill bar with "89 / 150" on it, and the next skill-up estimate
    local skillLabel = SectionLabel(frame, "Fishing Skill")
    skillLabel:SetPoint("TOPLEFT", inset, "TOPLEFT", PAD, -28)

    local barBorder = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    barBorder:SetPoint("TOPLEFT", skillLabel, "BOTTOMLEFT", -2, -5)
    barBorder:SetPoint("RIGHT", inset, "RIGHT", -PAD + 2, 0)
    barBorder:SetHeight(20)
    barBorder:SetBackdrop({
        bgFile = BAR_TEXTURE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10, insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    barBorder:SetBackdropColor(0, 0, 0, 0.6)
    barBorder:SetBackdropBorderColor(0.7, 0.7, 0.7, 1)

    local bar = CreateFrame("StatusBar", nil, barBorder)
    bar:SetPoint("TOPLEFT", 3, -3)
    bar:SetPoint("BOTTOMRIGHT", -3, 3)
    bar:SetStatusBarTexture(BAR_TEXTURE)
    bar:SetStatusBarColor(0.25, 0.4, 0.9) -- the blue of the classic skill bars
    bar:SetMinMaxValues(0, 1)
    ui.skillBar = bar

    local barText = Text(bar, "GameFontHighlightSmall")
    barText:SetPoint("CENTER")
    ui.skillValue = barText

    local nextUp = Text(frame, "GameFontHighlightSmall")
    nextUp:SetPoint("TOPLEFT", barBorder, "BOTTOMLEFT", 2, -5)
    nextUp:SetWidth(innerWidth)
    nextUp:SetJustifyH("LEFT")
    ui.nextSkillText = nextUp

    local skillHover = CreateFrame("Frame", nil, frame)
    skillHover:SetPoint("TOPLEFT", skillLabel, "TOPLEFT", 0, 2)
    skillHover:SetPoint("BOTTOMRIGHT", nextUp, "BOTTOMRIGHT", 0, -2)
    skillHover:EnableMouse(true)
    skillHover:SetScript("OnEnter", function(self) BB:ShowSkillTooltip(self) end)
    skillHover:SetScript("OnLeave", GameTooltip_Hide)
    skillHover:RegisterForDrag("LeftButton")
    skillHover:SetScript("OnDragStart", function() frame:StartMoving() end)
    skillHover:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        BB:SaveTrackerPosition()
    end)

    -- Session stats grid
    local statsLabel = SectionLabel(frame, "Session")
    statsLabel:SetPoint("TOPLEFT", nextUp, "BOTTOMLEFT", 0, -12)

    local cellWidth = (innerWidth - 16) / 2
    local cells = {
        catches = StatCell(frame, "Catches:", cellWidth),
        total = StatCell(frame, "Lifetime:", cellWidth),
        casts = StatCell(frame, "Casts:", cellWidth),
        time = StatCell(frame, "Time:", cellWidth),
        value = StatCell(frame, "Value:", cellWidth),
        perHour = StatCell(frame, "|TInterface\\MoneyFrame\\UI-GoldIcon:0|t/hr:", cellWidth),
    }
    local order = { { "catches", "total" }, { "casts", "time" }, { "value", "perHour" } }
    local previous = statsLabel
    for i, row in ipairs(order) do
        local left, right = cells[row[1]], row[2] and cells[row[2]]
        left:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, i == 1 and -6 or -3)
        if right then right:SetPoint("LEFT", left, "RIGHT", 16, 0) end
        previous = left
    end
    ui.cells = cells
    Tooltip(cells.catches, "Catches", "What you've fished up this session.")
    Tooltip(cells.total, "Lifetime", "Everything you've ever fished up. Open the Log for the full list and where.")
    Tooltip(cells.value, "Session value",
        "What this session's catches are worth, plus any coins you fished up. Uses Auctionator prices " ..
        "when it has one, otherwise the vendor price.")
    Tooltip(cells.perHour, "Per hour",
        "Session value per hour, measured from your first cast this session. Clear restarts it.")

    -- This session's catches
    local listLabel = SectionLabel(frame, "This Session")
    listLabel:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -12)
    ui.listLabel = listLabel

    local moreText = Text(frame, "GameFontDisableSmall")
    moreText:SetPoint("RIGHT", inset, "RIGHT", -PAD, 0)
    moreText:SetPoint("BOTTOM", listLabel, "BOTTOM", 0, 0)
    ui.moreText = moreText

    -- Buttons along the bottom, below the inset
    local third = (WIDTH - 20 - 8) / 3
    local clear = PanelButton(frame, "Clear", function() BB:ClearSessionData() end)
    clear:SetWidth(third)
    clear:SetPoint("BOTTOMLEFT", 10, 8)
    Tooltip(clear, "Clear session", "Clears this session's list and value. Your lifetime log is kept.")
    local log = PanelButton(frame, "Log", function() BB:ToggleFishingLog() end)
    log:SetWidth(third)
    log:SetPoint("LEFT", clear, "RIGHT", 4, 0)
    local settings = PanelButton(frame, "Settings", function() BB:OpenSettings() end)
    settings:SetWidth(third)
    settings:SetPoint("LEFT", log, "RIGHT", 4, 0)

    -- Scrollable list (mouse wheel)
    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", listLabel, "BOTTOMLEFT", 0, -6)
    scroll:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -PAD, 8)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(innerWidth, ROW_HEIGHT)
    scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(s, delta)
        local range = s:GetVerticalScrollRange()
        s:SetVerticalScroll(math.min(math.max(s:GetVerticalScroll() - delta * ROW_HEIGHT * 2, 0), range))
        BB:UpdateMoreText()
    end)
    ui.scroll, ui.content = scroll, content
    ui.rowWidth = innerWidth

    local empty = Text(content, "GameFontDisableSmall")
    empty:SetPoint("TOPLEFT", 2, -4)
    empty:SetText("Nothing caught yet this session.")
    ui.noFishText = empty

    -- Tick the time once a second while the window is open and you're fishing
    local sinceTick = 0
    frame:SetScript("OnUpdate", function(_, elapsed)
        sinceTick = sinceTick + elapsed
        if sinceTick >= 1 then
            sinceTick = 0
            BB:UpdateStatsLine() -- keeps time and the skill bonus current while the window is open
        end
    end)

    -- Not added to UISpecialFrames: Escape (and the game closing its settings window) closes every
    -- window on that list at once, which took the tracker down with the options. Use its close button.

    StaticPopupDialogs["BOBBERBUDDY_CONFIRM_RESET"] = {
        text = "Reset all Bobber Buddy data?\nThis clears every catch, your cast count, fishing time and lures used.\nThis cannot be undone!",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function() BB:ClearAllData() end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3, -- avoids clashing with Blizzard's own popups
    }

    ui.listItems = {}
    self:RefreshFishingSkill()
    self:UpdateFishTrackerUI()
end

-- Skill, stats and value; cheap enough to refresh every second
function BB:UpdateStatsLine()
    local ui = self.ui
    if not ui or not ui.cells then return end
    local cells = ui.cells

    cells.catches.value:SetText(self:GetSessionTotal())
    cells.total.value:SetText(self:GetLifetimeTotal())
    cells.casts.value:SetText(self.db.stats.fishingCasts or 0)
    cells.time.value:SetText(BB.FormatDuration(self:GetTimeSpentFishing()))
    cells.value.value:SetText(BB.FormatMoneyShort(self:GetSessionValue()))
    local perHour = self:GetGoldPerHour()
    cells.perHour.value:SetText(perHour and BB.FormatMoneyShort(perHour) or "|cFF808080--|r")

    -- Fishing skill
    local skill = self.db.fishingSkill
    if skill.rank then
        -- "225 (+95) / 300", like the character window: base skill, then the bonus in green
        -- The game's own bonus can leave out the pole, so add up pole, gear, lure and buffs
        -- ourselves and use whichever is bigger
        local _, _, liveBonus = self:ReadFishingSkill()
        local _, counted = self:GetFishingSkillBreakdown()
        local bonus = math.max(liveBonus or self.cache.skillBonus or 0, counted)
        self.cache.skillBonus = bonus
        local text = tostring(skill.rank)
        if bonus > 0 then
            text = text .. " |cFF20FF20(+" .. bonus .. ")|r"
        elseif bonus < 0 then
            text = text .. " |cFFFF2020(" .. bonus .. ")|r"
        end
        if skill.max then text = text .. " / " .. skill.max end
        ui.skillValue:SetText(text)
        ui.skillBar:SetValue(skill.max and skill.max > 0 and (skill.rank / skill.max) or 1)
        if skill.max and skill.rank >= skill.max then
            ui.nextSkillText:SetText(skill.max >= 300 and "Max skill reached"
                or "|cFFFFB040At your cap|r - train the next rank to keep going")
        else
            local catches, seconds = self:EstimateNextSkillUp()
            if catches then
                ui.nextSkillText:SetText(catches < 1 and "Next skill-up: any catch now"
                    or ("Next skill-up in ~" .. catches .. (catches == 1 and " catch" or " catches")
                        .. "  |cFFA0A0A0(~" .. BB.FormatDuration(seconds) .. ")|r"))
            elseif seconds then
                ui.nextSkillText:SetText(seconds < 1 and "Next skill-up: any catch now"
                    or ("Next skill-up in |cFFA0A0A0~" .. BB.FormatDuration(seconds) .. "|r"))
            else
                ui.nextSkillText:SetText("|cFFA0A0A0Next skill-up: estimating after a couple of skill-ups|r")
            end
        end
    else
        ui.skillValue:SetText("")
        ui.skillBar:SetValue(0)
        ui.nextSkillText:SetText("|cFFA0A0A0Cast once to read your skill|r")
    end
end

-- Hover on the skill bar: base skill, what each item, lure and buff adds, and the totals
function BB:ShowSkillTooltip(owner)
    local skill = self.db.fishingSkill
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Fishing Skill")
    if not skill.rank then
        GameTooltip:AddLine("Cast once to read your skill.", 1, 1, 1, true)
        GameTooltip:Show()
        return
    end

    local list, counted = self:GetFishingSkillBreakdown()
    local _, _, gameBonus = self:ReadFishingSkill()
    local bonus = math.max(gameBonus or 0, counted)

    GameTooltip:AddDoubleLine("Base skill", skill.max and (skill.rank .. " / " .. skill.max) or skill.rank,
        1, 0.82, 0, 1, 1, 1)
    if #list > 0 then
        GameTooltip:AddLine(" ")
        for _, entry in ipairs(list) do
            local label = entry.icon and ("|T" .. entry.icon .. ":14:14:0:0|t " .. entry.name) or entry.name
            local amount = entry.unknown and "|cFFA0A0A0?|r" or ("+" .. entry.amount)
            GameTooltip:AddDoubleLine(label, amount, 1, 1, 1, 0.13, 1, 0.13)
        end
        if (gameBonus or 0) > counted then
            GameTooltip:AddDoubleLine("Other", "+" .. (gameBonus - counted), 1, 1, 1, 0.13, 1, 0.13)
        end
    else
        GameTooltip:AddLine("No pole, lure, gear or buff bonus right now.", 0.63, 0.63, 0.63, true)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Total bonus", "+" .. bonus, 1, 0.82, 0, 0.13, 1, 0.13)
    GameTooltip:AddDoubleLine("Effective skill", skill.rank + bonus, 1, 0.82, 0, 1, 1, 1)

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("The next skill-up estimate is the typical number of catches (and fishing time) " ..
        "your recent skill-ups took. Only catches earn skill, not casts. It appears after your second " ..
        "skill-up.", 0.63, 0.63, 0.63, true)
    GameTooltip:Show()
end

-- One row in the session list: icon, name (quality colored), count; hover for the item tooltip
local function CreateFishRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(parent:GetWidth(), ROW_HEIGHT)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(14, 14)
    icon:SetPoint("LEFT", 2, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- trim the default icon border
    row.icon = icon

    local count = Text(row, "GameFontHighlightSmall")
    count:SetPoint("RIGHT", -4, 0)
    count:SetJustifyH("RIGHT")
    row.countText = count

    local name = Text(row, "GameFontHighlightSmall")
    name:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    name:SetPoint("RIGHT", count, "LEFT", -6, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    row.nameText = name

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.06)

    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.itemID then GameTooltip:SetItemByID(self.itemID) else GameTooltip:SetText(self.fishName) end
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Caught this session:", self.count, 0.5, 0.8, 1, 1, 1, 1)
        local each, source = BB:GetItemValue(self.itemID)
        if each > 0 then
            GameTooltip:AddDoubleLine("Worth (" .. source .. "):", BB.FormatMoney(each * self.count), 0.5, 0.8, 1, 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    -- Shift-click to link it in chat, like a bag item
    row:SetScript("OnClick", function(self)
        local link = self.itemID and select(2, BB.compat.GetItemInfo(self.itemID))
        if link and HandleModifiedItemClick then HandleModifiedItemClick(link) end
    end)
    return row
end

-- "+3 more" when the list runs past the bottom (scroll to see them)
function BB:UpdateMoreText()
    local ui = self.ui
    local scroll = ui.scroll
    local hiddenPixels = scroll:GetVerticalScrollRange() - scroll:GetVerticalScroll()
    local hiddenRows = math.floor(hiddenPixels / ROW_HEIGHT + 0.5)
    ui.moreText:SetText(hiddenRows > 0 and ("+" .. hiddenRows .. " more - scroll") or "")
end

function BB:UpdateFishTrackerUI()
    local ui = self.ui
    if not ui or not ui.trackerFrame then return end

    ui.zoneText:SetText(self.cache.lastZone or GetRealZoneText() or "Unknown")
    self:UpdateStatsLine()

    local fishData = self:GetSortedSessionFish()
    for _, row in ipairs(ui.listItems) do row:Hide() end
    for i, fish in ipairs(fishData) do
        ui.listItems[i] = ui.listItems[i] or CreateFishRow(ui.content)
        local row = ui.listItems[i]
        row:SetPoint("TOPLEFT", ui.content, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row:Show()

        local itemID = self:GetFishItemID(fish.name)
        row.itemID, row.fishName, row.count = itemID, fish.name, fish.count

        -- Icon is available instantly; quality color once the game has the item cached
        local icon = itemID and select(5, BB.compat.GetItemInfoInstant(itemID))
        row.icon:SetTexture(icon or 134400) -- question mark until known
        local quality = itemID and select(3, BB.compat.GetItemInfo(itemID))
        local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
        row.nameText:SetTextColor(color and color.r or 1, color and color.g or 1, color and color.b or 1)
        row.nameText:SetText(fish.name)
        row.countText:SetText(fish.count)
    end
    ui.noFishText:SetShown(#fishData == 0)
    ui.content:SetHeight(math.max(#fishData * ROW_HEIGHT, ROW_HEIGHT))
    ui.scroll:UpdateScrollChildRect()
    self:UpdateMoreText()
end

function BB:UpdateTrackerVisibility()
    if self.ui and self.ui.trackerFrame then
        self.ui.trackerFrame:SetShown(self:GetSetting("showTracker") and true or false)
    end
end

-- Show the tracker when you pick up a fishing pole (and optionally hide it when you put it away).
-- Only reacts when the main hand actually changes between pole and not-pole.
local poleWatcher = CreateFrame("Frame")
poleWatcher:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
poleWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
poleWatcher:SetScript("OnEvent", function(_, event, slot)
    if not BB.db then return end
    if event == "PLAYER_EQUIPMENT_CHANGED" and slot ~= (INVSLOT_MAINHAND or 16) then return end

    local hasPole = BB:IsFishingPoleEquipped()
    if event == "PLAYER_ENTERING_WORLD" then
        BB.hadPoleEquipped = hasPole -- just remember the starting state
        return
    end
    if hasPole == BB.hadPoleEquipped then return end
    BB.hadPoleEquipped = hasPole

    if hasPole and BB:GetSetting("showTrackerWithPole") then
        BB:SetSetting("showTracker", true)
        BB:UpdateTrackerVisibility()
    elseif not hasPole and BB:GetSetting("hideTrackerWithoutPole") then
        BB:SetSetting("showTracker", false)
        BB:UpdateTrackerVisibility()
    end
end)

function BB:SaveTrackerPosition()
    local point, _, relativePoint, x, y = self.ui.trackerFrame:GetPoint()
    self:SetSetting("trackerPosition", { point, relativePoint, x, y })
end

function BB:ResetTrackerPosition()
    if self.ui and self.ui.trackerFrame then
        self.ui.trackerFrame:ClearAllPoints()
        self.ui.trackerFrame:SetPoint("RIGHT", UIParent, "RIGHT", -50, 0)
        self:SaveTrackerPosition()
        print("|cFF80FF80Bobber Buddy|r: Tracker position has been reset.")
    end
end
