--[[
    BobberBuddy - Fish Tracker Module
    Tracks fish caught during the session
]]

<<<<<<< HEAD
-- Check if addon is loaded and create local reference
BobberBuddy = BobberBuddy or {}
local BB = BobberBuddy

-- Initialize session tracking
BB.sessionFishCaught = {}

=======
local BB = BobberBuddy

>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
-- Initialize fish tracking system
function BB:InitFishTracker()
    -- Set up additional loot event handling
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_LOOT")
    frame:SetScript("OnEvent", function(self, event, ...)
        if event == "CHAT_MSG_LOOT" then
            BB:ProcessLootMessage(...)
        end
    end)
    
    -- Also register for fishing events
    frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    frame:RegisterEvent("UNIT_SPELLCAST_FAILED")
    frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    
    frame:HookScript("OnEvent", function(self, event, unit, _, spellID)
        if unit ~= "player" then return end
        
        local fishingID = BB.isRetail and FISHING_SPELL_ID or FISHING_SPELL_ID_CLASSIC
        
        if event == "UNIT_SPELLCAST_CHANNEL_START" and spellID == fishingID then
            -- Started fishing
            BB:TrackFishingCast()
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" and spellID == fishingID then
            -- Successful cast
        elseif (event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED") and spellID == fishingID then
            -- Failed cast
            BB:TrackFishingEnd(false)
        elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" and spellID == fishingID then
            -- Stopped fishing
            -- Note: This will also fire when fish is caught, but we'll handle that in loot events
        end
    end)
end

-- Process loot message from chat
function BB:ProcessLootMessage(message)
    -- Format: "You receive loot: [Fish Name]"
    if message and message:match("You receive loot: ") then
        local itemLink = message:match("|c.-|r")
        if itemLink then
            local itemName = GetItemInfo(itemLink)
            if itemName then
                local quantity = 1
                if message:match("x(%d+)") then
                    quantity = tonumber(message:match("x(%d+)"))
                end
                
                -- Check if this is a fish
                local _, _, _, _, _, itemType, itemSubType = GetItemInfo(itemLink)
                
                -- In Retail, fish are typically categorized as Consumable -> Meat or Consumable -> Fish
                if (itemType == "Consumable" and (itemSubType == "Meat" or itemSubType == "Fish" or itemSubType == "Food & Drink")) or
                   -- In Classic/TBC, fish might be categorized differently, so we also check the name
                   (BB.isClassic and (string.find(itemName:lower(), "fish") or 
                                     string.find(itemName:lower(), "eel") or 
                                     string.find(itemName:lower(), "crab") or
                                     string.find(itemName:lower(), "mackeral") or
                                     string.find(itemName:lower(), "herring"))) then
                    -- Add to database with zone tracking
                    local currentZone = self.cache.lastZone or GetRealZoneText() or "Unknown"
                    self:AddFishToDatabase(itemName, quantity, currentZone)
                    
                    -- Mark fishing as ended successfully
                    if self.cache.isFishing then
                        self:TrackFishingEnd(true)
                    end
                    
                    -- Print message to chat to confirm catch
                    print("|cFF80FF80BobberBuddy|r: Caught " .. quantity .. "x " .. itemName .. " in " .. currentZone)
                end
            end
        end
    end
end

-- Add caught fish to tracking
function BB:AddFishCaught(fishName, quantity)
    quantity = quantity or 1
    
    -- Add to session tracking
    if not self.sessionFishCaught[fishName] then
        self.sessionFishCaught[fishName] = 0
    end
    self.sessionFishCaught[fishName] = self.sessionFishCaught[fishName] + quantity
    
    -- Add to persistent tracking
    if not self.db.fishCaught[fishName] then
        self.db.fishCaught[fishName] = 0
    end
    self.db.fishCaught[fishName] = self.db.fishCaught[fishName] + quantity
    
    -- Get current zone
    local zone = GetRealZoneText() or "Unknown"
    
    -- Store zone information if not already stored
    if not self.db.fishZones then
        self.db.fishZones = {}
    end
    
    if not self.db.fishZones[fishName] then
        self.db.fishZones[fishName] = {}
    end
    
    if not self.db.fishZones[fishName][zone] then
        self.db.fishZones[fishName][zone] = 0
    end
    
    self.db.fishZones[fishName][zone] = self.db.fishZones[fishName][zone] + quantity
    
    -- Update the UI
    self:UpdateFishTrackerUI()
    
    -- Print message to chat to confirm catch
    print("|cFF80FF80BobberBuddy|r: Caught " .. quantity .. "x " .. fishName .. " in " .. zone)
end

-- Get total fish caught in current session
function BB:GetSessionTotalFishCount()
    local total = 0
<<<<<<< HEAD
    
    -- Ensure sessionFishCaught exists
    if not self.sessionFishCaught then
        self.sessionFishCaught = {}
        return 0
    end
    
=======
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
    for _, count in pairs(self.sessionFishCaught) do
        total = total + count
    end
    return total
end

-- Get total fish caught all-time
function BB:GetTotalFishCount()
    local total = 0
<<<<<<< HEAD
    
    -- Ensure db and fishCaught exist
    if not self.db or not self.db.fishCaught then
        return 0
    end
    
=======
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
    for _, count in pairs(self.db.fishCaught) do
        total = total + count
    end
    return total
end

-- Clear session fish count
function BB:ClearSessionFishCount()
<<<<<<< HEAD
    -- Ensure sessionFishCaught exists
    self.sessionFishCaught = {}
    
    -- Check if UI system is available
    if self.UpdateFishTrackerUI then
        self:UpdateFishTrackerUI()
    end
=======
    self.sessionFishCaught = {}
    self:UpdateFishTrackerUI()
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
end

-- Clear all fish count
function BB:ClearAllFishCount()
<<<<<<< HEAD
    -- Ensure db exists
    if not self.db then
        return
    end
    
    -- Ensure self.sessionFishCaught exists
    if not self.sessionFishCaught then
        self.sessionFishCaught = {}
    else
        self.sessionFishCaught = {}
    end
    
    -- Clear database components safely
    if self.db.fishCaught then
        self.db.fishCaught = {}
    end
    
    if self.db.fishZones then
        self.db.fishZones = {}
    end
    
=======
    self.db.fishCaught = {}
    self.sessionFishCaught = {}
    self.db.fishZones = {}
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
    self:UpdateFishTrackerUI()
end

-- Get fish data for display
function BB:GetFishDisplayData()
    local fishData = {}
    
<<<<<<< HEAD
    -- Ensure sessionFishCaught exists
    if not self.sessionFishCaught then
        self.sessionFishCaught = {}
        return fishData
    end
    
=======
>>>>>>> b55af0803a5f5df259b8c0744c364f651ec9b88f
    -- Convert hash table to sortable array
    for fish, count in pairs(self.sessionFishCaught) do
        table.insert(fishData, {name = fish, count = count})
    end
    
    -- Sort by count (descending)
    table.sort(fishData, function(a, b) return a.count > b.count end)
    
    return fishData
end
