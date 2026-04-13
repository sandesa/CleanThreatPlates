local CP = CleanPlates
CP.Interrupt = {}

local Interrupt = CP.Interrupt

-------------------------------------------------
-- Variables
-------------------------------------------------

local colors = {
    interruptible = {1, 1, 0, 0.7},
    nonInterruptible = {1, 0, 0, 0.7},
    name = {1, 0.8, 0},
}

local BUTTON_HEIGHT = 40
local BUTTON_WIDTH = 250
local BUTTON_SPACING = 13

-------------------------------------------------
-- UI
-------------------------------------------------

local container = CreateFrame("Frame", nil, UIParent)
container:SetSize(220, 300)
container:SetPoint("LEFT", UIParent, "LEFT", 500, 0)
-- container:Hide()

container.buttons = {}

-------------------------------------------------
-- BUTTON
-------------------------------------------------

local function CreateButton(index)

    local btn = CreateFrame("Button", nil, container, "SecureActionButtonTemplate,BackdropTemplate")
    btn:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    local yOffset = (index - 1) * (BUTTON_HEIGHT + BUTTON_SPACING)
    btn:SetPoint("TOP", 0, -yOffset)
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp")
    btn:SetFrameStrata("DIALOG")
    btn:Enable()

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(30,30)
    btn.icon:SetPoint("LEFT", 5, 0)

    btn.text = btn:CreateFontString(nil,"OVERLAY","GameFontNormal")
    btn.text:SetPoint("LEFT", btn.icon, "RIGHT", 5, 0)

    btn.duration = btn:CreateFontString(nil,"OVERLAY","GameFontNormal")
    btn.duration:SetPoint("RIGHT", btn, "RIGHT", -5, 0)
    btn.duration:SetJustifyH("RIGHT")

    btn.castbar = CreateFrame("StatusBar", nil, btn)
    btn.castbar:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    btn.castbar:SetPoint("CENTER", btn, "CENTER")
    btn.castbar:SetStatusBarTexture("Interface/Buttons/WHITE8x8")
    btn.castbar:SetFrameLevel(btn:GetFrameLevel() - 1)  -- Behind icon and text
    btn:SetBackdrop({
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 12,
    })

    btn.castbar.bg = btn.castbar:CreateTexture(nil, "BACKGROUND")
    btn.castbar.bg:SetAllPoints(btn.castbar)
    btn.castbar.bg:SetColorTexture(0, 0, 0, 0.3)

    btn.name = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.name:SetPoint("BOTTOM", btn, "TOP", 0, 2)
    btn.name:SetTextColor(colors.name[1], colors.name[2], colors.name[3]) -- optional gold color

    btn.castbar:SetScript("OnUpdate", function(self, elapsed)
        if not self.startTime or not self.endTime then return end
    
        local now = GetTime() * 1000
        local target = now
    
        self.currentValue = self.currentValue or target
    
        local speed = 18
        self.currentValue = self.currentValue + (target - self.currentValue) * math.min(elapsed * speed, 1)
    
        self:SetValue(self.currentValue)
    end)

    -- Secure attributes
    btn:SetAttribute("type", "target")
    btn:SetAttribute("type1", "target")
    btn:SetAttribute("type2", "menu")

    return btn
end

-------------------------------------------------
-- CAST DETECTION
-------------------------------------------------

function Interrupt:GetCastInfo(unit)
    local name, text, texture, startTime, endTime, isTradeskill, castID, notInterruptible, spellId = UnitCastingInfo(unit)
    local icon = texture

    if not name then
        name, text, texture, startTime, endTime, isTradeskill, notInterruptible, spellId = UnitChannelInfo(unit)
        icon = texture
    end

    if not name then
        return nil
    end

    local castTime
    if spellId then
        local spellInfo = C_Spell.GetSpellInfo(spellId)
        if spellInfo then
            castTime = spellInfo.castTime
        end
    end

    return {
        spell = name,
        icon = icon,
        startTime = startTime,
        endTime = endTime,
        castTime = castTime,
        spellId = spellId,
        notInterruptible = notInterruptible,    
    }
end

function Interrupt:OnCastEvent(event, unit)
    local data = CP.activeUnits[unit]
    if not data then return end

    if event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        data.cast = nil
        return
    end

    local cast = self:GetCastInfo(unit)
    if not cast then
        data.cast = nil
        return
    end

    if cast.castTime then
        cast.startTime = GetTime() * 1000
    end

    data.cast = cast
end

function Interrupt:UpdateUnit(unit)
    if CP.activeUnits[unit] then
        self:UpdateUI()
    end
end

-------------------------------------------------
-- CLEANUP
-------------------------------------------------

function Interrupt:OnUnitAdded(unit)
    local data = CP.activeUnits[unit]
    if data then data.cast = nil end
end

function Interrupt:OnUnitRemoved(unit)
    local data = CP.activeUnits[unit]
    if data then data.cast = nil end
end

-------------------------------------------------
-- UI BUILD
-------------------------------------------------

function Interrupt:UpdateUI()

    local sorted = {}

    for unit, data in pairs(CP.activeUnits) do
        if data.cast then
            table.insert(sorted, {unit = unit, cast = data.cast})
        end
    end

    local index = 1

    for _, entry in ipairs(sorted) do
        local unit = entry.unit
        local cast = entry.cast

        local btn = container.buttons[index]

        if not btn then
            btn = CreateButton(index)
            container.buttons[index] = btn
        end

        btn:SetAttribute("unit", unit)
        btn:SetAttribute("unit1", unit)
        btn.text:SetText(cast.spell)
        btn.icon:SetTexture(cast.icon)

        btn.startTime = cast.startTime
        btn.endTime = cast.endTime
        btn.castbar:SetMinMaxValues(cast.startTime, cast.endTime)
        local now = GetTime() * 1000
        btn.castbar:SetValue(now)
        btn.duration:SetText("")

        btn.castbar:SetStatusBarColor(colors.interruptible[1], colors.interruptible[2], colors.interruptible[3], colors.interruptible[4])

        local unitName = UnitName(unit)

        btn.name:SetText(unitName or "")

        btn:Show()
        index = index + 1
    end

    for i = index, #container.buttons do
        container.buttons[i]:Hide()
    end

    if index == 1 then
        container:Hide()
    else
        container:Show()
    end
end