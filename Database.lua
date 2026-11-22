--[[
    BobberBuddy - Database Module
    Saved variables and persistent data storage (per character)
]]

BobberBuddy = BobberBuddy or {}
local BB = BobberBuddy

-- Default per-character data
local defaultDB = {
    settings = {}, -- filled from BB.defaults; missing keys fall back to defaults
    fishData = {
        session = {},    -- Current session catch counts
        lifetime = {},   -- All-time catch counts
        zoneData = {},   -- zone -> { item -> count }
        lastCaught = {}, -- item -> timestamp
        firstCaught = {}, -- item -> timestamp of your first one
        itemIDs = {},    -- item name -> itemID (for icons, tooltips and prices)
        totalCaught = 0,
    },
    stats = {
        fishingCasts = 0,
        timeSpentFishing = 0,
        luresUsed = 0,
        totalPlayTime = 0,
        zoneTime = {},   -- zone -> seconds spent fishing there
    },
    savedGear = {}, -- slot -> item link you wore before fishing gear went on
    normalWeapons = {}, -- [16]/[17] -> last non-pole weapons you wore (false = empty off-hand)
    buffUsed = {},  -- itemID -> time you last used that fishing buff item
    mutedSounds = {}, -- sound groups currently muted by us (so a reload can unmute them)
    fishingSkill = { ups = {} }, -- rank, max, and recent skill-ups { time, casts } for the estimate
}

-- Session-only state
BB.cache = {
    fishCaught = {},
    sessionStartTime = 0,
    isFishing = false,
    fishingStart = 0,
    lastZone = nil,
}

-- Copy defaults into target without overwriting existing values.
-- Tables are copied, never shared, so characters can't alias each other's data.
local function ApplyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            ApplyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

function BB:InitDatabase()
    BobberBuddyDB = BobberBuddyDB or {}
    BobberBuddyDB.characters = BobberBuddyDB.characters or {}
    BobberBuddyDB.global = nil -- v1 wrote defaults here but never read them

    local fullName = UnitName("player") .. "-" .. GetRealmName()
    local existingCharacter = BobberBuddyDB.characters[fullName] ~= nil
    BobberBuddyDB.characters[fullName] = BobberBuddyDB.characters[fullName] or {}
    local db = BobberBuddyDB.characters[fullName]
    ApplyDefaults(db, defaultDB)

    -- 1.0.1 made most features off by default. Characters that used Bobber Buddy before then
    -- keep 1.0.0's defaults for anything they never changed, so an update doesn't quietly turn
    -- their features off. Settings a player chose are never touched.
    if not db.settingsVersion then
        if existingCharacter then
            local OLD_DEFAULTS = {
                enableAutoLure = true, enableFishingGear = true, enableBuffItems = true,
                oneKeyReel = true, fishingSound = true, fishingVolumeBoost = 200,
                muteCrafting = true, showTracker = true, showTrackerWithPole = true,
                hideTrackerWithoutPole = true,
            }
            for key, value in pairs(OLD_DEFAULTS) do
                if db.settings[key] == nil then db.settings[key] = value end
            end
        end
        db.settingsVersion = 2
    end

    -- v1 migrations
    local pos = db.settings.trackerPosition
    if type(pos) == "table" and #pos == 5 then
        -- v1 saved {point, <frame>, relativePoint, x, y}; frames can't be saved
        db.settings.trackerPosition = { pos[1], pos[3], pos[4], pos[5] }
    end
    if db.settings.enableAutoBobberClick ~= nil then
        db.settings.oneKeyReel = db.settings.enableAutoBobberClick
        db.settings.enableAutoBobberClick = nil
    end
    db.stats.sessionStartTime = nil

    self.db = db

    -- Session data starts fresh each login
    db.fishData.session = {}
    self.cache.fishCaught = db.fishData.session
    self.cache.sessionStartTime = time()

    return db
end

function BB:GetSetting(key)
    local value = self.db and self.db.settings[key]
    if value == nil then
        return self.defaults[key]
    end
    return value
end

function BB:SetSetting(key, value)
    self.db.settings[key] = value
end

-- Record a catch
function BB:AddFishToDatabase(fishName, quantity, zone, itemID)
    quantity = quantity or 1
    zone = zone or GetRealZoneText() or "Unknown"
    local data = self.db.fishData
    if itemID then data.itemIDs[fishName] = itemID end

    data.session[fishName] = (data.session[fishName] or 0) + quantity
    data.lifetime[fishName] = (data.lifetime[fishName] or 0) + quantity

    data.zoneData[zone] = data.zoneData[zone] or {}
    data.zoneData[zone][fishName] = (data.zoneData[zone][fishName] or 0) + quantity

    data.lastCaught[fishName] = time()
    data.firstCaught[fishName] = data.firstCaught[fishName] or time()
    if self.UpdateFishingLog then self:UpdateFishingLog() end
    data.totalCaught = data.totalCaught + quantity

    self:UpdateFishTrackerUI()
end

-- Coins looted while fishing (counted toward session value)
function BB:AddFishingMoney(copper)
    self.cache.sessionMoney = (self.cache.sessionMoney or 0) + copper
    self:UpdateFishTrackerUI()
end

function BB:ClearSessionData()
    wipe(self.db.fishData.session)
    self.cache.sessionMoney = 0
    self.cache.sessionFirstCast = nil
    self.cache.sessionStartTime = time()
    self:UpdateFishTrackerUI()
end

function BB:ClearAllData()
    local data = self.db.fishData
    wipe(data.session)
    wipe(data.lifetime)
    wipe(data.zoneData)
    wipe(data.lastCaught)
    wipe(data.firstCaught)
    data.totalCaught = 0
    self.cache.sessionMoney = 0
    self.cache.sessionFirstCast = nil

    -- Casts, fishing time and lures used too
    local stats = self.db.stats
    stats.fishingCasts = 0
    stats.timeSpentFishing = 0
    stats.luresUsed = 0
    wipe(stats.zoneTime)
    if self.cache.isFishing then
        self.cache.fishingStart = time() -- don't re-add the part of this cast before the reset
    end

    self:UpdateFishTrackerUI()
    if self.optionsPanel and self.optionsPanel:IsShown() then
        self.optionsPanel:GetScript("OnShow")(self.optionsPanel)
    end
    print("|cFF80FF80Bobber Buddy|r: All fishing data has been reset.")
end

function BB:GetSessionTotal()
    local total = 0
    for _, count in pairs(self.cache.fishCaught) do
        total = total + count
    end
    return total
end

function BB:GetLifetimeTotal()
    return self.db.fishData.totalCaught or 0
end

function BB:GetZoneFishData(zone)
    zone = zone or GetRealZoneText() or "Unknown"
    return self.db.fishData.zoneData[zone] or {}
end

function BB:GetSortedSessionFish()
    local list = {}
    for fish, count in pairs(self.cache.fishCaught) do
        table.insert(list, { name = fish, count = count })
    end
    table.sort(list, function(a, b) return a.count > b.count end)
    return list
end

-- Stats
function BB:TrackFishingCast()
    self.db.stats.fishingCasts = self.db.stats.fishingCasts + 1
    self.cache.fishingStart = time()
    self.cache.isFishing = true
    self.cache.sessionFirstCast = self.cache.sessionFirstCast or time() -- gold/hour clock
    self:UpdateFishTrackerUI()
end

-- Saved fishing time plus the cast in progress
function BB:GetTimeSpentFishing()
    local total = self.db.stats.timeSpentFishing or 0
    if self.cache.isFishing and self.cache.fishingStart > 0 then
        total = total + (time() - self.cache.fishingStart)
    end
    return total
end

function BB:TrackLureUsage()
    self.db.stats.luresUsed = self.db.stats.luresUsed + 1
end

function BB:TrackFishingEnd()
    if self.cache.isFishing and self.cache.fishingStart > 0 then
        local duration = time() - self.cache.fishingStart
        local stats = self.db.stats
        stats.timeSpentFishing = stats.timeSpentFishing + duration
        local zone = self.cache.lastZone or GetRealZoneText() or "Unknown"
        stats.zoneTime[zone] = (stats.zoneTime[zone] or 0) + duration
    end
    self.cache.isFishing = false
    self:UpdateFishTrackerUI()
    if self.UpdateFishingLog then self:UpdateFishingLog() end
end
