-- SavedVariables
SavedVariables = SavedVariables or {}

-- Безопасно берём шрифт как в старой версии (с fallback)
local fontName, fontHeight, fontFlags = "Fonts\\FRIZQT__.TTF", 12, ""
if PlayerFrameHealthBar and PlayerFrameHealthBar.TextString and PlayerFrameHealthBar.TextString.GetFont then
  local n, h, f = PlayerFrameHealthBar.TextString:GetFont()
  if n then fontName = n end
  if h then fontHeight = h end
  if f then fontFlags = f end
end

-- Состояние щита
local POWER_WORD_SHIELD_IDS = {
  [17] = true, [592] = true, [600] = true, [3747] = true, [6065] = true, [6066] = true,
  [10898] = true, [10899] = true, [10900] = true, [10901] = true,
}

local maxShield = 0
local currentShield = 0
local shieldExpirationTime = 0
local timer = nil

-- === Фрейм ===
local frame = CreateFrame("Frame", "PowerWordShieldCenterFrame")
frame:SetSize(100, 100)
frame:SetPoint("CENTER", PlayerFrame, "CENTER", 670, -360)
frame:Hide()

local texture = frame:CreateTexture(nil, "BACKGROUND")
texture:SetAllPoints()
texture:SetVertexColor(1, 1, 0)
texture:Hide()

local fontString = frame:CreateFontString(nil, "OVERLAY")
fontString:SetFont(fontName, fontHeight * 2, fontFlags)
fontString:SetPoint("CENTER", frame, "CENTER", 0, -80)
fontString:SetTextColor(1, 1, 1)
fontString:Hide()

-- === Дефолты настроек ===
local function EnsureDefaults()
  if SavedVariables.visibility == nil then SavedVariables.visibility = 0 end
  if SavedVariables.style == nil then SavedVariables.style = 0 end
  if SavedVariables.texturePath == nil then SavedVariables.texturePath = "Interface\\AddOns\\PriestShieldTracker\\Aura14.tga" end
  if SavedVariables.offsetX == nil then SavedVariables.offsetX = 0 end
  if SavedVariables.offsetY == nil then SavedVariables.offsetY = 0 end
end

-- === Применяем внешний вид ===
local function ApplyVisual()
  EnsureDefaults()
  local path = SavedVariables.texturePath or "Interface\\AddOns\\PriestShieldTracker\\Aura14.tga"
  texture:SetTexture(path)

  -- смещения
  local offsetX = SavedVariables.offsetX or 0
  local offsetY = SavedVariables.offsetY or 0
  if path == "Interface\\AddOns\\PriestShieldTracker\\Aura62.tga" then
    frame:SetSize(300, 300)
    frame:SetPoint("CENTER", PlayerFrame, "CENTER", 570 + offsetX, -360 + offsetY)
    fontString:SetPoint("CENTER", frame, "CENTER", 100, -80)
  else
    frame:SetSize(100, 100)
    frame:SetPoint("CENTER", PlayerFrame, "CENTER", 670 + offsetX, -360 + offsetY)
    fontString:SetPoint("CENTER", frame, "CENTER", 0, -80)
    texture:SetAllPoints()
  end

  -- стиль
  if SavedVariables.style == 0 then fontString:Show(); texture:Show()
  elseif SavedVariables.style == 1 then fontString:Hide(); texture:Show()
  elseif SavedVariables.style == 2 then fontString:Show(); texture:Hide()
  else fontString:Hide(); texture:Hide() end

  -- видимость
  local shouldShow = (SavedVariables.visibility == 0 and currentShield > 0)
    or (SavedVariables.visibility == 1 and UnitAffectingCombat("player") and currentShield > 0)
  if SavedVariables.visibility == 2 or SavedVariables.style == 3 then shouldShow = false end

  if shouldShow then frame:Show() else frame:Hide() end
  fontString:SetText(currentShield or 0)
end

-- === Подсчёт прочности ===
local function RecalcShieldFromBuff(resetCurrent)
  local found = false
  for i = 1, 32 do
    local _, _, _, _, _, _, expirationTime, _, _, buffSpellId = UnitBuff("player", i)
    if POWER_WORD_SHIELD_IDS[buffSpellId] then
      found = true
      local description = GetSpellDescription(buffSpellId)
      local v = description and description:match("(%d+)")
      maxShield = v and tonumber(v) or 0
      if resetCurrent then
        currentShield = maxShield
      end
      shieldExpirationTime = type(expirationTime) == "number" and expirationTime or 0
      break
    end
  end
  if not found then
    maxShield = 0
    currentShield = 0
    shieldExpirationTime = 0
    if timer then timer:Cancel(); timer = nil end
  end
end

-- === Логика ===
local function HandleEvent(event, unit)
  if event == "PLAYER_ENTERING_WORLD" then
    EnsureDefaults()
    RecalcShieldFromBuff(true)
    ApplyVisual()
    return
  end

  if event == "UNIT_AURA" and unit == "player" then
    -- не сбрасываем currentShield! только обновляем визуал
    ApplyVisual()
    return
  end

  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    local info = { CombatLogGetCurrentEventInfo() }
    local subevent = info[2]
    local destName = info[9]
    local spellId = info[12]
    local playerName = UnitName("player")

    if subevent == "SPELL_AURA_APPLIED" and destName == playerName and POWER_WORD_SHIELD_IDS[spellId] then
      RecalcShieldFromBuff(true)
      ApplyVisual()
      return
    end

    if subevent == "SPELL_AURA_REFRESH" and destName == playerName and POWER_WORD_SHIELD_IDS[spellId] then
      RecalcShieldFromBuff(true)
      ApplyVisual()
      return
    end

    if subevent == "SPELL_AURA_REMOVED" and destName == playerName and POWER_WORD_SHIELD_IDS[spellId] then
      maxShield = 0
      currentShield = 0
      shieldExpirationTime = 0
      if timer then timer:Cancel(); timer = nil end
      ApplyVisual()
      return
    end

    if subevent == "SPELL_ABSORBED" and destName == playerName then
      local absorbed = info[#info]
      if type(absorbed) == "number" and absorbed > 0 then
        currentShield = math.max(0, (currentShield or 0) - absorbed)
        ApplyVisual()
      end
      return
    end
  end

  if shieldExpirationTime > 0 and GetTime() >= shieldExpirationTime then
    maxShield = 0
    currentShield = 0
    shieldExpirationTime = 0
    if timer then timer:Cancel(); timer = nil end
    ApplyVisual()
  end
end

-- === События ===
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UNIT_AURA")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:SetScript("OnEvent", function(_, event, unit) HandleEvent(event, unit) end)

-- === Настройки ===
SLASH_POWERWORDSHIELD1, SLASH_POWERWORDSHIELD2 = '/pws', '/powerwordshield'
local category = Settings.RegisterVerticalLayoutCategory("PowerWordShield")
Settings.RegisterAddOnCategory(category)
function SlashCmdList.POWERWORDSHIELD() Settings.OpenToCategory(category:GetID()) end

-- Visibility
do
  local proxySetting = Settings.RegisterProxySetting(
    category, "PST_visibility", Settings.VarType.Number, "Visibility", 0,
    function() return SavedVariables.visibility or 0 end,
    function(v) SavedVariables.visibility = v; ApplyVisual() end
  )
  Settings.CreateDropdown(category, proxySetting, function()
    local c = Settings.CreateControlTextContainer()
    c:Add(0, "Always")
    c:Add(1, "Combat Only")
    c:Add(2, "Never")
    return c:GetData()
  end, "Visibility")
end

-- Style
do
  local proxySetting = Settings.RegisterProxySetting(
    category, "PST_style", Settings.VarType.Number, "Style", 0,
    function() return SavedVariables.style or 0 end,
    function(v) SavedVariables.style = v; ApplyVisual() end
  )
  Settings.CreateDropdown(category, proxySetting, function()
    local c = Settings.CreateControlTextContainer()
    c:Add(0, "Icon and Numeric Value")
    c:Add(1, "Icon")
    c:Add(2, "Numeric Value")
    c:Add(3, "Hidden")
    return c:GetData()
  end, "Style")
end

-- Texture
do
  local proxySetting = Settings.RegisterProxySetting(
    category, "PST_texturePath", Settings.VarType.String, "Texture", "Interface\\AddOns\\PriestShieldTracker\\Aura14.tga",
    function() return SavedVariables.texturePath or "Interface\\AddOns\\PriestShieldTracker\\Aura14.tga" end,
    function(v) SavedVariables.texturePath = v; ApplyVisual() end
  )
  Settings.CreateDropdown(category, proxySetting, function()
    local c = Settings.CreateControlTextContainer()
    c:Add("Interface\\AddOns\\PriestShieldTracker\\Aura14.tga", "Aura14")
    c:Add("Interface\\AddOns\\PriestShieldTracker\\Aura62.tga", "Aura62")
    return c:GetData()
  end, "Texture")
end

-- Offset X
do
  local proxySetting = Settings.RegisterProxySetting(
    category, "PST_offsetX", Settings.VarType.Number, "Offset X", 0,
    function() return SavedVariables.offsetX or 0 end,
    function(v) SavedVariables.offsetX = v; ApplyVisual() end
  )
  local options = Settings.CreateSliderOptions(-500, 500, 1)
  Settings.CreateSlider(category, proxySetting, options, "Offset X")
end

-- Offset Y
do
  local proxySetting = Settings.RegisterProxySetting(
    category, "PST_offsetY", Settings.VarType.Number, "Offset Y", 0,
    function() return SavedVariables.offsetY or 0 end,
    function(v) SavedVariables.offsetY = v; ApplyVisual() end
  )
  local options = Settings.CreateSliderOptions(-500, 500, 1)
  Settings.CreateSlider(category, proxySetting, options, "Offset Y")
end

-- Первичное применение
ApplyVisual()
