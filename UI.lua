--[[
    BobberBuddy - UI Module
    Handles the fish tracker display and UI interactions
]]

-- Check if addon is loaded and create local reference
BobberBuddy = BobberBuddy or {}
local BB = BobberBuddy

-- Initialize UI components
function BB:InitUI()
    -- Create main frame
    self.ui = {}
    
    -- Check if we're in WoW environment
    if not CreateFrame then
        print("Bobber Buddy: Not running in WoW environment, skipping UI initialization")
        return
    end
    
    -- Create tracker frame
    self:CreateTrackerFrame()
    
    -- Update UI based on settings
    self:UpdateTrackerVisibility()
end

-- Create tracker frame
function BB:CreateTrackerFrame()
    local frame = CreateFrame("Frame", "BobberBuddyTrackerFrame", UIParent, "BackdropTemplate")
    self.ui.trackerFrame = frame
    
    -- Set frame properties
    frame:SetSize(240, 300) -- Larger to accommodate more info
    
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
        -- Closing with Escape or the X button should stay closed (but not Alt+Z hiding the UI)
        if UIParent:IsShown() and BB:GetSetting("showTracker") then
            BB:SetSetting("showTracker", false)
        end
    end)
    
    -- Set backdrop
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    
    -- Create title text
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -15)
    title:SetText("Bobber Buddy")
    self.ui.title = title
    
    -- Create zone text
    local zoneText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    zoneText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    zoneText:SetText("Zone: " .. (self.cache.lastZone or GetRealZoneText() or "Unknown"))
    self.ui.zoneText = zoneText
    
    -- Create session text
    local sessionText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sessionText:SetPoint("TOPLEFT", zoneText, "BOTTOMLEFT", 0, -5)
    sessionText:SetText("Session Catches: 0")
    self.ui.sessionText = sessionText
    
    -- Create total text
    local totalText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    totalText:SetPoint("TOPLEFT", sessionText, "BOTTOMLEFT", 0, -5)
    totalText:SetText("Total Catches: 0")
    self.ui.totalText = totalText
    
    -- Create fishing stats
    local statsText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statsText:SetPoint("TOPLEFT", totalText, "BOTTOMLEFT", 0, -5)
    statsText:SetText("Casts: 0  |  Time: 0:00")
    self.ui.statsText = statsText

    -- Session value and gold per hour (hover for how it's worked out)
    local valueText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valueText:SetPoint("TOPLEFT", statsText, "BOTTOMLEFT", 0, -5)
    self.ui.valueText = valueText

    local valueHover = CreateFrame("Frame", nil, frame)
    valueHover:SetAllPoints(valueText)
    valueHover:SetScript("OnEnter", function(hover)
        GameTooltip:SetOwner(hover, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Session value")
        GameTooltip:AddLine("What this session's catches are worth, plus any coins you fished up. " ..
            "Uses Auctionator's auction prices when it has one, otherwise the vendor price.", 1, 1, 1, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Per hour is measured from your first cast this session. Clear Session restarts it.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    valueHover:SetScript("OnLeave", GameTooltip_Hide)

    -- Tick the time once a second while the window is open and you're fishing
    local sinceTick = 0
    frame:SetScript("OnUpdate", function(_, elapsed)
        sinceTick = sinceTick + elapsed
        if sinceTick >= 1 then
            sinceTick = 0
            if BB.cache.isFishing then BB:UpdateStatsLine() end
        end
    end)
    
    -- Create session label
    local sessionLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sessionLabel:SetPoint("TOPLEFT", valueText, "BOTTOMLEFT", 0, -10)
    sessionLabel:SetText("Session Fish:")
    sessionLabel:SetTextColor(1, 0.8, 0)
    
    -- Create scroll frame for fish list
    local scrollFrame = CreateFrame("ScrollFrame", "BobberBuddyScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", sessionLabel, "BOTTOMLEFT", 0, -5)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 35)
    self.ui.scrollFrame = scrollFrame
    
    -- Create content frame for scroll frame
    local content = CreateFrame("Frame", "BobberBuddyScrollFrameContent", scrollFrame)
    content:SetSize(190, 80) -- height grows with the list in UpdateFishTrackerUI
    scrollFrame:SetScrollChild(content)
    self.ui.content = content
    
    -- Create close button
    local closeButton = CreateFrame("Button", "BobberBuddyCloseButton", frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    
    -- Create clear session button
    local clearButton = CreateFrame("Button", "BobberBuddyClearButton", frame, "UIPanelButtonTemplate")
    clearButton:SetSize(80, 24)
    clearButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 8)
    clearButton:SetText("Clear")
    clearButton:SetScript("OnClick", function() BB:ClearSessionData() end)
    clearButton:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_TOP")
        GameTooltip:SetText("Clear this session's list (your lifetime log is kept)", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    clearButton:SetScript("OnLeave", GameTooltip_Hide)

    -- Fishing log button
    local logButton = CreateFrame("Button", "BobberBuddyLogButton", frame, "UIPanelButtonTemplate")
    logButton:SetSize(60, 24)
    logButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 8)
    logButton:SetText("Log")
    logButton:SetScript("OnClick", function() BB:ToggleFishingLog() end)

    -- Create settings button
    local settingsButton = CreateFrame("Button", "BobberBuddySettingsButton", frame, "UIPanelButtonTemplate")
    settingsButton:SetSize(80, 24)
    settingsButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 8)
    settingsButton:SetText("Settings")
    settingsButton:SetScript("OnClick", function() BB:OpenSettings() end)
    
    -- Register escape key to close
    table.insert(UISpecialFrames, "BobberBuddyTrackerFrame")
    
    -- Create confirmation dialog for reset
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
    
    -- Initialize list items
    self.ui.listItems = {}
    self:UpdateFishTrackerUI()
end

-- Casts and time line; cheap enough to refresh every second
function BB:UpdateStatsLine()
    if not self.ui or not self.ui.statsText then return end
    local casts = self.db.stats.fishingCasts or 0
    self.ui.statsText:SetText("Casts: " .. casts .. "  |  Time: " .. SecondsToTime(self:GetTimeSpentFishing()))

    local perHour = self:GetGoldPerHour()
    self.ui.valueText:SetText("Value: " .. BB.FormatMoney(self:GetSessionValue()) ..
        "  |  " .. (perHour and (BB.FormatMoney(perHour) .. " /hr") or "-- /hr"))
end

-- One row in the session list: icon, name (quality colored), count; hover for the item tooltip
local function CreateFishRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(180, 20)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.icon = icon

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nameText:SetPoint("LEFT", icon, "RIGHT", 5, 0)
    nameText:SetPoint("RIGHT", row, "RIGHT", -30, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    row.nameText = nameText

    local countText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    countText:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    countText:SetJustifyH("RIGHT")
    row.countText = countText

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.08)

    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.itemID then
            GameTooltip:SetItemByID(self.itemID)
        else
            GameTooltip:SetText(self.fishName)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Caught this session:", self.count, 0.5, 0.8, 1, 1, 1, 1)
        local each, source = BB:GetItemValue(self.itemID)
        if each > 0 then
            GameTooltip:AddDoubleLine("Worth (" .. source .. "):",
                BB.FormatMoney(each * self.count), 0.5, 0.8, 1, 1, 1, 1)
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

-- Update fish tracker UI
function BB:UpdateFishTrackerUI()
    if not self.ui or not self.ui.trackerFrame then return end
    
    -- Update zone information
    local currentZone = self.cache.lastZone or GetRealZoneText() or "Unknown"
    self.ui.zoneText:SetText("Zone: " .. currentZone)
    
    -- Update session and total counts
    local sessionTotal = self:GetSessionTotal()
    local lifetimeTotal = self:GetLifetimeTotal()
    
    self.ui.sessionText:SetText("Session Catches: " .. sessionTotal)
    self.ui.totalText:SetText("Total Catches: " .. lifetimeTotal)
    
    self:UpdateStatsLine()

    -- Get fish data
    local fishData = self:GetSortedSessionFish()
    
    -- Clear existing list items
    for _, item in ipairs(self.ui.listItems or {}) do
        item:Hide()
    end
    
    -- Create or update list items
    local yOffset = 5
    for i, fish in ipairs(fishData) do
        self.ui.listItems[i] = self.ui.listItems[i] or CreateFishRow(self.ui.content)
        local row = self.ui.listItems[i]
        row:Show()
        row:SetPoint("TOPLEFT", self.ui.content, "TOPLEFT", 0, -yOffset)

        local itemID = self:GetFishItemID(fish.name)
        row.itemID, row.fishName, row.count = itemID, fish.name, fish.count

        -- Icon is available instantly; quality color once the game has the item cached
        local icon = itemID and select(5, BB.compat.GetItemInfoInstant(itemID))
        row.icon:SetTexture(icon or 134400) -- question mark until known
        local quality = itemID and select(3, BB.compat.GetItemInfo(itemID))
        local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
        if color then
            row.nameText:SetTextColor(color.r, color.g, color.b)
        else
            row.nameText:SetTextColor(1, 1, 1)
        end
        row.nameText:SetText(fish.name)
        row.countText:SetText(fish.count)

        yOffset = yOffset + 20
    end
    
    -- Show a message if no fish caught
    if #fishData == 0 then
        -- Create placeholder text if it doesn't exist
        if not self.ui.noFishText then
            local noFishText = self.ui.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            noFishText:SetPoint("CENTER", self.ui.content, "CENTER", 0, 0)
            noFishText:SetText("No fish caught yet")
            noFishText:SetTextColor(0.7, 0.7, 0.7)
            self.ui.noFishText = noFishText
        end
        self.ui.noFishText:Show()
    else
        -- Hide the placeholder if we have fish
        if self.ui.noFishText then
            self.ui.noFishText:Hide()
        end
    end
    
    -- Update content frame height
    local contentHeight = max(yOffset + 5, 80)
    self.ui.content:SetHeight(contentHeight)
end

-- Toggle tracker visibility
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

-- Reset tracker position
function BB:ResetTrackerPosition()
    if self.ui and self.ui.trackerFrame then
        self.ui.trackerFrame:ClearAllPoints()
        self.ui.trackerFrame:SetPoint("RIGHT", UIParent, "RIGHT", -50, 0)
        self:SaveTrackerPosition()
        print("|cFF80FF80Bobber Buddy|r: Tracker position has been reset.")
    end
end
