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
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("LOOT_OPENED")
    frame:RegisterEvent("LOOT_CLOSED")
    frame:RegisterEvent("CHAT_MSG_LOOT")
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
            end
        elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
            local _, _, spellID = ...
            if BB:IsFishingSpell(spellID) then
                BB.lastFishingStop = GetTime()
                BB:TrackFishingEnd()
                BB:EndReelMode()
                BB:ScheduleSoundRestore()
            end
        elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
            local _, _, spellID = ...
            BB:OnSpellFailed(spellID)
        elseif event == "PLAYER_REGEN_DISABLED" then
            BB:RestoreSound() -- you'll want to hear the fight
        elseif event == "LOOT_OPENED" then
            -- A loot window you leave open (no auto-loot) can be picked from later
            BB.fishingLootOpen = BB:IsRecentFishing()
        elseif event == "LOOT_CLOSED" then
            BB.fishingLootOpen = false
        elseif event == "CHAT_MSG_LOOT" then
            BB:OnLootMessage(...)
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
