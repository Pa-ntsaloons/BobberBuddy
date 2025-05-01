--[[
    BobberBuddy - Fish Tracker Module
    Tracks fish caught during the session
]]

local BB = BobberBuddy

-- Initialize fish tracking system
function BB:InitFishTracker()
    -- Initialize fish data table if not exists
    if not self.db.fishCaught then
        self.db.fishCaught = {}
    end
    
    -- Track fish caught during the current session
    self.sessionFishCaught = {}
    
    -- Set up loot event handling
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_LOOT")
    frame:SetScript("OnEvent", function(self, event, ...)
        if event == "CHAT_MSG_LOOT" then
            BB:ProcessLootMessage(...)
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
                    self:AddFishCaught(itemName, quantity)
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
    for _, count in pairs(self.sessionFishCaught) do
        total = total + count
    end
    return total
end

-- Get total fish caught all-time
function BB:GetTotalFishCount()
    local total = 0
    for _, count in pairs(self.db.fishCaught) do
        total = total + count
    end
    return total
end

-- Clear session fish count
function BB:ClearSessionFishCount()
    self.sessionFishCaught = {}
    self:UpdateFishTrackerUI()
end

-- Clear all fish count
function BB:ClearAllFishCount()
    self.db.fishCaught = {}
    self.sessionFishCaught = {}
    self.db.fishZones = {}
    self:UpdateFishTrackerUI()
end

-- Get fish data for display
function BB:GetFishDisplayData()
    local fishData = {}
    
    -- Convert hash table to sortable array
    for fish, count in pairs(self.sessionFishCaught) do
        table.insert(fishData, {name = fish, count = count})
    end
    
    -- Sort by count (descending)
    table.sort(fishData, function(a, b) return a.count > b.count end)
    
    return fishData
end
