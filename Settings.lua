--[[
    BobberBuddy - Settings Module
    Handles the addon configuration panel
]]

local BB = BobberBuddy

-- Initialize settings panel
function BB:InitSettings()
    -- Create main options panel
    self.optionsPanel = CreateFrame("Frame", "BobberBuddyOptionsPanel")
    self.optionsPanel.name = "BobberBuddy"
    InterfaceOptions_AddCategory(self.optionsPanel)
    
    -- Title
    local title = self.optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("BobberBuddy Options")
    
    -- Version
    local version = self.optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    version:SetText("Version: " .. self.version)
    
    local lastElement = version
    local yOffset = -20
    
    -- Enable Auto Lure checkbox
    local lureCheckbox = CreateFrame("CheckButton", "BobberBuddyLureCheckbox", self.optionsPanel, "InterfaceOptionsCheckButtonTemplate")
    lureCheckbox:SetPoint("TOPLEFT", lastElement, "BOTTOMLEFT", 0, yOffset)
    BobberBuddyLureCheckboxText:SetText("Automatically apply fishing lures")
    lureCheckbox.tooltipText = "When enabled, BobberBuddy will automatically apply the best available lure to your fishing pole"
    lureCheckbox:SetChecked(self.db.enableAutoLure)
    lureCheckbox:SetScript("OnClick", function(self)
        BB.db.enableAutoLure = self:GetChecked()
    end)
    
    lastElement = lureCheckbox
    
    -- Enable Auto Bobber Click checkbox
    local bobberCheckbox = CreateFrame("CheckButton", "BobberBuddyBobberCheckbox", self.optionsPanel, "InterfaceOptionsCheckButtonTemplate")
    bobberCheckbox:SetPoint("TOPLEFT", lastElement, "BOTTOMLEFT", 0, -8)
    BobberBuddyBobberCheckboxText:SetText("Automatically click fishing bobber")
    bobberCheckbox.tooltipText = "When enabled, BobberBuddy will automatically click the fishing bobber when it splashes"
    bobberCheckbox:SetChecked(self.db.enableAutoBobberClick)
    bobberCheckbox:SetScript("OnClick", function(self)
        BB.db.enableAutoBobberClick = self:GetChecked()
    end)
    
    lastElement = bobberCheckbox
    
    -- Show Tracker checkbox
    local trackerCheckbox = CreateFrame("CheckButton", "BobberBuddyTrackerCheckbox", self.optionsPanel, "InterfaceOptionsCheckButtonTemplate")
    trackerCheckbox:SetPoint("TOPLEFT", lastElement, "BOTTOMLEFT", 0, -8)
    BobberBuddyTrackerCheckboxText:SetText("Show Fish Tracker window")
    trackerCheckbox.tooltipText = "When enabled, the fish tracker window will be shown"
    trackerCheckbox:SetChecked(self.db.showTracker)
    trackerCheckbox:SetScript("OnClick", function(self)
        BB.db.showTracker = self:GetChecked()
        BB:UpdateTrackerVisibility()
    end)
    
    lastElement = trackerCheckbox
    
    -- Keybinding section
    local keybindTitle = self.optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    keybindTitle:SetPoint("TOPLEFT", lastElement, "BOTTOMLEFT", 0, -20)
    keybindTitle:SetText("Keybinding")
    
    local keybindInfo = self.optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    keybindInfo:SetPoint("TOPLEFT", keybindTitle, "BOTTOMLEFT", 0, -8)
    keybindInfo:SetText("Set your BobberBuddy fishing key in Blizzard's Key Bindings menu (under AddOns category).")
    
    lastElement = keybindInfo
    
    -- Reset Tracker Position button
    local resetButton = CreateFrame("Button", "BobberBuddyResetPosButton", self.optionsPanel, "UIPanelButtonTemplate")
    resetButton:SetSize(150, 24)
    resetButton:SetPoint("TOPLEFT", lastElement, "BOTTOMLEFT", 0, -20)
    resetButton:SetText("Reset Tracker Position")
    resetButton:SetScript("OnClick", function() BB:ResetTrackerPosition() end)
    
    lastElement = resetButton
    
    -- Clear Session button
    local clearSessionButton = CreateFrame("Button", "BobberBuddyClearSessionButton", self.optionsPanel, "UIPanelButtonTemplate")
    clearSessionButton:SetSize(150, 24)
    clearSessionButton:SetPoint("TOPLEFT", lastElement, "BOTTOMLEFT", 0, -8)
    clearSessionButton:SetText("Clear Session Tracking")
    clearSessionButton:SetScript("OnClick", function() BB:ClearSessionFishCount() end)
    
    lastElement = clearSessionButton
    
    -- Reset All Data button
    local resetAllButton = CreateFrame("Button", "BobberBuddyResetAllButton", self.optionsPanel, "UIPanelButtonTemplate")
    resetAllButton:SetSize(150, 24)
    resetAllButton:SetPoint("TOPLEFT", lastElement, "BOTTOMLEFT", 0, -8)
    resetAllButton:SetText("Reset All Fish Data")
    resetAllButton:SetScript("OnClick", function()
        StaticPopup_Show("BOBBERBUDDY_CONFIRM_RESET")
    end)
    
    -- Set up open settings function
    function BB:OpenSettings()
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
        -- Sometimes needs to be called twice to actually open the panel
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
    end
end
