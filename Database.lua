--[[
    BobberBuddy - Database Module
    Handles all saved variables and persistent data storage
]]

local BB = BobberBuddy

-- Default database structure
local defaultDB = {
    -- User settings
    settings = {
        enableAutoLure = true,
        enableAutoBobberClick = true,
        showTracker = true,
        trackerPosition = {"RIGHT", UIParent, "RIGHT", -50, 0},
    },
    
    -- Fish tracking data
    fishData = {
        session = {},        -- Current session fish counts
        lifetime = {},       -- All-time fish counts
        zoneData = {},       -- Zone-specific fish data
        lastCaught = {},     -- Last caught timestamp by fish
        totalCaught = 0,     -- Total fish caught all-time
        raresCaught = 0,     -- Number of rare fish caught
    },
    
    -- Statistics tracking
    stats = {
        fishingCasts = 0,    -- Total number of fishing casts
        timeSpentFishing = 0, -- Time spent fishing in seconds
        luresUsed = 0,        -- Total lures used
        sessionStartTime = 0, -- Current session start time
    },
    
    -- Tracking per character
    characters = {},         -- Character-specific data storage
}

-- Global cache for session data
BB.cache = {
    fishCaught = {},         -- Fish caught this session
    sessionStartTime = 0,     -- When session started
    isFishing = false,        -- Currently fishing or not
    fishingStart = 0,         -- When current cast started
    fishingPoleEquipped = false, -- Is fishing pole equipped
    activeLure = nil,         -- Currently active lure data
    lastZone = nil,           -- Last zone where fishing occurred
}

-- Initialize database
function BB:InitDatabase()
    -- Create saved variables if they don't exist
    if not BobberBuddyDB then
        BobberBuddyDB = {}
    end
    
    -- Create master table if it doesn't exist
    if not BobberBuddyDB.global then
        BobberBuddyDB.global = {}
    end
    
    -- Create character-specific table if it doesn't exist
    local playerName = UnitName("player")
    local realmName = GetRealmName()
    local fullName = playerName .. "-" .. realmName
    
    if not BobberBuddyDB.characters then
        BobberBuddyDB.characters = {}
    end
    
    if not BobberBuddyDB.characters[fullName] then
        BobberBuddyDB.characters[fullName] = {}
    end
    
    -- Initialize with default values for missing entries
    for category, defaults in pairs(defaultDB) do
        if type(defaults) == "table" then
            -- Initialize global settings
            if not BobberBuddyDB.global[category] then
                BobberBuddyDB.global[category] = {}
            end
            
            -- Add missing values with defaults
            for key, value in pairs(defaults) do
                if BobberBuddyDB.global[category][key] == nil then
                    BobberBuddyDB.global[category][key] = value
                end
            end
            
            -- Initialize character settings
            if not BobberBuddyDB.characters[fullName][category] then
                BobberBuddyDB.characters[fullName][category] = {}
            end
            
            -- Add missing values with defaults for character
            for key, value in pairs(defaults) do
                if BobberBuddyDB.characters[fullName][category][key] == nil then
                    BobberBuddyDB.characters[fullName][category][key] = value
                end
            end
        end
    end
    
    -- Store reference to character-specific data
    self.db = BobberBuddyDB.characters[fullName]
    self.globalDB = BobberBuddyDB.global
    
    -- Initialize cache for this session
    self.cache.sessionStartTime = time()
    self.db.stats.sessionStartTime = self.cache.sessionStartTime
    
    -- Return database for other modules
    return self.db
end

-- Get a setting value (prioritize character setting, fall back to global)
function BB:GetSetting(key)
    if self.db and self.db.settings and self.db.settings[key] ~= nil then
        return self.db.settings[key]
    elseif self.globalDB and self.globalDB.settings and self.globalDB.settings[key] ~= nil then
        return self.globalDB.settings[key]
    else
        return defaultDB.settings[key] -- Fall back to default
    end
end

-- Set a setting value
function BB:SetSetting(key, value, isGlobal)
    if isGlobal then
        self.globalDB.settings[key] = value
    else
        self.db.settings[key] = value
    end
end

-- Add a fish to tracking
function BB:AddFishToDatabase(fishName, quantity, zone)
    quantity = quantity or 1
    zone = zone or GetRealZoneText() or "Unknown"
    
    -- Update session cache
    if not self.cache.fishCaught[fishName] then
        self.cache.fishCaught[fishName] = 0
    end
    self.cache.fishCaught[fishName] = self.cache.fishCaught[fishName] + quantity
    
    -- Update lifetime data
    if not self.db.fishData.lifetime[fishName] then
        self.db.fishData.lifetime[fishName] = 0
    end
    self.db.fishData.lifetime[fishName] = self.db.fishData.lifetime[fishName] + quantity
    
    -- Update zone data
    if not self.db.fishData.zoneData[zone] then
        self.db.fishData.zoneData[zone] = {}
    end
    if not self.db.fishData.zoneData[zone][fishName] then
        self.db.fishData.zoneData[zone][fishName] = 0
    end
    self.db.fishData.zoneData[zone][fishName] = self.db.fishData.zoneData[zone][fishName] + quantity
    
    -- Update session data
    if not self.db.fishData.session[fishName] then
        self.db.fishData.session[fishName] = 0
    end
    self.db.fishData.session[fishName] = self.db.fishData.session[fishName] + quantity
    
    -- Update last caught time
    self.db.fishData.lastCaught[fishName] = time()
    
    -- Update total counts
    self.db.fishData.totalCaught = self.db.fishData.totalCaught + quantity
    
    -- Trigger UI update
    self:UpdateFishTrackerUI()
    
    return true
end

-- Clear session fish data
function BB:ClearSessionData()
    self.cache.fishCaught = {}
    self.db.fishData.session = {}
    self.cache.sessionStartTime = time()
    self.db.stats.sessionStartTime = self.cache.sessionStartTime
    self:UpdateFishTrackerUI()
end

-- Clear all fish tracking data
function BB:ClearAllData()
    self.db.fishData = table.wipe(self.db.fishData)
    self.cache.fishCaught = {}
    
    -- Re-initialize empty data structure
    for key, value in pairs(defaultDB.fishData) do
        self.db.fishData[key] = type(value) == "table" and {} or value
    end
    
    self:UpdateFishTrackerUI()
end

-- Get total fish caught in current session
function BB:GetSessionTotal()
    local total = 0
    for _, count in pairs(self.cache.fishCaught) do
        total = total + count
    end
    return total
end

-- Get total fish caught all-time
function BB:GetLifetimeTotal()
    return self.db.fishData.totalCaught or 0
end

-- Get fish data for a specific zone
function BB:GetZoneFishData(zone)
    zone = zone or GetRealZoneText() or "Unknown"
    return self.db.fishData.zoneData[zone] or {}
end

-- Get session fish data as a sorted array for display
function BB:GetSortedSessionFish()
    local fishData = {}
    
    -- Convert hash table to sortable array
    for fish, count in pairs(self.cache.fishCaught) do
        table.insert(fishData, {name = fish, count = count})
    end
    
    -- Sort by count (descending)
    table.sort(fishData, function(a, b) return a.count > b.count end)
    
    return fishData
end

-- Track stats about fishing
function BB:TrackFishingCast()
    self.db.stats.fishingCasts = self.db.stats.fishingCasts + 1
    self.cache.fishingStart = time()
    self.cache.isFishing = true
end

-- Track stats about lure usage
function BB:TrackLureUsage(lureID)
    self.db.stats.luresUsed = self.db.stats.luresUsed + 1
end

-- Track end of fishing
function BB:TrackFishingEnd(success)
    if self.cache.isFishing and self.cache.fishingStart > 0 then
        local duration = time() - self.cache.fishingStart
        self.db.stats.timeSpentFishing = self.db.stats.timeSpentFishing + duration
        self.cache.isFishing = false
    end
end
