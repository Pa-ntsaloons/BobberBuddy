--[[
    BobberBuddy - Core Module
    Main functionality for the fishing automation
]]

-- Create addon namespace and initialize variables
BobberBuddy = {}
local BB = BobberBuddy
BB.name = "BobberBuddy"
<<<<<<< HEAD

-- Check if we're running in WoW environment
if GetAddOnMetadata then
    BB.version = GetAddOnMetadata("BobberBuddy", "Version") or "1.0"
else
    BB.version = "1.0"
end

-- Detect WoW version
if WOW_PROJECT_ID and WOW_PROJECT_MAINLINE then
    BB.isRetail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
    BB.isClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
    BB.isTBC = WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC
    BB.isWrath = WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC
else
    -- Default to Classic for external testing
    BB.isRetail = false
    BB.isClassic = true
    BB.isTBC = false
    BB.isWrath = false
end

-- Provide SecondsToTime function if not available (WoW API function)
if not SecondsToTime then
    function SecondsToTime(seconds)
        local minutes = math.floor(seconds / 60)
        local hours = math.floor(minutes / 60)
        minutes = minutes % 60
        seconds = seconds % 60
        
        if hours > 0 then
            return string.format("%d:%02d:%02d", hours, minutes, seconds)
        else
            return string.format("%d:%02d", minutes, seconds)
        end
    end
end
=======
BB.version = GetAddOnMetadata("BobberBuddy", "Version")
BB.isRetail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
BB.isClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
BB.isTBC = WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC
BB.isWrath = WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f

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
<<<<<<< HEAD
    -- Check if we're in WoW environment
    if not CreateFrame then
        print("BobberBuddy: Not running in WoW environment, skipping initialization")
        return
    end
    
=======
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
    -- Register events
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("LOOT_OPENED")
    frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    frame:RegisterEvent("PLAYER_LOGOUT")
    frame:SetScript("OnEvent", function(self, event, ...)
        if event == "ADDON_LOADED" and ... == BB.name then
            BB:OnAddonLoaded()
        elseif event == "LOOT_OPENED" then
            BB:OnLootOpened()
        elseif event == "PLAYER_EQUIPMENT_CHANGED" then
            BB:OnEquipmentChanged(...)
        elseif event == "ZONE_CHANGED_NEW_AREA" then
            BB:OnZoneChanged()
        elseif event == "PLAYER_LOGOUT" then
            BB:OnLogout()
        end
    end)
    
    -- Set up fishing hotkey
    self:SetupHotkey()
end

-- Handle hotkey press (called from bindings)
function BB:OnHotkey()
    -- This function is called from the keybind in Bindings.xml
    
    -- If bobber is already present, try to click it
    if self:IsBobberTarget() then
        self:ClickBobber()
        return
    end
    
    -- Check if we need to equip a fishing pole
    if not self:IsFishingPoleEquipped() then
        self:EquipBestFishingPole()
    end
    
    -- Check if we need to apply a lure
    local enableAutoLure = self:GetSetting("enableAutoLure")
    if enableAutoLure and not self:HasActiveLure() then
        local lureApplied = self:ApplyBestLure()
        if lureApplied then
            self:TrackLureUsage()
        end
    end
    
    -- Cast fishing
    local fishingSpellID = self.isRetail and FISHING_SPELL_ID or FISHING_SPELL_ID_CLASSIC
    CastSpellByID(fishingSpellID)
    self:TrackFishingCast()
    
    -- Set up post-cast action for bobber clicking
    local enableAutoBobberClick = self:GetSetting("enableAutoBobberClick")
    if enableAutoBobberClick then
        C_Timer.After(0.5, function() self:WatchForBobber() end)
    end
end

-- Called when addon is fully loaded
function BB:OnAddonLoaded()
<<<<<<< HEAD
    -- Initialize cache
    if not self.cache then
        self.cache = {}
    end
    
=======
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
    -- Initialize database first
    self:InitDatabase()
    
    -- Initialize modules after all files are loaded
    self:InitFishTracker()
    self:InitUI()
    self:InitSettings()
    
    -- Check for fishing pole equipped
    self:CheckEquippedFishingPole()
    
    -- Check current zone
    self.cache.lastZone = GetRealZoneText() or "Unknown"
    
    print("|cFF80FF80" .. self.name .. " v" .. self.version .. " loaded. Type /bb or /bobberbuddy for options.|r")
end

-- Called when player changes equipment
function BB:OnEquipmentChanged(slot)
    if slot == 16 or slot == 17 then -- Main hand or offhand
        self:CheckEquippedFishingPole()
    end
end

-- Check if fishing pole is equipped and update tracking
function BB:CheckEquippedFishingPole()
<<<<<<< HEAD
    -- Ensure cache exists
    if not self.cache then
        self.cache = {}
    end
    
=======
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
    self.cache.fishingPoleEquipped = self:IsFishingPoleEquipped()
end

-- Called when player changes zone
function BB:OnZoneChanged()
    local currentZone = GetRealZoneText() or "Unknown"
<<<<<<< HEAD
    
    -- Make sure cache exists before using it
    if not self.cache then
        self.cache = {}
    end
    
=======
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
    self.cache.lastZone = currentZone
end

-- Called when player logs out
function BB:OnLogout()
    -- Save session time
    if self.db and self.db.stats then
        local sessionDuration = time() - (self.db.stats.sessionStartTime or time())
        if sessionDuration > 0 then
            self.db.stats.totalPlayTime = (self.db.stats.totalPlayTime or 0) + sessionDuration
        end
    end
    
<<<<<<< HEAD
    -- Ensure cache exists
    if not self.cache then
        self.cache = {}
    end
    
    -- If currently fishing, track fishing time
    if self.cache.isFishing and self.cache.fishingStart and self.cache.fishingStart > 0 then
=======
    -- If currently fishing, track fishing time
    if self.cache.isFishing and self.cache.fishingStart > 0 then
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
        self:TrackFishingEnd(false)
    end
end

-- Create keybinding for fishing
function BB:SetupHotkey()
<<<<<<< HEAD
    -- Check if we're in WoW environment
    if not CreateFrame then
        print("BobberBuddy: Not running in WoW environment, skipping hotkey setup")
        return
    end
    
=======
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
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
        print("  |cFFFFFF00/bb stats|r - Show fishing statistics")
        print("  |cFFFFFF00/bb clear|r - Clear session fish data")
<<<<<<< HEAD
        print("  |cFFFFFF00/bb clearall|r - Clear all fish tracking data (with confirmation)")
        print("  |cFFFFFF00/bb clearnow|r - Clear all fish tracking data (no confirmation)")
        print("\nBobberBuddy v" .. self.version .. " - Fishing utility addon")
=======
        print("  |cFFFFFF00/bb clearall|r - Clear all fish tracking data")
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
    elseif args[1] == "toggle" then
        self:SetSetting("showTracker", not self:GetSetting("showTracker"))
        self:UpdateTrackerVisibility()
    elseif args[1] == "reset" then
        self:ResetTrackerPosition()
    elseif args[1] == "config" then
        self:OpenSettings()
    elseif args[1] == "stats" then
        self:ShowFishingStats()
    elseif args[1] == "clear" then
        print("|cFF80FF80BobberBuddy|r: Clearing session fish data...")
        self:ClearSessionData()
    elseif args[1] == "clearall" then
<<<<<<< HEAD
        if StaticPopup_Show then
            StaticPopup_Show("BOBBERBUDDY_CONFIRM_RESET")
        else
            print("BobberBuddy: Confirmation dialogs not available outside of WoW")
            print("BobberBuddy: To reset all fish data, type /bb clearnow")
        end
    elseif args[1] == "clearnow" then
        print("BobberBuddy: Clearing all fish data...")
        self:ClearAllData()
=======
        StaticPopup_Show("BOBBERBUDDY_CONFIRM_RESET")
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
    end
end

-- Show fishing statistics
function BB:ShowFishingStats()
    local sessionTotal = self:GetSessionTotal()
    local lifetimeTotal = self:GetLifetimeTotal()
    local casts = self.db.stats.fishingCasts or 0
    local timeSpent = self.db.stats.timeSpentFishing or 0
    local luresUsed = self.db.stats.luresUsed or 0
<<<<<<< HEAD
    
    -- Ensure cache exists
    if not self.cache then
        self.cache = {}
    end
    
=======
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
    local currentZone = self.cache.lastZone or GetRealZoneText() or "Unknown"
    
    print("|cFF80FF80BobberBuddy Statistics:|r")
    print("Session fish caught: " .. sessionTotal)
    print("Lifetime fish caught: " .. lifetimeTotal)
    print("Total fishing casts: " .. casts)
    print("Time spent fishing: " .. SecondsToTime(timeSpent))
    print("Lures used: " .. luresUsed)
    print("Current zone: " .. currentZone)
    
    -- Show top 3 fish for current zone
    local zoneFish = self:GetZoneFishData(currentZone)
    if next(zoneFish) then
        print("\nTop fish in " .. currentZone .. ":")
        
        local sortedFish = {}
        for fish, count in pairs(zoneFish) do
            table.insert(sortedFish, {name = fish, count = count})
        end
        
        table.sort(sortedFish, function(a,b) return a.count > b.count end)
        
        for i = 1, math.min(3, #sortedFish) do
            print(i .. ". " .. sortedFish[i].name .. ": " .. sortedFish[i].count)
        end
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
    local fishCaught = false
    
<<<<<<< HEAD
    -- Ensure cache exists
    if not self.cache then
        self.cache = {}
    end
    
=======
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
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
                
                -- Add to fish tracker database
                local currentZone = self.cache.lastZone or GetRealZoneText() or "Unknown"
                self:AddFishToDatabase(lootName, lootQuantity, currentZone)
                fishCaught = true
            end
        end
    end
    
    -- Track fishing end with success
    if fishCaught and self.cache.isFishing then
        self:TrackFishingEnd(true)
    end
end

-- Initialize the addon
BB:Init()
