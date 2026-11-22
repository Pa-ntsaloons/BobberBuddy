--[[
    BobberBuddy - Core Module
    One hotkey: equips your pole, applies your best lure, casts, and reels in.

    Modern clients (Retail and WoW Forever) only allow casting, using items and
    interacting from a real key press on a secure button. So instead of doing
    those things directly, we re-point one secure button before every press
    (PreClick), and while the bobber is out we temporarily bind the same key to
    "Interact With Target" so the next press reels in.
]]

local ADDON_NAME = ...
BobberBuddy = BobberBuddy or {}
local BB = BobberBuddy
BB.name = ADDON_NAME or "BobberBuddy"

---------------------------------------------------------------------------
-- API compatibility (Forever/Retail use C_* namespaces; older clients don't)
---------------------------------------------------------------------------
local C = {}
BB.compat = C

C.GetAddOnMetadata  = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
C.GetItemInfo       = (C_Item and C_Item.GetItemInfo) or GetItemInfo
C.GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
C.GetContainerNumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
C.GetContainerItemID   = (C_Container and C_Container.GetContainerItemID) or GetContainerItemID

function C.GetSpellName(spellID)
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(spellID)
    elseif GetSpellInfo then
        return (GetSpellInfo(spellID))
    end
end

-- Midnight-era clients can hand addons "secret" values that error when compared.
function C.IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

BB.version = (C.GetAddOnMetadata and C.GetAddOnMetadata(BB.name, "Version")) or "?"

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------
BB.BUTTON_NAME = "BobberBuddyFishingButton"
BB.BINDING = "CLICK " .. BB.BUTTON_NAME .. ":LeftButton"

-- Key binding labels (shown under Key Bindings > Bobber Buddy)
BINDING_HEADER_BOBBERBUDDY = "Bobber Buddy"
_G["BINDING_NAME_" .. BB.BINDING] = "Fish (cast / reel in)"

-- Known Fishing spell IDs across versions (ranks in Classic, one ID in Retail).
-- We also match by name, so a new ID on Forever still works.
local FISHING_SPELL_IDS = {
    [7620] = true, [7731] = true, [7732] = true, [18248] = true, -- Classic ranks
    [33095] = true, [51294] = true, [88868] = true,             -- TBC / Wrath / Cata
    [131474] = true, [131490] = true,                           -- Retail
}

-- Weapon class 2, subclass 20 = Fishing Pole (language-independent)
local ITEM_CLASS_WEAPON = 2
local WEAPON_SUBCLASS_FISHING_POLE = 20

-- Lures: [itemID] = skill bonus
BB.LURES = {
    [6529]  = 25,  -- Shiny Bauble
    [6530]  = 50,  -- Nightcrawlers
    [6811]  = 50,  -- Aquadynamic Fish Lens
    [6532]  = 75,  -- Bright Baubles
    [7307]  = 75,  -- Flesh Eating Worm
    [6533]  = 100, -- Aquadynamic Fish Attractor
    [34861] = 100, -- Sharpened Fish Hook
    [46006] = 100, -- Glow Worm
    [116825] = 200, -- Bladebone Hook
}

-- Default settings
BB.defaults = {
    enableAutoLure = false,
    enableFishingGear = false,
    enableBuffItems = false,
    oneKeyReel = false,
    fishingSound = false,
    fishingVolumeBoost = 100, -- fishing volume in % of your normal master volume (100 = unchanged)
    soundRestoreDelay = 15, -- seconds after the last cast before sounds come back
    muteCrafting = false,
    muteSpells = false,
    muteFootsteps = false,
    muteVoices = false,
    showTracker = false,
    showTrackerWithPole = false,
    hideTrackerWithoutPole = false,
    showMinimapButton = true,
}

-- Second key binding: swap back to normal gear
BINDING_NAME_BOBBERBUDDY_RESTORE = "Swap back to normal gear"

---------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
BB.eventFrame = events
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... == BB.name then
            events:UnregisterEvent("ADDON_LOADED")
            BB:OnAddonLoaded()
        end
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        BB.cache.lastZone = GetRealZoneText() or "Unknown"
        BB:UpdateFishTrackerUI()
    elseif event == "PLAYER_REGEN_ENABLED" then
        BB:EndReelMode() -- finish anything combat prevented us from undoing
    elseif event == "PLAYER_LOGOUT" then
        BB:OnLogout()
    end
end)

function BB:OnAddonLoaded()
    self:InitDatabase()
    self.cache.lastZone = GetRealZoneText() or "Unknown"
    self.failedLures = {}

    self:RestoreSoftInteractCVar() -- in case we reloaded mid-cast
    self:RestoreSound()
    self:CreateFishingButton()
    self:InitFishTracker()
    self:InitUI()
    self:InitMinimapButton()
    self:InitSettings()
    self:RegisterSlashCommands()

    print("|cFF80FF80Bobber Buddy v" .. self.version .. " loaded.|r Set your fishing key in /bb config or Key Bindings > Bobber Buddy. Type /bb for help.")
end

function BB:OnLogout()
    self:RestoreSound()
    if self.cache.isFishing then
        self:TrackFishingEnd()
    end
    local sessionDuration = time() - (self.cache.sessionStartTime or time())
    if sessionDuration > 0 then
        self.db.stats.totalPlayTime = (self.db.stats.totalPlayTime or 0) + sessionDuration
    end
end

---------------------------------------------------------------------------
-- Fishing spell helpers
---------------------------------------------------------------------------
function BB:GetFishingSpellName()
    if not self.fishingSpellName then
        self.fishingSpellName = C.GetSpellName(7620) or C.GetSpellName(131474) or "Fishing"
    end
    return self.fishingSpellName
end

function BB:IsFishingSpell(spellID)
    if not spellID or C.IsSecret(spellID) then return false end
    if FISHING_SPELL_IDS[spellID] then return true end
    local name = C.GetSpellName(spellID)
    return name ~= nil and not C.IsSecret(name) and name == self:GetFishingSpellName()
end

---------------------------------------------------------------------------
-- Gear helpers
---------------------------------------------------------------------------
function BB:IsFishingPole(item)
    if not item then return false end
    local _, _, _, _, _, classID, subclassID = C.GetItemInfoInstant(item)
    return classID == ITEM_CLASS_WEAPON and subclassID == WEAPON_SUBCLASS_FISHING_POLE
end

function BB:IsFishingPoleEquipped()
    return self:IsFishingPole(GetInventoryItemID("player", INVSLOT_MAINHAND or 16))
end

-- Calls fn(itemID) for every item in the backpack and equipped bags
local LAST_BAG = NUM_TOTAL_EQUIPPED_BAG_SLOTS or ((NUM_BAG_SLOTS or 4) + (NUM_REAGENTBAG_SLOTS or 0))
local function ForEachBagItem(fn)
    -- Backpack, the four bag slots, and the extra (reagent) bag slot the modern client has
    for bag = 0, LAST_BAG do
        for slot = 1, C.GetContainerNumSlots(bag) or 0 do
            local itemID = C.GetContainerItemID(bag, slot)
            if itemID then fn(itemID) end
        end
    end
end
BB.ForEachBagItem = ForEachBagItem

-- Lures in Classic-style fishing are temporary main-hand enchants
-- A lure with under 10 seconds left counts as gone, so a fresh one goes on before the cast
function BB:HasActiveLure()
    local hasMainHandEnchant, expirationMS = GetWeaponEnchantInfo()
    if not hasMainHandEnchant then return false end
    if expirationMS and not C.IsSecret(expirationMS) and expirationMS < 10000 then return false end
    return true
end

-- Lures that failed to go on twice in a row rest for 2 minutes (not the whole session)
local LURE_REST = 120
function BB:IsLureResting(itemID)
    local untilTime = self.lureRestUntil and self.lureRestUntil[itemID]
    return untilTime ~= nil and GetTime() < untilTime
end

-- The last lure press didn't result in a lure on the pole
function BB:CountLureMiss(lure)
    self.lureMisses = self.lureMisses or {}
    self.lureRestUntil = self.lureRestUntil or {}
    self.lureMisses[lure] = (self.lureMisses[lure] or 0) + 1
    if self.lureMisses[lure] >= 2 then
        self.lureMisses[lure] = 0
        self.lureRestUntil[lure] = GetTime() + LURE_REST
        local link = select(2, C.GetItemInfo(lure)) or "your lure"
        print("|cFF80FF80Bobber Buddy|r: " .. link .. " didn't go on twice in a row, so I'm fishing without it " ..
            "for 2 minutes, then trying again. Type /bb lure to see what's going on.")
    end
end

-- Lure application stopped: interrupted (moved, jumped) isn't the lure's fault - just retry
function BB:OnLureCastStopped(spellID, interrupted)
    local pending = self.pendingLure
    if not pending or not pending.spellID or spellID ~= pending.spellID then return end
    self.pendingLure = nil
    if not interrupted then self:CountLureMiss(pending.id) end
end

-- /bb lure: what the addon sees, for working out lure problems
function BB:PrintLureStatus()
    local hasEnchant, expirationMS = GetWeaponEnchantInfo()
    print("|cFF80FF80Bobber Buddy lures:|r")
    print("  Fishing pole equipped: " .. (self:IsFishingPoleEquipped() and "yes" or "|cFFFF4040no|r"))
    if hasEnchant then
        local left = expirationMS and not C.IsSecret(expirationMS) and SecondsToTime(math.floor(expirationMS / 1000)) or "?"
        print("  Lure on your pole: yes (" .. left .. " left)")
    else
        print("  Lure on your pole: |cFFFF4040none|r")
    end
    print("  Auto-apply lures: " .. (self:GetSetting("enableAutoLure") and "on" or "|cFFFF4040off|r (Bobber Buddy settings)"))
    local found = false
    ForEachBagItem(function(itemID)
        if self.LURES[itemID] then
            found = true
            local link = select(2, C.GetItemInfo(itemID)) or ("item " .. itemID)
            local status = "|cFF40FF40will use|r"
            if self.failedLures[itemID] then
                status = "|cFFFF4040skipped this session (the game said it can't be used)|r"
            elseif self:IsLureResting(itemID) then
                status = "|cFFFF8040resting " .. math.ceil(self.lureRestUntil[itemID] - GetTime()) .. "s after failing twice|r"
            elseif not self:CanUseItem(itemID) then
                status = "|cFFFF4040can't use yet (level or skill)|r"
            end
            print("  " .. link .. " (+" .. self.LURES[itemID] .. "): " .. status)
        end
    end)
    if not found then print("  No lures found in your bags.") end
end

-- Can you use this item right now? (level/skill requirements - what greys out action bar items)
C.IsUsableItem = (C_Item and C_Item.IsUsableItem) or IsUsableItem
-- Item's level requirement met? (unknown until the item is cached - then assume yes)
function BB:MeetsLevel(itemID)
    local minLevel = select(5, C.GetItemInfo(itemID))
    return not minLevel or minLevel <= UnitLevel("player")
end

function BB:CanUseItem(itemID)
    if self.failedLures[itemID] then return false end -- the game already said no this session
    if not self:MeetsLevel(itemID) then return false end
    if not C.IsUsableItem then return true end
    local usable = C.IsUsableItem(itemID)
    return usable and true or false
end

-- Stop trying an item for the rest of this session, and say which one
function BB:SkipItem(itemID, reason)
    if not itemID or self.failedLures[itemID] then return end
    self.failedLures[itemID] = true
    local link = select(2, C.GetItemInfo(itemID)) or ("item " .. itemID)
    print("|cFF80FF80Bobber Buddy|r: Skipping " .. link .. " for this session (" .. reason .. ").")
end

-- After a gear swap, check what actually went on; anything that didn't (level, skill,
-- unique-equipped...) is skipped so the fishing key doesn't keep trying it every press
function BB:VerifyGearSwap(attempts)
    C_Timer.After(1.5, function()
        if InCombatLockdown() then return end
        for _, a in ipairs(attempts) do
            if GetInventoryItemID("player", a.slot) ~= a.id then
                self:SkipItem(a.id, "it couldn't be equipped")
            end
        end
    end)
end

-- Remember which item a key press tried to use, so a "can't use" error can be pinned on it
function BB:NoteItemAttempt(itemID)
    self.lastItemAttempt = { id = itemID, time = GetTime() }
end

function BB:OnUIError(message)
    local attempt = self.lastItemAttempt
    if not attempt or GetTime() - attempt.time > 1.5 then return end
    if message and not C.IsSecret(message) and (message == ERR_CANT_USE_ITEM or message == ERR_ITEM_CANNOT_BE_USED
        or message == SPELL_FAILED_LOW_CASTLEVEL or message == ERR_USE_LOCKED_WITH_ITEM_S
        or message:lower():find("can't use", 1, true)) then
        if self.LURES[attempt.id] then
            -- Lures rest for 2 minutes instead of a whole session, in case the error was a fluke
            self.lureRestUntil = self.lureRestUntil or {}
            self.lureRestUntil[attempt.id] = GetTime() + LURE_REST
            local link = select(2, C.GetItemInfo(attempt.id)) or "your lure"
            print("|cFF80FF80Bobber Buddy|r: The game says " .. link .. " can't be used (\"" .. message ..
                "\"). Fishing without it for 2 minutes. Type /bb lure for details.")
        else
            self:SkipItem(attempt.id, "the game says it can't be used yet")
        end
        self.db.buffUsed[attempt.id] = nil
        self.pendingLure, self.pendingBuff, self.lastItemAttempt = nil, nil, nil
    end
end

function BB:FindBestLure()
    local bestID, bestBonus = nil, 0
    ForEachBagItem(function(itemID)
        local bonus = self.LURES[itemID]
        if bonus and bonus > bestBonus and self:CanUseItem(itemID) and not self:IsLureResting(itemID) then
            bestID, bestBonus = itemID, bonus
        end
    end)
    return bestID
end

---------------------------------------------------------------------------
-- The secure fishing button
---------------------------------------------------------------------------
function BB:CreateFishingButton()
    local button = CreateFrame("Button", self.BUTTON_NAME, UIParent, "SecureActionButtonTemplate")
    button:SetSize(1, 1)
    button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
    -- Modern clients fire bound clicks on key down or key up depending on the
    -- ActionButtonUseKeyDown CVar; registering both lets the template pick.
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetAttribute("type", "spell")
    button:SetAttribute("spell", self:GetFishingSpellName())
    button:SetScript("PreClick", function(btn, _, down)
        BB:PrepareButton(btn, down)
    end)
    self.fishingButton = button
end

local function SetMacro(button, text)
    button:SetAttribute("type", "macro")
    button:SetAttribute("macrotext", text)
end

-- Decide what this key press should do:
-- equip fishing gear > use buff food/drink > apply lure > cast
function BB:PrepareButton(button, down)
    -- With both edges registered, PreClick runs twice; only act on the edge that fires
    if down ~= nil and down ~= GetCVarBool("ActionButtonUseKeyDown") then return end
    if InCombatLockdown() then return end -- attributes are locked; it will just cast

    -- Busy casting a lure, or sitting down eating: do nothing so we don't interrupt it
    if UnitCastingInfo("player") or UnitChannelInfo("player") or self:IsEating() then
        button:SetAttribute("type", nil)
        return
    end

    local gearMacro, gearAttempts = self:BuildGearMacro()
    if gearMacro then
        SetMacro(button, gearMacro)
        self:VerifyGearSwap(gearAttempts)
        return
    end

    if self:GetSetting("enableBuffItems") then
        local buffItem = self:FindBuffItem()
        if buffItem then
            self:MarkBuffUsed(buffItem)
            self:NoteItemAttempt(buffItem)
            SetMacro(button, "/use item:" .. buffItem)
            return
        end
    end

    if self:IsFishingPoleEquipped() and self:GetSetting("enableAutoLure") then
        if self:HasActiveLure() then
            if self.pendingLure and self.lureMisses then self.lureMisses[self.pendingLure.id] = 0 end
            self.pendingLure = nil
        else
            -- Last press tried a lure, the cast wasn't interrupted, and still no lure: count a miss
            -- (two in a row rests that lure for 2 minutes - see CountLureMiss)
            if self.pendingLure and GetTime() - self.pendingLure.time < 30 then
                self:CountLureMiss(self.pendingLure.id)
            end
            self.pendingLure = nil

            local lure = self:FindBestLure()
            if lure then
                local _, lureSpellID = C.GetItemSpell(lure)
                self.pendingLure = { id = lure, time = GetTime(), spellID = lureSpellID }
                self:NoteItemAttempt(lure)
                SetMacro(button, "/use item:" .. lure .. "\n/use " .. (INVSLOT_MAINHAND or 16))
                self:TrackLureUsage()
                return
            end
        end
    end

    button:SetAttribute("type", "spell")
    button:SetAttribute("spell", self:GetFishingSpellName())
end

---------------------------------------------------------------------------
-- Reel mode: while the bobber is out, the fishing key becomes "Interact"
---------------------------------------------------------------------------
local reelOwner = CreateFrame("Frame") -- owner for our override bindings

function BB:StartReelMode()
    if not self:GetSetting("oneKeyReel") or InCombatLockdown() then return end

    local keys = { GetBindingKey(self.BINDING) }
    if #keys == 0 then return end
    for _, key in ipairs(keys) do
        SetOverrideBinding(reelOwner, true, key, "INTERACTTARGET")
    end

    -- Soft-interact lets "Interact With Target" pick up the bobber without targeting it
    if GetCVar("SoftTargetInteract") ~= "3" then
        self.db.savedSoftInteract = GetCVar("SoftTargetInteract")
        SetCVar("SoftTargetInteract", "3")
    end
    self.reelMode = true
end

function BB:EndReelMode()
    if not self.reelMode or InCombatLockdown() then return end
    ClearOverrideBindings(reelOwner)
    self:RestoreSoftInteractCVar()
    self.reelMode = false
end

function BB:RestoreSoftInteractCVar()
    if self.db and self.db.savedSoftInteract and not InCombatLockdown() then
        SetCVar("SoftTargetInteract", self.db.savedSoftInteract)
        self.db.savedSoftInteract = nil
    end
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
function BB:RegisterSlashCommands()
    SLASH_BOBBERBUDDY1 = "/bobberbuddy"
    SLASH_BOBBERBUDDY2 = "/bb"
    SlashCmdList["BOBBERBUDDY"] = function(msg)
        BB:HandleSlashCommand(msg)
    end
end

function BB:HandleSlashCommand(msg)
    local cmd = strtrim(msg or ""):lower()

    if cmd == "" or cmd == "help" then
        print("|cFF80FF80Bobber Buddy Commands:|r")
        print("  |cFFFFFF00/bb toggle|r - Toggle fish tracker display")
        print("  |cFFFFFF00/bb reset|r - Reset fish tracker position")
        print("  |cFFFFFF00/bb config|r - Open configuration panel")
        print("  |cFFFFFF00/bb stats|r - Show fishing statistics")
        print("  |cFFFFFF00/bb log|r - Open your lifetime fishing log")
        print("  |cFFFFFF00/bb lure|r - Show what Bobber Buddy sees about your lures")
        print("  |cFFFFFF00/bb gear|r - Swap back to your normal gear")
        print("  |cFFFFFF00/bb minimap|r - Show/hide the minimap button")
        print("  |cFFFFFF00/bb clear|r - Clear session fish data")
        print("  |cFFFFFF00/bb clearall|r - Clear all fish tracking data (with confirmation)")
        local key = GetBindingKey(self.BINDING)
        print("Fishing key: " .. (key and ("|cFFFFFF00" .. key .. "|r") or "|cFFFF4040not bound|r - set it in /bb config or Key Bindings > Bobber Buddy"))
    elseif cmd == "toggle" then
        self:SetSetting("showTracker", not self:GetSetting("showTracker"))
        self:UpdateTrackerVisibility()
    elseif cmd == "reset" then
        self:ResetTrackerPosition()
    elseif cmd == "config" then
        self:OpenSettings()
    elseif cmd == "stats" then
        self:ShowFishingStats()
    elseif cmd == "gear" then
        self:RestoreGear()
    elseif cmd == "lure" or cmd == "lures" then
        self:PrintLureStatus()
    elseif cmd == "log" then
        self:ToggleFishingLog()
    elseif cmd == "minimap" then
        self:SetSetting("showMinimapButton", not self:GetSetting("showMinimapButton"))
        self:UpdateMinimapButton()
        print("|cFF80FF80Bobber Buddy|r: Minimap button " .. (self:GetSetting("showMinimapButton") and "shown." or "hidden. Type /bb minimap to bring it back."))
    elseif cmd == "clear" then
        self:ClearSessionData()
        print("|cFF80FF80Bobber Buddy|r: Session fish data cleared.")
    elseif cmd == "clearall" then
        StaticPopup_Show("BOBBERBUDDY_CONFIRM_RESET")
    else
        print("|cFF80FF80Bobber Buddy|r: Unknown command. Type /bb for help.")
    end
end

function BB:ShowFishingStats()
    local stats = self.db.stats
    local currentZone = self.cache.lastZone or GetRealZoneText() or "Unknown"

    print("|cFF80FF80Bobber Buddy Statistics:|r")
    print("Session catches: " .. self:GetSessionTotal())
    print("Lifetime catches: " .. self:GetLifetimeTotal())
    print("Total fishing casts: " .. (stats.fishingCasts or 0))
    print("Time spent fishing: " .. SecondsToTime(self:GetTimeSpentFishing()))
    print("Lures used: " .. (stats.luresUsed or 0))
    print("Current zone: " .. currentZone)

    local sorted = {}
    for fish, count in pairs(self:GetZoneFishData(currentZone)) do
        table.insert(sorted, { name = fish, count = count })
    end
    if #sorted > 0 then
        table.sort(sorted, function(a, b) return a.count > b.count end)
        print("Top catches in " .. currentZone .. ":")
        for i = 1, math.min(3, #sorted) do
            print(i .. ". " .. sorted[i].name .. ": " .. sorted[i].count)
        end
    end
end
