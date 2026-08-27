local addonName, ns = ...

local PREFIX = "|cff33ff99Unrefined|r: "

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg)
end

local function PrintStatus()
    local db = UnrefinedDB
    Print(("Enabled: %s"):format(db.enabled and "On" or "Off"))
    local parts = {}
    for _, key in ipairs(ns.EMOTE_ORDER) do
        table.insert(parts, ("%s: %s"):format(ns.EMOTE_LABELS[key], db.emotes[key] and "On" or "Off"))
    end
    Print(table.concat(parts, ", "))
    Print(("Interval: %d - %d minutes"):format(db.minMinutes, db.maxMinutes))
    Print(("Allowed in combat: %s"):format(db.allowInCombat and "Yes" or "No"))
    Print(("Allowed in dungeons/raids: %s"):format(db.allowInDungeons and "Yes" or "No"))
    Print(("Allowed in battlegrounds/arenas: %s"):format(db.allowInPvP and "Yes" or "No"))
    Print(("Emote on zone change: %s"):format(db.emoteOnZoneChange and "On" or "Off"))
end

local function PrintNext()
    local remaining = ns.GetSecondsUntilNext()
    if not remaining then
        Print("Timer hasn't started yet.")
        return
    end
    local minutes = math.floor(remaining / 60)
    local seconds = math.floor(remaining - minutes * 60)
    local when = ("Next check in %dm %ds."):format(minutes, seconds)
    if not UnrefinedDB.enabled then
        when = when .. " (addon is disabled, so it will be skipped)"
    end
    Print(when)
end

local function ParseOnOff(val)
    if val == "on" or val == "1" or val == "true" or val == "yes" then return true end
    if val == "off" or val == "0" or val == "false" or val == "no" then return false end
    return nil
end

local function ShowHelp()
    Print("Commands:")
    Print("/urf on|off - enable or disable the addon")
    Print("/urf <emote> on|off - toggle one emote: burp, fart, nose, moon, spit, rude, drool, scratch, gag, lick, squeal, sniff, snort, bonk, chicken, shifty")
    Print("/urf combat on|off - allow or disallow emotes during combat")
    Print("/urf dungeons on|off - allow or disallow emotes in dungeons and raids")
    Print("/urf pvp on|off - allow or disallow emotes in battlegrounds and arenas")
    Print("/urf zone on|off - also trigger an emote whenever you enter a new zone")
    Print("/urf interval <min> <max> - set the random interval range in minutes (1-30)")
    Print("/urf status - show current settings")
    Print("/urf next - show time until the next check")
    Print("/urf config - open the options panel")
    Print("/urf help - show this help")
end

SLASH_UNREFINED1 = "/unrefined"
SLASH_UNREFINED2 = "/urf"

SlashCmdList["UNREFINED"] = function(msg)
    local db = UnrefinedDB
    msg = strtrim((msg or ""):lower())
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    rest = rest or ""

    if cmd == "" or cmd == "help" then
        ShowHelp()
    elseif cmd == "status" then
        PrintStatus()
    elseif cmd == "next" then
        PrintNext()
    elseif cmd == "config" or cmd == "options" then
        ns.OpenOptions()
    elseif cmd == "on" then
        db.enabled = true
        Print("Enabled.")
    elseif cmd == "off" then
        db.enabled = false
        Print("Disabled.")
    elseif ns.EMOTE_LABELS[ns.EMOTE_ALIASES[cmd] or cmd] then
        local key = ns.EMOTE_ALIASES[cmd] or cmd
        local val = ParseOnOff(rest)
        if val == nil then
            Print(("Usage: /urf %s on|off"):format(cmd))
        else
            db.emotes[key] = val
            Print(("%s %s."):format(ns.EMOTE_LABELS[key], val and "enabled" or "disabled"))
        end
    elseif cmd == "combat" then
        local val = ParseOnOff(rest)
        if val == nil then
            Print("Usage: /urf combat on|off")
        else
            db.allowInCombat = val
            Print(("Emotes in combat %s."):format(val and "allowed" or "disallowed"))
        end
    elseif cmd == "dungeons" or cmd == "dungeon" or cmd == "raids" then
        local val = ParseOnOff(rest)
        if val == nil then
            Print("Usage: /urf dungeons on|off")
        else
            db.allowInDungeons = val
            Print(("Emotes in dungeons/raids %s."):format(val and "allowed" or "disallowed"))
        end
    elseif cmd == "pvp" or cmd == "battlegrounds" or cmd == "arena" or cmd == "arenas" or cmd == "bg" then
        local val = ParseOnOff(rest)
        if val == nil then
            Print("Usage: /urf pvp on|off")
        else
            db.allowInPvP = val
            Print(("Emotes in battlegrounds/arenas %s."):format(val and "allowed" or "disallowed"))
        end
    elseif cmd == "zone" or cmd == "zones" then
        local val = ParseOnOff(rest)
        if val == nil then
            Print("Usage: /urf zone on|off")
        else
            db.emoteOnZoneChange = val
            Print(("Emote on zone change %s."):format(val and "enabled" or "disabled"))
        end
    elseif cmd == "interval" then
        local a, b = rest:match("^(%S+)%s+(%S+)$")
        if not a or not b then
            Print("Usage: /urf interval <minMinutes> <maxMinutes>")
        else
            local minV = ns.ClampMinutes(tonumber(a))
            local maxV = ns.ClampMinutes(tonumber(b))
            if minV > maxV then minV, maxV = maxV, minV end
            db.minMinutes, db.maxMinutes = minV, maxV
            ns.RerollNext()
            Print(("Interval set to %d - %d minutes."):format(minV, maxV))
        end
    else
        Print("Unknown command. Type /urf help for a list of commands.")
    end

    if ns.RefreshPanel then
        ns.RefreshPanel()
    end
end
