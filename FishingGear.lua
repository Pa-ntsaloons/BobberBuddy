--[[
    BobberBuddy - Fishing Gear Module
    Finds fishing gear (pole, clothes, trinkets) and fishing-buff food/drink
    by reading item tooltips, so new or Forever-only items work without a list.
    Remembers what you were wearing so you can swap back.
]]

BobberBuddy = BobberBuddy or {}
local BB = BobberBuddy
local C = BB.compat

C.EquipItemByName = (C_Item and C_Item.EquipItemByName) or EquipItemByName
C.GetItemSpell = (C_Item and C_Item.GetItemSpell) or GetItemSpell

-- Equip location -> inventory slots it can go in
local SLOT_GROUPS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
}
local MAINHAND, OFFHAND = INVSLOT_MAINHAND or 16, INVSLOT_OFFHAND or 17
-- Restore weapons first, then armor
local RESTORE_ORDER = { MAINHAND, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 }

-- Fallback bonuses for items whose tooltip can't be read yet
local KNOWN_GEAR = {
    [6256]  = 0,  -- Fishing Pole
    [12225] = 3,  -- Blump Family Fishing Pole
    [6365]  = 5,  -- Strong Fishing Pole
    [6366]  = 15, -- Darkwood Fishing Pole
    [6367]  = 20, -- Big Iron Fishing Pole
    [19022] = 25, -- Nat Pagle's Extreme Angler FC-5000
    [19970] = 35, -- Arcanite Fishing Pole
    [19972] = 5,  -- Lucky Fishing Hat
    [19969] = 5,  -- Nat Pagle's Extreme Anglin' Boots
    [33820] = 5,  -- Weather-Beaten Fishing Hat
}
local KNOWN_BUFF_ITEMS = {
    [34832] = 10, -- Captain Rumsey's Lager
}

---------------------------------------------------------------------------
-- Tooltip reading
---------------------------------------------------------------------------
local scanTip
local function GetTooltipLines(itemID)
    local lines = {}
    if C_TooltipInfo and C_TooltipInfo.GetItemByID then
        local data = C_TooltipInfo.GetItemByID(itemID)
        for _, line in ipairs(data and data.lines or {}) do
            if line.leftText and not C.IsSecret(line.leftText) then
                lines[#lines + 1] = line.leftText
            end
        end
    else
        scanTip = scanTip or CreateFrame("GameTooltip", "BobberBuddyScanTip", nil, "GameTooltipTemplate")
        scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
        scanTip:ClearLines()
        scanTip:SetItemByID(itemID)
        for i = 1, scanTip:NumLines() do
            local fs = _G["BobberBuddyScanTipTextLeft" .. i]
            local text = fs and fs:GetText()
            if text then lines[#lines + 1] = text end
        end
        scanTip:Hide()
    end
    return lines
end

local function StartsWith(text, prefix)
    return text:sub(1, #prefix) == prefix
end

-- The number that goes with "Fishing": "+5 Fishing", "Fishing +5", "Fishing skill by 10"
local function FishingAmount(lower, pos)
    local before = lower:sub(1, pos - 1):match("(%d+)%D*$")
    local after = lower:sub(pos):match("^%D*(%d+)")
    -- Prefer a "+N" right before the word, otherwise the first number after it
    if before and lower:sub(1, pos - 1):match("%+%s*" .. before .. "%D*$") then
        return tonumber(before)
    end
    return tonumber(after or before)
end

local function ParseDuration(lower)
    local hours = lower:match("(%d+)%s*hour")
    if hours then return tonumber(hours) * 3600 end
    local mins = lower:match("(%d+)%s*min")
    if mins then return tonumber(mins) * 60 end
end

local infoCache = {}

-- Returns { equip = bonus when worn, use = bonus when used, duration, isLure }
function BB:GetFishingInfo(itemID)
    if infoCache[itemID] then return infoCache[itemID] end

    local info = { equip = KNOWN_GEAR[itemID] or 0, use = KNOWN_BUFF_ITEMS[itemID] or 0 }
    if self.LURES[itemID] then
        info.isLure = true
        return info
    end

    local lines = GetTooltipLines(itemID)
    local fishing = self:GetFishingSpellName():lower()
    local equipPrefix = (ITEM_SPELL_TRIGGER_ONEQUIP or "Equip:"):lower()
    local usePrefix = (ITEM_SPELL_TRIGGER_ONUSE or "Use:"):lower()

    for _, text in ipairs(lines) do
        local lower = text:lower()
        local pos = lower:find(fishing, 1, true)
        if pos then
            local amount = FishingAmount(lower, pos)
            if amount and StartsWith(lower, usePrefix) then
                if lower:find("teach", 1, true) or lower:find("learn", 1, true) then
                    -- a recipe or skill book, not a buff
                elseif lower:find("pole", 1, true) or lower:find("applied", 1, true) then
                    info.isLure = true -- a lure we don't know yet; leave it to the lure logic
                    self.LURES[itemID] = amount
                else
                    info.use = math.max(info.use, amount)
                    info.duration = ParseDuration(lower:sub(pos))
                end
            elseif amount and (StartsWith(lower, equipPrefix) or lower:match("^%+%d")) then
                info.equip = math.max(info.equip, amount)
            end
        end
    end

    -- Only cache once the tooltip has actually loaded
    if #lines > 1 then infoCache[itemID] = info end
    return info
end

function BB:IsFishingGear(itemID)
    return itemID ~= nil and (self:IsFishingPole(itemID) or self:GetFishingInfo(itemID).equip > 0)
end

---------------------------------------------------------------------------
-- Gear swapping
---------------------------------------------------------------------------
-- Remember what was in a slot before we put fishing gear there (only the first time)
local function SaveSlot(slot)
    local saved = BB.db.savedGear
    if saved[slot] ~= nil then return end
    local current = GetInventoryItemID("player", slot)
    if current and not BB:IsFishingGear(current) then
        saved[slot] = GetInventoryItemLink("player", slot)
    end
end

-- Gear we can actually wear: level requirement met and not refused earlier this session
function BB:CanWear(itemID)
    return not self.failedLures[itemID] and self:MeetsLevel(itemID)
end

-- Builds a macro that equips everything better than what's worn, or nil if nothing to do.
-- Also returns { {slot, id}, ... } so the swap can be checked afterwards.
-- includeGear: put on clothes/rings/trinkets even if the setting is off (the tracker's gear button)
function BB:BuildGearMacro(includeGear)
    local lines, attempts = {}, {}

    -- Pole (always, so you can cast at all)
    local bestPole, bestPoleScore = nil, -1
    self.ForEachBagItem(function(itemID)
        if self:IsFishingPole(itemID) and self:CanWear(itemID) then
            local score = self:GetFishingInfo(itemID).equip
            if score > bestPoleScore then bestPole, bestPoleScore = itemID, score end
        end
    end)
    local current = GetInventoryItemID("player", MAINHAND)
    local currentScore = self:IsFishingPole(current) and self:GetFishingInfo(current).equip or -1
    if bestPole and bestPoleScore > currentScore then
        SaveSlot(MAINHAND)
        SaveSlot(OFFHAND)
        lines[#lines + 1] = "/equip item:" .. bestPole
        attempts[#attempts + 1] = { slot = MAINHAND, id = bestPole }
    end

    -- Clothes, rings, trinkets
    if includeGear or self:GetSetting("enableFishingGear") then
        local candidates = {} -- equipLoc -> { {id, bonus}, ... }
        self.ForEachBagItem(function(itemID)
            local _, _, _, equipLoc = C.GetItemInfoInstant(itemID)
            if SLOT_GROUPS[equipLoc] and self:CanWear(itemID) then
                local bonus = self:GetFishingInfo(itemID).equip
                if bonus > 0 then
                    candidates[equipLoc] = candidates[equipLoc] or {}
                    table.insert(candidates[equipLoc], { id = itemID, bonus = bonus })
                end
            end
        end)

        for equipLoc, list in pairs(candidates) do
            table.sort(list, function(a, b) return a.bonus > b.bonus end)
            -- Current bonus in each slot this item type can use
            local slotBonus = {}
            for _, slot in ipairs(SLOT_GROUPS[equipLoc]) do
                local worn = GetInventoryItemID("player", slot)
                slotBonus[slot] = worn and self:GetFishingInfo(worn).equip or 0
            end
            -- Put each candidate into the weakest slot it beats
            for _, cand in ipairs(list) do
                local weakest
                for slot, bonus in pairs(slotBonus) do
                    if not weakest or bonus < slotBonus[weakest] then weakest = slot end
                end
                if weakest and cand.bonus > slotBonus[weakest] then
                    SaveSlot(weakest)
                    lines[#lines + 1] = "/equipslot " .. weakest .. " item:" .. cand.id
                    attempts[#attempts + 1] = { slot = weakest, id = cand.id }
                    slotBonus[weakest] = cand.bonus
                end
            end
        end
    end

    if #lines > 0 then return table.concat(lines, "\n"), attempts end
end

-- Gear can't change in combat or while a cast or fishing channel is going
function BB:CanSwapGear()
    if InCombatLockdown() then
        print("|cFF80FF80Bobber Buddy|r: Can't change gear in combat.")
        return false
    end
    if UnitChannelInfo("player") or UnitCastingInfo("player") then
        print("|cFF80FF80Bobber Buddy|r: Can't change gear while you're fishing or casting. Try again once your bobber is gone.")
        return false
    end
    return true
end

local function ItemIDOf(item)
    if type(item) == "number" then return item end
    return item and (tonumber(item:match("item:(%d+)")) or C.GetItemInfoInstant(item))
end

function BB:RestoreGear()
    if not self:CanSwapGear() then return end
    local saved = self.db.savedGear
    local swapped = false
    local expected = {} -- slot -> item we asked for, checked a moment later

    -- Weapons: if a pole is in your hands, put your weapons back. Use what we saved
    -- when the pole went on, or else the last weapons we saw you wearing.
    if self:IsFishingPole(GetInventoryItemID("player", MAINHAND)) then
        local normal = self.db.normalWeapons
        local mainhand = saved[MAINHAND] or normal[MAINHAND]
        local offhand = saved[OFFHAND] or (not saved[MAINHAND] and normal[OFFHAND]) or nil
        if mainhand then
            -- Both in the same moment, like a /equipslot weapon-swap macro;
            -- the game won't allow it from a timer afterwards.
            C.EquipItemByName(mainhand, MAINHAND)
            if offhand then C.EquipItemByName(offhand, OFFHAND) end
            swapped = true
            expected[MAINHAND] = mainhand
        end
    end

    -- Armor: only put back slots that still hold fishing gear (you may have changed things yourself)
    for _, slot in ipairs(RESTORE_ORDER) do
        local item = saved[slot]
        if slot ~= MAINHAND and item then
            local current = GetInventoryItemID("player", slot)
            if current == nil or self:IsFishingGear(current) then
                C.EquipItemByName(item, slot)
                swapped = true
                expected[slot] = item
            else
                saved[slot] = nil -- you've put something else on there yourself; leave it
            end
        end
    end

    if not swapped then
        print("|cFF80FF80Bobber Buddy|r: Nothing to swap back.")
        return
    end

    -- Only say it worked once the items are really on; keep anything that didn't go on saved
    -- so the next try puts it back
    C_Timer.After(1, function()
        local failed = 0
        for slot, item in pairs(expected) do
            if GetInventoryItemID("player", slot) == ItemIDOf(item) then
                if saved[slot] == item then saved[slot] = nil end
                if slot == MAINHAND then saved[OFFHAND] = nil end
            else
                failed = failed + 1
            end
        end
        if failed == 0 then
            print("|cFF80FF80Bobber Buddy|r: Swapped back to your normal gear.")
        else
            print("|cFF80FF80Bobber Buddy|r: |cFFFF4040Couldn't swap " .. failed .. " item(s) back.|r Try again in a moment.")
        end
        if BB.UpdateGearButton then BB:UpdateGearButton() end
    end)
end

-- Remember your real weapons whenever they change, so we can always put them back
-- (even if the pole went on by hand). Read a moment later, once both hands have settled.
local function SnapshotWeapons()
    if not BB.db then return end
    local mainhand = GetInventoryItemID("player", MAINHAND)
    if mainhand and not BB:IsFishingPole(mainhand) then
        BB.db.normalWeapons[MAINHAND] = GetInventoryItemLink("player", MAINHAND)
        BB.db.normalWeapons[OFFHAND] = GetInventoryItemLink("player", OFFHAND) or false
    end
end

local weaponWatcher = CreateFrame("Frame")
weaponWatcher:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
weaponWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
weaponWatcher:SetScript("OnEvent", function(_, event, slot)
    if event == "PLAYER_ENTERING_WORLD" or slot == MAINHAND or slot == OFFHAND then
        C_Timer.After(1, SnapshotWeapons)
    end
end)

---------------------------------------------------------------------------
-- Fishing buff food and drink
---------------------------------------------------------------------------
local function GetPlayerAura(spellID)
    if spellID and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        return C_UnitAuras.GetPlayerAuraBySpellID(spellID)
    end
end

function BB:IsBuffItemActive(itemID)
    local _, spellID = C.GetItemSpell(itemID)
    if GetPlayerAura(spellID) then return true end
    -- Food gives "Well Fed" (a different aura) after you finish eating, so also
    -- trust our own record of when we last used it
    local used = self.db.buffUsed[itemID]
    local duration = self:GetFishingInfo(itemID).duration or 600
    return used ~= nil and time() - used < duration
end

-- Currently sitting and eating/drinking something we used? Don't interrupt it.
function BB:IsEating()
    local pending = self.pendingBuff
    if not pending then return false end
    local aura = GetPlayerAura(pending.spellID)
    -- The eating aura is short; a long aura is the buff itself
    return aura ~= nil and aura.duration ~= nil and not C.IsSecret(aura.duration) and aura.duration <= 35
end

function BB:FindBuffItem()
    local best, bestBonus = nil, 0
    self.ForEachBagItem(function(itemID)
        local info = self:GetFishingInfo(itemID)
        if not info.isLure and info.use > bestBonus and self:CanUseItem(itemID) then
            best, bestBonus = itemID, info.use
        end
    end)
    if best and not self:IsBuffItemActive(best) then return best end
end

function BB:MarkBuffUsed(itemID)
    local _, spellID = C.GetItemSpell(itemID)
    self.pendingBuff = { id = itemID, spellID = spellID }
    self.db.buffUsed[itemID] = time()
end

-- If using the item failed (moved, in combat...), allow trying again
function BB:OnSpellFailed(spellID)
    local pending = self.pendingBuff
    if pending and pending.spellID and spellID == pending.spellID then
        self.db.buffUsed[pending.id] = nil
        self.pendingBuff = nil
    end
end

---------------------------------------------------------------------------
-- Fishing skill breakdown: what each item, lure and buff adds right now
---------------------------------------------------------------------------
local function LinesFromData(data)
    local lines = {}
    for _, line in ipairs(data and data.lines or {}) do
        if line.leftText and not C.IsSecret(line.leftText) then lines[#lines + 1] = line.leftText end
    end
    return lines
end

local function ScanLines(setter)
    scanTip = scanTip or CreateFrame("GameTooltip", "BobberBuddyScanTip", nil, "GameTooltipTemplate")
    scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanTip:ClearLines()
    setter(scanTip)
    local lines = {}
    for i = 1, scanTip:NumLines() do
        local fs = _G["BobberBuddyScanTipTextLeft" .. i]
        local text = fs and fs:GetText()
        if text and not C.IsSecret(text) then lines[#lines + 1] = text end
    end
    scanTip:Hide()
    return lines
end

-- The lure on your pole: its line on the pole's tooltip, e.g. "Fishing Lure (+100 Fishing Skill) (9 min)"
local function GetLureBonus(fishing)
    if not GetWeaponEnchantInfo() then return nil end
    local lines
    if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
        lines = LinesFromData(C_TooltipInfo.GetInventoryItem("player", MAINHAND))
    else
        lines = ScanLines(function(tip) tip:SetInventoryItem("player", MAINHAND) end)
    end
    local equipPrefix = (ITEM_SPELL_TRIGGER_ONEQUIP or "Equip:"):lower()
    for i = 2, #lines do
        local lower = lines[i]:lower()
        local pos = lower:find(fishing, 1, true)
        if pos and not StartsWith(lower, equipPrefix) and not lower:match("^%+%d")
            and (lower:find("lure", 1, true) or lower:find("%(")) then
            local amount = FishingAmount(lower, pos)
            if amount then
                return (lines[i]:match("^(.-)%s*%(") or "Lure"), amount
            end
        end
    end
    return "Lure", nil -- a lure is on but its bonus couldn't be read
end

local function GetAuraLines(index, aura)
    if C_TooltipInfo and C_TooltipInfo.GetUnitBuffByAuraInstanceID and aura.auraInstanceID then
        return LinesFromData(C_TooltipInfo.GetUnitBuffByAuraInstanceID("player", aura.auraInstanceID))
    end
    return ScanLines(function(tip) tip:SetUnitBuff("player", index) end)
end

-- Which lure is on the pole: the one you last applied if its bonus matches, otherwise a lure
-- in your bags with that bonus, otherwise any known lure with that bonus
function BB:IdentifyLure(amount)
    local last = self.db and self.db.lastLureID
    if last and (not amount or self.LURES[last] == amount) then return last end
    if not amount then return nil end
    local found
    self.ForEachBagItem(function(itemID)
        if not found and self.LURES[itemID] == amount then found = itemID end
    end)
    if found then return found end
    for itemID, bonus in pairs(self.LURES) do
        if bonus == amount then return itemID end
    end
end

-- Returns a list of { name, amount, icon, itemID } and their total
function BB:GetFishingSkillBreakdown()
    local list, total = {}, 0
    local fishing = self:GetFishingSpellName():lower()
    local function Add(name, amount, icon)
        if amount and amount ~= 0 then
            list[#list + 1] = { name = name, amount = amount, icon = icon }
            total = total + amount
        end
    end

    -- Worn gear and the pole
    for slot = 1, 17 do
        local itemID = GetInventoryItemID("player", slot)
        if itemID then
            local bonus = self:GetFishingInfo(itemID).equip
            if bonus > 0 then
                local name = C.GetItemInfo(itemID) or ("item " .. itemID)
                Add(name, bonus, GetInventoryItemTexture("player", slot))
                list[#list].itemID = itemID
            end
        end
    end

    -- Lure on the pole
    if self:IsFishingPoleEquipped() then
        local lureName, lureBonus = GetLureBonus(fishing)
        if lureName then
            local lureID = self:IdentifyLure(lureBonus)
            local icon = lureID and select(5, C.GetItemInfoInstant(lureID)) or 136243 -- generic lure icon
            if lureID then lureName = C.GetItemInfo(lureID) or lureName end
            if lureBonus then
                Add(lureName, lureBonus, icon)
            else
                list[#list + 1] = { name = lureName, unknown = true, icon = icon }
            end
            list[#list].itemID = lureID
        end
    end

    -- Buffs (fishing food and drink, and anything else that mentions Fishing)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 40 do
            local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
            if not aura then break end
            if aura.name and not C.IsSecret(aura.name) then
                local lines = GetAuraLines(i, aura)
                for j = 2, #lines do
                    local lower = lines[j]:lower()
                    local pos = lower:find(fishing, 1, true)
                    local amount = pos and FishingAmount(lower, pos)
                    if amount then
                        Add(aura.name, amount, aura.icon)
                        break
                    end
                end
            end
        end
    end

    return list, total
end
