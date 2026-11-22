--[[
    BobberBuddy - Fishing Sound Module
    While fishing:
      - optionally mute music, ambience and dialog and turn sound effects
        (where the bobber splash lives) up to full
      - optionally mute noisy sound groups (crafting, spells, footsteps, voices)
    Everything comes back once you stop fishing for a little while, when you
    enter combat, or on the next login if the game closed mid-fishing.
]]

BobberBuddy = BobberBuddy or {}
local BB = BobberBuddy



local FISHING_VOLUME = {
    Sound_EnableAllSound = "1",
    Sound_EnableSFX = "1",
    Sound_SFXVolume = "1.0",
    Sound_MusicVolume = "0",
    Sound_AmbienceVolume = "0",
    Sound_DialogVolume = "0",
}

-- Setting key -> list name in SoundLists.lua
BB.MUTE_GROUPS = {
    { setting = "muteCrafting",  list = "crafting" },
    { setting = "muteSpells",    list = "spells" },
    { setting = "muteFootsteps", list = "footsteps" },
    { setting = "muteVoices",    list = "voices" },
}

local function ForEachSound(listName, fn)
    local ranges = BB.SOUND_LISTS and BB.SOUND_LISTS[listName]
    if not ranges or not fn then return end
    local neverMute = BB.NEVER_MUTE or {}
    for i = 1, #ranges, 2 do
        for fileID = ranges[i], ranges[i + 1] do
            if not neverMute[fileID] then -- bobber/fishing sounds always stay audible
                fn(fileID)
            end
        end
    end
end

function BB:StartFishingSound()
    if self.soundRestoreTimer then
        self.soundRestoreTimer:Cancel()
        self.soundRestoreTimer = nil
    end

    -- Volumes
    if self:GetSetting("fishingSound") and not self.db.savedSound then
        local saved = {}
        for cvar, value in pairs(FISHING_VOLUME) do
            local current = GetCVar(cvar)
            if current ~= nil then
                saved[cvar] = current
                SetCVar(cvar, value)
            end
        end
        saved.Sound_MasterVolume = GetCVar("Sound_MasterVolume")
        self.db.savedSound = saved -- saved to disk so a reload or crash can't leave you muted
        self:ApplyFishingVolume()
    end

    -- Sound groups
    for _, group in ipairs(self.MUTE_GROUPS) do
        if self:GetSetting(group.setting) and not self.db.mutedSounds[group.list] then
            ForEachSound(group.list, MuteSoundFile)
            self.db.mutedSounds[group.list] = true
        end
    end
end

-- Master volume while fishing (the "Fishing volume" slider). Applied live, so
-- moving the slider mid-fishing changes it right away.
-- Your normal master volume (0-1): what we saved when fishing started, or the current setting
function BB:GetNormalMasterVolume()
    local saved = self.db.savedSound and tonumber(self.db.savedSound.Sound_MasterVolume)
    return saved or tonumber(GetCVar("Sound_MasterVolume")) or 1
end

-- Fishing volume is relative: 100% = your normal volume, 200% = twice as loud.
-- WoW's master volume can't go above 1.0, so the boost tops out there.
function BB:GetFishingMasterVolume()
    local boost = (self:GetSetting("fishingVolumeBoost") or 100) / 100
    return math.min(math.max(self:GetNormalMasterVolume() * boost, 0), 1)
end

-- Highest boost (in %) that still makes a difference with your normal volume
function BB:GetMaxUsefulBoost()
    local normal = self:GetNormalMasterVolume()
    if normal <= 0 then return 100 end
    return math.floor(100 / normal + 0.5)
end

function BB:ApplyFishingVolume()
    if self.db.savedSound then
        SetCVar("Sound_MasterVolume", tostring(self:GetFishingMasterVolume()))
    end
end

function BB:HasFishingSoundActive()
    return self.db.savedSound ~= nil or next(self.db.mutedSounds) ~= nil
end

-- Called when a cast ends; waits so sounds don't flicker between casts
function BB:ScheduleSoundRestore()
    if not self:HasFishingSoundActive() then return end
    if self.soundRestoreTimer then self.soundRestoreTimer:Cancel() end
    self.soundRestoreTimer = C_Timer.NewTimer(self:GetSetting("soundRestoreDelay") or 15, function()
        self.soundRestoreTimer = nil
        self:RestoreSound()
    end)
end

function BB:RestoreSound()
    if not self.db then return end

    local saved = self.db.savedSound
    if saved then
        for cvar, value in pairs(saved) do
            SetCVar(cvar, value)
        end
        self.db.savedSound = nil
    end

    for listName in pairs(self.db.mutedSounds) do
        ForEachSound(listName, UnmuteSoundFile)
    end
    wipe(self.db.mutedSounds)

    -- v2.3 could mute some bobber sounds; make sure they're always unmuted
    for fileID in pairs(BB.NEVER_MUTE or {}) do
        UnmuteSoundFile(fileID)
    end
end
