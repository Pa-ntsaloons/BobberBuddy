--[[
    BobberBuddy - UI Module
    Handles the fish tracker display and UI interactions
]]

local BB = BobberBuddy

-- Initialize UI components
function BB:InitUI()
    -- Create main frame
    self.ui = {}
    
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
    frame:SetSize(200, 220)
    frame:SetPoint("RIGHT", UIParent, "RIGHT", -50, 0)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    
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
    title:SetText("BobberBuddy Fish Tracker")
    self.ui.title = title
    
    -- Create session text
    local sessionText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sessionText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    sessionText:SetText("Session Catches: 0")
    self.ui.sessionText = sessionText
    
    -- Create total text
    local totalText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    totalText:SetPoint("TOPLEFT", sessionText, "BOTTOMLEFT", 0, -5)
    totalText:SetText("Total Catches: 0")
    self.ui.totalText = totalText
    
    -- Create scroll frame for fish list
    local scrollFrame = CreateFrame("ScrollFrame", "BobberBuddyScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", totalText, "BOTTOMLEFT", 0, -10)
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
    clearButton:SetScript("OnClick", function() BB:ClearSessionFishCount() end)
    
    -- Create reset all button
    local resetButton = CreateFrame("Button", "BobberBuddyResetButton", frame, "UIPanelButtonTemplate")
    resetButton:SetSize(90, 24)
    resetButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 8)
    resetButton:SetText("Reset All")
    resetButton:SetScript("OnClick", function()
        StaticPopup_Show("BOBBERBUDDY_CONFIRM_RESET")
    end)
    
    -- Register escape key to close
    table.insert(UISpecialFrames, "BobberBuddyTrackerFrame")
    
    -- Create confirmation dialog for reset
    StaticPopupDialogs["BOBBERBUDDY_CONFIRM_RESET"] = {
        text = "Are you sure you want to reset all fish tracking data?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function() BB:ClearAllFishCount() end,
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
    
    -- Update session and total counts
    self.ui.sessionText:SetText("Session Catches: " .. self:GetSessionTotalFishCount())
    self.ui.totalText:SetText("Total Catches: " .. self:GetTotalFishCount())
    
    -- Get fish data
    local fishData = self:GetFishDisplayData()
    
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
            nameText:SetWidth(120)
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
    
    -- Update content frame height
    local contentHeight = max(yOffset + 5, 50)
    self.ui.content:SetHeight(contentHeight)
end

-- Toggle tracker visibility
function BB:UpdateTrackerVisibility()
    if self.ui and self.ui.trackerFrame then
        if self.db.showTracker then
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
    end
end
