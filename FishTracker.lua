--[[
    BobberBuddy - Fish Tracker Module
    Watches the Fishing channel and records what you loot from it.

    Catches are read from your own "You receive loot: ..." chat messages that
    arrive right after a Fishing cast ends (or while a loot window opened from
    fishing is still open). This works with or without auto-loot, which the
    loot-window API did not on WoW Forever.
]]

BobberBuddy = BobberBuddy or {}
local BB = BobberBuddy

local LOOT_GRACE = 8 -- seconds after the cast ends that loot still counts as fishing loot

-- Turn a Blizzard format string like "You receive loot: %sx%d." into a Lua pattern
local function ToPattern(format)
    if not format then return end
    local pattern = format:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    pattern = pattern:gsub("%%%%s", "(.+)")
    pattern = pattern:gsub("%%%%d", "(%%d+)")
    return "^" .. pattern .. "$"
end

-- Only "You receive loot:" counts. "You receive item:" (LOOT_ITEM_PUSHED_SELF) is what
-- buying from a vendor, quest rewards and mail produce, so those are never catches.
-- Multiple-quantity pattern first, so "x3" isn't swallowed into the item name.
local LOOT_PATTERNS = {}
for _, format in ipairs({ LOOT_ITEM_SELF_MULTIPLE, LOOT_ITEM_SELF }) do
    local pattern = ToPattern(format)
    if pattern then LOOT_PATTERNS[#LOOT_PATTERNS + 1] = pattern end
end
if #LOOT_PATTERNS == 0 then -- English fallback
    LOOT_PATTERNS = { "^You receive loot: (.+)x(%d+)%.$", "^You receive loot: (.+)%.$" }
end

function BB:InitFishTracker()
    local frame = CreateFrame("Frame")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("LOOT_OPENED")
    frame:RegisterEvent("LOOT_CLOSED")
    frame:RegisterEvent("CHAT_MSG_LOOT")
    frame:RegisterEvent("CHAT_MSG_SKILL")
    frame:RegisterEvent("SKILL_LINES_CHANGED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("CHAT_MSG_MONEY")
    frame:RegisterEvent("UI_ERROR_MESSAGE")
    frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "UNIT_SPELLCAST_CHANNEL_START" then
            local _, _, spellID = ...
            if BB:IsFishingSpell(spellID) then
                BB:TrackFishingCast()
                BB:StartReelMode()
                BB:StartFishingSound()
                -- Pole was already in your hands (so no equip happened)? Open the tracker on the cast
                if BB:GetSetting("showTrackerWithPole") and not BB:GetSetting("showTracker") then
                    BB:SetSetting("showTracker", true)
                    BB:UpdateTrackerVisibility()
                end
            end
        elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
            local _, _, spellID = ...
            if BB:IsFishingSpell(spellID) then
                BB.lastFishingStop = GetTime()
                BB:TrackFishingEnd()
                BB:RefreshFishingSkill()
                BB:EndReelMode()
                BB:ScheduleSoundRestore()
            end
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            local _, _, spellID = ...
            BB:OnLureCastSucceeded(spellID)
        elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
            local _, _, spellID = ...
            BB:OnSpellFailed(spellID)
            BB:OnLureCastStopped(spellID, event == "UNIT_SPELLCAST_INTERRUPTED")
        elseif event == "PLAYER_REGEN_DISABLED" then
            BB:RestoreSound() -- you'll want to hear the fight
        elseif event == "LOOT_OPENED" then
            -- A loot window you leave open (no auto-loot) can be picked from later
            BB.fishingLootOpen = BB:IsRecentFishing()
        elseif event == "LOOT_CLOSED" then
            BB.fishingLootOpen = false
        elseif event == "CHAT_MSG_LOOT" then
            BB:OnLootMessage(...)
        elseif event == "CHAT_MSG_SKILL" then
            BB:OnSkillMessage(...)
        elseif event == "SKILL_LINES_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
            BB:RefreshFishingSkill()
        elseif event == "CHAT_MSG_MONEY" then
            BB:OnMoneyMessage(...)
        elseif event == "UI_ERROR_MESSAGE" then
            local _, message = ...
            BB:OnUIError(message)
        elseif event == "GET_ITEM_INFO_RECEIVED" then
            -- Item names/prices arrive from the server a moment later; redraw once
            if not BB.itemRefreshPending then
                BB.itemRefreshPending = true
                C_Timer.After(0.3, function()
                    BB.itemRefreshPending = false
                    BB:UpdateFishTrackerUI()
                end)
            end
        end
    end)
end

function BB:IsRecentFishing()
    return GetTime() - (self.lastFishingStop or 0) < LOOT_GRACE
end

function BB:OnLootMessage(message)
    if not message or BB.compat.IsSecret(message) then return end
    if not (self.fishingLootOpen or self:IsRecentFishing()) then return end

    for _, pattern in ipairs(LOOT_PATTERNS) do
        local item, quantity = message:match(pattern)
        if item then
            local name = item:match("%[(.-)%]") or item
            local itemID = tonumber(item:match("|Hitem:(%d+)"))
            self:AddFishToDatabase(name, tonumber(quantity) or 1, self.cache.lastZone or GetRealZoneText() or "Unknown", itemID)
            return
        end
    end
end

-- "You loot 1 Gold, 5 Silver, 3 Copper" while fishing (treasure, pools of coins)
local MONEY_PATTERNS = {}
for _, entry in ipairs({ { GOLD_AMOUNT, 10000 }, { SILVER_AMOUNT, 100 }, { COPPER_AMOUNT, 1 } }) do
    if entry[1] then
        MONEY_PATTERNS[#MONEY_PATTERNS + 1] = { entry[1]:gsub("%%d", "(%%d+)"), entry[2] }
    end
end

function BB:OnMoneyMessage(message)
    if not message or BB.compat.IsSecret(message) then return end
    if not (self.fishingLootOpen or self:IsRecentFishing()) then return end
    local copper = 0
    for _, entry in ipairs(MONEY_PATTERNS) do
        local amount = message:match(entry[1])
        if amount then copper = copper + tonumber(amount) * entry[2] end
    end
    if copper > 0 then self:AddFishingMoney(copper) end
end

---------------------------------------------------------------------------
-- Value and gold per hour
---------------------------------------------------------------------------
function BB:GetFishItemID(name)
    local ids = self.db.fishData.itemIDs
    if not ids[name] then
        ids[name] = BB.compat.GetItemInfoInstant(name) -- works for items the game already knows
    end
    return ids[name]
end

-- Price of one item in copper: Auctionator's auction price when it has one, else vendor price
function BB:GetItemValue(itemID)
    if not itemID then return 0 end
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if api and api.GetAuctionPriceByItemID then
        local ok, price = pcall(api.GetAuctionPriceByItemID, "BobberBuddy", itemID)
        if ok and type(price) == "number" and price > 0 then
            return price, "auction"
        end
    end
    local sellPrice = select(11, BB.compat.GetItemInfo(itemID))
    return sellPrice or 0, "vendor"
end

function BB:GetSessionValue()
    local total = self.cache.sessionMoney or 0
    for name, count in pairs(self.cache.fishCaught) do
        total = total + self:GetItemValue(self:GetFishItemID(name)) * count
    end
    return total
end

-- Copper per hour since your first cast this session (nil for the first minute)
function BB:GetGoldPerHour()
    local start = self.cache.sessionFirstCast
    if not start then return nil end
    local elapsed = time() - start
    if elapsed < 60 then return nil end
    return math.floor(self:GetSessionValue() * 3600 / elapsed)
end

function BB.FormatMoney(copper)
    copper = math.floor(copper or 0)
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        return C_CurrencyInfo.GetCoinTextureString(copper)
    elseif GetCoinTextureString then
        return GetCoinTextureString(copper)
    end
    return string.format("%dg %ds %dc", math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100)
end

---------------------------------------------------------------------------
-- Fishing skill: current level and an estimate of the time to the next one
---------------------------------------------------------------------------
local SKILL_UP_PATTERN = ToPattern(SKILL_RANK_UP) or "^Your skill in (.+) has increased to (%d+)%.$"
local MAX_SKILL_UPS_KEPT = 6

-- Read Fishing rank and max from the game (modern profession API, then classic skill lines)
function BB:ReadFishingSkill()
    if GetProfessions and GetProfessionInfo then
        local ok, _, _, _, fishing = pcall(GetProfessions)
        if ok and fishing then
            local ok2, _, _, rank, maxRank = pcall(GetProfessionInfo, fishing)
            if ok2 and type(rank) == "number" and not BB.compat.IsSecret(rank) then return rank, maxRank end
        end
    end
    if GetNumSkillLines and GetSkillLineInfo then
        local fishingName = self:GetFishingSpellName()
        for i = 1, GetNumSkillLines() do
            local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
            if not isHeader and name == fishingName then return rank, maxRank end
        end
    end
end

-- Store the latest rank; a rise counts as a skill-up (with the fishing time and casts it took)
function BB:RecordFishingSkill(rank, maxRank)
    if not self.db or not rank then return end
    local skill = self.db.fishingSkill
    if skill.rank and rank > skill.rank then
        table.insert(skill.ups, { time = self:GetTimeSpentFishing(), casts = self.db.stats.fishingCasts or 0 })
        while #skill.ups > MAX_SKILL_UPS_KEPT do table.remove(skill.ups, 1) end
    end
    skill.rank = rank
    if maxRank and maxRank > 0 then skill.max = maxRank end
    self:UpdateStatsLine()
end

function BB:RefreshFishingSkill()
    local rank, maxRank = self:ReadFishingSkill()
    if rank then self:RecordFishingSkill(rank, maxRank) end
end

-- "Your skill in Fishing has increased to 89." (works even if the skill APIs don't)
function BB:OnSkillMessage(message)
    if not message or BB.compat.IsSecret(message) then return end
    local skillName, rank = message:match(SKILL_UP_PATTERN)
    if skillName and skillName == self:GetFishingSpellName() then
        self:RecordFishingSkill(tonumber(rank))
    end
end

-- Estimate the next skill-up from the average fishing time (and casts) your recent ones took.
-- Returns secondsLeft, castsLeft - or nil until there are at least two skill-ups to compare.
function BB:EstimateNextSkillUp()
    local ups = self.db.fishingSkill.ups
    if #ups < 2 then return nil end
    local first, last = ups[1], ups[#ups]
    local intervals = #ups - 1
    local avgTime = (last.time - first.time) / intervals
    local avgCasts = (last.casts - first.casts) / intervals
    local sinceTime = self:GetTimeSpentFishing() - last.time
    local sinceCasts = (self.db.stats.fishingCasts or 0) - last.casts
    return math.max(avgTime - sinceTime, 0), math.max(math.ceil(avgCasts - sinceCasts), 0)
end

-- Shorter money for tight spaces: drop copper once there's gold ("19g 30s"), else silver + copper
function BB.FormatMoneyShort(copper)
    copper = math.floor(copper or 0)
    if copper >= 10000 then
        copper = copper - (copper % 100)
    end
    return BB.FormatMoney(copper)
end
