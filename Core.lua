--[[
    BobberBuddy - Core Module
    Main functionality for the fishing automation
]]

-- Create addon namespace and initialize variables
BobberBuddy = {}
local BB = BobberBuddy
BB.name = "BobberBuddy"
BB.version = GetAddOnMetadata("BobberBuddy", "Version")
BB.isRetail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
BB.isClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
BB.isTBC = WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC
BB.isWrath = WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC

-- Default settings
BB.defaults = {
    enableAutoLure = true,
    enableAutoBobberClick = true,
    showTracker = true,
    hotkey = "F2",
}

-- Initialize saved variables
BB.db = {}

-- Constants
local FISHING_SPELL_ID = 131474 -- Retail spell ID
local FISHING_SPELL_ID_CLASSIC = 7620 -- Classic spell ID
local FISHING_SPELL_NAME = "Fishing"

-- Lure information (ID, bonus)
local LURES = {
    -- Items that can be applied to fishing poles to increase skill
    -- Format: [itemID] = {bonus, duration}
    [34861] = {100, 10}, -- Sharpened Fish Hook (+100 for 10 min)
    [6533] = {100, 10},  -- Aquadynamic Fish Attractor (+100 for 10 min)
    [7307] = {75, 10},   -- Flesh Eating Worm (+75 for 10 min)
    [6532] = {75, 10},   -- Bright Baubles (+75 for 10 min)
    [6530] = {50, 10},   -- Nightcrawlers (+50 for 10 min)
    [6529] = {25, 10},   -- Shiny Bauble (+25 for 10 min)
    -- Retail lures
    [116825] = {200, 10}, -- Bladebone Hook
    [133717] = {150, 10}, -- Leyshimmer Blenny
    [133720] = {200, 10}, -- Leyshimmer Blenny' Sleeping with the Fishes
    [133795] = {100, 10}, -- Underlight Angler
    [168302] = {100, 10}, -- Scarlet Herring Lure 
    [165699] = {100, 10}, -- Drain Minnow
}

-- Fishing pole item types
local FISHING_POLE_TYPES = {
    "Fishing Pole",
    "Fishing Rod"
}

-- Initialize the addon
function BB:Init()
    -- Set up saved variables
    if not BobberBuddyDB then
        BobberBuddyDB = {}
    end
    
    -- Initialize settings with defaults for missing values
    for key, value in pairs(self.defaults) do
        if BobberBuddyDB[key] == nil then
            BobberBuddyDB[key] = value
        end
    end
    
    self.db = BobberBuddyDB
    
    -- Register events
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("LOOT_OPENED")
    frame:SetScript("OnEvent", function(self, event, ...)
        if event == "ADDON_LOADED" and ... == BB.name then
            BB:OnAddonLoaded()
        elseif event == "LOOT_OPENED" then
            BB:OnLootOpened()
        end
    end)
    
    -- Set up fishing hotkey
    self:SetupHotkey()
    
    -- Initialize modules
    self:InitFishTracker()
    self:InitUI()
    self:InitSettings()
    
    print("|cFF80FF80" .. self.name .. " v" .. self.version .. " loaded. Type /bb or /bobberbuddy for options.|r")
end

-- Called when addon is fully loaded
function BB:OnAddonLoaded()
    -- Additional initialization if needed
end

-- Create keybinding for fishing
function BB:SetupHotkey()
    -- Create fishing secure button
    local fishingButton = CreateFrame("Button", "BobberBuddyFishingButton", nil, "SecureActionButtonTemplate")
    fishingButton:SetAttribute("type", "macro")
    fishingButton:SetAttribute("macrotext", "/click BobberBuddyFishingMacro")
    
    -- Create secure macro button
    local macroButton = CreateFrame("Button", "BobberBuddyFishingMacro", nil, "SecureActionButtonTemplate")
    macroButton:SetScript("PreClick", function() BB:PreFishing() end)
    macroButton:SetAttribute("type", "macro")
    macroButton:SetAttribute("macrotext", "/cast " .. FISHING_SPELL_NAME)
    
    -- Register with key binding UI
    _G["BINDING_NAME_CLICK BobberBuddyFishingButton:LeftButton"] = "BobberBuddy: Fish"
    
    -- Register slash commands
    SLASH_BOBBERBUDDY1 = "/bobberbuddy"
    SLASH_BOBBERBUDDY2 = "/bb"
    SlashCmdList["BOBBERBUDDY"] = function(msg)
        BB:HandleSlashCommand(msg)
    end
end

-- Process slash commands
function BB:HandleSlashCommand(msg)
    local args = {}
    for arg in string.gmatch(msg, "%S+") do
        table.insert(args, string.lower(arg))
    end
    
    if #args == 0 or args[1] == "help" then
        print("|cFF80FF80BobberBuddy Commands:|r")
        print("  |cFFFFFF00/bb|r or |cFFFFFF00/bobberbuddy|r - Show this help")
        print("  |cFFFFFF00/bb toggle|r - Toggle fish tracker display")
        print("  |cFFFFFF00/bb reset|r - Reset fish tracker position")
        print("  |cFFFFFF00/bb config|r - Open configuration panel")
    elseif args[1] == "toggle" then
        self.db.showTracker = not self.db.showTracker
        self:UpdateTrackerVisibility()
    elseif args[1] == "reset" then
        self:ResetTrackerPosition()
    elseif args[1] == "config" then
        self:OpenSettings()
    end
end

-- Called before fishing action
function BB:PreFishing()
    -- Check if we need to equip a fishing pole
    if not self:IsFishingPoleEquipped() then
        self:EquipBestFishingPole()
    end
    
    -- Check if we need to apply a lure
    if self.db.enableAutoLure and not self:HasActiveLure() then
        self:ApplyBestLure()
    end
    
    -- Set up post-cast action for bobber clicking
    if self.db.enableAutoBobberClick then
        C_Timer.After(0.5, function() self:WatchForBobber() end)
    end
end

-- Check if a fishing pole is currently equipped
function BB:IsFishingPoleEquipped()
    local mainHandLink = GetInventoryItemLink("player", 16) -- 16 is main hand slot
    if not mainHandLink then return false end
    
    local _, _, _, _, _, itemType = GetItemInfo(mainHandLink)
    for _, poleType in ipairs(FISHING_POLE_TYPES) do
        if itemType == poleType then
            return true
        end
    end
    
    return false
end

-- Equip the best fishing pole from bags
function BB:EquipBestFishingPole()
    local bestPoleSlot, bestPoleItem, bestPoleValue = nil, nil, 0
    
    -- Function to scan bags - handles both Classic and Retail API
    local function ScanBags()
        if BB.isRetail then
            -- Retail API
            for bagID = 0, NUM_BAG_SLOTS do
                local slots = C_Container.GetContainerNumSlots(bagID)
                for slot = 1, slots do
                    local itemLink = C_Container.GetContainerItemLink(bagID, slot)
                    if itemLink then
                        local _, _, _, _, _, itemType, itemSubType, _, _, _, itemValue = GetItemInfo(itemLink)
                        for _, poleType in ipairs(FISHING_POLE_TYPES) do
                            if itemType == poleType and itemValue > bestPoleValue then
                                bestPoleValue = itemValue
                                bestPoleSlot = slot
                                bestPoleItem = itemLink
                                bestPoleBag = bagID
                            end
                        end
                    end
                end
            end
            
            -- Equip the best pole if found
            if bestPoleSlot and bestPoleBag then
                C_Container.PickupContainerItem(bestPoleBag, bestPoleSlot)
                EquipCursorItem(16) -- 16 is main hand slot
                return true
            end
        else
            -- Classic API
            for bagID = 0, NUM_BAG_SLOTS do
                local slots = GetContainerNumSlots(bagID)
                for slot = 1, slots do
                    local itemLink = GetContainerItemLink(bagID, slot)
                    if itemLink then
                        local _, _, _, _, _, itemType, itemSubType, _, _, _, itemValue = GetItemInfo(itemLink)
                        for _, poleType in ipairs(FISHING_POLE_TYPES) do
                            if itemType == poleType and itemValue > bestPoleValue then
                                bestPoleValue = itemValue
                                bestPoleSlot = slot
                                bestPoleItem = itemLink
                                bestPoleBag = bagID
                            end
                        end
                    end
                end
            end
            
            -- Equip the best pole if found
            if bestPoleSlot and bestPoleBag then
                PickupContainerItem(bestPoleBag, bestPoleSlot)
                EquipCursorItem(16) -- 16 is main hand slot
                return true
            end
        end
        return false
    end
    
    return ScanBags()
end

-- Check if player has an active lure buff
function BB:HasActiveLure()
    local i = 1
    local name, _, _, _, _, expirationTime = UnitBuff("player", i)
    
    while name do
        if string.find(name, "Fishing Lure") or 
           string.find(name, "Bright Baubles") or 
           string.find(name, "Nightcrawlers") or 
           string.find(name, "Fish Attractor") or 
           string.find(name, "Flesh Eating Worm") or 
           string.find(name, "Shiny Bauble") or 
           string.find(name, "Sharpened Fish Hook") or
           string.find(name, "Bladebone Hook") or
           string.find(name, "Leyshimmer Blenny") or
           string.find(name, "Underlight Angler") then
            return true
        end
        
        i = i + 1
        name, _, _, _, _, expirationTime = UnitBuff("player", i)
    end
    
    return false
end

-- Apply the best available lure from bags
function BB:ApplyBestLure()
    local bestLureID, bestLureBonus, bestLureBag, bestLureSlot = nil, 0, nil, nil
    
    -- Function to scan bags - handles both Classic and Retail API
    local function ScanBags()
        if BB.isRetail then
            -- Retail API
            for bagID = 0, NUM_BAG_SLOTS do
                local slots = C_Container.GetContainerNumSlots(bagID)
                for slot = 1, slots do
                    local itemID = C_Container.GetContainerItemID(bagID, slot)
                    if itemID and LURES[itemID] and LURES[itemID][1] > bestLureBonus then
                        bestLureID = itemID
                        bestLureBonus = LURES[itemID][1]
                        bestLureBag = bagID
                        bestLureSlot = slot
                    end
                end
            end
            
            -- Apply the best lure if found
            if bestLureSlot then
                C_Container.UseContainerItem(bestLureBag, bestLureSlot)
                return true
            end
        else
            -- Classic API
            for bagID = 0, NUM_BAG_SLOTS do
                local slots = GetContainerNumSlots(bagID)
                for slot = 1, slots do
                    local itemID = GetContainerItemID(bagID, slot)
                    if itemID and LURES[itemID] and LURES[itemID][1] > bestLureBonus then
                        bestLureID = itemID
                        bestLureBonus = LURES[itemID][1]
                        bestLureBag = bagID
                        bestLureSlot = slot
                    end
                end
            end
            
            -- Apply the best lure if found
            if bestLureSlot then
                UseContainerItem(bestLureBag, bestLureSlot)
                return true
            end
        end
        return false
    end
    
    return ScanBags()
end

-- Watch for bobber to appear and set up click
function BB:WatchForBobber()
    local bobberWatchFrame = bobberWatchFrame or CreateFrame("Frame")
    local elapsedTime = 0
    local maxWatchTime = 15 -- Maximum time to watch for a bobber (in seconds)
    
    bobberWatchFrame:SetScript("OnUpdate", function(self, elapsed)
        elapsedTime = elapsedTime + elapsed
        
        -- Stop watching if it's been too long
        if elapsedTime > maxWatchTime then
            self:SetScript("OnUpdate", nil)
            return
        end
        
        -- Check if bobber is our target and clickable
        if BB:IsBobberTarget() then
            -- Try clicking the bobber
            self:SetScript("OnUpdate", nil)
            BB:ClickBobber()
        end
    end)
end

-- Check if the current target is a fishing bobber
function BB:IsBobberTarget()
    -- Check if mouse is over a bobber
    local focusedFrame = GetMouseFocus()
    if focusedFrame and focusedFrame:GetName() and string.find(focusedFrame:GetName(), "FishingBobber") then
        return true
    end
    
    -- Check game target
    return (UnitName("softTarget") == "Fishing Bobber" or UnitName("target") == "Fishing Bobber")
end

-- Attempt to click the bobber
function BB:ClickBobber()
    -- Use the interactable target system
    if UnitName("softTarget") == "Fishing Bobber" then
        InteractUnit("softTarget")
    elseif UnitName("target") == "Fishing Bobber" then
        InteractUnit("target")
    else
        -- Try to find and click a bobber frame
        local focusedFrame = GetMouseFocus()
        if focusedFrame and focusedFrame:GetName() and string.find(focusedFrame:GetName(), "FishingBobber") then
            focusedFrame:Click()
        end
    end
end

-- Handle a successful fishing catch
function BB:OnLootOpened()
    local numItems = GetNumLootItems()
    
    for i = 1, numItems do
        local lootIcon, lootName, lootQuantity = GetLootSlotInfo(i)
        local lootLink = GetLootSlotLink(i)
        
        if lootLink then
            local itemID = GetItemInfoFromHyperlink(lootLink)
            local _, _, _, _, _, itemType, itemSubType = GetItemInfo(lootLink)
            
            -- Check if this is a fish item
            if itemType == "Consumable" and 
               (itemSubType == "Meat" or itemSubType == "Fish" or itemSubType == "Food & Drink") or
               -- In Classic/TBC, fish might be categorized differently
               (BB.isClassic and (string.find(lootName:lower(), "fish") or 
                                string.find(lootName:lower(), "eel") or 
                                string.find(lootName:lower(), "crab") or
                                string.find(lootName:lower(), "mackeral") or
                                string.find(lootName:lower(), "herring"))) then
                
                -- Add to fish tracker
                self:AddFishCaught(lootName, lootQuantity)
            end
        end
    end
end

-- Initialize the addon
BB:Init()
