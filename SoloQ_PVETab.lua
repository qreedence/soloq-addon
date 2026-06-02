local _, SQ = ...

local TAB_LABEL = "SoloQ"
local TAB_TEMPLATE = "PanelTabButtonTemplate"

-- The three Blizzard side panels.
local BLIZZARD_PANELS = { "GroupFinderFrame", "ChallengesFrame", "PVPUIFrame" }

local function PositionTab(tab, id)
    local prev = _G["PVEFrameTab" .. (id - 1)]
    if not prev then
        tab:ClearAllPoints()
        tab:SetPoint("BOTTOMLEFT", PVEFrame, "BOTTOMLEFT", 10, 45)
        return
    end

    local spacing = 0
    local prev2 = _G["PVEFrameTab" .. (id - 2)]
    if prev2 then
        local prevLeft, prev2Right = prev:GetLeft(), prev2:GetRight()
        if prevLeft and prev2Right then
            spacing = prevLeft - prev2Right
        end
    end

    tab:ClearAllPoints()
    tab:SetPoint("LEFT", prev, "RIGHT", spacing, 0)
end

local function HideBlizzardPanels()
    for _, name in ipairs(BLIZZARD_PANELS) do
        local f = _G[name]
        if f and f.IsShown and f:IsShown() then
            f:Hide()
        end
    end
end

local PANEL_INSET_TOP = 18
local PANEL_INSET_BOTTOM = 2
local PANEL_INSET_SIDE = 2

local SOLOQ_PVE_WIDTH = 563

local function LayoutInPVEFrame(panel)
    PVEFrame:SetWidth(SOLOQ_PVE_WIDTH)

    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", PVEFrame, "TOPLEFT", PANEL_INSET_SIDE, -PANEL_INSET_TOP)
    panel:SetPoint("BOTTOMRIGHT", PVEFrame, "BOTTOMRIGHT", -PANEL_INSET_SIDE, PANEL_INSET_BOTTOM)
end

local function DockQueuePanel(panel)
    panel:SetParent(PVEFrame)
    panel:SetMovable(false)
    panel:RegisterForDrag()
    panel:SetScript("OnDragStart", nil)
    panel:SetScript("OnDragStop", nil)
    panel:SetFrameStrata(PVEFrame:GetFrameStrata())
    panel:SetFrameLevel(PVEFrame:GetFrameLevel() + 5)

    if panel._bg then
        panel._bg:SetColorTexture(0.05, 0.05, 0.05, 1)
    end

    if panel.titleBar then panel.titleBar:Hide() end
    if panel.closeBtn then panel.closeBtn:Hide() end

    local content = panel.content
    if content then
        content:ClearAllPoints()
        content:SetWidth(panel.contentWidth or 306)
        content:SetHeight(panel.contentHeight or 384)
        content:SetPoint("CENTER", panel, "CENTER", 0, -10)
    end

    LayoutInPVEFrame(panel)
    panel:Hide()
end

function SQ:CreatePVETab()
    if self.pveTab or not PVEFrame then
        return
    end

    local id = (PVEFrame.numTabs or 0) + 1

    local ok, tab = pcall(CreateFrame, "Button", "PVEFrameTab" .. id, PVEFrame, TAB_TEMPLATE)
    if not ok or not tab then
        return
    end

    tab:SetID(id)
    tab:SetText(TAB_LABEL)
    if PanelTemplates_TabResize then
        PanelTemplates_TabResize(tab, 0)
    end
    PositionTab(tab, id)
    PVEFrame.numTabs = id

    tab:SetScript("OnClick", function()
        if PlaySound and SOUNDKIT then
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        end
        SQ:ShowPVETab()
    end)

    self.pveTab = tab

    self:CreateQueuePanel()
    if self.queuePanel then
        DockQueuePanel(self.queuePanel)
    end

    if not self.pveHooked then
        hooksecurefunc("PVEFrame_ShowFrame", function()
            if SQ.queuePanel then
                SQ.queuePanel:Hide()
            end
        end)
        self.pveHooked = true
    end

    -- Re-match tab spacing once PVEFrame has been laid out (region coordinates
    -- aren't available until it's first shown).
    if not self.pveShowHook then
        PVEFrame:HookScript("OnShow", function()
            if SQ.pveTab then
                PositionTab(SQ.pveTab, SQ.pveTab:GetID())
            end
        end)
        self.pveShowHook = true
    end
end

function SQ:ShowPVETab()
    self:CreatePVETab()

    if not self.pveTab or not self.queuePanel then
        self:ToggleQueuePanel()
        return
    end

    if not PVEFrame:IsShown() then
        ShowUIPanel(PVEFrame)
    end

    HideBlizzardPanels()
    LayoutInPVEFrame(self.queuePanel)

    if PanelTemplates_SetTab then
        pcall(PanelTemplates_SetTab, PVEFrame, self.pveTab:GetID())
    end

    if PVEFrame.SetTitle then
        PVEFrame:SetTitle(TAB_LABEL)
    elseif PVEFrameTitleText then
        PVEFrameTitleText:SetText(TAB_LABEL)
    end

    local portrait = PVEFrame.PortraitContainer and PVEFrame.PortraitContainer.portrait
        or PVEFrame.portrait or _G.PVEFramePortrait
    if portrait and portrait.SetTexture then
        portrait:SetTexture("Interface\\AddOns\\SoloQ\\icon")
        portrait:SetPoint("CENTER", portrait:GetParent(), "CENTER", 0, -20)
    end

    if C_MythicPlus and C_MythicPlus.RequestMapInfo then
        C_MythicPlus.RequestMapInfo()
    end

    self.queuePanel:Show()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    if PVEFrame then
        SQ:CreatePVETab()
    end
end)
