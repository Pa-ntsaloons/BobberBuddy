--[[
    BobberBuddy - UI Module
    Handles the fish tracker display and UI interactions
]]

<<<<<<< HEAD
-- Check if addon is loaded and create local reference
BobberBuddy = BobberBuddy or {}
=======
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
local BB = BobberBuddy

-- Initialize UI components
function BB:InitUI()
    -- Create main frame
    self.ui = {}
    
<<<<<<< HEAD
    -- Check if we're in WoW environment
    if not CreateFrame then
        print("BobberBuddy: Not running in WoW environment, skipping UI initialization")
        return
    end
    
=======
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
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
<<<<<<< HEAD
    frame:SetSize(240, 280) -- Larger to accommodate more info
    
    -- Get saved position or use default
    local position = self:GetSetting("trackerPosition") or {"RIGHT", UIParent, "RIGHT", -50, 0}
    frame:SetPoint(position[1], position[2], position[3], position[4], position[5])
    
=======
    frame:SetSize(200, 220)
    frame:SetPoint("RIGHT", UIParent, "RIGHT", -50, 0)
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
<<<<<<< HEAD
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        
        -- Save position
        local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
        BB:SetSetting("trackerPosition", {point, relativeTo, relativePoint, xOfs, yOfs})
    end)
=======
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
    
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
<<<<<<< HEAD
    title:SetText("BobberBuddy")
    self.ui.title = title
    
    -- Create zone text
    local zoneText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    zoneText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    zoneText:SetText("Zone: " .. (self.cache.lastZone or GetRealZoneText() or "Unknown"))
    self.ui.zoneText = zoneText
    
    -- Create session text
    local sessionText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sessionText:SetPoint("TOPLEFT", zoneText, "BOTTOMLEFT", 0, -5)
=======
    title:SetText("BobberBuddy Fish Tracker")
    self.ui.title = title
    
    -- Create session text
    local sessionText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sessionText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
    sessionText:SetText("Session Catches: 0")
    self.ui.sessionText = sessionText
    
    -- Create total text
    local totalText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    totalText:SetPoint("TOPLEFT", sessionText, "BOTTOMLEFT", 0, -5)
    totalText:SetText("Total Catches: 0")
    self.ui.totalText = totalText
    
<<<<<<< HEAD
    -- Create fishing stats
    local statsText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statsText:SetPoint("TOPLEFT", totalText, "BOTTOMLEFT", 0, -5)
    statsText:SetText("Casts: 0  |  Time: 0:00")
    self.ui.statsText = statsText
    
    -- Create session label
    local sessionLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sessionLabel:SetPoint("TOPLEFT", statsText, "BOTTOMLEFT", 0, -10)
    sessionLabel:SetText("Session Fish:")
    sessionLabel:SetTextColor(1, 0.8, 0)
    
    -- Create scroll frame for fish list
    local scrollFrame = CreateFrame("ScrollFrame", "BobberBuddyScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", sessionLabel, "BOTTOMLEFT", 0, -5)
=======
    -- Create scroll frame for fish list
    local scrollFrame = CreateFrame("ScrollFrame", "BobberBuddyScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", totalText, "BOTTOMLEFT", 0, -10)
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 35)
    self.ui.scrollFrame = scrollFrame
    
    -- Create content frame for scroll frame
    local content = CreateFrame("Frame", "BobberBuddyScrollFrameContent", scrollFrame)
    content:SetSize(scrollFrame:GetWidth(), 400) -- Make it taller than visible area for scrolling
    scrollFrame:SetScrollChild(content)
    self.ui.content = content
    
    -- Create close button
    local closeButton = CreateFrame("Button", "BobberBuddyCloseButton", frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    
    -- Create clear session button
    local clearButton = CreateFrame("Button", "BobberBuddyClearButton", frame, "UIPanelButtonTemplate")
    clearButton:SetSize(90, 24)
    clearButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 8)
    clearButton:SetText("Clear Session")
<<<<<<< HEAD
    clearButton:SetScript("OnClick", function() BB:ClearSessionData() end)
    
    -- Create settings button
    local settingsButton = CreateFrame("Button", "BobberBuddySettingsButton", frame, "UIPanelButtonTemplate")
    settingsButton:SetSize(90, 24)
    settingsButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 8)
    settingsButton:SetText("Settings")
    settingsButton:SetScript("OnClick", function() BB:OpenSettings() end)
=======
    clearButton:SetScript("OnClick", function() BB:ClearSessionFishCount() end)
    
    -- Create reset all button
    local resetButton = CreateFrame("Button", "BobberBuddyResetButton", frame, "UIPanelButtonTemplate")
    resetButton:SetSize(90, 24)
    resetButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 8)
    resetButton:SetText("Reset All")
    resetButton:SetScript("OnClick", function()
        StaticPopup_Show("BOBBERBUDDY_CONFIRM_RESET")
    end)
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
    
    -- Register escape key to close
    table.insert(UISpecialFrames, "BobberBuddyTrackerFrame")
    
    -- Create confirmation dialog for reset
    StaticPopupDialogs["BOBBERBUDDY_CONFIRM_RESET"] = {
<<<<<<< HEAD
        text = "Are you sure you want to reset all fish tracking data?\nThis cannot be undone!",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function() BB:ClearAllData() end,
=======
        text = "Are you sure you want to reset all fish tracking data?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function() BB:ClearAllFishCount() end,
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    
    -- Initialize list items
    self.ui.listItems = {}
    self:UpdateFishTrackerUI()
end

-- Update fish tracker UI
function BB:UpdateFishTrackerUI()
    if not self.ui or not self.ui.trackerFrame then return end
    
<<<<<<< HEAD
    -- Update zone information
    local currentZone = self.cache.lastZone or GetRealZoneText() or "Unknown"
    self.ui.zoneText:SetText("Zone: " .. currentZone)
    
    -- Update session and total counts
    local sessionTotal = self:GetSessionTotal()
    local lifetimeTotal = self:GetLifetimeTotal()
    
    self.ui.sessionText:SetText("Session Catches: " .. sessionTotal)
    self.ui.totalText:SetText("Total Catches: " .. lifetimeTotal)
    
    -- Update stats
    local casts = self.db.stats.fishingCasts or 0
    local timeSpent = self.db.stats.timeSpentFishing or 0
    self.ui.statsText:SetText("Casts: " .. casts .. "  |  Time: " .. SecondsToTime(timeSpent))
    
    -- Get fish data
    local fishData = self:GetSortedSessionFish()
=======
    -- Update session and total counts
    self.ui.sessionText:SetText("Session Catches: " .. self:GetSessionTotalFishCount())
    self.ui.totalText:SetText("Total Catches: " .. self:GetTotalFishCount())
    
    -- Get fish data
    local fishData = self:GetFishDisplayData()
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
    
    -- Clear existing list items
    for _, item in ipairs(self.ui.listItems or {}) do
        item:Hide()
    end
    
    -- Create or update list items
    local yOffset = 5
    for i, fish in ipairs(fishData) do
        -- Create new list item if needed
        if not self.ui.listItems[i] then
            local item = CreateFrame("Frame", "BobberBuddyListItem" .. i, self.ui.content)
            item:SetSize(self.ui.content:GetWidth() - 10, 20)
            
            local nameText = item:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            nameText:SetPoint("LEFT", item, "LEFT", 5, 0)
            nameText:SetJustifyH("LEFT")
<<<<<<< HEAD
            nameText:SetWidth(150)
=======
            nameText:SetWidth(120)
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
            item.nameText = nameText
            
            local countText = item:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            countText:SetPoint("RIGHT", item, "RIGHT", -5, 0)
            countText:SetJustifyH("RIGHT")
            item.countText = countText
            
            self.ui.listItems[i] = item
        end
        
        -- Update list item
        local item = self.ui.listItems[i]
        item:Show()
        item:SetPoint("TOPLEFT", self.ui.content, "TOPLEFT", 5, -yOffset)
        
        item.nameText:SetText(fish.name)
        item.countText:SetText(fish.count)
        
        yOffset = yOffset + 20
    end
    
<<<<<<< HEAD
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
=======
    -- Update content frame height
    local contentHeight = max(yOffset + 5, 50)
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
    self.ui.content:SetHeight(contentHeight)
end

-- Toggle tracker visibility
function BB:UpdateTrackerVisibility()
    if self.ui and self.ui.trackerFrame then
<<<<<<< HEAD
        local showTracker = self:GetSetting("showTracker")
        if showTracker then
=======
        if self.db.showTracker then
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
            self.ui.trackerFrame:Show()
        else
            self.ui.trackerFrame:Hide()
        end
    end
end

-- Reset tracker position
function BB:ResetTrackerPosition()
    if self.ui and self.ui.trackerFrame then
        self.ui.trackerFrame:ClearAllPoints()
        self.ui.trackerFrame:SetPoint("RIGHT", UIParent, "RIGHT", -50, 0)
<<<<<<< HEAD
        
        -- Save the new position
        local point, relativeTo, relativePoint, xOfs, yOfs = self.ui.trackerFrame:GetPoint()
        self:SetSetting("trackerPosition", {point, relativeTo, relativePoint, xOfs, yOfs})
        
        print("|cFF80FF80BobberBuddy|r: Tracker position has been reset.")
=======
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
    end
end
