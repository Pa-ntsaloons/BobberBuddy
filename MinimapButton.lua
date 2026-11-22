--[[
    BobberBuddy - Minimap Button
    Left-click: show/hide the fish tracker. Right-click: settings.
    Shift-click: swap back to normal gear. Drag to move it around the minimap.
]]

BobberBuddy = BobberBuddy or {}
local BB = BobberBuddy

local DEFAULT_ANGLE = 225 -- bottom-left of the minimap

local function UpdatePosition(button)
    local angle = math.rad(BB:GetSetting("minimapAngle") or DEFAULT_ANGLE)
    local radiusX = Minimap:GetWidth() / 2 + 5
    local radiusY = Minimap:GetHeight() / 2 + 5
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radiusX, math.sin(angle) * radiusY)
end

-- While dragging, follow the cursor around the minimap's edge
local function OnDragUpdate(button)
    local centerX, centerY = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local cursorX, cursorY = GetCursorPosition()
    local angle = math.deg(math.atan2(cursorY / scale - centerY, cursorX / scale - centerX)) % 360
    BB:SetSetting("minimapAngle", angle)
    UpdatePosition(button)
end

local function ShowTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:AddLine("Bobber Buddy")
    GameTooltip:AddLine("Session catches: " .. BB:GetSessionTotal(), 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cFFFFFF00Left-click|r to show/hide the fish tracker", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("|cFFFFFF00Right-click|r to open settings", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("|cFFFFFF00Ctrl-click|r to open your fishing log", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("|cFFFFFF00Shift-click|r to swap back to normal gear", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("|cFFFFFF00Drag|r to move this button", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end

function BB:InitMinimapButton()
    local button = CreateFrame("Button", "BobberBuddyMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    -- Standard round minimap button look
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(20, 20)
    background:SetPoint("TOPLEFT", 7, -5)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(136245) -- Trade_Fishing
    icon:SetSize(17, 17)
    icon:SetPoint("TOPLEFT", 7, -6)
    button.icon = icon

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    button:SetScript("OnClick", function(_, mouseButton)
        if IsShiftKeyDown() then
            BB:RestoreGear()
        elseif IsControlKeyDown() then
            BB:ToggleFishingLog()
        elseif mouseButton == "RightButton" then
            BB:OpenSettings()
        else
            BB:SetSetting("showTracker", not BB:GetSetting("showTracker"))
            BB:UpdateTrackerVisibility()
        end
    end)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", OnDragUpdate)
        GameTooltip:Hide()
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", GameTooltip_Hide)
    -- Pressed look: nudge the icon like Blizzard's buttons do
    button:SetScript("OnMouseDown", function() icon:SetPoint("TOPLEFT", 8, -7) end)
    button:SetScript("OnMouseUp", function() icon:SetPoint("TOPLEFT", 7, -6) end)

    self.minimapButton = button
    UpdatePosition(button)
    self:UpdateMinimapButton()
end

function BB:UpdateMinimapButton()
    if self.minimapButton then
        self.minimapButton:SetShown(self:GetSetting("showMinimapButton") and true or false)
    end
end
