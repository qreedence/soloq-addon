local _, SQ = ...

local WHITE8 = "Interface\\Buttons\\WHITE8X8"

local WOW_ROLE_MAP = {
    TANK = "tank",
    HEALER = "healer",
    DAMAGER = "dps",
}

local DUNGEON_ICON_SIZE = 72
local DUNGEON_GAP = 6
local DUNGEONS_PER_ROW = 4
local SPEC_BUTTON_SIZE = 36
local PADDING = 16

local PANEL_WIDTH = DUNGEONS_PER_ROW * DUNGEON_ICON_SIZE + (DUNGEONS_PER_ROW - 1) * DUNGEON_GAP + PADDING * 2

local MODES = {
    { key = "required",  label = "Push",     tip = "Only match where you can gain M+ score." },
    { key = "preferred", label = "Balanced",  tip = "Prefer score gain, but relax the requirements if the queue times are long." },
    { key = "relaxed",   label = "Relaxed",   tip = "Match with any viable group at your level." },
    { key = "weekly",    label = "Weekly",    tip = "Fast queue for vault. Ignores score." },
}

local function SetBgColor(frame, r, g, b, a)
    if not frame._bg then
        frame._bg = frame:CreateTexture(nil, "BACKGROUND")
        frame._bg:SetAllPoints()
    end
    frame._bg:SetColorTexture(r, g, b, a or 1)
end

local function SetBorderColor(border, r, g, b, a)
    border.top:SetColorTexture(r, g, b, a)
    border.bottom:SetColorTexture(r, g, b, a)
    border.left:SetColorTexture(r, g, b, a)
    border.right:SetColorTexture(r, g, b, a)
end

function SQ:CreateQueuePanel()
    if self.queuePanel then return end

    local theme = SQ.Theme
    local bg = theme.bg

    local panel = CreateFrame("Frame", "SoloQQueuePanel", UIParent)
    panel:SetSize(PANEL_WIDTH, 480)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("HIGH")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetClampedToScreen(true)
    panel:SetScript("OnDragStart", function(f) f:StartMoving() end)
    panel:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)

    SetBgColor(panel, bg[1], bg[2], bg[3], bg[4])
    SQ.CreateBorder(panel, theme.border[1], theme.border[2], theme.border[3], theme.border[4])

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, panel)
    titleBar:SetHeight(32)
    titleBar:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
    SetBgColor(titleBar, theme.card[1], theme.card[2], theme.card[3], theme.card[4])

    local titleBorder = titleBar:CreateTexture(nil, "BORDER")
    titleBorder:SetColorTexture(theme.border[1], theme.border[2], theme.border[3], theme.border[4])
    titleBorder:SetHeight(1)
    titleBorder:SetPoint("BOTTOMLEFT", titleBar, "BOTTOMLEFT", 0, 0)
    titleBorder:SetPoint("BOTTOMRIGHT", titleBar, "BOTTOMRIGHT", 0, 0)

    local title = SQ.MakeText(titleBar, 13)
    title:SetText("SoloQ")
    title:SetPoint("LEFT", titleBar, "LEFT", 12, 0)

    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -8, 0)
    closeBtn:SetNormalAtlas("common-search-clearbutton")
    closeBtn:SetScript("OnClick", function() panel:Hide() end)

    -- Content area
    local content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", PADDING, -PADDING)
    content:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -PADDING, PADDING)

    local yOffset = 0

    -- Spec section
    local specLabel = SQ.MakeMutedText(content, 11)
    specLabel:SetText("SPEC")
    specLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOffset)
    yOffset = yOffset + 14 + 6

    self.selectedSpecs = {}
    self.specButtons = {}

    local specContainer = CreateFrame("Frame", nil, content)
    specContainer:SetHeight(SPEC_BUTTON_SIZE)
    specContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOffset)
    specContainer:SetPoint("RIGHT", content, "RIGHT", 0, 0)

    self.specContainer = specContainer
    self:PopulateSpecButtons()

    -- Roles summary
    self.rolesSummary = SQ.MakeMutedText(specContainer, 11)
    self.rolesSummary:SetPoint("LEFT", specContainer, "LEFT", (SPEC_BUTTON_SIZE + 6) * 4 + 8, 0)
    self.rolesSummary:SetText("")

    yOffset = yOffset + SPEC_BUTTON_SIZE + 14

    -- Mode section
    local modeLabel = SQ.MakeMutedText(content, 11)
    modeLabel:SetText("MODE")
    modeLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOffset)
    yOffset = yOffset + 14 + 6

    self.selectedMode = "preferred"
    self.modeButtons = {}

    local modeContainer = CreateFrame("Frame", nil, content)
    modeContainer:SetHeight(26)
    modeContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOffset)
    modeContainer:SetPoint("RIGHT", content, "RIGHT", 0, 0)

    for i, mode in ipairs(MODES) do
        local btn = CreateFrame("Button", nil, modeContainer)
        btn:SetHeight(26)

        local label = SQ.MakeText(btn, 11)
        label:SetText(mode.label)
        label:SetPoint("CENTER")
        btn._label = label

        local textWidth = label:GetStringWidth()
        btn:SetWidth(textWidth + 20)

        if i == 1 then
            btn:SetPoint("LEFT", modeContainer, "LEFT", 0, 0)
        else
            btn:SetPoint("LEFT", self.modeButtons[i - 1], "RIGHT", 6, 0)
        end

        SetBgColor(btn, theme.card[1], theme.card[2], theme.card[3], theme.card[4])
        btn._border = SQ.CreateBorder(btn, theme.border[1], theme.border[2], theme.border[3], theme.border[4])
        btn._modeKey = mode.key
        btn._tip = mode.tip

        btn:SetScript("OnClick", function() SQ:SelectMode(mode.key) end)
        btn:SetScript("OnEnter", function(f)
            GameTooltip:SetOwner(f, "ANCHOR_TOP")
            GameTooltip:SetText(mode.label, 1, 1, 1)
            GameTooltip:AddLine(mode.tip, theme.muted[1], theme.muted[2], theme.muted[3], true)
            GameTooltip:Show()
            if SQ.selectedMode ~= mode.key then f._label:SetAlpha(0.8) end
        end)
        btn:SetScript("OnLeave", function(f)
            GameTooltip:Hide()
            if SQ.selectedMode ~= mode.key then f._label:SetAlpha(0.5) end
        end)

        self.modeButtons[i] = btn
    end

    -- Key offer checkbox + info icon (inline after mode buttons)
    local lastModeBtn = self.modeButtons[#self.modeButtons]

    local keyOfferCb = CreateFrame("Button", nil, modeContainer)
    keyOfferCb:SetSize(18, 18)
    keyOfferCb:SetPoint("LEFT", lastModeBtn, "RIGHT", 12, 0)
    SetBgColor(keyOfferCb, theme.card[1], theme.card[2], theme.card[3], 1)
    keyOfferCb._border = SQ.CreateBorder(keyOfferCb, theme.border[1], theme.border[2], theme.border[3], theme.border[4])
    keyOfferCb:Hide()

    local checkMark = keyOfferCb:CreateTexture(nil, "OVERLAY")
    checkMark:SetSize(16, 16)
    checkMark:SetPoint("CENTER")
    checkMark:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
    checkMark:Hide()
    keyOfferCb._mark = checkMark
    keyOfferCb._checked = false

    keyOfferCb:SetScript("OnClick", function(f)
        f._checked = not f._checked
        local s = theme.success
        if f._checked then
            f._mark:Show()
            SetBorderColor(f._border, s[1], s[2], s[3], 0.3)
        else
            f._mark:Hide()
            SetBorderColor(f._border, theme.border[1], theme.border[2], theme.border[3], theme.border[4])
        end
        SQ.offerKeyWeekly = f._checked
    end)

    local keyOfferInfo = CreateFrame("Button", nil, modeContainer)
    keyOfferInfo:SetSize(18, 18)
    keyOfferInfo:SetPoint("LEFT", keyOfferCb, "RIGHT", 6, 0)
    keyOfferInfo:Hide()

    local infoIcon = keyOfferInfo:CreateTexture(nil, "ARTWORK")
    infoIcon:SetSize(16, 16)
    infoIcon:SetPoint("CENTER")
    infoIcon:SetTexture("Interface\\FriendsFrame\\InformationIcon")

    keyOfferInfo._tipText = ""
    keyOfferInfo:SetScript("OnEnter", function(f)
        GameTooltip:SetOwner(f, "ANCHOR_TOP")
        GameTooltip:SetText("Offer Key", 1, 1, 1)
        GameTooltip:AddLine(f._tipText, theme.muted[1], theme.muted[2], theme.muted[3], true)
        GameTooltip:Show()
    end)
    keyOfferInfo:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self.keyOfferCheck = keyOfferCb
    self.keyOfferInfo = keyOfferInfo
    self.offerKeyWeekly = false

    yOffset = yOffset + 26 + 14

    -- Dungeons section
    local dungeonLabel = SQ.MakeMutedText(content, 11)
    dungeonLabel:SetText("DUNGEONS")
    dungeonLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOffset)
    yOffset = yOffset + 14 + 6

    self.selectedDungeons = {}
    self.dungeonButtons = {}

    local dungeonContainer = CreateFrame("Frame", nil, content)
    dungeonContainer:SetHeight(DUNGEON_ICON_SIZE * 2 + DUNGEON_GAP)
    dungeonContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOffset)
    dungeonContainer:SetPoint("RIGHT", content, "RIGHT", 0, 0)

    self.dungeonContainer = dungeonContainer
    self:PopulateDungeonButtons()

    -- Queue button
    local queueBtn = CreateFrame("Button", nil, content)
    queueBtn:SetHeight(34)
    queueBtn:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 0, 24)
    queueBtn:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 24)

    local sc = theme.success
    SetBgColor(queueBtn, sc[1], sc[2], sc[3], 0.15)
    queueBtn._border = SQ.CreateBorder(queueBtn, sc[1], sc[2], sc[3], 0.3)

    local queueBtnText = SQ.MakeText(queueBtn, 13, sc[1], sc[2], sc[3], 1)
    queueBtnText:SetPoint("CENTER")
    queueBtnText:SetText("Copy Queue Code")

    queueBtn:SetScript("OnEnter", function(f) SetBgColor(f, sc[1], sc[2], sc[3], 0.25) end)
    queueBtn:SetScript("OnLeave", function(f) SetBgColor(f, sc[1], sc[2], sc[3], 0.15) end)
    queueBtn:SetScript("OnClick", function()
        if #SQ:GetSelectedRoles() == 0 then
            if SQ.statusText then
                local e = SQ.Theme.error
                SQ.statusText:SetText("Select a spec before copying your queue code.")
                SQ.statusText:SetTextColor(e[1], e[2], e[3], 1)
            end
            return
        end
        SQ:CopyCode()
    end)

    -- Status text
    self.statusText = SQ.MakeMutedText(content, 11)
    self.statusText:SetPoint("BOTTOM", content, "BOTTOM", 0, 6)
    self.statusText:SetText("Select a spec and dungeons to queue.")

    -- Version label (absolute bottom-right corner of panel)
    local version = C_AddOns and C_AddOns.GetAddOnMetadata
        and C_AddOns.GetAddOnMetadata("SoloQ", "Version")
        or (GetAddOnMetadata and GetAddOnMetadata("SoloQ", "Version"))
        or ""
    if version and version ~= "" then
        local versionText = SQ.MakeMutedText(panel, 9)
        versionText:SetText("v" .. version)
        versionText:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -6, 4)
        versionText:SetAlpha(0.4)
    end

    panel.titleBar = titleBar
    panel.closeBtn = closeBtn
    panel.content = content
    panel.contentWidth = PANEL_WIDTH - PADDING * 2
    panel.contentHeight = 384

    self.queuePanel = panel
    local savedMode = SoloQDB and SoloQDB.mode or "preferred"
    self:SelectMode(savedMode)
    panel:Hide()
end

function SQ:PopulateSpecButtons()
    if not GetNumSpecializations or not GetSpecializationInfo then return end

    local numSpecs = GetNumSpecializations()
    local theme = SQ.Theme
    local container = self.specContainer

    for i = 1, numSpecs do
        local specID, specName, _, specIcon, wowRole = GetSpecializationInfo(i)
        if not specID then break end

        local role = WOW_ROLE_MAP[wowRole] or "dps"

        local btn = CreateFrame("Button", nil, container)
        btn:SetSize(SPEC_BUTTON_SIZE, SPEC_BUTTON_SIZE)

        if i == 1 then
            btn:SetPoint("LEFT", container, "LEFT", 0, 0)
        else
            btn:SetPoint("LEFT", self.specButtons[i - 1], "RIGHT", 6, 0)
        end

        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexture(specIcon)
        icon:SetDesaturated(true)
        icon:SetAlpha(0.4)

        btn._icon = icon
        btn._border = nil
        btn._specID = specID
        btn._specName = specName
        btn._role = role
        btn._selected = false

        btn:SetScript("OnClick", function(f)
            f._selected = not f._selected
            SQ:UpdateSpecButton(f)
            SQ:UpdateRolesSummary()
            SQ:UpdateStatusText()
        end)

        btn:SetScript("OnEnter", function(f)
            GameTooltip:SetOwner(f, "ANCHOR_TOP")
            GameTooltip:SetText(specName, 1, 1, 1)
            local c = theme.roleColors[role]
            GameTooltip:AddLine(role:sub(1,1):upper() .. role:sub(2), c[1], c[2], c[3])
            GameTooltip:Show()
            if not f._selected then f._icon:SetAlpha(0.7) end
        end)

        btn:SetScript("OnLeave", function(f)
            GameTooltip:Hide()
            if not f._selected then f._icon:SetAlpha(0.4) end
        end)

        local saved = SoloQDB and SoloQDB.specs
        if saved and saved[specID] then
            btn._selected = true
            SQ:UpdateSpecButton(btn)
        end

        self.specButtons[i] = btn
    end

    if SoloQDB and SoloQDB.specs then
        self:UpdateRolesSummary()
    end
end

function SQ:UpdateSpecButton(btn)
    if btn._selected then
        btn._icon:SetDesaturated(false)
        btn._icon:SetAlpha(1)
    else
        btn._icon:SetDesaturated(true)
        btn._icon:SetAlpha(0.4)
    end
end

function SQ:GetSelectedRoles()
    local roles = {}
    local seen = {}
    for _, btn in ipairs(self.specButtons) do
        if btn._selected and not seen[btn._role] then
            roles[#roles + 1] = btn._role
            seen[btn._role] = true
        end
    end
    return roles
end

function SQ:UpdateRolesSummary()
    if not self.rolesSummary then return end
    local roles = self:GetSelectedRoles()
    if #roles == 0 then
        self.rolesSummary:SetText("")
        return
    end

    local parts = {}
    local theme = SQ.Theme
    for _, role in ipairs(roles) do
        local c = theme.roleColors[role]
        local hex = string.format("%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255)
        parts[#parts + 1] = "|cff" .. hex .. role:sub(1,1):upper() .. role:sub(2) .. "|r"
    end
    self.rolesSummary:SetText(table.concat(parts, " + "))
end

function SQ:PopulateDungeonButtons()
    if not C_ChallengeMode or not C_ChallengeMode.GetMapTable then return end

    local maps = C_ChallengeMode.GetMapTable()
    if not maps or #maps == 0 then return end

    local container = self.dungeonContainer
    local theme = SQ.Theme

    for i, mapID in ipairs(maps) do
        local name, id, _, texID = C_ChallengeMode.GetMapUIInfo(mapID)
        if not name then name = "Unknown" end

        local row = math.floor((i - 1) / DUNGEONS_PER_ROW)
        local col = (i - 1) % DUNGEONS_PER_ROW

        local btn = CreateFrame("Button", nil, container)
        btn:SetSize(DUNGEON_ICON_SIZE, DUNGEON_ICON_SIZE)
        btn:SetPoint("TOPLEFT", container, "TOPLEFT",
            col * (DUNGEON_ICON_SIZE + DUNGEON_GAP),
            -(row * (DUNGEON_ICON_SIZE + DUNGEON_GAP)))

        SetBgColor(btn, theme.card[1], theme.card[2], theme.card[3], theme.card[4])
        btn._border = SQ.CreateBorder(btn, theme.border[1], theme.border[2], theme.border[3], theme.border[4])

        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()

        if texID and texID ~= 0 then
            icon:SetTexture(texID)
        else
            icon:SetColorTexture(0.15, 0.15, 0.15, 1)
        end

        icon:SetDesaturated(true)
        icon:SetAlpha(0.4)
        btn._icon = icon
        btn._mapID = mapID
        btn._dungeonName = name
        local saved = SoloQDB and SoloQDB.dungeons
        local deselected = saved and saved[mapID] == false
        btn._selected = not deselected
        if btn._selected then
            SQ.selectedDungeons[name] = true
        end
        SQ:UpdateDungeonButton(btn)

        btn:SetScript("OnClick", function(f)
            f._selected = not f._selected
            SQ:UpdateDungeonButton(f)
            if f._selected then
                SQ.selectedDungeons[name] = true
            else
                SQ.selectedDungeons[name] = nil
            end
            SQ:UpdateStatusText()
        end)

        btn:SetScript("OnEnter", function(f)
            GameTooltip:SetOwner(f, "ANCHOR_TOP")
            GameTooltip:SetText(f._dungeonName, 1, 1, 1)
            GameTooltip:Show()
            if not f._selected then f._icon:SetAlpha(0.7) end
        end)

        btn:SetScript("OnLeave", function(f)
            GameTooltip:Hide()
            if not f._selected then f._icon:SetAlpha(0.4) end
        end)

        self.dungeonButtons[i] = btn
    end
end

function SQ:UpdateDungeonButton(btn)
    local theme = SQ.Theme
    if btn._selected then
        btn._icon:SetDesaturated(false)
        btn._icon:SetAlpha(1)
        SetBorderColor(btn._border, theme.success[1], theme.success[2], theme.success[3], 0.4)
    else
        btn._icon:SetDesaturated(true)
        btn._icon:SetAlpha(0.4)
        SetBorderColor(btn._border, theme.border[1], theme.border[2], theme.border[3], theme.border[4])
    end
end

function SQ:SelectMode(modeKey)
    self.selectedMode = modeKey
    local theme = SQ.Theme

    for _, btn in ipairs(self.modeButtons) do
        local isSelected = btn._modeKey == modeKey
        if isSelected then
            btn._label:SetAlpha(1)
            local s = theme.success
            SetBorderColor(btn._border, s[1], s[2], s[3], 0.3)
            SetBgColor(btn, s[1], s[2], s[3], 0.10)
        else
            btn._label:SetAlpha(0.5)
            SetBorderColor(btn._border, theme.border[1], theme.border[2], theme.border[3], theme.border[4])
            SetBgColor(btn, theme.card[1], theme.card[2], theme.card[3], theme.card[4])
        end
    end

    if self.keyOfferCheck then
        local showOffer = false
        if modeKey == "weekly" then
            local level = C_MythicPlus and C_MythicPlus.GetOwnedKeystoneLevel
                and C_MythicPlus.GetOwnedKeystoneLevel()
            if level and level >= 10 then
                showOffer = true
                local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID
                    and C_MythicPlus.GetOwnedKeystoneChallengeMapID()
                local mapName = "your key"
                if mapID and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
                    mapName = C_ChallengeMode.GetMapUIInfo(mapID) or mapName
                end
                self.keyOfferInfo._tipText = "Offer my +" .. level .. " " .. mapName .. " for the group."
            end
        end

        if showOffer then
            self.keyOfferCheck:Show()
            self.keyOfferInfo:Show()
        else
            self.keyOfferCheck:Hide()
            self.keyOfferInfo:Hide()
            self.keyOfferCheck._checked = false
            self.keyOfferCheck._mark:Hide()
            SetBorderColor(self.keyOfferCheck._border,
                theme.border[1], theme.border[2], theme.border[3], theme.border[4])
            self.offerKeyWeekly = false
        end
    end
end

function SQ:UpdateStatusText()
    if not self.statusText then return end

    local m = SQ.Theme.muted
    self.statusText:SetTextColor(m[1], m[2], m[3], m[4]) -- clear any error color

    local roles = self:GetSelectedRoles()
    if #roles == 0 then
        self.statusText:SetText("Select a spec to continue.")
        return
    end

    local count = 0
    for _ in pairs(self.selectedDungeons) do count = count + 1 end

    if count == 0 then
        self.statusText:SetText("Select dungeons, or queue for all.")
    else
        self.statusText:SetText(count .. " dungeon" .. (count > 1 and "s" or "") .. " selected.")
    end
end

function SQ:ToggleQueuePanel()
    self:CreateQueuePanel()
    if self.queuePanel:IsShown() then
        self.queuePanel:Hide()
    else
        if C_MythicPlus and C_MythicPlus.RequestMapInfo then
            C_MythicPlus.RequestMapInfo()
        end
        self.queuePanel:Show()
    end
end
