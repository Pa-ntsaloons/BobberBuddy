--[[
    BobberBuddy - Settings Module
    Handles the addon configuration panel
]]

<<<<<<< HEAD
-- Check if addon is loaded and create local reference
BobberBuddy = BobberBuddy or {}
=======
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
local BB = BobberBuddy

-- Initialize settings panel
function BB:InitSettings()
<<<<<<< HEAD
    -- Check if we're in WoW environment
    if not CreateFrame then
        print("BobberBuddy: Not running in WoW environment, skipping UI initialization")
        return
    end
    
    -- Create main options panel
    self.optionsPanel = CreateFrame("Frame", "BobberBuddyOptionsPanel")
    self.optionsPanel.name = "BobberBuddy"
    
    -- Check if InterfaceOptions_AddCategory exists (WoW API function)
    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(self.optionsPanel)
    else
        print("BobberBuddy: InterfaceOptions_AddCategory not available")
    end
=======
    -- Create main options panel
    self.optionsPanel = CreateFrame("Frame", "BobberBuddyOptionsPanel")
    self.optionsPanel.name = "BobberBuddy"
    InterfaceOptions_AddCategory(self.optionsPanel)
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
    
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
    
<<<<<<< HEAD
    -- Settings scope selection
    local scopeTitle = self.optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    scopeTitle:SetPoint("TOPLEFT", lastElement, "BOTTOMLEFT", 0, yOffset)
    scopeTitle:SetText("Settings Scope")
    
    -- Create radio buttons for scope
    local characterRadio = CreateFrame("CheckButton", "BobberBuddyCharacterRadio", self.optionsPanel, "UIRadioButtonTemplate")
    characterRadio:SetPoint("TOPLEFT", scopeTitle, "BOTTOMLEFT", 0, -8)
    BobberBuddyCharacterRadioText:SetText("Character Specific")
    
    local globalRadio = CreateFrame("CheckButton", "BobberBuddyGlobalRadio", self.optionsPanel, "UIRadioButtonTemplate")
    globalRadio:SetPoint("LEFT", characterRadio, "RIGHT", 130, 0)
    BobberBuddyGlobalRadioText:SetText("Account Wide")
    
    -- Set initial value based on where settings are coming from
    local isGlobalSettings = (BB.db.settings.enableAutoLure == nil)
    characterRadio:SetChecked(not isGlobalSettings)
    globalRadio:SetChecked(isGlobalSettings)
    
    -- Track current scope for use in checkboxes
    local settingsScope = isGlobalSettings and "global" or "character"
    
    -- Click handlers for radio buttons
    characterRadio:SetScript("OnClick", function()
        characterRadio:SetChecked(true)
        globalRadio:SetChecked(false)
        settingsScope = "character"
        
        -- Refresh checkboxes to show character values
        lureCheckbox:SetChecked(BB:GetSetting("enableAutoLure"))
        bobberCheckbox:SetChecked(BB:GetSetting("enableAutoBobberClick"))
        trackerCheckbox:SetChecked(BB:GetSetting("showTracker"))
    end)
    
    globalRadio:SetScript("OnClick", function()
        characterRadio:SetChecked(false)
        globalRadio:SetChecked(true)
        settingsScope = "global"
        
        -- Refresh checkboxes to show global values
        lureCheckbox:SetChecked(BB.globalDB.settings.enableAutoLure)
        bobberCheckbox:SetChecked(BB.globalDB.settings.enableAutoBobberClick)
        trackerCheckbox:SetChecked(BB.globalDB.settings.showTracker)
    end)
    
    lastElement = characterRadio
    
    -- Enable Auto Lure checkbox
    local lureCheckbox = CreateFrame("CheckButton", "BobberBuddyLureCheckbox", self.optionsPanel, "InterfaceOptionsCheckButtonTemplate")
    lureCheckbox:SetPoint("TOPLEFT", lastElement, "BOTTOMLEFT", 0, -20)
    BobberBuddyLureCheckboxText:SetText("Automatically apply fishing lures")
    lureCheckbox.tooltipText = "When enabled, BobberBuddy will automatically apply the best available lure to your fishing pole"
    lureCheckbox:SetChecked(BB:GetSetting("enableAutoLure"))
    lureCheckbox:SetScript("OnClick", function(self)
        local isChecked = self:GetChecked()
        local isGlobal = (settingsScope == "global")
        BB:SetSetting("enableAutoLure", isChecked, isGlobal)
=======
    -- Enable Auto Lure checkbox
    local lureCheckbox = CreateFrame("CheckButton", "BobberBuddyLureCheckbox", self.optionsPanel, "InterfaceOptionsCheckButtonTemplate")
    lureCheckbox:SetPoint("TOPLEFT", lastElement, "BOTTOMLEFT", 0, yOffset)
    BobberBuddyLureCheckboxText:SetText("Automatically apply fishing lures")
    lureCheckbox.tooltipText = "When enabled, BobberBuddy will automatically apply the best available lure to your fishing pole"
    lureCheckbox:SetChecked(self.db.enableAutoLure)
    lureCheckbox:SetScript("OnClick", function(self)
        BB.db.enableAutoLure = self:GetChecked()
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
    end)
    
    lastElement = lureCheckbox
    
    -- Enable Auto Bobber Click checkbox
    local bobberCheckbox = CreateFrame("CheckButton", "BobberBuddyBobberCheckbox", self.optionsPanel, "InterfaceOptionsCheckButtonTemplate")
    bobberCheckbox:SetPoint("TOPLEFT", lastElement, "BOTTOMLEFT", 0, -8)
    BobberBuddyBobberCheckboxText:SetText("Automatically click fishing bobber")
    bobberCheckbox.tooltipText = "When enabled, BobberBuddy will automatically click the fishing bobber when it splashes"
<<<<<<< HEAD
    bobberCheckbox:SetChecked(BB:GetSetting("enableAutoBobberClick"))
    bobberCheckbox:SetScript("OnClick", function(self)
        local isChecked = self:GetChecked()
        local isGlobal = (settingsScope == "global")
        BB:SetSetting("enableAutoBobberClick", isChecked, isGlobal)
=======
    bobberCheckbox:SetChecked(self.db.enableAutoBobberClick)
    bobberCheckbox:SetScript("OnClick", function(self)
        BB.db.enableAutoBobberClick = self:GetChecked()
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
    end)
    
    lastElement = bobberCheckbox
    
    -- Show Tracker checkbox
    local trackerCheckbox = CreateFrame("CheckButton", "BobberBuddyTrackerCheckbox", self.optionsPanel, "InterfaceOptionsCheckButtonTemplate")
    trackerCheckbox:SetPoint("TOPLEFT", lastElement, "BOTTOMLEFT", 0, -8)
    BobberBuddyTrackerCheckboxText:SetText("Show Fish Tracker window")
    trackerCheckbox.tooltipText = "When enabled, the fish tracker window will be shown"
<<<<<<< HEAD
    trackerCheckbox:SetChecked(BB:GetSetting("showTracker"))
    trackerCheckbox:SetScript("OnClick", function(self)
        local isChecked = self:GetChecked()
        local isGlobal = (settingsScope == "global")
        BB:SetSetting("showTracker", isChecked, isGlobal)
=======
    trackerCheckbox:SetChecked(self.db.showTracker)
    trackerCheckbox:SetScript("OnClick", function(self)
        BB.db.showTracker = self:GetChecked()
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
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
    
<<<<<<< HEAD
    -- Create fishing stats section
    local statsTitle = self.optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    statsTitle:SetPoint("TOPLEFT", lastElement, "BOTTOMLEFT", 0, -20)
    statsTitle:SetText("Fishing Statistics")
    
    local statsText = self.optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    statsText:SetPoint("TOPLEFT", statsTitle, "BOTTOMLEFT", 0, -8)
    statsText:SetText("")
    
    -- Function to update stats text
    local function UpdateStatsText()
        local sessionTotal = BB:GetSessionTotal()
        local lifetimeTotal = BB:GetLifetimeTotal()
        local casts = BB.db.stats.fishingCasts or 0
        local timeSpent = BB.db.stats.timeSpentFishing or 0
        local formattedTime = SecondsToTime(timeSpent)
        
        statsText:SetText(
            "Session fish: " .. sessionTotal .. "  |  " ..
            "Lifetime fish: " .. lifetimeTotal .. "\n" ..
            "Fishing casts: " .. casts .. "  |  " ..
            "Time spent: " .. formattedTime
        )
    end
    
    -- Initial update
    UpdateStatsText()
    
    lastElement = statsText
    
    -- Data management section
    local dataTitle = self.optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    dataTitle:SetPoint("TOPLEFT", lastElement, "BOTTOMLEFT", 0, -20)
    dataTitle:SetText("Data Management")
    
    lastElement = dataTitle
    
=======
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
    -- Clear Session button
    local clearSessionButton = CreateFrame("Button", "BobberBuddyClearSessionButton", self.optionsPanel, "UIPanelButtonTemplate")
    clearSessionButton:SetSize(150, 24)
    clearSessionButton:SetPoint("TOPLEFT", lastElement, "BOTTOMLEFT", 0, -8)
    clearSessionButton:SetText("Clear Session Tracking")
<<<<<<< HEAD
    clearSessionButton:SetScript("OnClick", function() 
        BB:ClearSessionData()
        UpdateStatsText()
    end)
=======
    clearSessionButton:SetScript("OnClick", function() BB:ClearSessionFishCount() end)
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
    
    lastElement = clearSessionButton
    
    -- Reset All Data button
    local resetAllButton = CreateFrame("Button", "BobberBuddyResetAllButton", self.optionsPanel, "UIPanelButtonTemplate")
    resetAllButton:SetSize(150, 24)
    resetAllButton:SetPoint("TOPLEFT", lastElement, "BOTTOMLEFT", 0, -8)
    resetAllButton:SetText("Reset All Fish Data")
    resetAllButton:SetScript("OnClick", function()
<<<<<<< HEAD
        if StaticPopup_Show then
            StaticPopup_Show("BOBBERBUDDY_CONFIRM_RESET")
        else
            print("BobberBuddy: Confirmation dialogs not available outside of WoW")
            -- Direct reset as fallback
            if BB.ClearAllData then
                BB:ClearAllData()
            end
        end
    end)
    
    -- Update the stats whenever the panel is shown
    self.optionsPanel:SetScript("OnShow", function()
        UpdateStatsText()
=======
        StaticPopup_Show("BOBBERBUDDY_CONFIRM_RESET")
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
    end)
    
    -- Set up open settings function
    function BB:OpenSettings()
<<<<<<< HEAD
        -- Check if WoW interface function exists
        if InterfaceOptionsFrame_OpenToCategory then
            InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
            -- Sometimes needs to be called twice to actually open the panel
            InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
        else
            print("BobberBuddy: Settings panel cannot be opened outside of WoW")
        end
=======
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
        -- Sometimes needs to be called twice to actually open the panel
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
    end
end
