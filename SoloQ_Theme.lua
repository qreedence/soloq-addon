local _, SQ = ...

SQ.Theme = {
    bg         = { 0.05, 0.05, 0.05, 0.95 },
    card       = { 0.10, 0.10, 0.10, 1.00 },
    foreground = { 0.97, 0.97, 0.97, 1.00 },
    muted      = { 0.55, 0.55, 0.55, 1.00 },
    border     = { 1.00, 1.00, 1.00, 0.10 },
    primary    = { 0.55, 0.18, 0.14, 1.00 },
    success    = { 0.34, 0.80, 0.44, 1.00 },
    error      = { 0.82, 0.36, 0.27, 1.00 },

    roleColors = {
        tank   = { 0.34, 0.60, 0.85, 1.00 },
        healer = { 0.34, 0.80, 0.44, 1.00 },
        dps    = { 0.82, 0.36, 0.27, 1.00 },
    },

    font       = "Fonts\\FRIZQT__.TTF",
    fontBold   = "Fonts\\FRIZQT__.TTF",
}

local WHITE8 = "Interface\\Buttons\\WHITE8X8"

function SQ.CreateBorder(frame, r, g, b, a, thickness)
    thickness = thickness or 1
    r = r or 1
    g = g or 1
    b = b or 1
    a = a or 0.10

    local top = frame:CreateTexture(nil, "BORDER")
    top:SetTexture(WHITE8)
    top:SetColorTexture(r, g, b, a)
    top:SetHeight(thickness)
    top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)

    local bottom = frame:CreateTexture(nil, "BORDER")
    bottom:SetTexture(WHITE8)
    bottom:SetColorTexture(r, g, b, a)
    bottom:SetHeight(thickness)
    bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

    local left = frame:CreateTexture(nil, "BORDER")
    left:SetTexture(WHITE8)
    left:SetColorTexture(r, g, b, a)
    left:SetWidth(thickness)
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)

    local right = frame:CreateTexture(nil, "BORDER")
    right:SetTexture(WHITE8)
    right:SetColorTexture(r, g, b, a)
    right:SetWidth(thickness)
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

    return { top = top, bottom = bottom, left = left, right = right }
end

function SQ.MakeText(parent, size, r, g, b, a)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(SQ.Theme.font, size or 12, "")
    if r then
        fs:SetTextColor(r, g, b, a or 1)
    else
        local t = SQ.Theme.foreground
        fs:SetTextColor(t[1], t[2], t[3], t[4])
    end
    return fs
end

function SQ.MakeMutedText(parent, size)
    local t = SQ.Theme.muted
    return SQ.MakeText(parent, size, t[1], t[2], t[3], t[4])
end
