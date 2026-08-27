local addonName, ns = ...

local RefreshPanel

local function CreateCheckbox(parent, label, tooltip)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    local text = check:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", check, "RIGHT", 4, 0)
    text:SetText(label)
    if tooltip then
        check:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(label)
            GameTooltip:AddLine(tooltip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        check:SetScript("OnLeave", GameTooltip_Hide)
    end
    return check
end

local function CreateMinuteBox(parent)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetSize(40, 20)
    box:SetMaxLetters(2)
    box:SetFontObject(ChatFontNormal)
    box:SetTextColor(1, 1, 1, 1)
    box:SetJustifyH("CENTER")
    box:SetTextInsets(4, 4, 0, 0)
    return box
end

function ns.BuildOptionsPanel()
    if ns.optionsBuilt then return end
    ns.optionsBuilt = true

    local panel = CreateFrame("Frame")
    panel.name = "Unrefined"

    -- Shared column spacing for every 2-column checkbox row on this panel.
    local COLUMN_WIDTH = 160

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Unrefined")

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText("Makes your character burp, fart, pick their nose, and more, at random intervals.")

    local enabledCheck = CreateCheckbox(panel, "Enable Unrefined", "Turns all random emotes on or off.")
    enabledCheck:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", -2, -16)
    enabledCheck:SetScript("OnClick", function(self)
        UnrefinedDB.enabled = self:GetChecked() and true or false
    end)

    local zoneCheck = CreateCheckbox(panel, "Emote on Zone Change", "Also trigger an emote whenever you enter a new zone.")
    zoneCheck:SetPoint("TOPLEFT", enabledCheck, "TOPLEFT", COLUMN_WIDTH, 0)
    zoneCheck:SetScript("OnClick", function(self)
        UnrefinedDB.emoteOnZoneChange = self:GetChecked() and true or false
    end)

    -- Combat and Dungeons/Raids stack in column 1; PvP sits alone in column 2, since these
    -- labels are long enough that the standard COLUMN_WIDTH would make them overlap.
    local CONDITION_COLUMN_WIDTH = 220

    local combatCheck = CreateCheckbox(panel, "Allow During Combat", "Allow emotes to trigger while you are in combat.")
    combatCheck:SetPoint("TOPLEFT", enabledCheck, "BOTTOMLEFT", 0, -20)
    combatCheck:SetScript("OnClick", function(self)
        UnrefinedDB.allowInCombat = self:GetChecked() and true or false
    end)

    local dungeonCheck = CreateCheckbox(panel, "Allow in Dungeons/Raids", "Allow emotes to trigger while inside a dungeon or raid instance.")
    dungeonCheck:SetPoint("TOPLEFT", combatCheck, "BOTTOMLEFT", 0, -8)
    dungeonCheck:SetScript("OnClick", function(self)
        UnrefinedDB.allowInDungeons = self:GetChecked() and true or false
    end)

    local pvpCheck = CreateCheckbox(panel, "Allow in Battlegrounds/Arenas", "Allow emotes to trigger while inside a battleground or arena.")
    pvpCheck:SetPoint("TOPLEFT", enabledCheck, "BOTTOMLEFT", CONDITION_COLUMN_WIDTH, -20)
    pvpCheck:SetScript("OnClick", function(self)
        UnrefinedDB.allowInPvP = self:GetChecked() and true or false
    end)

    local conditionChecks = {
        allowInCombat = combatCheck,
        allowInDungeons = dungeonCheck,
        allowInPvP = pvpCheck,
    }

    local intervalHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    intervalHeader:SetPoint("TOPLEFT", dungeonCheck, "BOTTOMLEFT", 2, -20)
    intervalHeader:SetText("Random Interval (minutes, 1-30)")

    local minLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    minLabel:SetPoint("TOPLEFT", intervalHeader, "BOTTOMLEFT", 0, -10)
    minLabel:SetText("Minimum")

    local minBox = CreateMinuteBox(panel)
    minBox:SetPoint("TOPLEFT", minLabel, "BOTTOMLEFT", 0, -4)

    local maxLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    maxLabel:SetPoint("LEFT", minLabel, "RIGHT", 60, 0)
    maxLabel:SetText("Maximum")

    local maxBox = CreateMinuteBox(panel)
    maxBox:SetPoint("TOPLEFT", maxLabel, "BOTTOMLEFT", 0, -4)

    local function CommitMinBox(self)
        UnrefinedDB.minMinutes = ns.ClampMinutes(self:GetNumber())
        ns.FixRange()
        ns.RerollNext()
        self:ClearFocus()
        RefreshPanel()
    end
    local function CommitMaxBox(self)
        UnrefinedDB.maxMinutes = ns.ClampMinutes(self:GetNumber())
        ns.FixRange()
        ns.RerollNext()
        self:ClearFocus()
        RefreshPanel()
    end

    minBox:SetScript("OnEnterPressed", CommitMinBox)
    minBox:SetScript("OnEditFocusLost", CommitMinBox)
    minBox:SetScript("OnEscapePressed", function(self) self:ClearFocus(); RefreshPanel() end)

    maxBox:SetScript("OnEnterPressed", CommitMaxBox)
    maxBox:SetScript("OnEditFocusLost", CommitMaxBox)
    maxBox:SetScript("OnEscapePressed", function(self) self:ClearFocus(); RefreshPanel() end)

    -- Emotes live at the bottom of the panel, below everything else.
    local emoteHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    emoteHeader:SetPoint("TOPLEFT", minBox, "BOTTOMLEFT", -2, -20)
    emoteHeader:SetText("Emotes")

    -- Three columns keep this compact even as more emotes get added, since the
    -- canvas panel has no scroll frame and tall content would just clip.
    local EMOTE_COLUMNS = 3
    local EMOTE_COLUMN_WIDTH = 140
    local emoteChecks = {}
    local columnAnchor = {}
    for col = 1, EMOTE_COLUMNS do
        columnAnchor[col] = emoteHeader
    end
    for i, key in ipairs(ns.EMOTE_ORDER) do
        local col = ((i - 1) % EMOTE_COLUMNS) + 1
        local check = CreateCheckbox(panel, ns.EMOTE_LABELS[key], "Allow the " .. ns.EMOTE_LABELS[key] .. " emote to trigger.")
        if columnAnchor[col] == emoteHeader then
            check:SetPoint("TOPLEFT", emoteHeader, "BOTTOMLEFT", (col - 1) * EMOTE_COLUMN_WIDTH - 2, -8)
        else
            check:SetPoint("TOPLEFT", columnAnchor[col], "BOTTOMLEFT", 0, -8)
        end
        check:SetScript("OnClick", function(self)
            UnrefinedDB.emotes[key] = self:GetChecked() and true or false
        end)
        emoteChecks[key] = check
        columnAnchor[col] = check
    end

    RefreshPanel = function()
        enabledCheck:SetChecked(UnrefinedDB.enabled)
        zoneCheck:SetChecked(UnrefinedDB.emoteOnZoneChange)
        for key, check in pairs(emoteChecks) do
            check:SetChecked(UnrefinedDB.emotes[key])
        end
        for key, check in pairs(conditionChecks) do
            check:SetChecked(UnrefinedDB[key])
        end
        minBox:SetNumber(UnrefinedDB.minMinutes)
        minBox:SetTextColor(1, 1, 1, 1)
        minBox:SetCursorPosition(0)
        maxBox:SetNumber(UnrefinedDB.maxMinutes)
        maxBox:SetTextColor(1, 1, 1, 1)
        maxBox:SetCursorPosition(0)
    end

    panel:SetScript("OnShow", RefreshPanel)
    panel.OnRefresh = RefreshPanel
    RefreshPanel()

    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)

    ns.optionsCategory = category
    ns.RefreshPanel = RefreshPanel
end

function ns.OpenOptions()
    if not ns.optionsCategory then return end
    Settings.OpenToCategory(ns.optionsCategory:GetID())
end
