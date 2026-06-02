local _, SQ = ...

local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local DUNGEON_TELEPORTS = {
    ["Nexus-Point Xenas"]       = 1254563,
    ["Maisara Caverns"]         = 1254559,
    ["Magisters' Terrace"]      = 1254572,
    ["Pit of Saron"]            = 1254555,
    ["Seat of the Triumvirate"] = 1254551,
    ["Skyreach"]                = 159898,
    ["Windrunner Spire"]        = 1254400,
    ["Algeth'ar Academy"]       = 393273,
}

local COL_WIDTH = 88
local ICON_SIZE = 56
local PADDING = 16

function SQ.GetTeleportSpell(dungeon)
    return dungeon and DUNGEON_TELEPORTS[dungeon] or nil
end

-- Exposed so the teleport tools can read the table.
function SQ.GetDungeonTeleports()
    return DUNGEON_TELEPORTS
end

-- The server stores realms as slugs (e.g. "tarren-mill"); InviteUnit wants the
-- in-game display form with no spaces ("TarrenMill").
function SQ.SlugToRealm(slug)
    if not slug or slug == "" then
        return slug
    end

    local parts = {}
    for word in slug:gmatch("[^%-]+") do
        parts[#parts + 1] = word:sub(1, 1):upper() .. word:sub(2)
    end
    return table.concat(parts)
end

-- Build the "Name-Realm" string InviteUnit expects from a name + realm slug.
function SQ.InviteUnitString(name, realmSlug)
    local realm = SQ.SlugToRealm(realmSlug)
    if realm and realm ~= "" then
        return name .. "-" .. realm
    end
    return name
end

-- Is the given name+realm already in the player's group?
function SQ.IsInGroup(name, realmSlug)
    local n = GetNumGroupMembers()
    if n == 0 then
        return false
    end

    local targetName = name:lower()
    local targetRealm = (SQ.SlugToRealm(realmSlug) or ""):lower()
    local prefix = IsInRaid() and "raid" or "party"

    for i = 1, n do
        local unit = prefix .. i
        if UnitExists(unit) then
            local uname, urealm = UnitName(unit)
            if uname and uname:lower() == targetName then
                if not urealm or urealm == "" then
                    return true -- same realm as player
                end
                if urealm:gsub("%s+", ""):lower() == targetRealm then
                    return true
                end
            end
        end
    end
    return false
end

local function SetBg(frame, c)
    if not frame._bg then
        frame._bg = frame:CreateTexture(nil, "BACKGROUND")
        frame._bg:SetAllPoints()
    end
    frame._bg:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
end

local function SetBorder(border, c, a)
    border.top:SetColorTexture(c[1], c[2], c[3], a)
    border.bottom:SetColorTexture(c[1], c[2], c[3], a)
    border.left:SetColorTexture(c[1], c[2], c[3], a)
    border.right:SetColorTexture(c[1], c[2], c[3], a)
end

local function StyleInviteButton(btn, available)
    local theme = SQ.Theme
    if available then
        local s = theme.success
        SetBg(btn, { s[1], s[2], s[3], 0.15 })
        SetBorder(btn._border, s, 0.3)
        btn._label:SetText("Invite")
        btn._label:SetTextColor(s[1], s[2], s[3], 1)
    else
        SetBg(btn, theme.card)
        SetBorder(btn._border, theme.border, theme.border[4])
        btn._label:SetText("In group")
        btn._label:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3], 1)
    end
    btn._available = available
end

local function SpecIcon(specID)
    if not specID or not GetSpecializationInfoByID then
        return nil
    end
    local _, _, _, icon = GetSpecializationInfoByID(specID)
    return icon
end

local function SpellTexture(spellID)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if info then return info.iconID end
    end
    if C_Spell and C_Spell.GetSpellTexture then
        return C_Spell.GetSpellTexture(spellID)
    end
    return nil
end

function SQ:CreateInvitePanel()
    if self.invitePanel then
        return self.invitePanel
    end

    local theme = SQ.Theme
    local width = COL_WIDTH * 5 + PADDING * 2

    local panel = CreateFrame("Frame", "SoloQInvitePanel", UIParent)
    panel:SetSize(width, 180)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetClampedToScreen(true)
    panel:SetScript("OnDragStart", function(f) f:StartMoving() end)
    panel:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
    SetBg(panel, theme.bg)
    SQ.CreateBorder(panel, theme.border[1], theme.border[2], theme.border[3], theme.border[4])

    panel.title = SQ.MakeText(panel, 14)
    panel.title:SetPoint("TOP", panel, "TOP", 0, -12)

    local close = CreateFrame("Button", nil, panel)
    close:SetSize(10, 10)
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -8)
    close:SetNormalAtlas("common-search-clearbutton")
    close:SetScript("OnEnter", function(f) f:SetAlpha(0.7) end)
    close:SetScript("OnLeave", function(f) f:SetAlpha(1) end)
    close:SetScript("OnClick", function() panel:Hide() end)

    -- Five columns: four invite slots + one teleport slot.
    panel.slots = {}
    for c = 1, 5 do
        local col = CreateFrame("Frame", nil, panel)
        col:SetSize(COL_WIDTH, 120)
        col:SetPoint("TOPLEFT", panel, "TOPLEFT", PADDING + (c - 1) * COL_WIDTH, -44)

        local icon = col:CreateTexture(nil, "ARTWORK")
        icon:SetSize(ICON_SIZE, ICON_SIZE)
        icon:SetPoint("TOP", col, "TOP", 0, 0)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- crop the default icon border ring

        local mask = col:CreateMaskTexture()
        mask:SetAllPoints(icon)
        mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        icon:AddMaskTexture(mask)

        panel.slots[c] = { col = col, icon = icon }
    end

    for c = 1, 4 do
        local slot = panel.slots[c]
        local btn = CreateFrame("Button", nil, slot.col)
        btn:SetSize(COL_WIDTH - 12, 22)
        btn:SetPoint("TOP", slot.icon, "BOTTOM", 0, -10)
        btn._border = SQ.CreateBorder(btn, theme.border[1], theme.border[2], theme.border[3], theme.border[4])
        btn._label = SQ.MakeText(btn, 12)
        btn._label:SetPoint("CENTER")

        btn:SetScript("OnClick", function(f)
            if f._available and slot.unit then
                InviteUnit(slot.unit)
            end
        end)
        btn:SetScript("OnEnter", function(f)
            if f._available then
                local s = theme.success
                SetBg(f, { s[1], s[2], s[3], 0.25 })
            end
        end)
        btn:SetScript("OnLeave", function(f)
            if f._available then
                local s = theme.success
                SetBg(f, { s[1], s[2], s[3], 0.15 })
            end
        end)

        StyleInviteButton(btn, true)
        slot.button = btn
    end

    local tpSlot = panel.slots[5]
    local tp = CreateFrame("Button", "SoloQTeleportButton", tpSlot.col, "SecureActionButtonTemplate")
    tp:SetSize(ICON_SIZE, ICON_SIZE)
    tp:SetPoint("TOP", tpSlot.col, "TOP", 0, 0)
    tp.cooldown = CreateFrame("Cooldown", nil, tp, "CooldownFrameTemplate")
    tp.cooldown:SetAllPoints(tp)
    tp.cooldown:EnableMouse(false)
    tp:EnableMouse(true)
    tp:SetMotionScriptsWhileDisabled(true) -- fire OnEnter even when greyed/disabled
    tp:SetScript("OnEnter", function(f)
        if tpSlot.spellID then
            GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(tpSlot.spellID)
            GameTooltip:Show()
        end
    end)
    tp:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tpSlot.teleport = tp

    local tpLabel = SQ.MakeMutedText(tpSlot.col, 11)
    tpLabel:SetPoint("TOP", tpSlot.icon, "BOTTOM", 0, -10)
    tpLabel:SetText("Teleport")
    tpSlot.label = tpLabel

    self.invitePanel = panel
    return panel
end

function SQ:RefreshInviteButtons()
    local panel = self.invitePanel
    if not panel or not panel:IsShown() then
        return
    end

    for c = 1, 4 do
        local slot = panel.slots[c]
        if slot.unit and slot.button then
            StyleInviteButton(slot.button, not SQ.IsInGroup(slot.name, slot.realm))
        end
    end
end

function SQ:UpdateTeleportCooldown()
    local panel = self.invitePanel
    if not panel or not panel:IsShown() then
        return
    end

    local slot = panel.slots[5]
    local spellID = slot.spellID
    if not spellID then
        return
    end

    local start, duration
    if C_Spell and C_Spell.GetSpellCooldown then
        local cd = C_Spell.GetSpellCooldown(spellID)
        if cd then start, duration = cd.startTime, cd.duration end
    elseif GetSpellCooldown then
        start, duration = GetSpellCooldown(spellID)
    end

    if start and duration then
        slot.teleport.cooldown:SetCooldown(start, duration)
    end
end

function SQ:ShowInvitePanel(data)
    if not data then return end

    local panel = self:CreateInvitePanel()
    panel.title:SetText((data.dungeon or "Mythic+") .. (data.keyLevel and (" +" .. data.keyLevel) or ""))

    local invitees = data.invitees or {}
    for c = 1, 4 do
        local slot = panel.slots[c]
        local inv = invitees[c]
        if inv then
            slot.name = inv.name
            slot.realm = inv.realm
            slot.unit = SQ.InviteUnitString(inv.name, inv.realm)
            slot.icon:SetTexture(SpecIcon(inv.specID) or 134400) -- fallback: red question mark
            slot.icon:Show()
            slot.button:Show()
        else
            slot.name, slot.realm, slot.unit = nil, nil, nil
            slot.icon:Hide()
            slot.button:Hide()
        end
    end

    -- Teleport column.
    local tpSlot = panel.slots[5]
    local spellID = SQ.GetTeleportSpell(data.dungeon)
    tpSlot.spellID = spellID

    if spellID then
        tpSlot.icon:SetTexture(SpellTexture(spellID) or 134400)
        tpSlot.icon:Show()
        local known = (IsSpellKnown and IsSpellKnown(spellID)) or (IsPlayerSpell and IsPlayerSpell(spellID))
        tpSlot.icon:SetDesaturated(not known)
        tpSlot.label:Show()

        if not InCombatLockdown() then
            if known then
                tpSlot.teleport:SetAttribute("type", "spell")
                tpSlot.teleport:SetAttribute("spell", spellID)
                tpSlot.teleport:Enable()
            else
                tpSlot.teleport:SetAttribute("type", nil)
                tpSlot.teleport:SetAttribute("spell", nil)
                tpSlot.teleport:Disable()
            end
        end
    else
        -- No teleport mapped for this dungeon (e.g. missing spell ID).
        tpSlot.icon:Hide()
        tpSlot.label:Hide()
    end

    panel:Show()
    self:RefreshInviteButtons()
    self:UpdateTeleportCooldown()
end

local events = CreateFrame("Frame")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
events:SetScript("OnEvent", function(_, event)
    if event == "GROUP_ROSTER_UPDATE" then
        SQ:RefreshInviteButtons()
    else
        SQ:UpdateTeleportCooldown()
    end
end)
