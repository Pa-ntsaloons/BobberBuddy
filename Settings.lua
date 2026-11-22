--[[
    BobberBuddy - Settings Module
    Options panel (Game Menu > Options > AddOns > Bobber Buddy)
]]

BobberBuddy = BobberBuddy or {}
local BB = BobberBuddy

local function CreateCheckbox(parent, label, tooltip, settingKey, onChange)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    local text = cb.text or cb.Text
    if text then text:SetText(label) end
    cb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", GameTooltip_Hide)
    cb:SetScript("OnClick", function(self)
        BB:SetSetting(settingKey, self:GetChecked() and true or false)
        if onChange then onChange() end
    end)
    cb.settingKey = settingKey
    return cb
end

local function CreateButton(parent, label, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(170, 24)
    button:SetText(label)
    button:SetScript("OnClick", onClick)
    return button
end

-- A "label  [ KEY ]" row: click the button, press a key, and it's bound (saved like the Key Bindings menu does)
local MODIFIER_KEYS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
    LMETA = true, RMETA = true, UNKNOWN = true }
local MOUSE_KEYS = { LeftButton = "BUTTON1", RightButton = "BUTTON2", MiddleButton = "BUTTON3",
    Button4 = "BUTTON4", Button5 = "BUTTON5" }

local function SaveBindingsNow()
    if SaveBindings and GetCurrentBindingSet then SaveBindings(GetCurrentBindingSet()) end
end

-- Held modifiers in the game's binding order, e.g. "ALT-SHIFT-"
local function ModifierPrefix()
    return (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "")
        .. (IsShiftKeyDown() and "SHIFT-" or "")
end

-- A see-through layer over the whole screen, shown ONLY while a binding button is waiting,
-- so a mouse button (or wheel) pressed anywhere is captured - not just on the button itself.
local mouseCatcher
local function GetMouseCatcher()
    if not mouseCatcher then
        mouseCatcher = CreateFrame("Frame", nil, UIParent)
        mouseCatcher:SetAllPoints(UIParent)
        mouseCatcher:SetFrameStrata("FULLSCREEN_DIALOG")
        mouseCatcher:EnableMouse(true)
        mouseCatcher:EnableMouseWheel(true)
        mouseCatcher:Hide()
        mouseCatcher:SetScript("OnMouseDown", function(self, mouseButton)
            if self.onMouse then self.onMouse(mouseButton) end
        end)
        mouseCatcher:SetScript("OnMouseWheel", function(self, delta)
            if self.onWheel then self.onWheel(delta) end
        end)
    end
    return mouseCatcher
end

function BB:CreateKeybindButton(parent, action, labelText)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(440, 24)

    local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT")
    label:SetWidth(200)
    label:SetJustifyH("LEFT")
    label:SetText(labelText)

    local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    button:SetSize(160, 22)
    button:SetPoint("LEFT", label, "RIGHT", 6, 0)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp", "Button4Up", "Button5Up")

    local function Refresh()
        local key = GetBindingKey(action)
        button:SetText(key and GetBindingText and GetBindingText(key) or key or "|cFF808080Not bound|r")
    end

    -- IMPORTANT: the key handler only exists while capturing. A frame with an OnKeyDown
    -- script can take keyboard input away from the game, so it must never linger.
    local function ReleaseKeyboard()
        button:SetScript("OnKeyDown", nil)
        button:EnableKeyboard(false)
        if button.SetPropagateKeyboardInput then button:SetPropagateKeyboardInput(true) end
        local catcher = GetMouseCatcher()
        if catcher.owner == button then
            catcher.owner, catcher.onMouse, catcher.onWheel = nil, nil, nil
            catcher:Hide()
        end
    end

    -- fromKey: we're inside a key press. Release the keyboard on the next frame, so the
    -- key that ended the capture (Escape, or the key you bound) doesn't also reach the game
    -- - otherwise Escape would close the options window.
    local function StopCapture(fromKey)
        button.capturing = false
        button.pendingKey = nil
        button:UnlockHighlight()
        Refresh()
        if fromKey then C_Timer.After(0, ReleaseKeyboard) else ReleaseKeyboard() end
    end

    local function NameOfAction(bindingAction)
        return _G["BINDING_NAME_" .. bindingAction] or bindingAction
    end

    local function Bind(key, fromKey)
        if InCombatLockdown() then
            print("|cFF80FF80Bobber Buddy|r: Can't change key bindings in combat.")
            return StopCapture(fromKey)
        end
        local shown = GetBindingText and GetBindingText(key) or key
        local previous = GetBindingAction(key)

        -- Key already does something else (e.g. W = Move Forward)? Ask before taking it.
        if previous and previous ~= "" and previous ~= action and button.pendingKey ~= key then
            button.pendingKey = key
            button:SetText("|cFFFF8040" .. shown .. " again to replace|r")
            print("|cFF80FF80Bobber Buddy|r: |cFFFFFF00" .. shown .. "|r is already used for |cFFFFFF00" ..
                NameOfAction(previous) .. "|r. Press it again to use it for " .. labelText ..
                " instead, or press another key. Escape cancels.")
            return -- keep capturing
        end

        -- One key per action: drop our old key(s) first
        for _, oldKey in ipairs({ GetBindingKey(action) }) do SetBinding(oldKey) end
        if SetBinding(key, action) then
            SaveBindingsNow()
            if previous and previous ~= "" and previous ~= action then
                print("|cFF80FF80Bobber Buddy|r: " .. shown .. " is now " .. labelText ..
                    " (it was " .. NameOfAction(previous) .. ").")
            end
        end
        StopCapture(fromKey)
    end

    button:SetScript("OnClick", function(self, mouseButton)
        -- Right-click clears (when not already waiting for a key)
        if mouseButton == "RightButton" then
            row.Clear()
            return
        end
        if mouseButton ~= "LeftButton" or self.capturing then return end

        self.capturing = true
        self:SetText("|cFFFFFF00Press a key or mouse button...|r")
        self:LockHighlight()

        -- Keyboard
        self:SetScript("OnKeyDown", function(btn, key)
            -- Keep this key press to ourselves (Escape must not close the options window)
            if btn.SetPropagateKeyboardInput then btn:SetPropagateKeyboardInput(false) end
            if not btn.capturing or MODIFIER_KEYS[key] then return end
            if key == "ESCAPE" then return StopCapture(true) end
            Bind(ModifierPrefix() .. key, true)
        end)
        self:EnableKeyboard(true)
        if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end

        -- Mouse buttons and wheel, anywhere on screen
        local catcher = GetMouseCatcher()
        catcher.owner = self
        catcher.onMouse = function(pressed)
            local mods = ModifierPrefix()
            -- Plain left/right click can't be a binding (you'd lose camera and clicking) - it cancels
            if (pressed == "LeftButton" or pressed == "RightButton") and mods == "" then
                return StopCapture()
            end
            if MOUSE_KEYS[pressed] then Bind(mods .. MOUSE_KEYS[pressed]) end
        end
        catcher.onWheel = function(delta)
            Bind(ModifierPrefix() .. (delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN"))
        end
        catcher:Show()
    end)
    button:SetScript("OnHide", function(self) if self.capturing then StopCapture() end end)

    -- Start with the keyboard fully off (no capture yet)
    button:EnableKeyboard(false)

    -- Remove every key bound to this action, and check that it actually worked
    function row.Clear()
        if InCombatLockdown() then
            print("|cFF80FF80Bobber Buddy|r: Can't change key bindings in combat.")
            return
        end
        if button.capturing then StopCapture() end
        local keys = { GetBindingKey(action) }
        if #keys == 0 then return end
        for _, key in ipairs(keys) do
            SetBinding(key)
            if GetBindingAction(key) == action and GetCurrentBindingSet then
                SetBinding(key, nil, GetCurrentBindingSet()) -- some clients want the binding set spelled out
            end
        end
        SaveBindingsNow()
        Refresh()

        local stillBound = GetBindingKey(action)
        local shown = {}
        for _, key in ipairs(keys) do shown[#shown + 1] = GetBindingText and GetBindingText(key) or key end
        if stillBound then
            print("|cFF80FF80Bobber Buddy|r: Couldn't clear that key here - clear it under Options > Key Bindings > Bobber Buddy.")
        else
            print("|cFF80FF80Bobber Buddy|r: Cleared " .. table.concat(shown, ", ") .. " from " .. labelText ..
                ". If that key used to do something else (like W for Move Forward), set it again under Options > Key Bindings.")
        end
    end

    local clear = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    clear:SetSize(56, 22)
    clear:SetPoint("LEFT", button, "RIGHT", 6, 0)
    clear:SetText("Clear")
    clear:SetScript("OnClick", function() row.Clear() end)

    row.Refresh = Refresh
    Refresh()
    return row
end

function BB:InitSettings()
    -- The page the options window shows. Everything lives inside a scroll area so the page
    -- fits any window size or UI scale instead of spilling past the bottom.
    local outer = CreateFrame("Frame", "BobberBuddyOptionsPanel")
    outer:Hide() -- the options window shows it when you open the page; never active before that
    outer.name = "Bobber Buddy"
    self.optionsPanel = outer

    local scroll = CreateFrame("ScrollFrame", "BobberBuddyOptionsScroll", outer, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -4)
    scroll:SetPoint("BOTTOMRIGHT", -28, 4)
    local panel = CreateFrame("Frame", nil, scroll)
    panel:SetSize(640, 760) -- height is corrected to fit the content in Relayout
    scroll:SetScrollChild(panel)
    scroll:SetScript("OnSizeChanged", function(_, width) if width and width > 0 then panel:SetWidth(width) end end)

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Bobber Buddy")

    local version = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    version:SetText("Version " .. self.version)

    -- Checkboxes
    local checkboxes = {
        CreateCheckbox(panel, "Automatically apply fishing lures",
            "When your pole has no lure, the fishing key applies the best lure in your bags first.",
            "enableAutoLure"),
        CreateCheckbox(panel, "Wear fishing gear",
            "Puts on any hats, boots, gloves, rings or trinkets in your bags that add Fishing skill. Use /bb gear (or its key binding) to swap back.",
            "enableFishingGear"),
        CreateCheckbox(panel, "Use fishing buff food and drink",
            "Eats or drinks the best item in your bags that adds Fishing skill, when its buff isn't already active.",
            "enableBuffItems"),
        CreateCheckbox(panel, "Make the bobber easier to hear",
            "While fishing, mutes music, ambience and dialog and turns sound effects up to full. Your volumes come back a little after your last cast (you can set how long below), or as soon as you enter combat.",
            "fishingSound", function()
                if not BB:GetSetting("fishingSound") then BB:RestoreSound() end
            end),
        CreateCheckbox(panel, "One-key reel in",
            "While your bobber is out, the fishing key acts as Interact With Target, so pressing it again when the bobber splashes reels in your catch.",
            "oneKeyReel"),
        CreateCheckbox(panel, "Show fish tracker window",
            "Shows the window listing what you've caught this session.",
            "showTracker", function() BB:UpdateTrackerVisibility() end),
        CreateCheckbox(panel, "Show tracker when you equip a pole or cast",
            "Opens the fish tracker window when a fishing pole goes into your hands, and when you start a cast " ..
            "(so it also appears if the pole was already equipped).",
            "showTrackerWithPole"),
        CreateCheckbox(panel, "Close tracker when you unequip the fishing pole",
            "Closes the fish tracker window when the pole leaves your hands - by swapping back to your weapons or unequipping it.",
            "hideTrackerWithoutPole"),
        CreateCheckbox(panel, "Show minimap button",
            "Left-click it to show/hide the tracker, right-click for settings, shift-click to swap back to normal gear. Drag to move it. You can also type /bb minimap.",
            "showMinimapButton", function() BB:UpdateMinimapButton() end),
    }
    local last = version
    for i, cb in ipairs(checkboxes) do
        cb:SetPoint("TOPLEFT", last, "BOTTOMLEFT", i == 1 and -2 or 0, i == 1 and -16 or -4)
        last = cb
    end

    -- Second column: sounds to mute while fishing
    local muteTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    muteTitle:SetPoint("TOPLEFT", checkboxes[1], "TOPLEFT", 330, 0)
    muteTitle:SetText("While fishing, also mute:")

    -- Changing these mid-fishing takes effect on your next cast
    local function ResetMutes() BB:RestoreSound() end
    local muteBoxes = {
        CreateCheckbox(panel, "Crafting sounds (anvils, forges)",
            "Blacksmithing hammering, town forges and other profession sounds, from you or anyone nearby.",
            "muteCrafting", ResetMutes),
        CreateCheckbox(panel, "Spell sounds",
            "All spell sounds - other players' and your own. Your fishing cast and the bobber splash are not affected.",
            "muteSpells", ResetMutes),
        CreateCheckbox(panel, "Footsteps",
            "Footsteps of every player, NPC and mount, including yours.",
            "muteFootsteps", ResetMutes),
        CreateCheckbox(panel, "Character voices and emotes",
            "Player grunts, battle cries, /emote voices and clapping.",
            "muteVoices", ResetMutes),
    }
    local muteLast = muteTitle
    for i, cb in ipairs(muteBoxes) do
        cb:SetPoint("TOPLEFT", muteLast, "BOTTOMLEFT", i == 1 and -2 or 0, i == 1 and -6 or -4)
        muteLast = cb
        table.insert(checkboxes, cb) -- so OnShow refreshes them too
    end

    local muteNote = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    muteNote:SetPoint("TOPLEFT", muteLast, "BOTTOMLEFT", 2, -6)
    muteNote:SetWidth(260)
    muteNote:SetJustifyH("LEFT")
    muteNote:SetText("Everything comes back when you enter combat, or after the delay below. The bobber splash is never muted.")

    -- Sliders: { label, min, max, step, low text, high text, format(value), load(), save(value), tooltip }
    local sliders = {}
    local function CreateSlider(anchor, opts)
        local label = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -18)

        local slider = CreateFrame("Slider", nil, panel, "BackdropTemplate")
        slider:SetOrientation("HORIZONTAL")
        slider:SetSize(180, 17)
        slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
        slider:SetHitRectInsets(0, 0, -10, -10)
        slider:SetBackdrop({
            bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
            edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 3, right = 3, top = 6, bottom = 6 },
        })
        slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
        slider:SetMinMaxValues(opts.min, opts.max)
        slider:SetValueStep(opts.step)
        slider:SetObeyStepOnDrag(true)
        -- No mouse wheel: the page scrolls, and wheeling over a slider would change it by accident

        local low = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        low:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -2)
        low:SetText(opts.lowText)
        local high = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        high:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
        high:SetText(opts.highText)

        -- Typeable box next to the slider. It only takes the keyboard while you've clicked into it,
        -- and lets go on Enter, Escape, clicking elsewhere or closing settings.
        local box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        box:SetSize(40, 20)
        box:SetPoint("LEFT", slider, "RIGHT", 14, 0)
        box:SetAutoFocus(false)
        box:SetNumeric(true)
        box:SetMaxLetters(3)
        box:SetJustifyH("CENTER")
        local unit = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        unit:SetPoint("LEFT", box, "RIGHT", 4, 0)
        unit:SetText(opts.unit)

        local function SetLabel(value)
            label:SetText(opts.label .. ": |cFFFFFFFF" .. opts.format(value) .. "|r")
            if not box:HasFocus() then box:SetText(tostring(value)) end
        end

        local function ApplyTyped()
            local typed = tonumber(box:GetText())
            if typed then
                typed = math.min(math.max(math.floor(typed), opts.min), opts.max)
                slider:SetValue(typed)
            end
            box:SetText(tostring(math.floor(slider:GetValue() + 0.5)))
        end
        box:SetScript("OnEnterPressed", function(b) ApplyTyped(); b:ClearFocus() end)
        box:SetScript("OnEscapePressed", function(b)
            b:ClearFocus()
            b:SetText(tostring(math.floor(slider:GetValue() + 0.5))) -- undo what was typed
        end)
        box:SetScript("OnEditFocusLost", ApplyTyped)
        box:SetScript("OnHide", function(b) b:ClearFocus() end)

        slider:SetScript("OnValueChanged", function(_, value)
            -- Dragging still snaps to steps (SetObeyStepOnDrag); typed values can be any whole number
            value = math.floor(value + 0.5)
            SetLabel(value)
            opts.save(value)
        end)
        slider:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetText(opts.tooltip, nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        slider:SetScript("OnLeave", GameTooltip_Hide)

        -- Called from the panel's OnShow
        slider.Refresh = function()
            -- Some sliders work out their top end when shown (e.g. how loud the game can still go)
            if opts.getMax then
                opts.max = math.max(opts.getMax(), opts.min)
                slider:SetMinMaxValues(opts.min, opts.max)
                high:SetText(opts.max .. opts.unit)
            end
            local value = math.min(math.max(opts.load(), opts.min), opts.max)
            slider:SetValue(value)
            SetLabel(value)
        end
        table.insert(sliders, slider)
        return low -- anchor for whatever goes below
    end

    -- Fishing volume, relative to your normal volume (100% = unchanged)
    local below = CreateSlider(muteNote, {
        label = "Fishing volume", min = 50, max = 400, step = 10, lowText = "50%", highText = "400%", unit = "%",
        -- Top of the slider = as loud as WoW can go from your normal volume (it can't pass master 100%)
        getMax = function() return math.min(BB:GetMaxUsefulBoost(), 400) end,
        format = function(v)
            if v == 100 then return "100% (normal)" end
            return v .. "%"
        end,
        load = function() return BB:GetSetting("fishingVolumeBoost") or 100 end,
        save = function(v)
            BB:SetSetting("fishingVolumeBoost", v)
            BB:ApplyFishingVolume() -- hear the change right away if you're fishing
        end,
        tooltip = "How loud the game is while fishing, compared to your normal volume. " ..
            "100% = normal. The right end is the loudest the game can go.",
    })

    -- How long after your last cast before sounds come back
    local rightBottom = CreateSlider(below, {
        label = "Sound comes back after", min = 5, max = 120, step = 5, lowText = "5 sec", highText = "2 min", unit = "sec",
        format = function(v) return v .. " sec" end,
        load = function() return BB:GetSetting("soundRestoreDelay") or 15 end,
        save = function(v) BB:SetSetting("soundRestoreDelay", v) end,
        tooltip = "How long after your last cast ends before your normal volumes and muted sounds come back. " ..
            "Casting again within this time keeps everything as it is. Entering combat always brings sound back right away.",
    })

    -- Key bindings (starts below whichever column is longer - see Relayout)
    local keybindTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    keybindTitle:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 2, -20)
    keybindTitle:SetText("Key bindings")

    local fishKey = BB:CreateKeybindButton(panel, BB.BINDING, "Fish (cast / reel in)")
    fishKey:SetPoint("TOPLEFT", keybindTitle, "BOTTOMLEFT", 0, -8)
    local restoreKey = BB:CreateKeybindButton(panel, "BOBBERBUDDY_RESTORE", "Swap back to normal gear")
    restoreKey:SetPoint("TOPLEFT", fishKey, "BOTTOMLEFT", 0, -6)
    local keybindButtons = { fishKey, restoreKey }

    local keybindInfo = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    keybindInfo:SetPoint("TOPLEFT", restoreKey, "BOTTOMLEFT", 0, -6)
    keybindInfo:SetWidth(580)
    keybindInfo:SetJustifyH("LEFT")
    keybindInfo:SetText("Click a button, then press a key or mouse button (middle, 4, 5, wheel, or Shift/Ctrl/Alt + any click). Escape or a plain click cancels; Clear removes it. A key that is already in use needs pressing twice. " ..
        "These are also under Key Bindings > Bobber Buddy.")

    -- Stats
    local statsTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    statsTitle:SetPoint("TOPLEFT", keybindInfo, "BOTTOMLEFT", 0, -16)
    statsTitle:SetText("Fishing statistics")

    local statsText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    statsText:SetPoint("TOPLEFT", statsTitle, "BOTTOMLEFT", 0, -6)
    statsText:SetWidth(580)
    statsText:SetJustifyH("LEFT")

    -- Buttons, 2 x 2
    local restoreGear = CreateButton(panel, "Swap Back to Normal Gear", function() BB:RestoreGear() end)
    restoreGear:SetPoint("TOPLEFT", statsText, "BOTTOMLEFT", 0, -16)

    local resetPos = CreateButton(panel, "Reset Tracker Position", function() BB:ResetTrackerPosition() end)
    resetPos:SetPoint("LEFT", restoreGear, "RIGHT", 10, 0)

    local clearSession = CreateButton(panel, "Clear Session Tracking", function()
        BB:ClearSessionData()
        outer:GetScript("OnShow")(outer)
    end)
    clearSession:SetPoint("TOPLEFT", restoreGear, "BOTTOMLEFT", 0, -6)

    local resetAll = CreateButton(panel, "Reset All Data", function()
        StaticPopup_Show("BOBBERBUDDY_CONFIRM_RESET")
    end)
    resetAll:SetPoint("LEFT", clearSession, "RIGHT", 10, 0)

    -- The right column (mute options + sliders) can be longer than the checkbox column;
    -- push the bottom sections down so they never run underneath it.
    local function Relayout()
        local leftBottom, rightBottomY = last:GetBottom(), rightBottom:GetBottom()
        local extra = 0
        if leftBottom and rightBottomY and rightBottomY < leftBottom then
            extra = leftBottom - rightBottomY
        end
        keybindTitle:ClearAllPoints()
        keybindTitle:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 2, -20 - extra)

        -- Make the scroll area exactly as tall as the content (plus a little room)
        local top, bottom = panel:GetTop(), clearSession:GetBottom()
        if top and bottom then panel:SetHeight(top - bottom + 24) end
    end

    -- Refresh everything whenever the page is shown
    outer:SetScript("OnShow", function()
        for _, cb in ipairs(checkboxes) do
            cb:SetChecked(BB:GetSetting(cb.settingKey))
        end
        for _, slider in ipairs(sliders) do slider.Refresh() end
        Relayout()
        C_Timer.After(0, Relayout) -- again once the game has finished laying the page out

        for _, kb in ipairs(keybindButtons) do kb.Refresh() end

        local stats = BB.db.stats
        statsText:SetText(
            "Session catches: " .. BB:GetSessionTotal() .. "   |   Lifetime catches: " .. BB:GetLifetimeTotal() .. "\n" ..
            "Casts: " .. (stats.fishingCasts or 0) .. "   |   Lures used: " .. (stats.luresUsed or 0) ..
            "   |   Time fishing: " .. SecondsToTime(BB:GetTimeSpentFishing()))
    end)

    -- Register with whichever options system this client has
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(outer, outer.name)
        Settings.RegisterAddOnCategory(category)
        self.settingsCategory = category
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(outer)
    end
end

function BB:OpenSettings()
    if self.settingsCategory then
        Settings.OpenToCategory(self.settingsCategory:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel) -- first call often lands on the wrong page
    end
end
