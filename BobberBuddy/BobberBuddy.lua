-- Addon Initialization
local addonName = ...
local BobberBuddy = {}
local internal = {
  -- Internal state and defaults
  frame = CreateFrame("Frame"), -- Frame for event handling
  clearOverride = false, -- Tracks if override bindings need to be cleared
  cvarsChanged = false, -- Tracks if CVars have been modified
  isClassic = WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE, -- Checks if the game is Classic WoW
}

local softInteractDebounceTimer = nil

-- Keybinding name for the addon
BINDING_NAME_BOBBERBUDDYKEY = "Cast and Catch"

-- Fishing spell IDs for Classic WoW
local classicFishingIDs = {
  7620, 7731, 7732, 18248, 33095, 51294, 88868
}

-- Retrieves the fishing spell ID for casting
function BobberBuddy:GetFishingCastID()
  if internal.isClassic then
    for _, spellID in ipairs(classicFishingIDs) do
      if IsSpellKnown(spellID) then
        return spellID
      end
    end
  end
  return 131476 -- Default fishing spell ID for retail
end

-- Retrieves the fishing spell ID for interaction
function BobberBuddy:GetFishingID()
  if internal.isClassic then
    for _, spellID in ipairs(classicFishingIDs) do
      if IsSpellKnown(spellID) then
        return spellID
      end
    end
  end
  return 131474 -- Default fishing spell ID for retail
end

-- Retrieves the localized name of the fishing spell
function BobberBuddy:GetFishingName()
  local GetSpellName = GetSpellInfo or C_Spell.GetSpellName
  local localizedName = GetSpellName(7620) -- Fishing spell ID
  return localizedName or GetSpellName(131474)
end

-- Utility function to check if the game state is Insecure (e.g., during combat)
local function IsInsecureEnvironment()
    return InCombatLockdown() or UnitAffectingCombat("player") or UnitAffectingCombat("pet")
end

-- Creates or retrieves a secure button for fishing
function BobberBuddy:GetSecureButton()
  if not self.secureButton then
    local button = CreateFrame("Button", addonName .. "Button", nil, "SecureActionButtonTemplate")
    button:RegisterForClicks("AnyDown", "AnyUp")
    button:SetAttribute("type", "spell")
    button:SetAttribute("spell", self:GetFishingID())
    button:SetScript("PostClick", function(_, _, down)
      MouselookStart()
      if not down then
        MouselookStop()
      end
    end)
    SecureHandlerWrapScript(button, "PostClick", button, string.format([[
      local isClassic = %s
      if isClassic then
        self:ClearBindings()
      else
        if not down then
          self:ClearBindings()
        end
      end
    ]], tostring(internal.isClassic)))

    self.secureButton = button
  end
  return self.secureButton
end

-- Checks if the player is flying (includes Zen Flight for monks)
function BobberBuddy:IsFlying()
  if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID(125883) then
    return false
  else
    return IsFlying()
  end
end

-- Main function to handle fishing logic
function BobberBuddy_Fish()
    if IsInsecureEnvironment() or BobberBuddy:IsFlying() or GetNumLootItems() ~= 0 or BobberBuddy:IsFishing() or (not BobberBuddyDB.overrideLunker and BobberBuddy:IsLunkerActive()) then
        return
    end

    local key1, key2 = GetBindingKey("BOBBERBUDDYKEY")
    local localizedName = BobberBuddy:GetFishingName()
    if key1 then
        SetOverrideBindingSpell(BobberBuddy:GetSecureButton(), true, key1, localizedName)
    end
    if key2 then
        SetOverrideBindingSpell(BobberBuddy:GetSecureButton(), false, key2, localizedName)
    end

    -- Fallback timer to ensure fishing state is detected
    C_Timer.After(0.5, function()
        if not isFishingActive and BobberBuddy:IsFishing() then
            print("Fallback: Fishing state detected.")
            isFishingActive = true
        end
    end)

    -- Force a soft interact update after a delay
    C_Timer.After(3, function()
        WeakAuras.ScanEvents("PLAYER_SOFT_INTERACT_CHANGED")
    end)
end

-- Hook for mouse clicks to handle double-click fishing
WorldFrame:HookScript("OnMouseDown", function(_, button)
  if not BobberBuddyDB.doubleClickEnabled then return end
  if button == "RightButton" and not IsInsecureEnvironment() then
    if GetNumLootItems() == 0 then
      local doubleClickTime = GetTime() - internal.previousClickTime
      if doubleClickTime >= internal.DOUBLECLICK_MIN_SECONDS and doubleClickTime <= BobberBuddyDB.doubleClickSpeed then
        if BobberBuddy:AllowFishing() then
          SetOverrideBindingClick(BobberBuddy:GetSecureButton(), true, "BUTTON2", addonName .. "Button")
        elseif BobberBuddy:IsFishing() then
          SetOverrideBinding(BobberBuddy:GetSecureButton(), true, "BUTTON2", "INTERACTTARGET")
        end
        internal.previousClickTime = nil
      end
    end
    internal.previousClickTime = GetTime()
  end
end)

-- Checks if the player is currently fishing
function BobberBuddy:IsFishing()
  local spellID = select(8, UnitChannelInfo("player"))
  return spellID == self:GetFishingCastID() or spellID == 377895
end

-- Checks if a lunker is active (specific fishing mechanic)
function BobberBuddy:IsLunkerActive()
  local spellID = select(8, UnitChannelInfo("player"))
  return spellID == 392270
end

-- Checks if the player has a fishing pole equipped
function BobberBuddy:IsFishingPoleEquipped()
  local itemID = GetInventoryItemID("player", INVSLOT_MAINHAND)
  if itemID then
    local subclassID = select(7, C_Item.GetItemInfoInstant(itemID))
    return subclassID == Enum.ItemWeaponSubclass.Fishingpole
  end
  return false
end

-- Checks if the bobber is within the interactable range
function BobberBuddy:IsBobberInteractable()
    local interactRange = tonumber(GetCVar("SoftTargetInteractRange")) or 25 -- Default to 25 if the CVar is not set
    local bobberGUID = UnitGUID("mouseover")

    if bobberGUID and UnitExists("mouseover") then
        local distance = CheckInteractDistance("mouseover", 3) -- 3 = interact range
        print(string.format("Bobber detected. Distance: %s. Interact range: %s.", tostring(distance), tostring(interactRange)))
        return distance and distance <= interactRange
    else
        print("No bobber detected under the cursor.")
    end

    return false
end

-- Determines if fishing is allowed based on various conditions
function BobberBuddy:AllowFishing()
  if not IsSpellKnown(self:GetFishingID())
  or (internal.isClassic and not self:IsFishingPoleEquipped())
  or IsPlayerMoving()
  or IsMounted()
  or self:IsFlying()
  or IsFalling()
  or IsStealthed()
  or IsSwimming()
  or IsSubmerged()
  or UnitHasVehicleUI("player")
  or not HasFullControl() then
    return false
  end

  if not BobberBuddyDB.overrideLunker and self:IsLunkerActive() then
    return false
  end

  if self:IsFishing() then
    return (BobberBuddyDB.recastOnDoubleClick and not IsModifierKeyDown()) or (not BobberBuddyDB.recastOnDoubleClick and IsModifierKeyDown())
  end

  return true
end

-- Table of CVars related to interaction
local interactCVars = {
  "SoftTargetInteract",
  "SoftTargetInteractArc",
  "SoftTargetInteractRange",
  "SoftTargetIconGameObject",
  "SoftTargetIconInteract"
}

-- Cache for interaction CVars
local interactCVarCache = {}

-- Initialize the interaction CVars cache
do
  for _, cvar in ipairs(interactCVars) do
    interactCVarCache[string.lower(cvar)] = GetCVar(cvar)
  end
end

-- Hook to monitor changes to CVars
hooksecurefunc(C_CVar, "SetCVar", function(cvar, value)
  if internal.cvarsChanged then return end
  local cvarLower = string.lower(cvar)
  if interactCVarCache[cvarLower] then
    interactCVarCache[cvarLower] = value
  end
end)

-- Resets CVars to their original values
function BobberBuddy:ResetCVars(logout)
  if not logout then
    internal.cvarsChanged = true
  end
  for cvar, value in pairs(interactCVarCache) do
    SetCVar(cvar, value)
  end
  C_Timer.After(0.2, function() internal.cvarsChanged = false end)
end

-- Sets CVars for fishing interaction
function BobberBuddy:SetCVars()
  internal.cvarsChanged = true
  SetCVar("SoftTargetInteract", 3)
  SetCVar("SoftTargetInteractArc", 2)
  SetCVar("SoftTargetInteractRange", 25)
  SetCVar("SoftTargetIconGameObject", BobberBuddyDB.objectIconDisabled and 0 or 1)
  SetCVar("SoftTargetIconInteract", BobberBuddyDB.objectIconDisabled and 0 or 1)
  C_Timer.After(0.2, function() internal.cvarsChanged = false end)
end

-- Event handler for the addon
function BobberBuddy:OnEvent(event, ...)
    if event == "ADDON_LOADED" and addonName == ... then
        BobberBuddyDB = BobberBuddyDB or {}
    elseif event == "PLAYER_REGEN_ENABLED" then
        if internal.clearOverride then
            ClearOverrideBindings(self:GetSecureButton())
            internal.clearOverride = false
            self:ResetCVars()
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        local unit, _, spellID = ...
        if unit == "player" and (spellID == self:GetFishingCastID() or spellID == 377895) then
            isFishingActive = true -- Mark fishing as active
            print("Fishing state detected: Active")
            self:SetCVars()
            if IsInsecureEnvironment() then return end
            local key1, key2 = GetBindingKey("BOBBERBUDDYKEY")
            if key1 then
                SetOverrideBinding(self:GetSecureButton(), true, key1, "INTERACTTARGET")
            end
            if key2 then
                SetOverrideBinding(self:GetSecureButton(), true, key2, "INTERACTTARGET")
            end
        end
    elseif event == "PLAYER_SOFT_INTERACT_CHANGED" then
        -- Debug: Confirm the event is triggered
        print("PLAYER_SOFT_INTERACT_CHANGED event triggered.")

        -- Only handle this event if fishing is active
        if not isFishingActive then
            print("Fishing is not active. Ignoring event.")
            return
        end

        -- Update the fishing target state
        local interactState = ...
        fishingTargetInSoftBox = interactState -- Update the state based on the event argument

        -- Debug: Print the interact state
        print("Updated fishingTargetInSoftBox: " .. tostring(fishingTargetInSoftBox))

        -- Cancel the existing timer if it exists
        if softInteractDebounceTimer then
            softInteractDebounceTimer:Cancel()
            softInteractDebounceTimer = nil
        end

        -- Start a new debounce timer
        softInteractDebounceTimer = C_Timer.NewTimer(3, function()
            if not fishingTargetInSoftBox then
                print("Bobber not detected within 3 seconds. Forcing stand emote.")
                DoEmote("stand") -- Force the character to stand
                isFishingActive = false -- Reset fishing state after standing
            else
                print("Bobber detected within the soft interact box.")
            end
        end)
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        local unit, _, spellID = ...
        if unit == "player" and (spellID == self:GetFishingCastID() or spellID == 377895) then
            isFishingActive = false -- Mark fishing as inactive
            print("Fishing state: " .. (isFishingActive and "Active" or "Inactive"))
            if not IsInsecureEnvironment() then
                self:ResetCVars()
                ClearOverrideBindings(self:GetSecureButton())
            else
                internal.clearOverride = true
            end
        end
    elseif event == "PLAYER_LOGOUT" then
        self:ResetCVars(true)
    elseif event == "CVAR_UPDATE" then
        if self:IsFishing() then return end
    end
end

-- Register events for the addon
internal.frame:SetScript("OnEvent", function(_, ...) BobberBuddy:OnEvent(...) end)
FrameUtil.RegisterFrameForEvents(internal.frame, {
    "ADDON_LOADED",
    "PLAYER_REGEN_ENABLED",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP",
    "CVAR_UPDATE",
    "PLAYER_LOGOUT",
    "PLAYER_SOFT_INTERACT_CHANGED" -- New event
})
