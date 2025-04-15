local addonName, BobberBuddy = ...
local settingsFrame = nil
local minimapButton = nil

-- Default settings
BobberBuddyDB = BobberBuddyDB or {}
BobberBuddyDB.debugEnabled = BobberBuddyDB.debugEnabled or false

-- Function to toggle debug messages
function BobberBuddy:ToggleDebugMessages(enabled)
    BobberBuddyDB.debugEnabled = enabled
    if enabled then
        print("BobberBuddy: Debug messages enabled.")
    else
        print("BobberBuddy: Debug messages disabled.")
    end
end

-- Function to print debug messages (only if debug is enabled)
function BobberBuddy:DebugPrint(message)
    if BobberBuddyDB.debugEnabled then
        print("BobberBuddy Debug: " .. message)
    end
end

-- Create the settings menu
function BobberBuddy:CreateSettingsMenu()
    if settingsFrame then return end

    settingsFrame = CreateFrame("Frame", "BobberBuddySettingsFrame", UIParent)
    settingsFrame.name = "BobberBuddy"
    local category = Settings.RegisterCanvasLayoutCategory(settingsFrame, "BobberBuddy")
    Settings.RegisterAddOnCategory(category)

    local title = settingsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("BobberBuddy Settings")

    local debugCheckbox = CreateFrame("CheckButton", nil, settingsFrame, "InterfaceOptionsCheckButtonTemplate")
    debugCheckbox:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    debugCheckbox.Text:SetText("Enable Debug Messages")
    debugCheckbox:SetChecked(BobberBuddyDB.debugEnabled)
    debugCheckbox:SetScript("OnClick", function(self)
        BobberBuddy:ToggleDebugMessages(self:GetChecked())
    end)
end

-- Create the minimap button
function BobberBuddy:CreateMinimapButton()
    if minimapButton then return end

    minimapButton = CreateFrame("Button", "BobberBuddyMinimapButton", Minimap)
    minimapButton:SetSize(32, 32)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(8)
    minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\inv_fishingpole_02") -- Fishing pole icon
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    minimapButton.icon = icon

    minimapButton:SetScript("OnClick", function(_, button)
        if button == "LeftButton" then
            Settings.OpenToCategory("BobberBuddy")
            Settings.OpenToCategory("BobberBuddy") -- Call twice to ensure it opens
        elseif button == "RightButton" then
            BobberBuddy:ToggleDebugMessages(not BobberBuddyDB.debugEnabled)
        end
    end)

    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("BobberBuddy", 1, 1, 1)
        GameTooltip:AddLine("Left-Click: Open Settings", 1, 1, 1)
        GameTooltip:AddLine("Right-Click: Toggle Debug Messages", 1, 1, 1)
        GameTooltip:Show()
    end)

    minimapButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Position the minimap button
    minimapButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -10, -10)
end

-- Initialize the settings menu and minimap button
function BobberBuddy:InitializeSettings()
    self:CreateSettingsMenu()
    self:CreateMinimapButton()
end