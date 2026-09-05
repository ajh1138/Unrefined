local addonName, ns = ...

-- Emote tokens accepted by DoEmote(), keyed by our internal setting names.
ns.EMOTE_TOKENS = {
    burp = "BURP",
    fart = "FART",
    picknose = "PICK",
    moon = "MOON",
    spit = "SPIT",
    rude = "RUDE",
    drool = "DROOL",
    scratch = "SCRATCH",
    lick = "LICK",
    squeal = "SQUEAL",
    sniff = "SNIFF",
    snort = "SNORT",
    bonk = "BONK",
    chicken = "CHICKEN",
    shifty = "SHIFTY",
    cough = "COUGH",
    cackle = "CACKLE",
    mock = "MOCK",
}
ns.EMOTE_ORDER = {
    "burp", "fart", "picknose", "moon", "spit", "rude", "drool", "scratch",
    "lick", "squeal", "sniff", "snort", "bonk", "chicken", "shifty", "cough", "cackle", "mock",
}
ns.EMOTE_LABELS = {
    burp = "Burp",
    fart = "Fart",
    picknose = "Pick Nose",
    moon = "Moon",
    spit = "Spit",
    rude = "Rude Gesture",
    drool = "Drool",
    scratch = "Scratch",
    lick = "Lick",
    squeal = "Squeal",
    sniff = "Sniff",
    snort = "Snort",
    bonk = "Bonk",
    chicken = "Chicken",
    shifty = "Shifty",
    cough = "Cough",
    cackle = "Cackle",
    mock = "Mock",
}
-- Maps a slash-command word to its internal emote key, for the handful that don't match directly.
ns.EMOTE_ALIASES = { nose = "picknose" }

local defaults = {
    enabled = true,
    emotes = {
        burp = true, fart = true, picknose = true, moon = true,
        spit = true, rude = true, drool = true, scratch = true,
        lick = true, squeal = true, sniff = true,
        snort = true, bonk = true, chicken = true, shifty = true, cough = true,
        cackle = true, mock = true,
    },
    minMinutes = 5,
    maxMinutes = 7,
    allowInCombat = false,
    allowInDungeons = true,
    allowInPvP = false,
    emoteOnZoneChange = false,
}

-- Fills in any missing keys in UnrefinedDB from defaults without clobbering saved values.
local function ApplyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            ApplyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

local function ClampMinutes(n)
    n = tonumber(n) or 1
    if n < 1 then n = 1 end
    if n > 30 then n = 30 end
    return math.floor(n + 0.5)
end
ns.ClampMinutes = ClampMinutes

-- True while inside a 5-player dungeon or raid instance (not scenarios, arenas, or battlegrounds).
local function IsInDungeonOrRaid()
    local inInstance, instanceType = IsInInstance()
    return inInstance and (instanceType == "party" or instanceType == "raid")
end

-- True while inside a battleground or arena.
local function IsInPvPInstance()
    local inInstance, instanceType = IsInInstance()
    return inInstance and (instanceType == "pvp" or instanceType == "arena")
end

-- Keeps min <= max after any edit (options panel or slash command).
function ns.FixRange()
    UnrefinedDB.minMinutes = ClampMinutes(UnrefinedDB.minMinutes)
    UnrefinedDB.maxMinutes = ClampMinutes(UnrefinedDB.maxMinutes)
    if UnrefinedDB.minMinutes > UnrefinedDB.maxMinutes then
        UnrefinedDB.minMinutes, UnrefinedDB.maxMinutes = UnrefinedDB.maxMinutes, UnrefinedDB.minMinutes
    end
end

local function EnabledEmoteList()
    local list = {}
    for _, key in ipairs(ns.EMOTE_ORDER) do
        if UnrefinedDB.emotes[key] then
            table.insert(list, key)
        end
    end
    return list
end

-- Shuffle-bag randomization: drains a shuffled queue of the currently-enabled emotes so
-- every one gets used equally often over time, then reshuffles once the bag runs dry.
-- Plain uniform-random picking can cluster (the same emote popping up 3 times in 5 picks
-- while another rarely shows), which a bag avoids.
local bag = {}
local lastEmoteKey

local function ShuffleBag(list)
    local shuffled = {}
    for i, key in ipairs(list) do
        shuffled[i] = key
    end
    for i = #shuffled, 2, -1 do
        local j = math.random(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end
    -- table.remove(bag) below pops from the end, so the last slot is drawn first;
    -- swap it out if it matches the previous pick, to avoid a repeat at the bag seam.
    local n = #shuffled
    if lastEmoteKey and n > 1 and shuffled[n] == lastEmoteKey then
        local swapWith = math.random(n - 1)
        shuffled[n], shuffled[swapWith] = shuffled[swapWith], shuffled[n]
    end
    return shuffled
end

local function PickEmote(list)
    -- The enabled set may have changed since the bag was filled (an emote toggled
    -- mid-bag), so drop anything no longer valid before drawing.
    local enabledSet = {}
    for _, key in ipairs(list) do
        enabledSet[key] = true
    end
    for i = #bag, 1, -1 do
        if not enabledSet[bag[i]] then
            table.remove(bag, i)
        end
    end

    if #bag == 0 then
        bag = ShuffleBag(list)
    end

    local pick = table.remove(bag)
    lastEmoteKey = pick
    return pick
end

local activeTimer

local function ScheduleNext()
    ns.FixRange()
    if activeTimer then
        activeTimer:Cancel()
        activeTimer = nil
    end
    local minSec = UnrefinedDB.minMinutes * 60
    local maxSec = UnrefinedDB.maxMinutes * 60
    local delay = minSec + math.random() * (maxSec - minSec)
    ns.nextEmoteTime = GetTime() + delay
    activeTimer = C_Timer.NewTimer(delay, ns.TriggerEmote)
end
ns.ScheduleNext = ScheduleNext

-- Re-picks the next scheduled time using the current interval settings.
-- Call this after the min/max interval changes so the pending wait reflects the new range.
function ns.RerollNext()
    if ns.nextEmoteTime then
        ScheduleNext()
    end
end

-- Returns seconds remaining until the next scheduled check, or nil if the timer hasn't started yet.
function ns.GetSecondsUntilNext()
    if not ns.nextEmoteTime then return nil end
    local remaining = ns.nextEmoteTime - GetTime()
    if remaining < 0 then remaining = 0 end
    return remaining
end

-- Shared gating for any emote trigger, scheduled or event-driven.
local function CanEmoteNow()
    if not UnrefinedDB.enabled then return false end
    if IsInDungeonOrRaid() and not UnrefinedDB.allowInDungeons then return false end
    if IsInPvPInstance() and not UnrefinedDB.allowInPvP then return false end

    local inCombat = UnitAffectingCombat("player") or InCombatLockdown()
    if inCombat and not UnrefinedDB.allowInCombat then return false end

    if UnitIsDeadOrGhost("player") then return false end

    return true
end

local function DoRandomEmote()
    local list = EnabledEmoteList()
    if #list > 0 then
        local pick = PickEmote(list)
        pcall(DoEmote, ns.EMOTE_TOKENS[pick])
    end
end

function ns.TriggerEmote()
    if CanEmoteNow() then
        DoRandomEmote()
    end
    ScheduleNext()
end

-- Fires on ZONE_CHANGED_NEW_AREA, independent of the scheduled timer.
local function OnZoneChanged()
    if UnrefinedDB.emoteOnZoneChange and CanEmoteNow() then
        DoRandomEmote()
    end
end

local timerStarted = false
local function StartTimerIfNeeded()
    if not timerStarted then
        timerStarted = true
        ScheduleNext()
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if type(UnrefinedDB) ~= "table" then UnrefinedDB = {} end
        ApplyDefaults(UnrefinedDB, defaults)
        ns.FixRange()
        if ns.BuildOptionsPanel then
            ns.BuildOptionsPanel()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        StartTimerIfNeeded()
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        OnZoneChanged()
    end
end)
