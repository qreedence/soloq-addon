local ADDON_NAME, SQ = ...
SQ = SQ or {}
_G.SoloQ = SQ

local BASE64_URL_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local TOKEN_PREFIX = "soloq:v1:"
local TOKEN_SALT = "SoloQ export token v1"
local IMPORT_PREFIX = "soloq:g1:"
local IMPORT_SALT = "SoloQ import token g1"

local function Chat(message)
    local text = "|cff00ffccSoloQ|r " .. message
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    else
        print("SoloQ " .. message)
    end
end

local function Trim(text)
    return (text or ""):match("^%s*(.-)%s*$")
end

local function ValueOrUnknown(value)
    if value == nil or value == "" then
        return "unknown"
    end
    return tostring(value)
end

local function NumberOrZero(value)
    value = tonumber(value)
    if not value then
        return 0
    end
    return value
end

local function JsonEncodeString(s)
    s = s:gsub('\\', '\\\\')
    s = s:gsub('"', '\\"')
    s = s:gsub('\n', '\\n')
    s = s:gsub('\r', '\\r')
    s = s:gsub('\t', '\\t')
    return '"' .. s .. '"'
end

local function JsonEncode(value)
    if value == nil then
        return "null"
    end

    local t = type(value)

    if t == "string" then
        return JsonEncodeString(value)
    elseif t == "number" then
        if value ~= value then return "null" end
        if value == math.huge or value == -math.huge then return "null" end
        if value == math.floor(value) then
            return string.format("%d", value)
        end
        return tostring(value)
    elseif t == "boolean" then
        return value and "true" or "false"
    elseif t == "table" then
        if value._isArray then
            local parts = {}
            for i = 1, #value do
                parts[i] = JsonEncode(value[i])
            end
            return "[" .. table.concat(parts, ",") .. "]"
        end

        local parts = {}
        local keys = {}
        for k in pairs(value) do
            if k ~= "_isArray" and k ~= "_order" then
                keys[#keys + 1] = k
            end
        end

        if value._order then
            keys = value._order
        else
            table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        end

        for _, k in ipairs(keys) do
            parts[#parts + 1] = JsonEncodeString(tostring(k)) .. ":" .. JsonEncode(value[k])
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end

    return "null"
end

local function Base64UrlEncode(data)
    local output = {}

    for i = 1, #data, 3 do
        local a, b, c = data:byte(i, i + 2)
        local remaining = #data - i + 1

        b = b or 0
        c = c or 0

        local value = a * 65536 + b * 256 + c
        local n1 = math.floor(value / 262144) % 64
        local n2 = math.floor(value / 4096) % 64
        local n3 = math.floor(value / 64) % 64
        local n4 = value % 64

        output[#output + 1] = BASE64_URL_ALPHABET:sub(n1 + 1, n1 + 1)
        output[#output + 1] = BASE64_URL_ALPHABET:sub(n2 + 1, n2 + 1)

        if remaining > 1 then
            output[#output + 1] = BASE64_URL_ALPHABET:sub(n3 + 1, n3 + 1)
        end

        if remaining > 2 then
            output[#output + 1] = BASE64_URL_ALPHABET:sub(n4 + 1, n4 + 1)
        end
    end

    return table.concat(output)
end

local function Adler32Hex(data)
    local a = 1
    local b = 0

    for i = 1, #data do
        a = (a + data:byte(i)) % 65521
        b = (b + a) % 65521
    end

    return string.format("%08x", b * 65536 + a)
end

local function Base64UrlDecode(str)
    local lookup = {}
    for i = 1, #BASE64_URL_ALPHABET do
        lookup[BASE64_URL_ALPHABET:sub(i, i)] = i - 1
    end

    local bytes = {}
    local acc, bits = 0, 0
    for i = 1, #str do
        local v = lookup[str:sub(i, i)]
        if v then
            acc = acc * 64 + v
            bits = bits + 6
            if bits >= 8 then
                bits = bits - 8
                local divisor = 2 ^ bits
                bytes[#bytes + 1] = string.char(math.floor(acc / divisor) % 256)
                acc = acc % divisor
            end
        end
    end
    return table.concat(bytes)
end

-- Decode a server-generated group code (soloq:g1:<base64url>.<checksum>) into a
-- table { dungeon, keyLevel, invitees = { { name, realm, specID }, ... } }.
function SQ:DecodeImportCode(text)
    text = Trim(text)
    local idx = text:find(IMPORT_PREFIX, 1, true)
    if not idx then
        return nil, "That doesn't look like a SoloQ group code."
    end

    local body = text:sub(idx + #IMPORT_PREFIX)
    local base64, checksum = body:match("^(.*)%.([^%.]+)$")
    if not base64 then
        return nil, "Malformed code (missing checksum)."
    end

    if Adler32Hex(IMPORT_SALT .. base64):lower() ~= checksum:lower() then
        return nil, "Checksum mismatch — the code may be corrupted."
    end

    local payload = Base64UrlDecode(base64)
    local parts = {}
    for seg in (payload .. ";"):gmatch("(.-);") do
        parts[#parts + 1] = seg
    end

    local invitees = {}
    for i = 3, #parts do
        local name, realm, spec = parts[i]:match("^(.-),(.-),(.*)$")
        if name and name ~= "" then
            invitees[#invitees + 1] = { name = name, realm = realm, specID = tonumber(spec) }
        end
    end

    if not parts[1] or parts[1] == "" or #invitees == 0 then
        return nil, "Code contained no group data."
    end

    return { dungeon = parts[1], keyLevel = tonumber(parts[2]), invitees = invitees }
end

local function GetGeneratedAt()
    if date then
        return date("!%Y-%m-%dT%H:%M:%SZ")
    end

    return "unknown"
end

local function GetNameServer()
    local name, realm

    if UnitFullName then
        name, realm = UnitFullName("player")
    end

    name = name or UnitName("player") or "unknown"
    realm = realm or (GetNormalizedRealmName and GetNormalizedRealmName()) or GetRealmName()

    if realm and realm ~= "" then
        return name .. "-" .. realm
    end

    return name
end

local function GetRegion()
    if GetCurrentRegion then
        local regionID = GetCurrentRegion()
        local regions = { [1] = "us", [2] = "kr", [3] = "eu", [4] = "tw", [5] = "cn" }
        return regions[regionID] or "unknown"
    end
    return "unknown"
end

local function GetSpecName()
    if not GetSpecialization or not GetSpecializationInfo then
        return "unknown"
    end

    local specIndex = GetSpecialization()
    if not specIndex then
        return "unknown"
    end

    local _, specName = GetSpecializationInfo(specIndex)
    return ValueOrUnknown(specName)
end

local function GetCurrentKey()
    if not C_MythicPlus then
        return nil
    end

    local level = C_MythicPlus.GetOwnedKeystoneLevel and C_MythicPlus.GetOwnedKeystoneLevel()
    local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID and C_MythicPlus.GetOwnedKeystoneChallengeMapID()

    if not level or not mapID then
        return nil
    end

    local mapName = "unknown dungeon"
    if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        mapName = C_ChallengeMode.GetMapUIInfo(mapID) or mapName
    end

    return { dungeon = mapName, level = level }
end

local function PickBetterBest(currentLevel, currentTimed, info)
    if not info or not info.level then
        return currentLevel, currentTimed
    end

    local level = NumberOrZero(info.level)
    local timed = not info.overTime

    if level > NumberOrZero(currentLevel) then
        return level, timed
    end

    if level == NumberOrZero(currentLevel) and timed and currentTimed == false then
        return level, true
    end

    return currentLevel, currentTimed
end

local function GetHighestKeyForMap(mapID)
    local bestLevel
    local bestTimed

    if C_MythicPlus and C_MythicPlus.GetSeasonBestAffixScoreInfoForMap then
        local affixScores = C_MythicPlus.GetSeasonBestAffixScoreInfoForMap(mapID)
        if affixScores then
            for _, info in ipairs(affixScores) do
                bestLevel, bestTimed = PickBetterBest(bestLevel, bestTimed, info)
            end
        end
    end

    if not bestLevel and C_MythicPlus and C_MythicPlus.GetSeasonBestForMap then
        local timedInfo, overtimeInfo = C_MythicPlus.GetSeasonBestForMap(mapID)
        bestLevel, bestTimed = PickBetterBest(bestLevel, bestTimed, timedInfo)
        bestLevel, bestTimed = PickBetterBest(bestLevel, bestTimed, overtimeInfo)
    end

    if bestLevel and bestLevel > 0 then
        return bestLevel, bestTimed
    end
end

local function GetHighestKeys()
    if not C_ChallengeMode or not C_ChallengeMode.GetMapTable or not C_ChallengeMode.GetMapUIInfo then
        return {}
    end

    local maps = C_ChallengeMode.GetMapTable()
    if not maps or #maps == 0 then
        return {}
    end

    local keys = {}
    for _, mapID in ipairs(maps) do
        local mapName = C_ChallengeMode.GetMapUIInfo(mapID) or ("map_" .. tostring(mapID))
        local bestLevel, timed = GetHighestKeyForMap(mapID)

        if bestLevel then
            keys[mapName] = { level = bestLevel, timed = timed and true or false }
        end
    end

    return keys
end

local function SetFrameBackdrop(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
end

function SQ:BuildPayload()
    if C_MythicPlus and C_MythicPlus.RequestMapInfo then
        C_MythicPlus.RequestMapInfo()
    end

    local race = ValueOrUnknown(UnitRace("player"))
    local class = ValueOrUnknown(UnitClass("player"))
    local spec = GetSpecName()
    local score = 0

    if C_ChallengeMode and C_ChallengeMode.GetOverallDungeonScore then
        score = C_ChallengeMode.GetOverallDungeonScore() or 0
    end

    local roles = { _isArray = true }
    for _, r in ipairs(self:GetSelectedRoles()) do
        roles[#roles + 1] = r
    end

    local dungeons = { _isArray = true }
    for _, btn in ipairs(self.dungeonButtons or {}) do
        if btn._selected then
            dungeons[#dungeons + 1] = btn._dungeonName
        end
    end

    local offerKey = nil
    if self.selectedMode == "weekly" and self.offerKeyWeekly then
        offerKey = GetCurrentKey()
    end

    local payload = {
        generated_at = GetGeneratedAt(),
        name_server = GetNameServer(),
        region = GetRegion(),
        race = race,
        class = class,
        spec = spec,
        mplus_score = math.floor(score + 0.5),
        roles = roles,
        mode = self.selectedMode or "preferred",
        dungeons = dungeons,
        current_key = GetCurrentKey(),
        offer_key = offerKey,
        highest_keys = GetHighestKeys(),
        _order = { "generated_at", "name_server", "region", "race", "class", "spec", "mplus_score", "roles", "mode", "dungeons", "current_key", "offer_key", "highest_keys" },
    }

    return JsonEncode(payload)
end

function SQ:BuildCode()
    local payload = self:BuildPayload()
    local encoded = Base64UrlEncode(payload)
    local checksum = Adler32Hex(TOKEN_SALT .. encoded)

    return TOKEN_PREFIX .. encoded .. "." .. checksum
end

function SQ:ShowTextModal(kind, text)
    if not self.textModal then
        local frame = CreateFrame("Frame", "SoloQTextModal", UIParent, "BackdropTemplate")
        frame:SetSize(560, 270)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:EnableMouse(true)
        SetFrameBackdrop(frame)

        frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        frame.title:SetPoint("TOPLEFT", 18, -16)

        frame.help = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        frame.help:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -8)

        local urlBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        urlBox:SetSize(260, 22)
        urlBox:SetPoint("TOPLEFT", frame.help, "BOTTOMLEFT", 4, -4)
        urlBox:SetFontObject(ChatFontNormal)
        urlBox:SetAutoFocus(false)
        urlBox:SetText("soloq.qreedence.com")
        urlBox:SetCursorPosition(0)
        urlBox:SetScript("OnEditFocusGained", function(self)
            self:HighlightText()
        end)
        urlBox:SetScript("OnChar", function(self)
            self:SetText("soloq.qreedence.com")
            self:HighlightText()
        end)
        urlBox:SetScript("OnEscapePressed", function()
            frame:Hide()
        end)
        urlBox:Hide()
        frame.urlBox = urlBox

        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -6, -6)
        close:SetScript("OnClick", function()
            frame:Hide()
        end)

        local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 18, -62)
        scroll:SetPoint("BOTTOMRIGHT", -34, 50)
        frame.scroll = scroll

        local editBox = CreateFrame("EditBox", nil, scroll)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject(ChatFontNormal)
        editBox:SetSize(490, 160)
        editBox:SetScript("OnEscapePressed", function()
            frame:Hide()
        end)

        scroll:SetScrollChild(editBox)
        frame.editBox = editBox

        frame.primary = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        frame.primary:SetSize(110, 24)
        frame.primary:SetPoint("BOTTOMRIGHT", -96, 18)

        local closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        closeButton:SetSize(70, 24)
        closeButton:SetPoint("LEFT", frame.primary, "RIGHT", 8, 0)
        closeButton:SetText("Close")
        closeButton:SetScript("OnClick", function()
            frame:Hide()
        end)

        self.textModal = frame
    end

    local frame = self.textModal
    local editBox = frame.editBox

    if kind == "copy" then
        frame.title:SetText("Export code")
        frame.help:SetText("Go to the link below, then Ctrl+C to copy the code.")
        frame.urlBox:Show()
        frame.scroll:SetPoint("TOPLEFT", 18, -86)
        frame.primary:SetText("Select All")
        frame.primary:SetScript("OnClick", function()
            editBox:SetFocus()
            editBox:HighlightText()
        end)
        editBox:SetText(text or "")
        editBox:SetCursorPosition(0)
    else
        frame.title:SetText("Import code")
        frame.help:SetText("Paste a SoloQ group code, then click Show group.")
        frame.urlBox:Hide()
        frame.scroll:SetPoint("TOPLEFT", 18, -62)
        frame.primary:SetText("Show group")
        frame.primary:SetScript("OnClick", function()
            local data, err = SQ:DecodeImportCode(editBox:GetText())
            if data then
                frame:Hide()
                SQ:ShowInvitePanel(data)
            else
                frame.help:SetText("|cffff5555" .. (err or "Could not read code.") .. "|r")
            end
        end)
        editBox:SetText(text or "")
    end

    frame:Show()
    editBox:SetFocus()

    if kind == "copy" then
        editBox:HighlightText()
    else
        editBox:HighlightText(0, 0)
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if editBox:IsShown() then
                editBox:SetFocus()
                if kind == "copy" then
                    editBox:HighlightText()
                end
            end
        end)
    end
end

function SQ:CopyCode()
    self:ShowTextModal("copy", self:BuildCode())
end

function SQ:ImportCode()
    self:ShowTextModal("import", "")
end

function SQ:HandleSlash(input)
    local raw = Trim(input)

    -- A pasted group code (soloq:g1:...) opens the invite panel directly.
    -- Checked before lowercasing, since base64 is case-sensitive.
    local codeStart = raw:find(IMPORT_PREFIX, 1, true)
    if codeStart then
        local data, err = self:DecodeImportCode(raw:sub(codeStart))
        if data then
            self:ShowInvitePanel(data)
        else
            Chat(err or "Could not read group code.")
        end
        return
    end

    input = string.lower(raw)

    if input == "copy" then
        self:CopyCode()
    elseif input == "import" then
        self:ImportCode()
    elseif input == "queue" then
        self:ShowPVETab()
    elseif input == "float" then
        self:ToggleQueuePanel()
    else
        self:ShowPVETab()
    end
end

function SQ:SaveSelections()
    if not SoloQDB then return end

    local specs = {}
    for _, btn in ipairs(self.specButtons or {}) do
        if btn._selected then
            specs[btn._specID] = true
        end
    end

    local dungeons = {}
    for _, btn in ipairs(self.dungeonButtons or {}) do
        if not btn._selected then
            dungeons[btn._mapID] = false
        end
    end

    SoloQDB.specs = specs
    SoloQDB.dungeons = dungeons
    SoloQDB.mode = self.selectedMode
end

function SQ:OnLoad()
    SoloQDB = SoloQDB or {}

    if C_MythicPlus and C_MythicPlus.RequestMapInfo then
        C_MythicPlus.RequestMapInfo()
    end

    SLASH_SOLOQ1 = "/soloq"
    SLASH_SOLOQ2 = "/sq"
    SlashCmdList.SOLOQ = function(input)
        SQ:HandleSlash(input)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LEAVING_WORLD")
events:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" and addonName == ADDON_NAME then
        SQ:OnLoad()
    elseif event == "PLAYER_LEAVING_WORLD" then
        SQ:SaveSelections()
    end
end)
