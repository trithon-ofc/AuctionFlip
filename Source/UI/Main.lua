AuctionFlip.UI = {
  Frame = nil,
  TabCreated = false,
  CurrentTab = 1,
  CurrentSubTab = {},
  SelectedOpportunity = nil,
  FlatButtons = {},
  ActivityMessage = nil,
  PendingBuy = nil,
  BuyConfirmWindow = nil,
  SellConfirmWindow = nil,
  PendingPurchaseQueue = {},
  ActiveCommodityPurchase = nil,
  PurchaseToken = 0,
  PendingSale = nil,
}

-- Theme colors (mutated by ApplyThemeVariant)
local THEME = {
  bg = {0.03, 0.03, 0.05, 0.97},
  bgLight = {0.06, 0.06, 0.09, 0.95},
  bgDark = {0.02, 0.02, 0.03, 1},
  border = {0.0, 0.65, 1.0, 0.8},
  borderLight = {0.3, 0.8, 1.0, 0.6},
  gold = {0.3, 0.8, 1.0},
  goldDim = {0.2, 0.6, 0.8},
  text = {0.95, 0.95, 0.95},
  textDim = {0.55, 0.55, 0.55},
  green = {0, 0.85, 0.35},
  red = {0.9, 0.2, 0.2},
  blue = {0.3, 0.6, 1},
  accent = {0.0, 0.65, 1.0},
  accentSoft = {0.0, 0.35, 0.55},
  accentText = {0.35, 0.85, 1.0},
  highlight = {0.0, 0.65, 1.0, 0.10},
  hover = {0.0, 0.65, 1.0, 0.05},
}

local THEME_PRESETS = {
  neon_blue = {
    accent = {0.0, 0.65, 1.0},
    accentSoft = {0.0, 0.35, 0.55},
    accentText = {0.35, 0.85, 1.0},
  },
  neon_green = {
    accent = {0.1, 1.0, 0.45},
    accentSoft = {0.05, 0.45, 0.22},
    accentText = {0.4, 1.0, 0.6},
  },
  neon_red = {
    accent = {1.0, 0.25, 0.35},
    accentSoft = {0.5, 0.12, 0.16},
    accentText = {1.0, 0.55, 0.62},
  },
}

function AuctionFlip.UI.ApplyThemeVariant(variant)
  local preset = THEME_PRESETS[variant] or THEME_PRESETS.neon_blue
  THEME.accent = preset.accent
  THEME.accentSoft = preset.accentSoft
  THEME.accentText = preset.accentText
  THEME.border = {preset.accent[1], preset.accent[2], preset.accent[3], 0.85}
  THEME.borderLight = {preset.accent[1], preset.accent[2], preset.accent[3], 0.55}
  THEME.gold = {preset.accentText[1], preset.accentText[2], preset.accentText[3]}
  THEME.goldDim = {preset.accent[1], preset.accent[2], preset.accent[3]}
  THEME.highlight = {preset.accent[1], preset.accent[2], preset.accent[3], 0.10}
  THEME.hover = {preset.accent[1], preset.accent[2], preset.accent[3], 0.05}
end

local function GetCurrentThemeVariant()
  if AuctionFlip.Config and AuctionFlip.Config.Get then
    return AuctionFlip.Config.Get("theme_variant") or "neon_blue"
  end
  return "neon_blue"
end

-- Font definitions
local FONTS = {
  title = "GameFontNormalLarge",
  header = "GameFontNormal",
  normal = "GameFontHighlight",
  small = "GameFontNormalSmall",
  tiny = "GameFontHighlightSmall",
}

local NEON_FONT_PATH = "Fonts\\FRIZQT__.TTF"

local function ApplyNeonFont(fontString, size, flags)
  if not fontString or not fontString.SetFont then
    return
  end
  fontString:SetFont(NEON_FONT_PATH, size or 11, flags or "OUTLINE")
end

function AuctionFlip.UI.Initialize()
  AuctionFlip.UI.ApplyThemeVariant(GetCurrentThemeVariant())

  -- Always parent to UIParent so the frame is independent and side-by-side
  local frame = CreateFrame("Frame", "AuctionFlipMainFrame", UIParent, "BackdropTemplate")

  frame:SetSize(920, 620)
  frame:SetFrameStrata("HIGH")
  frame:SetToplevel(true)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
  frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  frame:SetClampedToScreen(true)

  -- Position side-by-side with AH if it's open
  AuctionFlip.UI.PositionBesideAH(frame)

  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\AddOns\\AuctionFlip\\Media\\border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
  })
  frame:SetBackdropColor(unpack(THEME.bg))
  frame:SetBackdropBorderColor(unpack(THEME.border))
  frame:Hide()

  -- Follow the AH when it moves (e.g. user drags it)
  frame:SetScript("OnUpdate", function(self, elapsed)
    self._updateTimer = (self._updateTimer or 0) + elapsed
    if self._updateTimer < 0.5 then return end
    self._updateTimer = 0
    if AuctionFlip.UI.IsAuctionHouseVisible() and not self._userDragged then
      AuctionFlip.UI.PositionBesideAH(self)
    end
  end)

  -- Track if user manually drags our frame (stop auto-positioning)
  frame:HookScript("OnDragStart", function(self)
    self._userDragged = true
  end)

  -- Title bar
  local titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  titleBar:SetHeight(32)
  titleBar:SetPoint("TOPLEFT", 0, 0)
  titleBar:SetPoint("TOPRIGHT", 0, 0)
  titleBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
  titleBar:SetBackdropColor(0.08, 0.08, 0.12, 1)
  frame.titleBar = titleBar

  -- Title icon
  local titleIcon = titleBar:CreateTexture(nil, "ARTWORK")
  titleIcon:SetSize(20, 20)
  titleIcon:SetPoint("LEFT", 10, 0)
  titleIcon:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")
  frame.titleIcon = titleIcon

  -- Title text
  local titleText = titleBar:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  titleText:SetPoint("LEFT", titleIcon, "RIGHT", 8, 0)
  titleText:SetText("AuctionFlip")
  titleText:SetTextColor(unpack(THEME.gold))
  ApplyNeonFont(titleText, 16, "OUTLINE")
  frame.titleText = titleText

  -- Version text
  local versionText = titleBar:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  versionText:SetPoint("LEFT", titleText, "RIGHT", 8, 0)
  versionText:SetText("v" .. AuctionFlip.Utilities.GetAddonVersion())
  versionText:SetTextColor(unpack(THEME.textDim))
  ApplyNeonFont(versionText, 10, "")
  frame.versionText = versionText

  -- Custom close button (hides frame, toggle button on AH can reopen)
  local closeBtn = CreateFrame("Button", nil, titleBar)
  closeBtn:SetSize(24, 24)
  closeBtn:SetPoint("RIGHT", -6, 0)
  AuctionFlip.UI.CreateThemedCloseButton(closeBtn)
  closeBtn:SetScript("OnClick", function()
    frame:Hide()
    AuctionFlip.UI.UpdateToggleButton()
  end)
  frame.closeBtn = closeBtn

  -- Main tabs
  frame.mainTabs = {}
  frame.mainTabContents = {}
  local mainTabNames = {"Opportunities", "Selling", "Settings", "About"}

  for i, name in ipairs(mainTabNames) do
    local tab = AuctionFlip.UI.CreateMainTab(frame, name, i, #mainTabNames)
    if i == 1 then
      tab:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 10, 0)
    else
      tab:SetPoint("LEFT", frame.mainTabs[i-1], "RIGHT", 3, 0)
    end
    frame.mainTabs[i] = tab

    local content = CreateFrame("Frame", nil, frame)
    content:SetAllPoints()
    content:SetPoint("TOPLEFT", 10, -65)
    content:SetPoint("BOTTOMRIGHT", -10, 10)
    content:Hide()
    frame.mainTabContents[i] = content
  end

  -- Initialize tab contents
  AuctionFlip.UI.InitOpportunitiesTab(frame.mainTabContents[1])
  AuctionFlip.UI.InitSellingTab(frame.mainTabContents[2])
  AuctionFlip.UI.InitSettingsTab(frame.mainTabContents[3])
  AuctionFlip.UI.InitAboutTab(frame.mainTabContents[4])

  AuctionFlip.UI.SelectMainTab(1)
  AuctionFlip.UI.Frame = frame
end

--- Positions the AuctionFlip frame to the right side of the AH window.
function AuctionFlip.UI.PositionBesideAH(frame)
  if not frame then return end
  frame:ClearAllPoints()

  if AuctionHouseFrame and AuctionHouseFrame:IsShown() then
    local frameWidth = frame:GetWidth() or 700
    local parentRight = UIParent:GetRight() or 0
    local ahRight = AuctionHouseFrame:GetRight() or 0
    local ahLeft = AuctionHouseFrame:GetLeft() or 0
    local rightSpace = parentRight - ahRight - 6
    local leftSpace = ahLeft - 6

    if rightSpace >= frameWidth then
      frame:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 2, 0)
    elseif leftSpace >= frameWidth then
      frame:SetPoint("TOPRIGHT", AuctionHouseFrame, "TOPLEFT", -2, 0)
    else
      frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
  else
    -- Fallback: center of screen
    frame:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
  end
end

--- Creates or updates a small toggle button pinned to the AH title bar.
-- Clicking it shows/hides the AuctionFlip side panel.
function AuctionFlip.UI.CreateToggleButton()
  if AuctionFlip.UI.ToggleButton then return end
  if not AuctionHouseFrame then return end

  local btn = CreateFrame("Button", "AuctionFlipToggleBtn", AuctionHouseFrame, "BackdropTemplate")
  btn:SetSize(94, 22)
  local function PositionToggleButton()
    btn:ClearAllPoints()
    if AuctionHouseFrame.CloseButton then
      btn:SetPoint("RIGHT", AuctionHouseFrame.CloseButton, "LEFT", -8, 0)
    else
      btn:SetPoint("TOPRIGHT", AuctionHouseFrame, "TOPRIGHT", -80, -4)
    end
  end
  PositionToggleButton()
  btn:SetScript("OnShow", PositionToggleButton)
  btn:SetFrameStrata("HIGH")
  btn:SetFrameLevel(AuctionHouseFrame:GetFrameLevel() + 10)

  btn.bg = btn:CreateTexture(nil, "BACKGROUND")
  btn.bg:SetAllPoints()
  btn.bg:SetColorTexture(0.08, 0.08, 0.12, 0.92)

  -- Gold border edges
  for _, info in ipairs({
    {"TOPLEFT", "TOPRIGHT", true, false},
    {"BOTTOMLEFT", "BOTTOMRIGHT", true, false},
    {"TOPLEFT", "BOTTOMLEFT", false, true},
    {"TOPRIGHT", "BOTTOMRIGHT", false, true},
  }) do
    local edge = btn:CreateTexture(nil, "BORDER")
    edge:SetColorTexture(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.75)
    edge:SetPoint(info[1])
    edge:SetPoint(info[2])
    if info[3] then edge:SetHeight(1) end
    if info[4] then edge:SetWidth(1) end
  end

  btn.icon = btn:CreateTexture(nil, "ARTWORK")
  btn.icon:SetSize(16, 16)
  btn.icon:SetPoint("LEFT", 4, 0)
  btn.icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")

  btn.text = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  btn.text:SetPoint("LEFT", btn.icon, "RIGHT", 4, 0)
  btn.text:SetText("AuctionFlip")
  btn.text:SetTextColor(unpack(THEME.accentText))

  btn:SetScript("OnClick", function()
    if AuctionFlip.UI.Frame then
      if AuctionFlip.UI.Frame:IsShown() then
        AuctionFlip.UI.Frame:Hide()
      else
        AuctionFlip.UI.Frame._userDragged = false  -- reset so it re-anchors
        AuctionFlip.UI.PositionBesideAH(AuctionFlip.UI.Frame)
        AuctionFlip.UI.Frame:Show()
        AuctionFlip.UI.SelectMainTab(1)
        local oppContent = AuctionFlip.UI.Frame.mainTabContents and AuctionFlip.UI.Frame.mainTabContents[1]
        if oppContent then
          AuctionFlip.UI.SelectSubTab(oppContent, 1)
        end
        AuctionFlip.UI.RefreshResults()
        AuctionFlip.UI.RefreshStats()
        if AuctionFlip.UI.RefreshSelling then
          AuctionFlip.UI.RefreshSelling()
        end
      end
      AuctionFlip.UI.UpdateToggleButton()
    end
  end)

  btn:SetScript("OnEnter", function(self)
    self.bg:SetColorTexture(0.12, 0.12, 0.18, 0.98)
    self.text:SetTextColor(1, 1, 1)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Toggle AuctionFlip panel", 1, 1, 1)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function(self)
    self.bg:SetColorTexture(0.08, 0.08, 0.12, 0.92)
    self.text:SetTextColor(unpack(THEME.accentText))
    GameTooltip:Hide()
  end)

  AuctionFlip.UI.ToggleButton = btn
  AuctionFlip.UI.UpdateToggleButton()
end

--- Updates the toggle button appearance based on whether AuctionFlip is visible.
function AuctionFlip.UI.UpdateToggleButton()
  local btn = AuctionFlip.UI.ToggleButton
  if not btn then return end
  if AuctionHouseFrame and AuctionHouseFrame.CloseButton then
    btn:ClearAllPoints()
    btn:SetPoint("RIGHT", AuctionHouseFrame.CloseButton, "LEFT", -8, 0)
  end

  local isVisible = AuctionFlip.UI.Frame and AuctionFlip.UI.Frame:IsShown()
  if isVisible then
    btn.bg:SetColorTexture(THEME.accentSoft[1], THEME.accentSoft[2], THEME.accentSoft[3], 0.95)
    btn.text:SetTextColor(1, 1, 1)
  else
    btn.bg:SetColorTexture(0.08, 0.08, 0.12, 0.92)
    btn.text:SetTextColor(unpack(THEME.accentText))
  end
end

-- Create themed close button
function AuctionFlip.UI.CreateThemedCloseButton(btn)
  btn.bg = btn:CreateTexture(nil, "BACKGROUND")
  btn.bg:SetAllPoints()
  btn.bg:SetColorTexture(0.10, 0.10, 0.14, 0.95)
  
  btn.border = {}
  for _, pos in ipairs({"Top", "Bottom", "Left", "Right"}) do
    local edge = btn:CreateTexture(nil, "BORDER")
    edge:SetColorTexture(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.65)
    btn.border[pos] = edge
  end
  btn.border.Top:SetPoint("TOPLEFT")
  btn.border.Top:SetPoint("TOPRIGHT")
  btn.border.Top:SetHeight(1)
  btn.border.Bottom:SetPoint("BOTTOMLEFT")
  btn.border.Bottom:SetPoint("BOTTOMRIGHT")
  btn.border.Bottom:SetHeight(1)
  btn.border.Left:SetPoint("TOPLEFT")
  btn.border.Left:SetPoint("BOTTOMLEFT")
  btn.border.Left:SetWidth(1)
  btn.border.Right:SetPoint("TOPRIGHT")
  btn.border.Right:SetPoint("BOTTOMRIGHT")
  btn.border.Right:SetWidth(1)
  
  btn.text = btn:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  btn.text:SetPoint("CENTER")
  btn.text:SetText("x")
  btn.text:SetTextColor(unpack(THEME.accentText))
  ApplyNeonFont(btn.text, 13, "OUTLINE")
  
  btn:SetScript("OnEnter", function(self)
    self.bg:SetColorTexture(THEME.accentSoft[1], THEME.accentSoft[2], THEME.accentSoft[3], 1.0)
    self.text:SetTextColor(1, 1, 1)
  end)
  btn:SetScript("OnLeave", function(self)
    self.bg:SetColorTexture(0.10, 0.10, 0.14, 0.95)
    self.text:SetTextColor(unpack(THEME.accentText))
  end)
end

-- Create main tab button
function AuctionFlip.UI.CreateMainTab(parent, text, index, total)
  local tab = CreateFrame("Button", nil, parent, "BackdropTemplate")
  tab:SetSize(110, 26)
  
  tab.bg = tab:CreateTexture(nil, "BACKGROUND")
  tab.bg:SetAllPoints()
  
  tab.topLine = tab:CreateTexture(nil, "ARTWORK")
  tab.topLine:SetPoint("TOPLEFT")
  tab.topLine:SetPoint("TOPRIGHT")
  tab.topLine:SetHeight(2)
  
  tab.text = tab:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  tab.text:SetPoint("CENTER")
  tab.text:SetText(text)
  ApplyNeonFont(tab.text, 12, "OUTLINE")
  
  tab:SetScript("OnClick", function() AuctionFlip.UI.SelectMainTab(index) end)
  
  return tab
end

function AuctionFlip.UI.SelectMainTab(index)
  if not AuctionFlip.UI.Frame then return end
  AuctionFlip.UI.CurrentTab = index
  
  for i, tab in ipairs(AuctionFlip.UI.Frame.mainTabs) do
    if i == index then
      tab.bg:SetColorTexture(THEME.accentSoft[1], THEME.accentSoft[2], THEME.accentSoft[3], 0.45)
      tab.topLine:SetColorTexture(unpack(THEME.gold))
      tab.text:SetTextColor(1, 1, 1)
      AuctionFlip.UI.Frame.mainTabContents[i]:Show()
    else
      tab.bg:SetColorTexture(0.05, 0.05, 0.08, 0.8)
      tab.topLine:SetColorTexture(0.3, 0.3, 0.35, 0.5)
      tab.text:SetTextColor(unpack(THEME.textDim))
      AuctionFlip.UI.Frame.mainTabContents[i]:Hide()
    end
  end

  if index == 2 and AuctionFlip.UI.RefreshSelling then
    AuctionFlip.UI.RefreshSelling()
  end
end

-- OPPORTUNITIES TAB
function AuctionFlip.UI.InitOpportunitiesTab(content)
  content.subTabs = {}
  content.subTabContents = {}
  
  local subNames = {"Scan", "Results", "Stats"}
  
  for i, name in ipairs(subNames) do
    local subTab = CreateFrame("Button", nil, content)
    subTab:SetSize(70, 20)
    if i == 1 then
      subTab:SetPoint("TOPLEFT", 0, 0)
    else
      subTab:SetPoint("LEFT", content.subTabs[i-1], "RIGHT", 5, 0)
    end
    
    subTab.text = subTab:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    subTab.text:SetPoint("CENTER")
    subTab.text:SetText(name)
    ApplyNeonFont(subTab.text, 11, "")
    
    subTab.line = subTab:CreateTexture(nil, "ARTWORK")
    subTab.line:SetPoint("BOTTOMLEFT")
    subTab.line:SetPoint("BOTTOMRIGHT")
    subTab.line:SetHeight(1)
    
    subTab:SetScript("OnClick", function()
      AuctionFlip.UI.SelectSubTab(content, i)
    end)
    
    content.subTabs[i] = subTab
    
    local subContent = CreateFrame("Frame", nil, content)
    subContent:SetAllPoints()
    subContent:SetPoint("TOPLEFT", 0, -25)
    subContent:SetPoint("BOTTOMRIGHT", 0, 0)
    subContent:Hide()
    content.subTabContents[i] = subContent
  end
  
  -- Init sub-tabs
  AuctionFlip.UI.InitScanSubTab(content.subTabContents[1], content)
  AuctionFlip.UI.InitResultsSubTab(content.subTabContents[2])
  AuctionFlip.UI.InitStatsSubTab(content.subTabContents[3])
  
  AuctionFlip.UI.SelectSubTab(content, 1)
end

function AuctionFlip.UI.SelectSubTab(parentContent, index)
  parentContent.currentSubTab = index
  for i, subTab in ipairs(parentContent.subTabs) do
    if i == index then
      subTab.text:SetTextColor(unpack(THEME.gold))
      subTab.line:SetColorTexture(unpack(THEME.gold))
      parentContent.subTabContents[i]:Show()
    else
      subTab.text:SetTextColor(unpack(THEME.textDim))
      subTab.line:SetColorTexture(0.3, 0.3, 0.35, 0.3)
      parentContent.subTabContents[i]:Hide()
    end
  end
end

local function CreateDashboardPanel(parent, width, height, titleText)
  local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  panel:SetSize(width, height)
  panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8" })
  panel:SetBackdropColor(0.04, 0.04, 0.07, 0.82)
  panel:SetBackdropBorderColor(0.14, 0.14, 0.20, 0.55)

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  title:SetPoint("TOPLEFT", 10, -8)
  title:SetText(titleText or "")
  title:SetTextColor(unpack(THEME.gold))
  ApplyNeonFont(title, 11, "OUTLINE")
  panel.title = title

  return panel
end

local function CreateDashboardStat(parent, labelText, left, top, width)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(width or 150, 30)
  holder:SetPoint("TOPLEFT", left, top)

  local label = holder:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  label:SetPoint("TOPLEFT", 0, 0)
  label:SetText(labelText)
  label:SetTextColor(unpack(THEME.textDim))

  local value = holder:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  value:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
  value:SetTextColor(unpack(THEME.text))

  return value
end

local function CreateHistoryChart(parent, titleText)
  local panel = CreateDashboardPanel(parent, 400, 160, titleText or "History")
  panel.bars = {}
  panel.labels = {}

  local plot = CreateFrame("Frame", nil, panel)
  plot:SetPoint("TOPLEFT", 12, -30)
  plot:SetPoint("BOTTOMRIGHT", -12, 22)
  panel.plot = plot

  local baseLine = plot:CreateTexture(nil, "ARTWORK")
  baseLine:SetPoint("BOTTOMLEFT", 0, 0)
  baseLine:SetPoint("BOTTOMRIGHT", 0, 0)
  baseLine:SetHeight(1)
  baseLine:SetColorTexture(unpack(THEME.borderLight))
  panel.baseLine = baseLine

  local summary = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  summary:SetPoint("BOTTOMLEFT", 12, 8)
  summary:SetPoint("BOTTOMRIGHT", -12, 8)
  summary:SetJustifyH("LEFT")
  summary:SetTextColor(unpack(THEME.textDim))
  panel.summary = summary

  for index = 1, 16 do
    local bar = plot:CreateTexture(nil, "ARTWORK")
    bar:SetWidth(18)
    bar:SetPoint("BOTTOMLEFT", (index - 1) * 22, 0)
    bar:SetColorTexture(unpack(THEME.accent))
    panel.bars[index] = bar

    local label = plot:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("TOP", bar, "BOTTOM", 0, -2)
    label:SetTextColor(unpack(THEME.textDim))
    label:SetText("")
    panel.labels[index] = label
  end

  return panel
end

local function UpdateHistoryChart(panel, history)
  if not panel or not panel.bars then
    return
  end

  history = history or {}
  local maxValue = 1
  for _, entry in ipairs(history) do
    maxValue = math.max(maxValue, tonumber(entry.opportunities) or 0)
  end

  local startIndex = math.max(1, #history - 16 + 1)
  local visible = 0
  for index = startIndex, #history do
    visible = visible + 1
    local entry = history[index]
    local value = math.max(tonumber(entry.opportunities) or 0, 0)
    local height = math.max(math.floor((value / maxValue) * 92), value > 0 and 8 or 2)
    local bar = panel.bars[visible]
    local label = panel.labels[visible]
    if bar then
      bar:SetHeight(height)
      bar:SetColorTexture(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.85)
      bar:Show()
    end
    if label then
      label:SetText(tostring(value))
      label:Show()
    end
  end

  for index = visible + 1, #panel.bars do
    if panel.bars[index] then
      panel.bars[index]:Hide()
    end
    if panel.labels[index] then
      panel.labels[index]:SetText("")
      panel.labels[index]:Hide()
    end
  end

  if panel.summary then
    if #history > 0 then
      local last = history[#history]
      panel.summary:SetText(
        "Latest: " .. tostring(last.opportunities or 0) ..
        " opps | Items: " .. tostring(last.items or 0) ..
        " | Best recent: " .. tostring(maxValue)
      )
    else
      panel.summary:SetText("No scan history yet.")
    end
  end
end

function AuctionFlip.UI.InitScanSubTab(content, parentContent)
  -- Scan button
  local scanBtn = AuctionFlip.UI.CreateFlatButton(content, "Scan AH", 120, 28)
  scanBtn:SetPoint("TOPLEFT", 0, -5)
  scanBtn:SetScript("OnClick", function() AuctionFlip.Scan.Start() end)
  content.scanBtn = scanBtn

  local helpBtn = AuctionFlip.UI.CreateFlatButton(content, "Help", 70, 28)
  helpBtn:SetPoint("LEFT", scanBtn, "RIGHT", 8, 0)
  helpBtn:SetScript("OnClick", function()
    AuctionFlip.UI.ShowContextHelpWindow(
      "scan_tab",
      "Scan Help",
      "Guide to scan modes, progress indicators and dashboard panels.",
      SCAN_HELP_TEXT,
      AuctionFlip.UI.Frame,
      560,
      500
    )
  end)
  content.helpBtn = helpBtn
  
  -- Cancel button
  local cancelBtn = AuctionFlip.UI.CreateFlatButton(content, "Cancel", 80, 28)
  cancelBtn:SetPoint("LEFT", helpBtn, "RIGHT", 8, 0)
  cancelBtn:SetScript("OnClick", function() AuctionFlip.Scan.Cancel() end)
  cancelBtn:Hide()
  content.cancelBtn = cancelBtn
  
  -- Status bar
  local statusBar = CreateFrame("StatusBar", nil, content, "BackdropTemplate")
  statusBar:SetSize(200, 12)
  statusBar:SetPoint("LEFT", cancelBtn, "RIGHT", 15, 0)
  statusBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
  statusBar:SetStatusBarColor(unpack(THEME.gold))
  statusBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
  statusBar:SetBackdropColor(0.1, 0.1, 0.15, 0.8)
  statusBar:Hide()
  content.statusBar = statusBar
  
  local statusText = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  statusText:SetPoint("LEFT", statusBar, "RIGHT", 10, 0)
  statusText:SetWidth(250)
  statusText:SetJustifyH("LEFT")
  statusText:SetText("")
  content.statusText = statusText
  
  -- Mode selector
  local modeLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  modeLabel:SetPoint("TOPLEFT", scanBtn, "BOTTOMLEFT", 0, -12)
  modeLabel:SetText("Scan Mode:")
  modeLabel:SetTextColor(unpack(THEME.textDim))
  
  local modeBtn1 = AuctionFlip.UI.CreateFlatButton(content, "Single", 70, 22)
  modeBtn1:SetPoint("LEFT", modeLabel, "RIGHT", 8, 0)
  
  local modeBtn2 = AuctionFlip.UI.CreateFlatButton(content, "Continuous", 92, 22)
  modeBtn2:SetPoint("LEFT", modeBtn1, "RIGHT", 4, 0)
  
  local modeBtn3 = AuctionFlip.UI.CreateFlatButton(content, "Retry If 0", 84, 22)
  modeBtn3:SetPoint("LEFT", modeBtn2, "RIGHT", 4, 0)
  
  content.modeButtons = {modeBtn1, modeBtn2, modeBtn3}
  
  modeBtn1:SetScript("OnClick", function()
    AuctionFlip.Config.Set("scan_mode", "single")
    AuctionFlip.UI.UpdateModeButtons(content)
  end)
  modeBtn2:SetScript("OnClick", function()
    AuctionFlip.Config.Set("scan_mode", "continuous")
    AuctionFlip.UI.UpdateModeButtons(content)
  end)
  modeBtn3:SetScript("OnClick", function()
    AuctionFlip.Config.Set("scan_mode", "until_opportunities")
    AuctionFlip.UI.UpdateModeButtons(content)
  end)
  
  AuctionFlip.UI.UpdateModeButtons(content)
  
  -- Quick stats
  local quickStats = CreateDashboardPanel(content, 370, 88, "Scan Snapshot")
  quickStats:SetPoint("TOPLEFT", modeLabel, "BOTTOMLEFT", 0, -12)
  
  quickStats.oppCount = CreateDashboardStat(quickStats, "Opportunities", 12, -28, 150)
  quickStats.totalProfit = CreateDashboardStat(quickStats, "Total Profit", 12, -54, 150)
  quickStats.itemsScanned = CreateDashboardStat(quickStats, "Items Scanned", 190, -28, 150)
  quickStats.lastScan = CreateDashboardStat(quickStats, "Last Scan", 190, -54, 150)
  content.quickStats = quickStats

  local sessionPanel = CreateDashboardPanel(content, 500, 88, "Session Statistics")
  sessionPanel:SetPoint("TOPLEFT", quickStats, "TOPRIGHT", 10, 0)
  sessionPanel.totalProfit = CreateDashboardStat(sessionPanel, "Total Profit", 12, -28, 115)
  sessionPanel.totalFlips = CreateDashboardStat(sessionPanel, "Total Flips", 132, -28, 100)
  sessionPanel.successRate = CreateDashboardStat(sessionPanel, "Success Rate", 250, -28, 110)
  sessionPanel.avgProfit = CreateDashboardStat(sessionPanel, "Avg Profit", 370, -28, 110)
  sessionPanel.scansCompleted = CreateDashboardStat(sessionPanel, "Scans", 12, -54, 115)
  sessionPanel.bestScan = CreateDashboardStat(sessionPanel, "Best Scan", 132, -54, 100)
  sessionPanel.avgOpps = CreateDashboardStat(sessionPanel, "Avg Opp/Scan", 250, -54, 110)
  sessionPanel.lastItems = CreateDashboardStat(sessionPanel, "Last Items", 370, -54, 110)
  content.sessionPanel = sessionPanel

  local chartPanel = CreateHistoryChart(content, "Recent Scan Opportunities")
  chartPanel:SetSize(880, 170)
  chartPanel:SetPoint("TOPLEFT", quickStats, "BOTTOMLEFT", 0, -12)
  content.scanChartPanel = chartPanel

  local infoPanel = CreateDashboardPanel(content, 880, 130, "Scan Activity")
  infoPanel:SetPoint("TOPLEFT", chartPanel, "BOTTOMLEFT", 0, -12)

  local infoText = infoPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  infoText:SetPoint("TOPLEFT", 10, -28)
  infoText:SetPoint("RIGHT", infoPanel, "RIGHT", -10, 0)
  infoText:SetJustifyH("LEFT")
  infoText:SetJustifyV("TOP")
  infoText:SetText(
    "Choose a scan mode and click Scan AH.\n" ..
    "Continuous keeps cycling automatically based on your rescan interval.\n" ..
    "Retry If 0 repeats until opportunities are found.\n" ..
    "Use Results to inspect candidates and Buy Confirmation to validate tier strategy."
  )
  infoText:SetTextColor(unpack(THEME.textDim))
  content.scanInfoText = infoText

  local resetBtn = AuctionFlip.UI.CreateFlatButton(infoPanel, "Reset Statistics", 130, 24)
  resetBtn:SetPoint("BOTTOMRIGHT", -10, 10)
  resetBtn:SetScript("OnClick", function()
    AuctionFlip.Stats.Reset()
    AuctionFlip.UI.RefreshStats()
  end)
  content.scanResetStatsBtn = resetBtn
end

function AuctionFlip.UI.InitResultsSubTab(content)
  -- Top bar: filters + risk profile + sort
  local topBar = CreateFrame("Frame", nil, content)
  topBar:SetHeight(24)
  topBar:SetPoint("TOPLEFT", 0, 0)
  topBar:SetPoint("TOPRIGHT", -4, 0)

  -- Filter buttons
  local filters = {
    {text = "All", filter = "all"},
    {text = "Vendor Flip", filter = "vendor_flip"},
    {text = "Underpriced", filter = "underpriced"},
  }

  content.filterButtons = {}
  for i, f in ipairs(filters) do
    local btn = AuctionFlip.UI.CreateFlatButton(topBar, f.text, 80, 22)
    if i == 1 then
      btn:SetPoint("LEFT", 0, 0)
    else
      btn:SetPoint("LEFT", content.filterButtons[i-1], "RIGHT", 5, 0)
    end
    btn.filterValue = f.filter
    btn:SetScript("OnClick", function()
      AuctionFlip.UI.CurrentFilter = f.filter
      AuctionFlip.UI.UpdateFilterButtons(content)
      AuctionFlip.UI.RefreshResults()
    end)
    content.filterButtons[i] = btn
  end

  -- Risk profile selector
  local profileLabel = topBar:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  profileLabel:SetPoint("LEFT", content.filterButtons[#content.filterButtons], "RIGHT", 15, 0)
  profileLabel:SetText("Risk:")
  profileLabel:SetTextColor(unpack(THEME.textDim))

  local profiles = {
    {text = "Safe", value = "conservative"},
    {text = "Balanced", value = "balanced"},
    {text = "Aggro", value = "aggressive"},
  }

  content.profileButtons = {}
  for i, p in ipairs(profiles) do
    local btn = AuctionFlip.UI.CreateFlatButton(topBar, p.text, 60, 22)
    if i == 1 then
      btn:SetPoint("LEFT", profileLabel, "RIGHT", 5, 0)
    else
      btn:SetPoint("LEFT", content.profileButtons[i-1], "RIGHT", 3, 0)
    end
    btn.profileValue = p.value
    btn:SetScript("OnClick", function()
      AuctionFlip.Config.Set("risk_profile", p.value)
      AuctionFlip.UI.UpdateProfileButtons(content)
      AuctionFlip.UI.SetActivityMessage("Risk profile: " .. p.text .. " | Rebuilding opportunities...")
      AuctionFlip.Utilities.Print("Risk profile set to " .. p.text .. ". Rebuilding opportunities...")
      -- Re-analyze with new profile
      AuctionFlip.Opportunities.Detect(nil)
    end)
    content.profileButtons[i] = btn
  end

  -- Results count
  local countText = topBar:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  countText:SetPoint("LEFT", content.profileButtons[#content.profileButtons], "RIGHT", 10, 0)
  countText:SetWidth(90)
  countText:SetJustifyH("LEFT")
  countText:SetText("0 items")
  countText:SetTextColor(unpack(THEME.textDim))
  content.countText = countText

  content.buyOneBtn = AuctionFlip.UI.CreateFlatButton(topBar, "Buy 1", 64, 22)
  content.buyOneBtn:SetPoint("RIGHT", topBar, "RIGHT", -70, 0)
  content.buyOneBtn:SetScript("OnClick", function()
    AuctionFlip.UI.BuySelectedOpportunity("single")
  end)

  content.buyAllBtn = AuctionFlip.UI.CreateFlatButton(topBar, "Buy All", 64, 22)
  content.buyAllBtn:SetPoint("LEFT", content.buyOneBtn, "RIGHT", 4, 0)
  content.buyAllBtn:SetScript("OnClick", function()
    AuctionFlip.UI.BuySelectedOpportunity("all")
  end)

  content.helpBtn = AuctionFlip.UI.CreateFlatButton(topBar, "Help", 60, 22)
  content.helpBtn:SetPoint("RIGHT", content.buyOneBtn, "LEFT", -8, 0)
  content.helpBtn:SetScript("OnClick", function()
    AuctionFlip.UI.ShowResultsHelpWindow()
  end)

  countText:ClearAllPoints()
  countText:SetPoint("RIGHT", content.helpBtn, "LEFT", -10, 0)
  countText:SetWidth(90)
  countText:SetJustifyH("RIGHT")

  local activityText = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  activityText:SetPoint("TOPLEFT", topBar, "BOTTOMLEFT", 2, -3)
  activityText:SetPoint("TOPRIGHT", topBar, "BOTTOMRIGHT", -4, -3)
  activityText:SetJustifyH("LEFT")
  activityText:SetTextColor(unpack(THEME.textDim))
  activityText:SetText("")
  content.activityText = activityText

  -- Results scroll background
  local scrollBg = CreateFrame("Frame", nil, content, "BackdropTemplate")
  scrollBg:SetPoint("TOPLEFT", activityText, "BOTTOMLEFT", -2, -3)
  scrollBg:SetPoint("BOTTOMRIGHT", -2, 30)
  scrollBg:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
  })
  scrollBg:SetBackdropColor(0.02, 0.02, 0.04, 0.8)
  scrollBg:SetBackdropBorderColor(0.2, 0.2, 0.25, 0.5)

  -- Column header background
  local headerBg = CreateFrame("Frame", nil, scrollBg)
  headerBg:SetHeight(20)
  headerBg:SetPoint("TOPLEFT", 1, -1)
  headerBg:SetPoint("TOPRIGHT", -1, -1)
  headerBg.header = headerBg:CreateTexture(nil, "BACKGROUND")
  headerBg.header:SetAllPoints()
  headerBg.header:SetColorTexture(0.1, 0.1, 0.14, 0.9)

  -- Column definitions with sort keys
  local headers = {
    {text = "Item",      width = 224, x = 8,   sortKey = nil},
    {text = "Type",      width = 84,  x = 238, sortKey = nil},
    {text = "Buy",       width = 76,  x = 326, sortKey = nil},
    {text = "Sell",      width = 82,  x = 406, sortKey = nil},
    {text = "Qty",       width = 54,  x = 492, sortKey = nil},
    {text = "Disc",      width = 48,  x = 550, sortKey = "discount"},
    {text = "Net",       width = 94,  x = 602, sortKey = "netProfit"},
    {text = "ROI%",      width = 50,  x = 700, sortKey = "roi"},
    {text = "Liq.",      width = 42,  x = 754, sortKey = "liquidity"},
    {text = "Conf",      width = 48,  x = 800, sortKey = "confidence"},
  }

  content.headerButtons = {}
  for _, h in ipairs(headers) do
    if h.sortKey then
      local btn = CreateFrame("Button", nil, headerBg)
      btn:SetPoint("LEFT", headerBg, "LEFT", h.x, 0)
      btn:SetSize(h.width, 20)
      local txt = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
      txt:SetAllPoints()
      txt:SetJustifyH("LEFT")
      txt:SetText(h.text)
      txt:SetTextColor(unpack(THEME.gold))
      ApplyNeonFont(txt, 10, "")
      btn.sortKey = h.sortKey
      btn:SetScript("OnClick", function()
        local current = AuctionFlip.Config.Get("results_sort_field")
        if current == h.sortKey then
          AuctionFlip.Config.Set("results_sort_ascending", not AuctionFlip.Config.Get("results_sort_ascending"))
        else
          AuctionFlip.Config.Set("results_sort_field", h.sortKey)
          AuctionFlip.Config.Set("results_sort_ascending", false)
        end
        AuctionFlip.Opportunities.SortList(AuctionFlip.Opportunities.List)
        AuctionFlip.UI.RefreshResults()
      end)
      btn:SetScript("OnEnter", function() txt:SetTextColor(1, 1, 1) end)
      btn:SetScript("OnLeave", function() txt:SetTextColor(unpack(THEME.gold)) end)
      content.headerButtons[h.sortKey] = btn
    else
      local text = headerBg:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
      text:SetPoint("LEFT", headerBg, "LEFT", h.x, 0)
      text:SetWidth(h.width)
      text:SetJustifyH("LEFT")
      text:SetText(h.text)
      text:SetTextColor(unpack(THEME.gold))
      ApplyNeonFont(text, 10, "")
    end
  end

  -- Scroll frame
  local scrollFrame = CreateFrame("ScrollFrame", "AuctionFlipResultsScroll", scrollBg, "FauxScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", 2, -22)
  scrollFrame:SetPoint("BOTTOMRIGHT", -1, 2)
  content.scrollFrame = scrollFrame

  -- Result rows (with new columns)
  content.resultRows = {}
  for i = 1, 12 do
    local row = CreateFrame("Button", nil, scrollBg)
    row:SetHeight(22)
    row:SetPoint("TOPLEFT", 1, -22 - (i-1) * 22)
    row:SetPoint("TOPRIGHT", -1, 0)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0, 0, 0, 0)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", 4, 0)

    row.nameText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
    row.nameText:SetWidth(218)
    row.nameText:SetJustifyH("LEFT")

    row.typeText = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.typeText:SetPoint("LEFT", row, "LEFT", 238, 0)
    row.typeText:SetWidth(84)

    row.buyText = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.buyText:SetPoint("LEFT", row, "LEFT", 326, 0)
    row.buyText:SetWidth(76)
    row.buyText:SetJustifyH("RIGHT")

    row.sellText = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.sellText:SetPoint("LEFT", row, "LEFT", 406, 0)
    row.sellText:SetWidth(82)
    row.sellText:SetJustifyH("RIGHT")

    row.qtyText = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.qtyText:SetPoint("LEFT", row, "LEFT", 492, 0)
    row.qtyText:SetWidth(54)
    row.qtyText:SetJustifyH("RIGHT")

    row.discountText = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.discountText:SetPoint("LEFT", row, "LEFT", 550, 0)
    row.discountText:SetWidth(48)
    row.discountText:SetJustifyH("RIGHT")

    row.netProfitText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.netProfitText:SetPoint("LEFT", row, "LEFT", 602, 0)
    row.netProfitText:SetWidth(94)
    row.netProfitText:SetJustifyH("RIGHT")

    row.roiText = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.roiText:SetPoint("LEFT", row, "LEFT", 700, 0)
    row.roiText:SetWidth(50)
    row.roiText:SetJustifyH("RIGHT")

    row.liqText = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.liqText:SetPoint("LEFT", row, "LEFT", 754, 0)
    row.liqText:SetWidth(42)
    row.liqText:SetJustifyH("CENTER")

    row.confText = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.confText:SetPoint("LEFT", row, "LEFT", 800, 0)
    row.confText:SetWidth(48)
    row.confText:SetJustifyH("RIGHT")

    row:Hide()
    content.resultRows[i] = row
  end

  -- Total profit bar
  local totalBg = CreateFrame("Frame", nil, content, "BackdropTemplate")
  totalBg:SetHeight(24)
  totalBg:SetPoint("BOTTOMLEFT", 0, 0)
  totalBg:SetPoint("BOTTOMRIGHT", 0, 0)
  totalBg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
  totalBg:SetBackdropColor(0.06, 0.06, 0.09, 0.8)

  local totalLabel = totalBg:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  totalLabel:SetPoint("LEFT", 10, 0)
  totalLabel:SetText("Total Net Profit:")
  totalLabel:SetTextColor(unpack(THEME.textDim))

  local totalValue = totalBg:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  totalValue:SetPoint("LEFT", totalLabel, "RIGHT", 10, 0)
  totalValue:SetTextColor(unpack(THEME.green))
  content.totalProfitDisplay = totalValue

  AuctionFlip.UI.CurrentFilter = "all"
  AuctionFlip.UI.UpdateFilterButtons(content)
  AuctionFlip.UI.UpdateProfileButtons(content)
  if content.buyOneBtn then
    content.buyOneBtn:Disable()
  end
  if content.buyAllBtn then
    content.buyAllBtn:Disable()
  end
end

function AuctionFlip.UI.InitStatsSubTab(content)
  local statsFrame = CreateDashboardPanel(content, 430, 128, "Session Statistics")
  statsFrame:SetPoint("TOPLEFT", 0, -8)
  statsFrame.totalProfit = CreateDashboardStat(statsFrame, "Total Profit", 12, -30, 120)
  statsFrame.totalFlips = CreateDashboardStat(statsFrame, "Total Flips", 152, -30, 90)
  statsFrame.successRate = CreateDashboardStat(statsFrame, "Success Rate", 262, -30, 120)
  statsFrame.avgProfit = CreateDashboardStat(statsFrame, "Avg Profit", 12, -64, 120)
  statsFrame.scansCompleted = CreateDashboardStat(statsFrame, "Scans Completed", 152, -64, 90)
  statsFrame.bestFlip = CreateDashboardStat(statsFrame, "Best Scan", 262, -64, 120)

  local insightPanel = CreateDashboardPanel(content, 438, 128, "Scan Insights")
  insightPanel:SetPoint("TOPLEFT", statsFrame, "TOPRIGHT", 12, 0)
  insightPanel.lastScan = CreateDashboardStat(insightPanel, "Last Scan", 12, -30, 140)
  insightPanel.lastItems = CreateDashboardStat(insightPanel, "Last Items", 170, -30, 100)
  insightPanel.lastOpps = CreateDashboardStat(insightPanel, "Last Opps", 290, -30, 100)
  insightPanel.avgOpps = CreateDashboardStat(insightPanel, "Avg Opp/Scan", 12, -64, 140)
  insightPanel.bestOpps = CreateDashboardStat(insightPanel, "Best Opps", 170, -64, 100)
  insightPanel.historyPoints = CreateDashboardStat(insightPanel, "History Points", 290, -64, 100)
  content.insightPanel = insightPanel

  local chartPanel = CreateHistoryChart(content, "Recent Opportunities History")
  chartPanel:SetSize(880, 220)
  chartPanel:SetPoint("TOPLEFT", statsFrame, "BOTTOMLEFT", 0, -14)
  content.statsChartPanel = chartPanel

  local resetBtn = AuctionFlip.UI.CreateFlatButton(content, "Reset Statistics", 130, 26)
  resetBtn:SetPoint("TOPLEFT", chartPanel, "BOTTOMLEFT", 0, -14)
  resetBtn:SetScript("OnClick", function()
    AuctionFlip.Stats.Reset()
    AuctionFlip.UI.RefreshStats()
  end)
  
  content.statsFrame = statsFrame
end

function AuctionFlip.UI.InitSellingTab(content)
  local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  title:SetPoint("TOPLEFT", 0, -5)
  title:SetText("Selling")
  title:SetTextColor(unpack(THEME.gold))

  local helpBtn = AuctionFlip.UI.CreateFlatButton(content, "Help", 70, 24)
  helpBtn:SetPoint("TOPRIGHT", content, "TOPRIGHT", -4, -4)
  helpBtn:SetScript("OnClick", function()
    AuctionFlip.UI.ShowContextHelpWindow(
      "selling_tab",
      "Selling Help",
      "Guide to the portfolio selling list and repost workflow.",
      SELLING_HELP_TEXT,
      AuctionFlip.UI.Frame,
      560,
      480
    )
  end)
  content.helpBtn = helpBtn

  local refreshBtn = AuctionFlip.UI.CreateFlatButton(content, "Refresh Market", 120, 24)
  refreshBtn:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  refreshBtn:SetScript("OnClick", function()
    AuctionFlip.Portfolio.UpdateSelectedMarket(function()
      AuctionFlip.UI.RefreshSelling()
    end)
  end)
  content.refreshBtn = refreshBtn

  local sellOneBtn = AuctionFlip.UI.CreateFlatButton(content, "Sell 1", 90, 24)
  sellOneBtn:SetPoint("LEFT", refreshBtn, "RIGHT", 8, 0)
  sellOneBtn:SetScript("OnClick", function()
    AuctionFlip.UI.OpenSellConfirmation("single")
  end)
  sellOneBtn:Disable()
  content.sellOneBtn = sellOneBtn

  local sellAllBtn = AuctionFlip.UI.CreateFlatButton(content, "Sell All", 90, 24)
  sellAllBtn:SetPoint("LEFT", sellOneBtn, "RIGHT", 8, 0)
  sellAllBtn:SetScript("OnClick", function()
    AuctionFlip.UI.OpenSellConfirmation("all")
  end)
  sellAllBtn:Disable()
  content.sellAllBtn = sellAllBtn

  local infoText = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  infoText:SetPoint("LEFT", sellAllBtn, "RIGHT", 12, 0)
  infoText:SetPoint("RIGHT", content, "RIGHT", -4, 0)
  infoText:SetJustifyH("LEFT")
  infoText:SetText("Select an item, refresh AH min, then open Sell 1 or Sell All confirmation.")
  infoText:SetTextColor(unpack(THEME.textDim))
  content.sellingInfoText = infoText

  local listBg = CreateFrame("Frame", nil, content, "BackdropTemplate")
  listBg:SetPoint("TOPLEFT", refreshBtn, "BOTTOMLEFT", 0, -8)
  listBg:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
  listBg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8" })
  listBg:SetBackdropColor(0.02, 0.02, 0.04, 0.8)
  listBg:SetBackdropBorderColor(0.18, 0.18, 0.24, 0.55)

  local header = CreateFrame("Frame", nil, listBg)
  header:SetPoint("TOPLEFT", 1, -1)
  header:SetPoint("TOPRIGHT", -25, -1)
  header:SetHeight(20)
  header.bg = header:CreateTexture(nil, "BACKGROUND")
  header.bg:SetAllPoints()
  header.bg:SetColorTexture(0.1, 0.1, 0.14, 0.9)

  local columns = {
    { text = "Item", x = 8, width = 220 },
    { text = "Bags", x = 240, width = 40 },
    { text = "Buy", x = 286, width = 72 },
    { text = "Suggested", x = 364, width = 90 },
    { text = "AH Min", x = 460, width = 80 },
    { text = "Status", x = 546, width = 150 },
  }
  for _, col in ipairs(columns) do
    local fs = header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    fs:SetPoint("LEFT", header, "LEFT", col.x, 0)
    fs:SetWidth(col.width)
    fs:SetJustifyH("LEFT")
    fs:SetText(col.text)
    fs:SetTextColor(unpack(THEME.gold))
  end

  local scroll = CreateFrame("ScrollFrame", "AuctionFlipSellingScroll", listBg, "FauxScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 2, -22)
  scroll:SetPoint("BOTTOMRIGHT", -26, 2)
  content.sellingScrollFrame = scroll
  content.sellingRows = {}

  for i = 1, 11 do
    local row = CreateFrame("Button", nil, listBg)
    row:SetHeight(22)
    row:SetPoint("TOPLEFT", 1, -22 - (i - 1) * 22)
    row:SetPoint("TOPRIGHT", -25, 0)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0, 0, 0, 0)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", 4, 0)

    row.itemText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.itemText:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.itemText:SetWidth(206)
    row.itemText:SetJustifyH("LEFT")

    row.bagsText = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.bagsText:SetPoint("LEFT", row, "LEFT", 240, 0)
    row.bagsText:SetWidth(40)

    row.buyText = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.buyText:SetPoint("LEFT", row, "LEFT", 286, 0)
    row.buyText:SetWidth(72)
    row.buyText:SetJustifyH("RIGHT")

    row.suggestedText = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.suggestedText:SetPoint("LEFT", row, "LEFT", 364, 0)
    row.suggestedText:SetWidth(90)
    row.suggestedText:SetJustifyH("RIGHT")

    row.minText = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.minText:SetPoint("LEFT", row, "LEFT", 460, 0)
    row.minText:SetWidth(80)
    row.minText:SetJustifyH("RIGHT")

    row.statusText = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.statusText:SetPoint("LEFT", row, "LEFT", 546, 0)
    row.statusText:SetWidth(146)
    row.statusText:SetJustifyH("LEFT")

    row:Hide()
    content.sellingRows[i] = row
  end
end

local CHANGELOG_TEXT = [[
v0.3.17
- Added contextual Help buttons for Scan, Selling, Settings and Sell Confirmation
- Help UX now covers the addon's main workflows before release

v0.3.16
- Buy Confirmation now includes a Help modal explaining market, execution, profit and analysis blocks

v0.3.15
- Results tab now has a Help modal explaining filters, risk profiles, columns, sorting and buy actions

v0.3.14
- Buy modal now centers on AuctionFlip window
- Scan tab now includes session stats and recent scan history chart
- Stats tab upgraded into a dashboard with historical chart

v0.3.13
- Buy modal layout anchored and narrowed so right-side panels stay inside bounds

v0.3.12
- Buy modal spacing fixed so strategy notes no longer overlap action buttons

v0.3.11
- Buy modal now reuses opportunity-card analysis metrics
- Item header now shows icon, rarity color and native tooltip on hover

v0.3.10
- Buy modal now uses colored strategy panels
- Stronger visual emphasis on Next tier and Est. net for speculation decisions

v0.3.9
- Buy modal redesigned into structured strategy sections
- Cheapest-tier quantity / rows / seller visibility added to buy confirmation
- Buy strategy explanation now highlights next-tier resale rule

v0.3.8
- Wider Opportunities results grid with less truncation
- Buy modal now shows cheapest listing, highest bought tier, next higher tier and pricing rule
- Resale rule messaging clarified: next higher AH tier first, history only as fallback/cap

v0.3.7
- Sell modal now shows "Last AH min update" timestamp (time + age)

v0.3.6
- Fixed Cheapest AH listing for commodity items in Sell modal
- Added "Refresh AH Min" button in Sell confirmation
- Market refresh now checks item + commodity listings and uses best unit price

v0.3.5
- Sell modal centered on AuctionFlip window
- Editable sell unit price + "Use Suggested"
- Live AH min + fee/deposit/cost basis + net profit in sell confirmation
- Auto-recalc on duration change and periodic market refresh
- Loss warning when configured sell price goes negative

v0.3.4
- Realistic buy preview: AH fee + deposit + duration model (12/24/48h)
- Verification now respects full item auction rows (no partial stack assumption)
- Better quantity/profit plan quality on non-commodity listings

v0.3.3
- Multi-tier listing verification strategy for opportunities
- Execution sell target uses undercut of next listing tier
- Buy actions now target only qualifying cheap tiers
- New scanning option: Opportunity Duration model

v0.3.2
- Selling actions: Sell 1 / Sell All with confirmation modal
- Suggested price, duration, deposit and total displayed before posting
- Settings button to toggle Debug ON/OFF
- Portfolio purchase deduplication and quantity merge

v0.3.1
- Selling and About tabs restored
- Buy 1 / Buy All actions in Opportunities
- No-competitor rule for Buy All
- Theme selector (blue/green/red neon)
- Compact list values and safer text fitting

v0.3.0
- Neon UI and advanced results analysis
- Risk profiles and confidence/liquidity metrics
- Guided selling and market refresh tools
- Buy workflow improvements (single/all)

v0.2.0
- Auction House integration and scanning engine
- Price history and opportunity detection

v0.1.0
- Initial addon structure and core modules
]]

local RESULTS_HELP_TEXT = [[
RESULTS OVERVIEW
The Results tab is the core decision screen for AuctionFlip speculation. It shows the opportunities that survived your current scan, risk profile and pricing rules.

FILTER BUTTONS
All
- Shows every opportunity currently in memory.

Vendor Flip
- Shows opportunities whose profit logic includes vendor value as a reference or floor.

Underpriced
- Shows items currently listed below the level that our market model considers profitable.

RISK PROFILES
Safe
- Tighter filters. Tends to prefer stronger confidence, cleaner margins and better liquidity.

Balanced
- Middle ground profile. Good default for regular flipping.

Aggro
- More permissive profile. Surfaces more speculative opportunities, usually with more volatility or slower movement.

COUNT
- Displays how many items match the active filter + active risk profile.

BUY ACTIONS
Buy 1
- Opens a confirmation modal for a single qualifying listing or stack.
- Best when you want to probe a market with lower exposure.

Buy All
- Attempts to buy all cheap qualifying listings that still fit the strategy.
- It should target only the profitable cheap tier(s), not every listing in the market.

COLUMN GUIDE
Item
- Item icon and item name.
- Hovering the row shows a richer tooltip with market and strategy context.

Type
- Opportunity family such as Underpriced or Vendor Flip.

Buy
- Current buy entry price used by the strategy.
- This should reflect the cheapest valid listing/tier the addon intends to attack.

Sell
- Expected execution sell price.
- This is not the most expensive listing in the market.
- It should usually be anchored to the first price tier above what we buy, or use historical fallback logic when live competition is insufficient.

Qty
- Estimated quantity available in the cheap qualifying tier(s).
- Useful to judge whether Buy All is realistic and how much capital the move may consume.

Disc
- Discount versus the market reference used by the scoring engine.
- Higher discount means the current buy is further below the reference market price.

Net
- Estimated net profit after cost basis and modeled AH costs.
- Usually the main "money made" column.

ROI%%
- Return on investment percentage.
- Great for efficiency, but do not read it alone. A very high ROI can still mean low absolute profit.

Liq.
- Liquidity estimate.
- H = higher chance to move quickly.
- M = moderate liquidity.
- L = slower market and usually higher repost risk.

Conf
- Confidence in the dataset and pricing model.
- Higher confidence means AuctionFlip trusts the historical/live evidence more.

SORTING
You can click these headers to sort:
- Disc
- Net
- ROI%%
- Liq.
- Conf

Clicking the same header again reverses the sorting direction.

BUSINESS LOGIC BEHIND RESULTS
AuctionFlip is built for real AH speculation:
- It evaluates the cheapest listing(s) first.
- If multiple cheap listings exist, it measures that cheap tier and its quantity.
- The expected resale point should come from the first tier above what we buy.
- Historical data helps as confirmation, fallback or cap logic. It should not be used to invent unrealistic profits when live AH competition disagrees.

HOW TO READ THE SCREEN WELL
- Prefer opportunities with a good balance of Net, ROI, Liquidity and Confidence.
- Use Buy 1 when confidence is lower, liquidity is weaker or the market looks unstable.
- Use Buy All when the cheap tier is small enough to clear and the next tier still leaves healthy profit after fees.
- Always read Qty before buying aggressively, so you understand the capital required and the stock you may need to repost.
]]

local BUY_CONFIRM_HELP_TEXT = [[
BUY CONFIRMATION OVERVIEW
This modal is the final strategy checkpoint before AuctionFlip submits the purchase. It summarizes what we are buying, why it qualifies, how we expect to resell it and the estimated net result.

HEADER
Item
- The item you are about to buy.

Action
- Shows whether this is Buy 1 or Buy All.

Source
- Tells you whether the market data comes from commodity listings or regular item listings.

Listing rows loaded
- Number of AH rows the addon loaded while validating this market.

MARKET SNAPSHOT
Cheapest
- Lowest unit price currently seen in the validated listings.

Tier qty
- Total quantity available at that exact cheapest price.
- This is critical because the strategy often starts by clearing the cheapest tier.

Tier rows
- Number of separate AH rows listed at the cheapest price.
- More rows often means more fragmented supply.

Sellers
- Number of distinct sellers at the cheapest tier, when the AH exposes seller identity.
- Commodity markets may show anonymous market behavior instead.

Highest buy
- Highest unit price among the listings we plan to buy in this action.
- If buying multiple cheap rows, this shows the top price we still accept inside the buy plan.

Next tier
- First unit price above what we are buying.
- This is one of the most important values in the modal because it usually anchors the resale strategy.

Rule
- Explains which pricing rule generated the resale assumption.
- In normal flipping, the addon should prefer the first tier above what we buy.
- Historical pricing is support or fallback, not fantasy pricing.

EXECUTION PLAN
Buy qty
- Quantity the current action intends to purchase.

Avg buy
- Average unit price across the selected listings.

Total cost
- Total copper/gold spent if this purchase is executed.

Max buy / unit
- Highest unit price this opportunity is allowed to pay while still matching the strategy.
- Listings above this threshold should not be included.

Exec sell
- Planned resale unit price used by the model.
- This should usually be tied to the next tier above our purchased listings.

Duration
- Auction duration used for deposit modeling on the expected resale.

Rows used
- Number of selected rows contributing to this buy plan.

PROFIT ESTIMATE
AH fee
- Estimated Auction House cut applied on resale.

Deposit
- Estimated posting deposit for the modeled resale duration.

Est. net
- Estimated net result after buy cost, AH fee and deposit.
- This is the clearest “will this flip make money?” number in the modal.

ITEM ANALYSIS
Discount
- How far below the market reference the current buy opportunity is.

ROI
- Estimated return on investment for the flip.

Liquidity
- Expected ease of resale.
- High liquidity usually means easier turnover.

Confidence
- Strength of the available evidence supporting the market estimate.
- Higher confidence generally means better historical/live support.

STRATEGY NOTE
The note at the bottom explains the logic in plain language:
- buy the cheapest qualifying tier(s),
- then reprice against the first meaningful tier above what we bought,
- while respecting fees, deposit and confidence.

HOW TO USE THIS MODAL WELL
- Focus first on Next tier and Est. net.
- Use Tier qty and Tier rows to understand how much cheap supply exists.
- If Sellers is fragmented, the market may refill quickly.
- Use Buy 1 when confidence is lower or the tier is large and uncertain.
- Use Buy All only when clearing the cheap tier still leaves enough margin at the next tier.
]]

local SCAN_HELP_TEXT = [[
SCAN OVERVIEW
The Scan tab is where you control AuctionFlip's market discovery cycle.

SCAN AH
- Starts the scan using the currently selected scan mode.

CANCEL
- Stops the current scan or verification cycle.

STATUS BAR
- Shows progress while the scan is running.
- Useful to confirm that the addon is actively processing the market.

SCAN MODES
Single
- Runs one complete scan cycle and stops.

Continuous
- Keeps scanning again after the configured rescan interval.
- Best for actively watching the market while standing at the Auction House.

Retry If 0
- Repeats scans until at least one opportunity is found.
- Useful when the market is thin and you want the addon to keep looking.

SCAN SNAPSHOT
- Shows the latest quick picture of opportunities, projected profit, scanned items and last scan time.

SESSION STATISTICS
- Summarizes your current session performance, including flips, scans and average outcomes.

RECENT SCAN OPPORTUNITIES
- Historical chart of recent scan results.
- Helps you see whether the market is getting richer or drying up.

SCAN ACTIVITY
- Live guidance and operational state of the current scan flow.

BEST PRACTICE
- Use Single for controlled checks.
- Use Continuous for live sniping/speculation sessions.
- If disconnects ever become a concern, tune browse throttle and rescan interval in Settings > Scanning.
]]

local SELLING_HELP_TEXT = [[
SELLING OVERVIEW
The Selling tab is where AuctionFlip helps you repost items you already bought.

REFRESH MARKET
- Refreshes the current AH minimum for the selected item.
- Important before posting, because the market may have changed since the item was purchased.

SELL 1
- Opens the sell confirmation for one unit or one selected stack plan.

SELL ALL
- Opens the sell confirmation using the maximum quantity that AuctionFlip currently considers ready to post.

TABLE COLUMNS
Item
- Item currently tracked in your portfolio.

Bags
- Quantity currently found in your bags.
- If Bags is 0, the item was tracked before but is not currently available to post.

Buy
- Your recorded purchase price basis.

Suggested
- AuctionFlip's suggested resale unit price based on strategy and live/historical signals.

AH Min
- Current minimum market price seen for the item.

Status
- Tells you whether the item is ready to sell, missing from bags, or needs market refresh attention.

HOW TO USE
- Select an item.
- Refresh AH min.
- Open Sell 1 or Sell All.
- Confirm duration, price and estimated net inside the sell modal before posting.
]]

local SETTINGS_GENERAL_HELP_TEXT = [[
GENERAL SETTINGS OVERVIEW
These settings control your core profitability filters and market-quality rules.

Diagnostics
- Toggle debug logs when you need to understand scan, buy or sell behavior more deeply.

Profit Rules
- Min Profit: minimum net profit required before an opportunity appears.
- Max Profit: hides unrealistic outliers or suspicious extremes.
- AH Cut: commission percentage used in profit modeling.

Opportunity Filters
- Min ROI: requires a minimum return on invested gold.
- Min Discount: requires the buy price to sit enough below the market reference.
- Min Volume / Day: removes extremely slow-moving items.

Market Analysis
- Confidence Min: minimum trust required in the dataset.
- Market Samples: minimum historical samples required.
- Market Window: how many days of price history are considered.

Category Filters
- Lets you limit the addon to specific classes of items and markets.
- Useful if you want to specialize in materials, consumables, recipes or transmog.
]]

local SETTINGS_SCANNING_HELP_TEXT = [[
SCANNING SETTINGS OVERVIEW
These settings control how aggressively AuctionFlip scans and verifies the Auction House.

Verification Strategy
- Verify Candidates: enables deeper validation before surfacing opportunities.
- Max Verified: maximum number of candidates that get verified per cycle.

Request Pacing
- Browse Throttle: delay between browse requests.
- Rescan Interval: wait time before continuous mode starts again.
- Opportunity Duration: auction duration used when modeling deposits and expected net.

Capital Controls
- Reserve Capital: percent of your gold that stays protected and should not be spent.
- Per-Item Cap: max share of spendable capital allowed for a single item.

WHY THIS MATTERS
- Higher verification improves quality but can be slower.
- Lower throttle is faster but can be riskier for stability.
- Strong capital controls protect you from overcommitting to one bad market.
]]

local SETTINGS_DISPLAY_HELP_TEXT = [[
DISPLAY SETTINGS OVERVIEW
These settings control how AuctionFlip looks and feels.

Theme
- Lets you switch between the neon accent variants supported by the addon.

Visual toggles
- Controls cosmetic and presentation preferences where available.

GOAL
- Keep readability high while matching your preferred neon style for long AH sessions.
]]

local SELL_CONFIRM_HELP_TEXT = [[
SELL CONFIRMATION OVERVIEW
This modal is the final review before posting an auction.

Item / Mode
- Shows what you are about to sell and whether this is Sell 1 or Sell All.

Duration
- Selects 12h, 24h or 48h posting duration.
- Duration affects deposit cost.

Sell / unit
- Editable target price per unit.
- You can override the suggested price if you want tighter control.

Use Suggested
- Restores AuctionFlip's current suggested sell price.

Quantity to post
- Quantity that this action intends to list.

Cheapest AH listing
- Lowest competing listing currently known.
- This is essential when deciding whether your sell price is still competitive.

Last AH min update
- Timestamp of the latest market refresh used by this modal.

Deposit
- Estimated deposit for posting the auction at the selected duration.

AH fee
- Estimated Auction House cut taken on a successful sale.

Cost basis
- Your recorded purchase cost for the posted quantity.

Total buyout
- Gross sale revenue if the auction sells at the configured price.

Estimated net profit
- Expected result after subtracting AH fee, deposit and purchase cost.

WARNING AREA
- Alerts you when the configured price may create a loss or when the market moved against your plan.

BEST PRACTICE
- Refresh AH min before posting.
- Watch the timestamp.
- If the cheapest listing moved down, reconsider your price before confirming.
]]

function AuctionFlip.UI.ShowChangelogWindow()
  if AuctionFlip.UI.ChangelogWindow and AuctionFlip.UI.ChangelogWindow:IsShown() then
    AuctionFlip.UI.ChangelogWindow:Hide()
    return
  end

  if not AuctionFlip.UI.ChangelogWindow then
    local win = CreateFrame("Frame", "AuctionFlipChangelogWindow", UIParent, "BackdropTemplate")
    win:SetSize(500, 360)
    win:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    win:SetFrameStrata("TOOLTIP")
    win:SetFrameLevel((AuctionFlip.UI.Frame and AuctionFlip.UI.Frame:GetFrameLevel() or 100) + 80)
    win:SetToplevel(true)
    win:EnableMouse(true)
    win:SetMovable(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", function(self) self:StartMoving() end)
    win:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    win:SetScript("OnMouseDown", function(self) self:Raise() end)
    win:SetClampedToScreen(true)
    win:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    win:SetBackdropColor(0.03, 0.03, 0.05, 0.98)
    win:SetBackdropBorderColor(unpack(THEME.border))

    local title = win:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("AuctionFlip Changelog")
    title:SetTextColor(unpack(THEME.gold))

    local close = AuctionFlip.UI.CreateFlatButton(win, "Close", 70, 22)
    close:SetPoint("TOPRIGHT", -10, -8)
    close:SetScript("OnClick", function() win:Hide() end)

    local scroll = CreateFrame("ScrollFrame", nil, win, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -34)
    scroll:SetPoint("BOTTOMRIGHT", -28, 12)

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(440, 1)
    scroll:SetScrollChild(child)

    local body = child:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    body:SetPoint("TOPLEFT", 0, 0)
    body:SetWidth(430)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetText(CHANGELOG_TEXT)
    body:SetTextColor(unpack(THEME.text))

    child:SetHeight(math.max(body:GetStringHeight() + 16, 320))
    win.body = body
    AuctionFlip.UI.ChangelogWindow = win
  end

  AuctionFlip.UI.ChangelogWindow:Show()
  AuctionFlip.UI.ChangelogWindow:Raise()
end

function AuctionFlip.UI.ShowResultsHelpWindow()
  if AuctionFlip.UI.ResultsHelpWindow and AuctionFlip.UI.ResultsHelpWindow:IsShown() then
    AuctionFlip.UI.ResultsHelpWindow:Hide()
    return
  end

  if not AuctionFlip.UI.ResultsHelpWindow then
    local host = AuctionFlip.UI.Frame or UIParent
    local win = CreateFrame("Frame", "AuctionFlipResultsHelpWindow", UIParent, "BackdropTemplate")
    win:SetSize(560, 520)
    win:SetPoint("CENTER", host, "CENTER", 0, 0)
    win:SetFrameStrata("TOOLTIP")
    win:SetFrameLevel((host:GetFrameLevel() or 100) + 80)
    win:SetToplevel(true)
    win:EnableMouse(true)
    win:SetMovable(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", function(self) self:StartMoving() end)
    win:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    win:SetScript("OnMouseDown", function(self) self:Raise() end)
    win:SetClampedToScreen(true)
    win:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    win:SetBackdropColor(0.03, 0.03, 0.05, 0.98)
    win:SetBackdropBorderColor(unpack(THEME.border))

    local title = win:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText("Results Help")
    title:SetTextColor(unpack(THEME.gold))
    ApplyNeonFont(title, 13, "OUTLINE")

    local subtitle = win:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    subtitle:SetPoint("TOPRIGHT", win, "TOPRIGHT", -40, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText("Reference guide for columns, filters, risk profiles, sorting and buy actions.")
    subtitle:SetTextColor(unpack(THEME.textDim))

    local closeX = AuctionFlip.UI.CreateFlatButton(win, "X", 24, 22)
    closeX:SetPoint("TOPRIGHT", -8, -8)
    closeX:SetScript("OnClick", function() win:Hide() end)

    local body = CreateFrame("Frame", nil, win, "BackdropTemplate")
    body:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -10)
    body:SetPoint("BOTTOMRIGHT", -12, 42)
    body:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    body:SetBackdropColor(0.04, 0.04, 0.07, 0.92)
    body:SetBackdropBorderColor(THEME.borderLight[1], THEME.borderLight[2], THEME.borderLight[3], 0.32)

    local scroll = CreateFrame("ScrollFrame", "AuctionFlipResultsHelpScroll", body, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -10)
    scroll:SetPoint("BOTTOMRIGHT", -28, 10)

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(500, 1)
    scroll:SetScrollChild(child)

    local text = child:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", 0, 0)
    text:SetWidth(494)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetSpacing(4)
    text:SetTextColor(unpack(THEME.text))
    text:SetText(RESULTS_HELP_TEXT)
    child.text = text

    local closeBtn = AuctionFlip.UI.CreateFlatButton(win, "Close", 90, 24)
    closeBtn:SetPoint("BOTTOMRIGHT", -12, 12)
    closeBtn:SetScript("OnClick", function() win:Hide() end)

    win:SetScript("OnShow", function(self)
      self:ClearAllPoints()
      self:SetPoint("CENTER", AuctionFlip.UI.Frame or UIParent, "CENTER", 0, 0)
      child:SetHeight(math.max((child.text:GetStringHeight() or 0) + 16, 460))
      scroll:SetVerticalScroll(0)
    end)

    AuctionFlip.UI.ResultsHelpWindow = win
  end

  AuctionFlip.UI.ResultsHelpWindow:Show()
  AuctionFlip.UI.ResultsHelpWindow:Raise()
end

function AuctionFlip.UI.ShowBuyConfirmationHelpWindow()
  if AuctionFlip.UI.BuyConfirmHelpWindow and AuctionFlip.UI.BuyConfirmHelpWindow:IsShown() then
    AuctionFlip.UI.BuyConfirmHelpWindow:Hide()
    return
  end

  if not AuctionFlip.UI.BuyConfirmHelpWindow then
    local host = AuctionFlip.UI.BuyConfirmWindow or AuctionFlip.UI.Frame or UIParent
    local win = CreateFrame("Frame", "AuctionFlipBuyConfirmHelpWindow", UIParent, "BackdropTemplate")
    win:SetSize(560, 540)
    win:SetPoint("CENTER", host, "CENTER", 0, 0)
    win:SetFrameStrata("TOOLTIP")
    win:SetFrameLevel((host:GetFrameLevel() or 100) + 20)
    win:SetToplevel(true)
    win:EnableMouse(true)
    win:SetMovable(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", function(self) self:StartMoving() end)
    win:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    win:SetScript("OnMouseDown", function(self) self:Raise() end)
    win:SetClampedToScreen(true)
    win:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    win:SetBackdropColor(0.03, 0.03, 0.05, 0.98)
    win:SetBackdropBorderColor(unpack(THEME.border))

    local title = win:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText("Buy Confirmation Help")
    title:SetTextColor(unpack(THEME.gold))
    ApplyNeonFont(title, 13, "OUTLINE")

    local subtitle = win:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    subtitle:SetPoint("TOPRIGHT", win, "TOPRIGHT", -40, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText("Guide to every block, metric and strategy signal shown before confirming a buy.")
    subtitle:SetTextColor(unpack(THEME.textDim))

    local closeX = AuctionFlip.UI.CreateFlatButton(win, "X", 24, 22)
    closeX:SetPoint("TOPRIGHT", -8, -8)
    closeX:SetScript("OnClick", function() win:Hide() end)

    local body = CreateFrame("Frame", nil, win, "BackdropTemplate")
    body:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -10)
    body:SetPoint("BOTTOMRIGHT", -12, 42)
    body:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    body:SetBackdropColor(0.04, 0.04, 0.07, 0.92)
    body:SetBackdropBorderColor(THEME.borderLight[1], THEME.borderLight[2], THEME.borderLight[3], 0.32)

    local scroll = CreateFrame("ScrollFrame", "AuctionFlipBuyConfirmHelpScroll", body, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -10)
    scroll:SetPoint("BOTTOMRIGHT", -28, 10)

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(500, 1)
    scroll:SetScrollChild(child)

    local text = child:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", 0, 0)
    text:SetWidth(494)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetSpacing(4)
    text:SetTextColor(unpack(THEME.text))
    text:SetText(BUY_CONFIRM_HELP_TEXT)
    child.text = text

    local closeBtn = AuctionFlip.UI.CreateFlatButton(win, "Close", 90, 24)
    closeBtn:SetPoint("BOTTOMRIGHT", -12, 12)
    closeBtn:SetScript("OnClick", function() win:Hide() end)

    win:SetScript("OnShow", function(self)
      local currentHost = AuctionFlip.UI.BuyConfirmWindow or AuctionFlip.UI.Frame or UIParent
      self:ClearAllPoints()
      self:SetPoint("CENTER", currentHost, "CENTER", 0, 0)
      child:SetHeight(math.max((child.text:GetStringHeight() or 0) + 16, 480))
      scroll:SetVerticalScroll(0)
    end)

    AuctionFlip.UI.BuyConfirmHelpWindow = win
  end

  AuctionFlip.UI.BuyConfirmHelpWindow:Show()
  AuctionFlip.UI.BuyConfirmHelpWindow:Raise()
end

function AuctionFlip.UI.ShowContextHelpWindow(cacheKey, titleText, subtitleText, bodyText, hostFrame, width, height)
  AuctionFlip.UI.ContextHelpWindows = AuctionFlip.UI.ContextHelpWindows or {}

  local win = AuctionFlip.UI.ContextHelpWindows[cacheKey]
  if win and win:IsShown() then
    win:Hide()
    return
  end

  if not win then
    local host = hostFrame or AuctionFlip.UI.Frame or UIParent
    win = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    win:SetSize(width or 560, height or 500)
    win:SetPoint("CENTER", host, "CENTER", 0, 0)
    win:SetFrameStrata("TOOLTIP")
    win:SetFrameLevel((host:GetFrameLevel() or 100) + 20)
    win:SetToplevel(true)
    win:EnableMouse(true)
    win:SetMovable(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", function(self) self:StartMoving() end)
    win:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    win:SetScript("OnMouseDown", function(self) self:Raise() end)
    win:SetClampedToScreen(true)
    win:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    win:SetBackdropColor(0.03, 0.03, 0.05, 0.98)
    win:SetBackdropBorderColor(unpack(THEME.border))

    local title = win:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetTextColor(unpack(THEME.gold))
    ApplyNeonFont(title, 13, "OUTLINE")
    win.title = title

    local subtitle = win:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    subtitle:SetPoint("TOPRIGHT", win, "TOPRIGHT", -40, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetTextColor(unpack(THEME.textDim))
    win.subtitle = subtitle

    local closeX = AuctionFlip.UI.CreateFlatButton(win, "X", 24, 22)
    closeX:SetPoint("TOPRIGHT", -8, -8)
    closeX:SetScript("OnClick", function() win:Hide() end)

    local body = CreateFrame("Frame", nil, win, "BackdropTemplate")
    body:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -10)
    body:SetPoint("BOTTOMRIGHT", -12, 42)
    body:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    body:SetBackdropColor(0.04, 0.04, 0.07, 0.92)
    body:SetBackdropBorderColor(THEME.borderLight[1], THEME.borderLight[2], THEME.borderLight[3], 0.32)

    local scroll = CreateFrame("ScrollFrame", nil, body, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -10)
    scroll:SetPoint("BOTTOMRIGHT", -28, 10)

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize((width or 560) - 66, 1)
    scroll:SetScrollChild(child)

    local text = child:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", 0, 0)
    text:SetWidth((width or 560) - 72)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetSpacing(4)
    text:SetTextColor(unpack(THEME.text))
    child.text = text
    win.bodyText = text
    win.scrollChild = child
    win.scroll = scroll

    local closeBtn = AuctionFlip.UI.CreateFlatButton(win, "Close", 90, 24)
    closeBtn:SetPoint("BOTTOMRIGHT", -12, 12)
    closeBtn:SetScript("OnClick", function() win:Hide() end)

    win:SetScript("OnShow", function(self)
      local currentHost = self.hostFrame or AuctionFlip.UI.Frame or UIParent
      self:ClearAllPoints()
      self:SetPoint("CENTER", currentHost, "CENTER", 0, 0)
      self.scrollChild:SetHeight(math.max((self.bodyText:GetStringHeight() or 0) + 16, 420))
      self.scroll:SetVerticalScroll(0)
    end)

    AuctionFlip.UI.ContextHelpWindows[cacheKey] = win
  end

  win.hostFrame = hostFrame or AuctionFlip.UI.Frame or UIParent
  win.title:SetText(titleText or "Help")
  win.subtitle:SetText(subtitleText or "")
  win.bodyText:SetText(bodyText or "")
  win:Show()
  win:Raise()
end

function AuctionFlip.UI.InitAboutTab(content)
  local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 0, -8)
  title:SetText("About AuctionFlip")
  title:SetTextColor(unpack(THEME.gold))

  local ver = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  ver:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -14)
  ver:SetText("Version: v" .. AuctionFlip.Utilities.GetAddonVersion())
  ver:SetTextColor(unpack(THEME.text))

  local dev = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  dev:SetPoint("TOPLEFT", ver, "BOTTOMLEFT", 0, -8)
  dev:SetText("Developer: Trithon")
  dev:SetTextColor(unpack(THEME.text))

  local desc = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  desc:SetPoint("TOPLEFT", dev, "BOTTOMLEFT", 0, -14)
  desc:SetPoint("RIGHT", content, "RIGHT", -8, 0)
  desc:SetJustifyH("LEFT")
  desc:SetJustifyV("TOP")
  desc:SetText("AuctionFlip scans the AH, identifies profitable flips, supports smart selling actions, and helps you manage risk by confidence, ROI and liquidity.")
  desc:SetTextColor(unpack(THEME.textDim))

  local changelogBtn = AuctionFlip.UI.CreateFlatButton(content, "Open Changelog", 130, 24)
  changelogBtn:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)
  changelogBtn:SetScript("OnClick", function()
    AuctionFlip.UI.ShowChangelogWindow()
  end)
end

function AuctionFlip.UI.InitSettingsTab(content)
  content.subTabs = {}
  content.subTabContents = {}
  
  local subNames = {"General", "Scanning", "Display"}
  
  for i, name in ipairs(subNames) do
    local subTab = CreateFrame("Button", nil, content)
    subTab:SetSize(80, 20)
    if i == 1 then
      subTab:SetPoint("TOPLEFT", 0, 0)
    else
      subTab:SetPoint("LEFT", content.subTabs[i-1], "RIGHT", 5, 0)
    end
    
    subTab.text = subTab:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    subTab.text:SetPoint("CENTER")
    subTab.text:SetText(name)
    ApplyNeonFont(subTab.text, 11, "")
    
    subTab.line = subTab:CreateTexture(nil, "ARTWORK")
    subTab.line:SetPoint("BOTTOMLEFT")
    subTab.line:SetPoint("BOTTOMRIGHT")
    subTab.line:SetHeight(1)
    
    subTab:SetScript("OnClick", function()
      AuctionFlip.UI.SelectSubTab(content, i)
    end)
    
    content.subTabs[i] = subTab
    
    local subContent = CreateFrame("Frame", nil, content)
    subContent:SetAllPoints()
    subContent:SetPoint("TOPLEFT", 0, -25)
    subContent:SetPoint("BOTTOMRIGHT", 0, 0)
    subContent:Hide()
    content.subTabContents[i] = subContent
  end
  
  AuctionFlip.UI.InitGeneralSettings(content.subTabContents[1])
  AuctionFlip.UI.InitScanningSettings(content.subTabContents[2])
  AuctionFlip.UI.InitDisplaySettings(content.subTabContents[3])
  
  AuctionFlip.UI.SelectSubTab(content, 1)
end

function AuctionFlip.UI.InitGeneralSettings(content)
  local bg = CreateFrame("Frame", nil, content, "BackdropTemplate")
  bg:SetPoint("TOPLEFT", 8, -8)
  bg:SetPoint("BOTTOMRIGHT", -8, 8)
  bg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8" })
  bg:SetBackdropColor(0.02, 0.02, 0.04, 0.55)
  bg:SetBackdropBorderColor(0.12, 0.12, 0.18, 0.45)

  local scrollFrame = CreateFrame("ScrollFrame", "AuctionFlipSettingsGeneralScroll", content, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", bg, "TOPLEFT", 10, -10)
  scrollFrame:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", -28, 10)
  local scrollChild = CreateFrame("Frame", nil, scrollFrame)
  scrollChild:SetSize(840, 1)
  scrollFrame:SetScrollChild(scrollChild)
  content.scrollChild = scrollChild

  local topTitle = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  topTitle:SetPoint("TOPLEFT", 6, -4)
  topTitle:SetText("General Settings")
  topTitle:SetTextColor(unpack(THEME.gold))
  ApplyNeonFont(topTitle, 14, "OUTLINE")

  local helpBtn = AuctionFlip.UI.CreateFlatButton(scrollChild, "Help", 70, 22)
  helpBtn:SetPoint("TOPRIGHT", -18, -2)
  helpBtn:SetScript("OnClick", function()
    AuctionFlip.UI.ShowContextHelpWindow(
      "settings_general",
      "General Settings Help",
      "Explanation of diagnostics, profit rules, market filters and category controls.",
      SETTINGS_GENERAL_HELP_TEXT,
      AuctionFlip.UI.Frame,
      560,
      480
    )
  end)
  content.helpBtn = helpBtn

  local topSubtitle = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  topSubtitle:SetPoint("TOPLEFT", topTitle, "BOTTOMLEFT", 0, -4)
  topSubtitle:SetText("Profit rules, market filters and diagnostics used by opportunity scoring.")
  topSubtitle:SetTextColor(unpack(THEME.textDim))

  local currentAnchor = topSubtitle

  local function CreateCard(title, subtitle, height)
    local card = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
    card:SetPoint("TOPLEFT", currentAnchor, "BOTTOMLEFT", 0, -14)
    card:SetSize(814, height)
    card:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    card:SetBackdropColor(0.04, 0.04, 0.07, 0.82)
    card:SetBackdropBorderColor(THEME.borderLight[1], THEME.borderLight[2], THEME.borderLight[3], 0.32)

    local header = card:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", 16, -12)
    header:SetText(title)
    header:SetTextColor(unpack(THEME.accentText))
    ApplyNeonFont(header, 12, "OUTLINE")

    if subtitle then
      local help = card:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
      help:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
      help:SetPoint("TOPRIGHT", card, "TOPRIGHT", -16, 0)
      help:SetJustifyH("LEFT")
      help:SetText(subtitle)
      help:SetTextColor(unpack(THEME.textDim))
      card.help = help
    end

    currentAnchor = card
    return card
  end

  local function CreateRow(parent, index, label, description)
    local row = CreateFrame("Frame", nil, parent)
    local topOffset = -42 - ((index - 1) * 42)
    row:SetPoint("TOPLEFT", 14, topOffset)
    row:SetPoint("TOPRIGHT", -14, topOffset)
    row:SetHeight(36)

    if index > 1 then
      local divider = row:CreateTexture(nil, "ARTWORK")
      divider:SetPoint("TOPLEFT", 0, 8)
      divider:SetPoint("TOPRIGHT", 0, 8)
      divider:SetHeight(1)
      divider:SetColorTexture(1, 1, 1, 0.05)
    end

    row.label = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.label:SetPoint("TOPLEFT", 10, -8)
    row.label:SetText(label)
    row.label:SetTextColor(unpack(THEME.text))
    ApplyNeonFont(row.label, 11, "")

    row.desc = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.desc:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -2)
    row.desc:SetWidth(470)
    row.desc:SetJustifyH("LEFT")
    row.desc:SetText(description or "")
    row.desc:SetTextColor(unpack(THEME.textDim))

    row.controlAnchor = CreateFrame("Frame", nil, row)
    row.controlAnchor:SetPoint("RIGHT", -10, 0)
    row.controlAnchor:SetSize(240, 28)

    return row
  end

  local function FormatSettingValue(value, unit)
    if unit == "gold" then
      return AuctionFlip.Utilities.CreatePaddedMoneyString(math.max(math.floor(tonumber(value) or 0), 0))
    end
    return tostring(value) .. (unit or "")
  end

  local function AddStepper(row, key, min, max, step, unit)
    local valueText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    valueText:SetPoint("RIGHT", row.controlAnchor, "RIGHT", -62, 0)
    valueText:SetWidth(124)
    valueText:SetJustifyH("RIGHT")
    valueText:SetTextColor(unpack(THEME.accentText))
    ApplyNeonFont(valueText, 12, "OUTLINE")

    local minus = AuctionFlip.UI.CreateFlatButton(row, "-", 26, 22)
    minus:SetPoint("RIGHT", valueText, "LEFT", -8, 0)

    local plus = AuctionFlip.UI.CreateFlatButton(row, "+", 26, 22)
    plus:SetPoint("LEFT", valueText, "RIGHT", 8, 0)

    local function Refresh()
      local raw = AuctionFlip.Config.Get(key)
      if raw == nil then
        raw = min
      end
      valueText:SetText(FormatSettingValue(raw, unit))
    end

    minus:SetScript("OnClick", function()
      local value = tonumber(AuctionFlip.Config.Get(key))
      if value == nil then value = min end
      value = math.max(min, value - step)
      AuctionFlip.Config.Set(key, value)
      Refresh()
    end)

    plus:SetScript("OnClick", function()
      local value = tonumber(AuctionFlip.Config.Get(key))
      if value == nil then value = min end
      value = math.min(max, value + step)
      AuctionFlip.Config.Set(key, value)
      Refresh()
    end)

    Refresh()
  end

  local function AddToggle(row, key, onLabel, offLabel)
    local btn = AuctionFlip.UI.CreateFlatButton(row, "", 122, 22)
    btn:SetPoint("RIGHT", row.controlAnchor, "RIGHT", 0, 0)

    local function Refresh()
      local enabled = AuctionFlip.Config.Get(key) and true or false
      btn.text:SetText(enabled and onLabel or offLabel)
      btn._isActive = enabled
      if btn._paint then
        btn._paint(btn, false, false)
      end
    end

    btn:SetScript("OnClick", function()
      local newValue = not (AuctionFlip.Config.Get(key) and true or false)
      AuctionFlip.Config.Set(key, newValue)
      Refresh()
      if key == "debug" then
        AuctionFlip.Utilities.Print("Debug mode " .. (newValue and "enabled." or "disabled."))
      end
    end)

    Refresh()
  end

  local function AddCheckboxRow(row, key)
    local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    cb:SetPoint("RIGHT", row.controlAnchor, "RIGHT", -2, 0)
    cb:SetChecked(AuctionFlip.Config.Get(key) and true or false)
    cb:SetScript("OnClick", function(self)
      AuctionFlip.Config.Set(key, self:GetChecked() and true or false)
    end)
  end

  local diagnosticsCard = CreateCard("Diagnostics", "Quick controls for troubleshooting and addon behavior visibility.", 96)
  AddToggle(CreateRow(diagnosticsCard, 1, "Addon Debug", "Enables chat/debug traces for scans, pricing and purchase flows."), "debug", "Debug ON", "Debug OFF")

  local profitCard = CreateCard("Profit Rules", "Hard limits used before an item can even qualify as a flip.", 170)
  AddStepper(CreateRow(profitCard, 1, "Min Profit", "Minimum net profit required for an opportunity to appear."), "profit_threshold", 1000, 1000000, 10000, "gold")
  AddStepper(CreateRow(profitCard, 2, "Max Profit", "Upper cap to hide outliers. Use 0 to effectively allow any ceiling."), "max_profit_threshold", 0, 10000000, 100000, "gold")
  AddStepper(CreateRow(profitCard, 3, "AH Cut", "Auction House commission used in estimated resale profit."), "ah_cut_percent", 0, 20, 1, "%")

  local filtersCard = CreateCard("Opportunity Filters", "Quality gates that keep low-conviction or slow-moving items out of the list.", 170)
  AddStepper(CreateRow(filtersCard, 1, "Min ROI", "Required return on investment after fees and deposits."), "min_roi_percent", 0, 200, 5, "%")
  AddStepper(CreateRow(filtersCard, 2, "Min Discount", "Discount versus market estimate needed before we consider buying."), "min_discount_percent", 0, 80, 5, "%")
  AddStepper(CreateRow(filtersCard, 3, "Min Volume / Day", "Minimum estimated daily volume to avoid illiquid flips."), "min_volume_per_day", 0, 500, 10, "")

  local analysisCard = CreateCard("Market Analysis", "Dataset confidence thresholds that drive our pricing and scoring model.", 170)
  AddStepper(CreateRow(analysisCard, 1, "Confidence Min", "Required dataset confidence before a market price is trusted."), "min_confidence_percent", 0, 100, 5, "%")
  AddStepper(CreateRow(analysisCard, 2, "Market Samples", "Minimum number of stored price points required for analysis."), "min_market_samples", 3, 50, 1, "")
  AddStepper(CreateRow(analysisCard, 3, "Market Window", "Historical window used to assemble market samples."), "market_window_days", 3, 30, 1, "d")

  local categoriesCard = CreateCard("Category Filters", "Choose which item classes are allowed into the opportunity engine.", 364)
  AddCheckboxRow(CreateRow(categoriesCard, 1, "Enable Category Filter", "Turn on class filtering to limit scans to selected markets."), "category_filter_enabled")
  AddCheckboxRow(CreateRow(categoriesCard, 2, "Consumables", "Food, potions and other consumable-driven opportunities."), "category_filter_consumable")
  AddCheckboxRow(CreateRow(categoriesCard, 3, "Tradeskill Materials", "Herbs, ore, cloth, leather and other crafting supplies."), "category_filter_tradeskill")
  AddCheckboxRow(CreateRow(categoriesCard, 4, "Recipes", "Patterns, plans, recipes and teachable unlock items."), "category_filter_recipe")
  AddCheckboxRow(CreateRow(categoriesCard, 5, "Gems", "Gems and socketable commodity opportunities."), "category_filter_gem")
  AddCheckboxRow(CreateRow(categoriesCard, 6, "Enhancements", "Enchants, kits, oils and comparable enhancement items."), "category_filter_enhancement")
  AddCheckboxRow(CreateRow(categoriesCard, 7, "Armor (Transmog)", "Armor pieces considered mainly for appearance resale."), "category_filter_armor")
  AddCheckboxRow(CreateRow(categoriesCard, 8, "Weapons (Transmog)", "Weapon appearance flips and collectible weapon listings."), "category_filter_weapon")
  AddCheckboxRow(CreateRow(categoriesCard, 9, "Miscellaneous", "Catch-all class group for special or irregular markets."), "category_filter_misc")

  scrollChild:SetHeight(1120)
end

function AuctionFlip.UI.InitScanningSettings(content)
  local bg = CreateFrame("Frame", nil, content, "BackdropTemplate")
  bg:SetPoint("TOPLEFT", 8, -8)
  bg:SetPoint("BOTTOMRIGHT", -8, 8)
  bg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8" })
  bg:SetBackdropColor(0.02, 0.02, 0.04, 0.55)
  bg:SetBackdropBorderColor(0.12, 0.12, 0.18, 0.45)

  local scrollFrame = CreateFrame("ScrollFrame", "AuctionFlipSettingsScanningScroll", content, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", bg, "TOPLEFT", 10, -10)
  scrollFrame:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", -28, 10)
  local scrollChild = CreateFrame("Frame", nil, scrollFrame)
  scrollChild:SetSize(840, 1)
  scrollFrame:SetScrollChild(scrollChild)

  local title = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  title:SetPoint("TOPLEFT", 6, -4)
  title:SetText("Scanning Settings")
  title:SetTextColor(unpack(THEME.gold))
  ApplyNeonFont(title, 14, "OUTLINE")

  local helpBtn = AuctionFlip.UI.CreateFlatButton(scrollChild, "Help", 70, 22)
  helpBtn:SetPoint("TOPRIGHT", -18, -2)
  helpBtn:SetScript("OnClick", function()
    AuctionFlip.UI.ShowContextHelpWindow(
      "settings_scanning",
      "Scanning Settings Help",
      "Explanation of verification depth, pacing and capital-protection settings.",
      SETTINGS_SCANNING_HELP_TEXT,
      AuctionFlip.UI.Frame,
      560,
      460
    )
  end)
  content.helpBtn = helpBtn

  local subtitle = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  subtitle:SetText("Tune verification depth, request pacing and capital exposure during active scans.")
  subtitle:SetTextColor(unpack(THEME.textDim))

  local currentAnchor = subtitle

  local function CreateCard(titleText, subtitleText, height)
    local card = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
    card:SetPoint("TOPLEFT", currentAnchor, "BOTTOMLEFT", 0, -14)
    card:SetSize(814, height)
    card:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    card:SetBackdropColor(0.04, 0.04, 0.07, 0.82)
    card:SetBackdropBorderColor(THEME.borderLight[1], THEME.borderLight[2], THEME.borderLight[3], 0.32)

    local header = card:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", 16, -12)
    header:SetText(titleText)
    header:SetTextColor(unpack(THEME.accentText))
    ApplyNeonFont(header, 12, "OUTLINE")

    if subtitleText then
      local help = card:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
      help:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
      help:SetPoint("TOPRIGHT", card, "TOPRIGHT", -16, 0)
      help:SetJustifyH("LEFT")
      help:SetText(subtitleText)
      help:SetTextColor(unpack(THEME.textDim))
    end

    currentAnchor = card
    return card
  end

  local function CreateRow(parent, index, label, description)
    local row = CreateFrame("Frame", nil, parent)
    local topOffset = -42 - ((index - 1) * 42)
    row:SetPoint("TOPLEFT", 14, topOffset)
    row:SetPoint("TOPRIGHT", -14, topOffset)
    row:SetHeight(36)

    if index > 1 then
      local divider = row:CreateTexture(nil, "ARTWORK")
      divider:SetPoint("TOPLEFT", 0, 8)
      divider:SetPoint("TOPRIGHT", 0, 8)
      divider:SetHeight(1)
      divider:SetColorTexture(1, 1, 1, 0.05)
    end

    row.label = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.label:SetPoint("TOPLEFT", 10, -8)
    row.label:SetText(label)
    row.label:SetTextColor(unpack(THEME.text))
    ApplyNeonFont(row.label, 11, "")

    row.desc = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.desc:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -2)
    row.desc:SetWidth(470)
    row.desc:SetJustifyH("LEFT")
    row.desc:SetText(description or "")
    row.desc:SetTextColor(unpack(THEME.textDim))

    row.controlAnchor = CreateFrame("Frame", nil, row)
    row.controlAnchor:SetPoint("RIGHT", -10, 0)
    row.controlAnchor:SetSize(240, 28)

    return row
  end

  local function AddStepper(row, key, min, max, step, unit)
    local valueText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    valueText:SetPoint("RIGHT", row.controlAnchor, "RIGHT", -62, 0)
    valueText:SetWidth(124)
    valueText:SetJustifyH("RIGHT")
    valueText:SetTextColor(unpack(THEME.accentText))
    ApplyNeonFont(valueText, 12, "OUTLINE")

    local minus = AuctionFlip.UI.CreateFlatButton(row, "-", 26, 22)
    minus:SetPoint("RIGHT", valueText, "LEFT", -8, 0)

    local plus = AuctionFlip.UI.CreateFlatButton(row, "+", 26, 22)
    plus:SetPoint("LEFT", valueText, "RIGHT", 8, 0)

    local function Refresh()
      local value = tonumber(AuctionFlip.Config.Get(key))
      if value == nil then
        value = min
      end
      valueText:SetText(tostring(value) .. (unit or ""))
    end

    minus:SetScript("OnClick", function()
      local value = tonumber(AuctionFlip.Config.Get(key))
      if value == nil then value = min end
      value = math.max(min, value - step)
      AuctionFlip.Config.Set(key, value)
      Refresh()
    end)

    plus:SetScript("OnClick", function()
      local value = tonumber(AuctionFlip.Config.Get(key))
      if value == nil then value = min end
      value = math.min(max, value + step)
      AuctionFlip.Config.Set(key, value)
      Refresh()
    end)

    Refresh()
  end

  local function AddCheckboxRow(row, key)
    local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    cb:SetPoint("RIGHT", row.controlAnchor, "RIGHT", -2, 0)
    cb:SetChecked(AuctionFlip.Config.Get(key) and true or false)
    cb:SetScript("OnClick", function(self)
      AuctionFlip.Config.Set(key, self:GetChecked() and true or false)
    end)
  end

  local strategyCard = CreateCard("Verification Strategy", "Control how aggressively we validate candidate listings before presenting them.", 128)
  AddCheckboxRow(CreateRow(strategyCard, 1, "Verify Candidates", "Run deeper listing checks before promoting an item into opportunities."), "verify_candidates")
  AddStepper(CreateRow(strategyCard, 2, "Max Verified", "Maximum number of top candidates to validate in each verification pass."), "max_verified_candidates", 1, 50, 1, "")

  local pacingCard = CreateCard("Request Pacing", "Throttle browse traffic so scans remain stable and reduce disconnect risk.", 170)
  AddStepper(CreateRow(pacingCard, 1, "Browse Throttle", "Delay between browse requests during category/full scans."), "browse_request_throttle_ms", 100, 2000, 50, "ms")
  AddStepper(CreateRow(pacingCard, 2, "Rescan Interval", "Delay before continuous mode starts a fresh market cycle."), "rescan_interval_seconds", 5, 120, 5, "s")
  AddStepper(CreateRow(pacingCard, 3, "Opportunity Duration", "Auction duration used when estimating deposits and sell-side net profit."), "opportunity_target_duration_hours", 12, 48, 12, "h")

  local capitalCard = CreateCard("Capital Controls", "Risk controls to keep enough gold reserved and limit oversized item exposure.", 128)
  AddStepper(CreateRow(capitalCard, 1, "Reserve Capital", "Percentage of your available gold that must remain untouched."), "capital_reserve_percent", 0, 80, 5, "%")
  AddStepper(CreateRow(capitalCard, 2, "Per-Item Cap", "Maximum percentage of free capital that can be committed to one item."), "max_capital_per_item_percent", 5, 50, 5, "%")

  scrollChild:SetHeight(640)
end

function AuctionFlip.UI.InitDisplaySettings(content)
  local y = -10

  local helpBtn = AuctionFlip.UI.CreateFlatButton(content, "Help", 70, 22)
  helpBtn:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, -8)
  helpBtn:SetScript("OnClick", function()
    AuctionFlip.UI.ShowContextHelpWindow(
      "settings_display",
      "Display Settings Help",
      "Explanation of visual preferences and theme behavior.",
      SETTINGS_DISPLAY_HELP_TEXT,
      AuctionFlip.UI.Frame,
      540,
      360
    )
  end)

  local function AddThemeSelector(yPos)
    local lbl = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", 20, yPos)
    lbl:SetText("Theme")
    lbl:SetTextColor(unpack(THEME.gold))

    local variants = {
      { text = "Neon Blue", value = "neon_blue" },
      { text = "Neon Green", value = "neon_green" },
      { text = "Neon Red", value = "neon_red" },
    }

    local themeButtons = {}
    local function RefreshThemeButtons()
      local activeVariant = AuctionFlip.Config.Get("theme_variant") or "neon_blue"
      for _, entry in ipairs(themeButtons) do
        if entry.value == activeVariant then
          entry.button.bg:SetColorTexture(THEME.accentSoft[1], THEME.accentSoft[2], THEME.accentSoft[3], 1)
          entry.button.text:SetTextColor(1, 1, 1)
        else
          entry.button.bg:SetColorTexture(0.08, 0.08, 0.12, 0.9)
          entry.button.text:SetTextColor(unpack(THEME.accentText))
        end
      end
    end

    local prevBtn = nil
    local active = AuctionFlip.Config.Get("theme_variant") or "neon_blue"
    for i, variant in ipairs(variants) do
      local btn = AuctionFlip.UI.CreateFlatButton(content, variant.text, 100, 22)
      if i == 1 then
        btn:SetPoint("TOPLEFT", 20, yPos - 24)
      else
        btn:SetPoint("LEFT", prevBtn, "RIGHT", 6, 0)
      end
      if variant.value == active then
        btn.bg:SetColorTexture(THEME.accentSoft[1], THEME.accentSoft[2], THEME.accentSoft[3], 1)
        btn.text:SetTextColor(1, 1, 1)
      end
      btn:SetScript("OnClick", function()
        AuctionFlip.Config.Set("theme_variant", variant.value)
        AuctionFlip.UI.ApplyThemeVariant(variant.value)
        RefreshThemeButtons()
        if AuctionFlip.UI.RefreshThemeVisuals then
          AuctionFlip.UI.RefreshThemeVisuals()
        end
        AuctionFlip.Utilities.Print("Theme set to " .. variant.text .. ".")
      end)
      table.insert(themeButtons, { value = variant.value, button = btn })
      prevBtn = btn
    end
    RefreshThemeButtons()

    return yPos - 56
  end

  local function AddCheckbox(label, key, yPos)
    local cb = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 20, yPos)
    cb.Text:SetText(label)
    cb:SetChecked(AuctionFlip.Config.Get(key))
    cb:SetScript("OnClick", function(self)
      AuctionFlip.Config.Set(key, self:GetChecked())
    end)
    return yPos - 28
  end
  
  y = AddThemeSelector(y)
  y = AddCheckbox("Sound Alerts", "sound_alerts", y)
  y = AddCheckbox("Chat Notifications", "show_notifications", y)
end

-- UI HELPERS
function AuctionFlip.UI.CreateFlatButton(parent, text, width, height)
  local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
  btn:SetSize(width, height)
  btn._isActive = false
  btn._isDisabled = false
  
  btn.bg = btn:CreateTexture(nil, "BACKGROUND")
  btn.bg:SetAllPoints()
  btn.bg:SetColorTexture(0.08, 0.08, 0.12, 0.9)
  
  btn.topEdge = btn:CreateTexture(nil, "ARTWORK")
  btn.topEdge:SetPoint("TOPLEFT")
  btn.topEdge:SetPoint("TOPRIGHT")
  btn.topEdge:SetHeight(1)
  btn.topEdge:SetColorTexture(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.75)
  
  btn.bottomEdge = btn:CreateTexture(nil, "ARTWORK")
  btn.bottomEdge:SetPoint("BOTTOMLEFT")
  btn.bottomEdge:SetPoint("BOTTOMRIGHT")
  btn.bottomEdge:SetHeight(1)
  btn.bottomEdge:SetColorTexture(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.75)
  
  btn.leftEdge = btn:CreateTexture(nil, "ARTWORK")
  btn.leftEdge:SetPoint("TOPLEFT")
  btn.leftEdge:SetPoint("BOTTOMLEFT")
  btn.leftEdge:SetWidth(1)
  btn.leftEdge:SetColorTexture(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.75)
  
  btn.rightEdge = btn:CreateTexture(nil, "ARTWORK")
  btn.rightEdge:SetPoint("TOPRIGHT")
  btn.rightEdge:SetPoint("BOTTOMRIGHT")
  btn.rightEdge:SetWidth(1)
  btn.rightEdge:SetColorTexture(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.75)
  
  btn.text = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  btn.text:SetPoint("CENTER")
  btn.text:SetText(text)
  btn.text:SetTextColor(unpack(THEME.accentText))
  ApplyNeonFont(btn.text, 11, "OUTLINE")
  
  local function paint(self, hovered, pressed)
    if self._isDisabled then
      self.bg:SetColorTexture(0.05, 0.05, 0.08, 0.85)
      self.text:SetTextColor(0.40, 0.40, 0.45)
      return
    end
    if pressed then
      self.bg:SetColorTexture(THEME.accentSoft[1], THEME.accentSoft[2], THEME.accentSoft[3], 1)
      self.text:SetTextColor(1, 1, 1)
      return
    end
    if self._isActive then
      self.bg:SetColorTexture(THEME.accentSoft[1], THEME.accentSoft[2], THEME.accentSoft[3], 1)
      self.text:SetTextColor(1, 1, 1)
      return
    end
    if hovered then
      self.bg:SetColorTexture(0.12, 0.12, 0.18, 0.95)
      self.text:SetTextColor(1, 1, 1)
      return
    end
    self.bg:SetColorTexture(0.08, 0.08, 0.12, 0.9)
    self.text:SetTextColor(unpack(THEME.accentText))
  end

  btn:SetScript("OnEnter", function(self) paint(self, true, false) end)
  btn:SetScript("OnLeave", function(self) paint(self, false, false) end)
  btn:SetScript("OnMouseDown", function(self) paint(self, false, true) end)
  btn:SetScript("OnMouseUp", function(self) paint(self, true, false) end)
  btn:SetScript("OnEnable", function(self)
    self._isDisabled = false
    if self._paint then
      self._paint(self, false, false)
    end
  end)
  btn:SetScript("OnDisable", function(self)
    self._isDisabled = true
    if self._paint then
      self._paint(self, false, false)
    end
  end)
  btn._paint = paint
  btn._paint(btn, false, false)

  table.insert(AuctionFlip.UI.FlatButtons, btn)
  
  return btn
end

function AuctionFlip.UI.UpdateModeButtons(content)
  if not content.modeButtons then return end
  local mode = AuctionFlip.Config.Get("scan_mode") or "single"
  for i, btn in ipairs(content.modeButtons) do
    local isActive = (i == 1 and mode == "single") or (i == 2 and mode == "continuous") or (i == 3 and mode == "until_opportunities")
    btn._isActive = isActive
    if btn._paint then
      btn._paint(btn, false, false)
    end
  end
end

function AuctionFlip.UI.UpdateFilterButtons(content)
  if not content.filterButtons then return end
  local filter = AuctionFlip.UI.CurrentFilter or "all"
  for _, btn in ipairs(content.filterButtons) do
    btn._isActive = (btn.filterValue == filter)
    if btn._paint then
      btn._paint(btn, false, false)
    end
  end
end

function AuctionFlip.UI.UpdateProfileButtons(content)
  if not content.profileButtons then return end
  local profile = AuctionFlip.Config.Get("risk_profile") or "balanced"
  for _, btn in ipairs(content.profileButtons) do
    btn._isActive = (btn.profileValue == profile)
    if btn._paint then
      btn._paint(btn, false, false)
    end
  end
end

function AuctionFlip.UI.RefreshThemeVisuals()
  local frame = AuctionFlip.UI.Frame
  if not frame then
    return
  end

  frame:SetBackdropColor(unpack(THEME.bg))
  frame:SetBackdropBorderColor(unpack(THEME.border))

  if frame.titleText then
    frame.titleText:SetTextColor(unpack(THEME.gold))
  end
  if frame.versionText then
    frame.versionText:SetTextColor(unpack(THEME.textDim))
  end
  if frame.closeBtn and frame.closeBtn.border then
    for _, edge in pairs(frame.closeBtn.border) do
      edge:SetColorTexture(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.65)
    end
    if frame.closeBtn.text then
      frame.closeBtn.text:SetTextColor(unpack(THEME.accentText))
    end
  end

  if AuctionFlip.UI.FlatButtons then
    for _, btn in ipairs(AuctionFlip.UI.FlatButtons) do
      if btn and btn.topEdge and btn.bottomEdge and btn.leftEdge and btn.rightEdge then
        btn.topEdge:SetColorTexture(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.75)
        btn.bottomEdge:SetColorTexture(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.75)
        btn.leftEdge:SetColorTexture(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.75)
        btn.rightEdge:SetColorTexture(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.75)
      end
      if btn and btn.text then
        btn.text:SetTextColor(unpack(THEME.accentText))
      end
      if btn and btn._paint then
        btn._paint(btn, false, false)
      end
    end
  end

  AuctionFlip.UI.UpdateToggleButton()
  AuctionFlip.UI.SelectMainTab(AuctionFlip.UI.CurrentTab or 1)
  AuctionFlip.UI.RefreshResults()
  AuctionFlip.UI.RefreshStats()
  if AuctionFlip.UI.RefreshSelling then
    AuctionFlip.UI.RefreshSelling()
  end
end

function AuctionFlip.UI.SetActivityMessage(text)
  AuctionFlip.UI.ActivityMessage = text
  if not AuctionFlip.UI.Frame or not AuctionFlip.UI.Frame.mainTabContents then
    return
  end
  local content = AuctionFlip.UI.Frame.mainTabContents[1]
  if not content or not content.subTabContents then
    return
  end
  local resultsContent = content.subTabContents[2]
  if resultsContent and resultsContent.activityText then
    resultsContent.activityText:SetText(tostring(text or ""))
  end
end

local function BuildItemSearchListings(itemKey)
  if not C_AuctionHouse or not C_AuctionHouse.GetNumItemSearchResults or not C_AuctionHouse.GetItemSearchResultInfo then
    return {}
  end

  local list = {}
  local count = C_AuctionHouse.GetNumItemSearchResults(itemKey) or 0
  for index = 1, count do
    local result = C_AuctionHouse.GetItemSearchResultInfo(itemKey, index)
    local totalPrice = result and result.buyoutAmount or nil
    local qty = (result and (result.quantity or result.totalQuantity)) or 1
    qty = math.max(tonumber(qty) or 1, 1)
    local sellerToken = nil
    if result and result.owners and type(result.owners) == "table" and #result.owners > 0 then
      sellerToken = table.concat(result.owners, "|")
    elseif result and result.ownerName then
      sellerToken = tostring(result.ownerName)
    elseif result and result.owner then
      sellerToken = tostring(result.owner)
    end
    if totalPrice and totalPrice > 0 then
      table.insert(list, {
        auctionID = result.auctionID,
        buyoutAmount = totalPrice,
        totalPrice = totalPrice,
        quantity = qty,
        unitPrice = math.floor(totalPrice / qty),
        sellerToken = sellerToken,
      })
    end
  end
  table.sort(list, function(a, b) return (a.unitPrice or 0) < (b.unitPrice or 0) end)
  return list
end

local function BuildCommoditySearchListings(itemId)
  if not itemId or not C_AuctionHouse or not C_AuctionHouse.GetNumCommoditySearchResults or not C_AuctionHouse.GetCommoditySearchResultInfo then
    return {}
  end
  local list = {}
  local count = C_AuctionHouse.GetNumCommoditySearchResults(itemId) or 0
  for index = 1, count do
    local result = C_AuctionHouse.GetCommoditySearchResultInfo(itemId, index)
    local qty = math.max((result and result.quantity) or 0, 0)
    local unitPrice = result and result.unitPrice or nil
    if qty > 0 and unitPrice and unitPrice > 0 then
      table.insert(list, {
        commodity = true,
        quantity = qty,
        unitPrice = unitPrice,
        totalPrice = unitPrice * qty,
      })
    end
  end
  table.sort(list, function(a, b) return (a.unitPrice or 0) < (b.unitPrice or 0) end)
  return list
end

local function LoadListingsForOpportunity(opportunity, callback)
  if not opportunity then
    callback(false, {}, false, "No opportunity selected")
    return
  end

  if not C_AuctionHouse or not C_AuctionHouse.SendSearchQuery then
    callback(false, {}, false, "This buy flow needs modern AH API.")
    return
  end

  local itemKey = opportunity.itemKey or (opportunity.itemId and { itemID = opportunity.itemId }) or nil
  if not itemKey then
    callback(false, {}, false, "Item key not available")
    return
  end

  local okSend = pcall(C_AuctionHouse.SendSearchQuery, itemKey, {}, true)
  if not okSend then
    callback(false, {}, false, "Search query failed")
    return
  end

  local function poll(attempt)
    local itemListings = BuildItemSearchListings(itemKey)
    if #itemListings > 0 then
      callback(true, itemListings, false, nil)
      return
    end

    local commodityListings = BuildCommoditySearchListings(opportunity.itemId)
    if #commodityListings > 0 then
      callback(true, commodityListings, true, nil)
      return
    end

    if attempt < 10 then
      C_Timer.After(0.25, function() poll(attempt + 1) end)
    else
      callback(false, {}, false, "No listings found")
    end
  end

  C_Timer.After(0.30, function() poll(1) end)
end

local function SelectPurchasableListings(opportunity, strategy, listings, mode)
  if not listings or #listings == 0 then
    return {}
  end

  local maxUnitBuy = strategy and strategy.maxUnitBuy or 0
  if maxUnitBuy <= 0 then
    return {}
  end

  local result = {}
  local wantedQty = math.max(math.floor(tonumber((opportunity and opportunity.quantity) or 0) or 0), 0)
  if mode ~= "all" or wantedQty <= 0 then
    wantedQty = 1
  end

  local remaining = wantedQty
  for _, listing in ipairs(listings) do
    local unitPrice = listing.unitPrice or 0
    local qty = math.max(math.floor(tonumber(listing.quantity) or 0), 0)
    if unitPrice > 0 and qty > 0 and unitPrice <= maxUnitBuy then
      if mode == "single" then
        table.insert(result, listing)
        break
      end

      local takeQty = math.min(qty, remaining)
      if takeQty > 0 then
        local isCommodity = listing.commodity and true or false
        if (not isCommodity) and takeQty < qty then
          -- For item listings we cannot partially buy a single auction row.
          -- Skip this row and look for smaller rows further down.
        else
          if takeQty == qty then
            table.insert(result, listing)
          else
            table.insert(result, {
              commodity = true,
              quantity = takeQty,
              unitPrice = unitPrice,
              totalPrice = unitPrice * takeQty,
            })
          end
          remaining = remaining - takeQty
          if remaining <= 0 then
            break
          end
        end
      end
    end
  end

  return result
end

local function PlayPurchaseSuccessSound()
  local soundId = (SOUNDKIT and (SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.ALARM_CLOCK_WARNING_3)) or 856
  pcall(PlaySound, soundId, "master")
end

local function NextPurchaseToken()
  AuctionFlip.UI.PurchaseToken = (AuctionFlip.UI.PurchaseToken or 0) + 1
  return AuctionFlip.UI.PurchaseToken
end

local function FindPendingPurchaseByToken(token)
  if not token then
    return nil, nil
  end
  for index, entry in ipairs(AuctionFlip.UI.PendingPurchaseQueue or {}) do
    if entry.token == token then
      return entry, index
    end
  end
  return nil, nil
end

local function FindPendingPurchaseByItem(itemId, preferCommodity)
  if not itemId then
    return nil, nil
  end
  for index, entry in ipairs(AuctionFlip.UI.PendingPurchaseQueue or {}) do
    if entry.itemId == itemId then
      if preferCommodity == nil or entry.isCommodity == preferCommodity then
        return entry, index
      end
    end
  end
  return nil, nil
end

local function RemovePendingPurchase(index)
  if index and AuctionFlip.UI.PendingPurchaseQueue and AuctionFlip.UI.PendingPurchaseQueue[index] then
    table.remove(AuctionFlip.UI.PendingPurchaseQueue, index)
  end
end

local function QueuePendingPurchase(opportunity, purchasePrice, quantity, spent, mode, isCommodity)
  if not opportunity or not opportunity.itemId then
    return nil
  end

  local token = NextPurchaseToken()
  local entry = {
    token = token,
    itemId = opportunity.itemId,
    itemName = opportunity.itemName or ("Item " .. tostring(opportunity.itemId)),
    opportunity = opportunity,
    purchasePrice = purchasePrice or opportunity.buyPrice or 0,
    quantity = math.max(quantity or 1, 1),
    spent = spent or 0,
    mode = mode or "single",
    isCommodity = isCommodity and true or false,
    submittedAt = time(),
  }

  table.insert(AuctionFlip.UI.PendingPurchaseQueue, entry)

  -- Expire stale pending records to avoid polluting confirmation flow
  C_Timer.After(90, function()
    local found, idx = FindPendingPurchaseByToken(token)
    if found and idx then
      RemovePendingPurchase(idx)
      if AuctionFlip.UI.ActiveCommodityPurchase and AuctionFlip.UI.ActiveCommodityPurchase.token == token then
        AuctionFlip.UI.ActiveCommodityPurchase = nil
      end
      AuctionFlip.UI.SetActivityMessage("Purchase confirmation timeout for " .. (found.itemName or "item") .. ".")
      AuctionFlip.Utilities.Print("Purchase confirmation timeout for " .. (found.itemName or "item") .. ".")
    end
  end)

  return token
end

local function ConfirmPendingPurchase(lookupValue, quantityBought, source, byToken, preferCommodity)
  local pending, idx
  if byToken then
    pending, idx = FindPendingPurchaseByToken(lookupValue)
  else
    pending, idx = FindPendingPurchaseByItem(lookupValue, preferCommodity)
  end

  if not pending or not idx then
    return false
  end

  local qty = math.max(quantityBought or pending.quantity or 1, 1)
  AuctionFlip.Portfolio.AddPurchase(pending.opportunity, pending.purchasePrice, qty)
  RemovePendingPurchase(idx)

  if AuctionFlip.UI.ActiveCommodityPurchase and AuctionFlip.UI.ActiveCommodityPurchase.token == pending.token then
    AuctionFlip.UI.ActiveCommodityPurchase = nil
  end

  PlayPurchaseSuccessSound()
  AuctionFlip.UI.SetActivityMessage("Purchase confirmed: " .. (pending.itemName or "item") ..
    " | Qty " .. tostring(qty) ..
    " | Source " .. tostring(source or "event"))
  AuctionFlip.Utilities.Print("Purchase confirmed for " .. (pending.itemName or "item") .. ".")
  if AuctionFlip.UI.RefreshSelling then
    AuctionFlip.UI.RefreshSelling()
  end

  return true
end

local function FailPendingPurchase(lookupValue, reason, byToken, preferCommodity)
  local pending, idx
  if byToken then
    pending, idx = FindPendingPurchaseByToken(lookupValue)
  else
    pending, idx = FindPendingPurchaseByItem(lookupValue, preferCommodity)
  end

  if not pending or not idx then
    return false
  end

  RemovePendingPurchase(idx)
  if AuctionFlip.UI.ActiveCommodityPurchase and AuctionFlip.UI.ActiveCommodityPurchase.token == pending.token then
    AuctionFlip.UI.ActiveCommodityPurchase = nil
  end

  AuctionFlip.UI.SetActivityMessage("Purchase failed: " .. (pending.itemName or "item") .. ". " .. tostring(reason or ""))
  AuctionFlip.Utilities.Print("Purchase failed for " .. (pending.itemName or "item") .. (reason and (": " .. tostring(reason)) or "."))
  return true
end

local function BuildPurchasePreview(opportunity, strategy, listings, isCommodity, mode, allListings)
  if not opportunity or not strategy or not listings or #listings == 0 then
    return nil
  end

  local preview = {
    mode = mode,
    modeLabel = mode == "all" and "Buy All" or "Buy 1",
    itemName = opportunity.itemName or "Unknown Item",
    itemId = opportunity.itemId,
    itemLink = opportunity.itemLink,
    icon = opportunity.icon or 134400,
    rarity = opportunity.rarity or 0,
    isCommodity = isCommodity and true or false,
    maxUnitBuy = strategy.maxUnitBuy or 0,
    expectedSale = strategy.expectedSale or 0,
    sourceCount = #listings,
    marketListingCount = allListings and #allListings or #listings,
    quantity = 0,
    totalCost = 0,
    averageUnit = 0,
    cheapestListing = nil,
    highestBoughtUnit = nil,
    nextHigherListing = nil,
    executionSale = (opportunity.score and opportunity.score.executionSalePrice) or opportunity.verifiedTargetSellPrice or strategy.expectedSale or 0,
    pricingSource = opportunity.verifiedPricingSource or nil,
  }
  local score = opportunity.score or {}
  preview.analysisDiscount = score.discountPercent or opportunity.discount or 0
  preview.analysisROI = score.roiPercent or 0
  preview.analysisLiquidity = score.liquidityLabel or "?"
  preview.analysisConfidence = score.confidencePercent or opportunity.marketConfidence or 0
  preview.analysisVolume = score.volumePerDay or 0

  if allListings and allListings[1] then
    preview.cheapestListing = allListings[1].unitPrice or 0
  elseif listings[1] then
    preview.cheapestListing = listings[1].unitPrice or 0
  end

  if preview.cheapestListing and preview.cheapestListing > 0 and allListings then
    local cheapestQty = 0
    local cheapestRows = 0
    local sellers = {}
    local uniqueSellerCount = 0
    for _, listing in ipairs(allListings) do
      if (listing.unitPrice or 0) == preview.cheapestListing then
        cheapestQty = cheapestQty + math.max(tonumber(listing.quantity) or 0, 0)
        cheapestRows = cheapestRows + 1
        if listing.sellerToken and listing.sellerToken ~= "" and not sellers[listing.sellerToken] then
          sellers[listing.sellerToken] = true
          uniqueSellerCount = uniqueSellerCount + 1
        end
      else
        break
      end
    end
    preview.cheapestTierQuantity = cheapestQty
    preview.cheapestTierRows = cheapestRows
    preview.cheapestTierSellerCount = uniqueSellerCount
    preview.cheapestTierSellerKnown = uniqueSellerCount > 0
  end

  if mode == "all" then
    for _, listing in ipairs(listings) do
      preview.quantity = preview.quantity + (listing.quantity or 0)
      preview.totalCost = preview.totalCost + (listing.totalPrice or 0)
      local unitPrice = listing.unitPrice or 0
      if unitPrice > 0 then
        preview.highestBoughtUnit = preview.highestBoughtUnit and math.max(preview.highestBoughtUnit, unitPrice) or unitPrice
      end
    end
    preview.quantity = math.max(preview.quantity, 0)
  else
    local target = listings[1]
    if isCommodity then
      preview.quantity = 1
      preview.totalCost = target and (target.unitPrice or 0) or 0
    else
      preview.quantity = target and math.max(target.quantity or 1, 1) or 1
      preview.totalCost = target and (target.totalPrice or 0) or 0
    end
    if target and (target.unitPrice or 0) > 0 then
      preview.highestBoughtUnit = target.unitPrice
    end
  end

  if preview.highestBoughtUnit and allListings then
    for _, listing in ipairs(allListings) do
      local unitPrice = listing.unitPrice or 0
      if unitPrice > preview.highestBoughtUnit then
        preview.nextHigherListing = unitPrice
        break
      end
    end
  end

  if not preview.pricingSource then
    preview.pricingSource = preview.nextHigherListing and "next_tier" or "historical"
  end

  if preview.quantity > 0 and preview.totalCost > 0 then
    preview.averageUnit = math.floor(preview.totalCost / preview.quantity)
  end

  local ahCutPercent = AuctionFlip.Config.Get("ah_cut_percent") or 5
  local quantity = math.max(preview.quantity or 0, 0)
  local executionSell = preview.executionSale or preview.expectedSale or 0
  local saleRevenue = executionSell * quantity
  local isVendorFlip = opportunity and opportunity.type == "vendor_flip"
  local ahFeeTotal = 0
  local depositTotal = 0
  local durationHours = 24

  if not isVendorFlip then
    ahFeeTotal = math.floor(saleRevenue * (ahCutPercent / 100))
    if AuctionFlip.Opportunities and AuctionFlip.Opportunities.GetVerificationDurationHours then
      durationHours = AuctionFlip.Opportunities.GetVerificationDurationHours()
    end
    if AuctionFlip.Opportunities and AuctionFlip.Opportunities.EstimateDepositCost then
      depositTotal = AuctionFlip.Opportunities.EstimateDepositCost(
        opportunity,
        quantity,
        durationHours,
        preview.isCommodity,
        executionSell
      ) or 0
    end
  end

  preview.durationHours = durationHours
  preview.estimatedFeeTotal = ahFeeTotal
  preview.estimatedDepositTotal = depositTotal
  preview.expectedNetTotal = saleRevenue - ahFeeTotal - depositTotal - (preview.totalCost or 0)

  return preview
end

function AuctionFlip.UI.ShowBuyConfirmation(preview, onConfirm)
  if not preview then
    return
  end

  local win = AuctionFlip.UI.BuyConfirmWindow
  if not win then
    win = CreateFrame("Frame", "AuctionFlipBuyConfirmWindow", UIParent, "BackdropTemplate")
    win:SetSize(520, 560)
    win:SetFrameStrata("TOOLTIP")
    win:SetFrameLevel((AuctionFlip.UI.Frame and AuctionFlip.UI.Frame:GetFrameLevel() or 100) + 90)
    win:SetToplevel(true)
    win:EnableMouse(true)
    win:SetMovable(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", function(self) self:StartMoving() end)
    win:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    win:SetClampedToScreen(true)
    win:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    win:SetBackdropColor(0.03, 0.03, 0.05, 0.98)
    win:SetBackdropBorderColor(unpack(THEME.border))

    local title = win:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetTextColor(unpack(THEME.gold))
    ApplyNeonFont(title, 13, "OUTLINE")
    win.title = title

    local loadingText = win:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    loadingText:SetPoint("TOPLEFT", 14, -38)
    loadingText:SetPoint("TOPRIGHT", -14, -38)
    loadingText:SetJustifyH("LEFT")
    loadingText:SetJustifyV("TOP")
    loadingText:SetTextColor(unpack(THEME.text))
    loadingText:Hide()
    win.loadingText = loadingText

    local itemLine = win:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    itemLine:SetPoint("TOPLEFT", 48, -38)
    itemLine:SetPoint("TOPRIGHT", -14, -38)
    itemLine:SetJustifyH("LEFT")
    itemLine:SetTextColor(unpack(THEME.text))
    win.itemLine = itemLine

    local itemIcon = win:CreateTexture(nil, "ARTWORK")
    itemIcon:SetSize(26, 26)
    itemIcon:SetPoint("TOPLEFT", 14, -38)
    win.itemIcon = itemIcon

    local tooltipAnchor = CreateFrame("Button", nil, win)
    tooltipAnchor:SetPoint("TOPLEFT", 12, -34)
    tooltipAnchor:SetPoint("TOPRIGHT", -14, -60)
    tooltipAnchor:SetHeight(30)
    tooltipAnchor:SetScript("OnEnter", function(self)
      local p = win.previewData
      if not p then
        return
      end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      if p.itemLink then
        GameTooltip:SetHyperlink(p.itemLink)
      elseif p.itemId then
        GameTooltip:SetHyperlink("item:" .. tostring(p.itemId))
      end
      GameTooltip:Show()
    end)
    tooltipAnchor:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)
    win.tooltipAnchor = tooltipAnchor

    local actionLine = win:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    actionLine:SetPoint("TOPLEFT", win, "TOPLEFT", 14, -68)
    actionLine:SetPoint("TOPRIGHT", win, "TOPRIGHT", -14, -68)
    actionLine:SetJustifyH("LEFT")
    actionLine:SetTextColor(unpack(THEME.textDim))
    win.actionLine = actionLine

    local function CreateSectionHeader(anchor, text)
      local header = win:CreateFontString(nil, "ARTWORK", "GameFontNormal")
      header:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)
      header:SetText(text)
      header:SetTextColor(unpack(THEME.gold))
      ApplyNeonFont(header, 11, "OUTLINE")
      return header
    end

    local function CreateSectionPanel(anchor, offsetX, offsetY, width, height, tint)
      local panel = CreateFrame("Frame", nil, win, "BackdropTemplate")
      panel:SetSize(width, height)
      panel:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", offsetX or 0, offsetY or -6)
      panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
      })
      local r = tint and tint[1] or THEME.accent[1]
      local g = tint and tint[2] or THEME.accent[2]
      local b = tint and tint[3] or THEME.accent[3]
      panel:SetBackdropColor(r * 0.08, g * 0.08, b * 0.08, 0.92)
      panel:SetBackdropBorderColor(r * 0.65, g * 0.65, b * 0.65, 0.65)
      return panel
    end

    local function CreateMetricRow(parent, topOffset, width, emphasis)
      local row = CreateFrame("Frame", nil, win)
      row:SetSize(width or 220, emphasis and 24 or 16)
      row:SetParent(parent)
      row:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, topOffset)
      row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, topOffset)
      row.label = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
      row.label:SetPoint("LEFT", 0, 0)
      row.label:SetWidth(emphasis and 100 or 92)
      row.label:SetJustifyH("LEFT")
      row.label:SetTextColor(unpack(THEME.textDim))
      row.value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
      row.value:SetPoint("LEFT", row.label, "RIGHT", 8, 0)
      row.value:SetPoint("RIGHT", 0, 0)
      row.value:SetJustifyH("RIGHT")
      row.value:SetTextColor(unpack(THEME.text))
      if emphasis then
        ApplyNeonFont(row.value, 14, "OUTLINE")
      else
        ApplyNeonFont(row.value, 11, "")
      end
      return row
    end

    local marketHeader = CreateSectionHeader(actionLine, "Market Snapshot")
    win.marketHeader = marketHeader
    win.marketLeftPanel = CreateSectionPanel(marketHeader, 0, -6, 232, 88, THEME.blue)
    win.marketRightPanel = CreateSectionPanel(marketHeader, 246, -6, 232, 88, THEME.accent)
    win.cheapestListingRow = CreateMetricRow(win.marketLeftPanel, -10, 216, false)
    win.cheapestTierQtyRow = CreateMetricRow(win.marketLeftPanel, -30, 216, false)
    win.cheapestTierRowsRow = CreateMetricRow(win.marketLeftPanel, -50, 216, false)
    win.cheapestTierSellersRow = CreateMetricRow(win.marketLeftPanel, -70, 216, false)
    win.highestBoughtRow = CreateMetricRow(win.marketRightPanel, -10, 216, false)
    win.nextHigherRow = CreateMetricRow(win.marketRightPanel, -36, 216, true)
    win.pricingRuleRow = CreateMetricRow(win.marketRightPanel, -68, 216, false)

    local executionHeader = CreateSectionHeader(win.marketLeftPanel, "Execution Plan")
    win.executionHeader = executionHeader
    win.executionLeftPanel = CreateSectionPanel(executionHeader, 0, -6, 232, 88, THEME.accent)
    win.executionRightPanel = CreateSectionPanel(executionHeader, 246, -6, 232, 88, THEME.blue)
    win.buyQtyRow = CreateMetricRow(win.executionLeftPanel, -10, 216, false)
    win.averageBuyRow = CreateMetricRow(win.executionLeftPanel, -30, 216, false)
    win.totalCostRow = CreateMetricRow(win.executionLeftPanel, -50, 216, false)
    win.maxBuyRow = CreateMetricRow(win.executionLeftPanel, -70, 216, false)
    win.sellUnitRow = CreateMetricRow(win.executionRightPanel, -10, 216, false)
    win.durationRow = CreateMetricRow(win.executionRightPanel, -30, 216, false)
    win.sourceRowsRow = CreateMetricRow(win.executionRightPanel, -50, 216, false)

    local profitHeader = CreateSectionHeader(win.executionLeftPanel, "Profit Estimate")
    win.profitHeader = profitHeader
    win.profitLeftPanel = CreateSectionPanel(profitHeader, 0, -6, 232, 72, THEME.red)
    win.profitRightPanel = CreateSectionPanel(profitHeader, 246, -6, 232, 72, THEME.green)
    win.feeRow = CreateMetricRow(win.profitLeftPanel, -10, 216, false)
    win.depositRow = CreateMetricRow(win.profitLeftPanel, -30, 216, false)
    win.netRow = CreateMetricRow(win.profitRightPanel, -24, 216, true)

    local notePanel = CreateSectionPanel(win.profitLeftPanel, 0, -10, 478, 94, THEME.accentSoft)
    win.notePanel = notePanel

    local analysisHeader = notePanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    analysisHeader:SetPoint("TOPLEFT", 10, -8)
    analysisHeader:SetText("Item Analysis")
    analysisHeader:SetTextColor(unpack(THEME.gold))
    ApplyNeonFont(analysisHeader, 11, "OUTLINE")
    win.analysisHeader = analysisHeader

    local function CreateSmallMetric(parent, anchor, leftX)
      local row = CreateFrame("Frame", nil, parent)
      row:SetSize(108, 28)
      row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", leftX, -4)
      row.label = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
      row.label:SetPoint("TOPLEFT", 0, 0)
      row.label:SetTextColor(unpack(THEME.textDim))
      row.value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
      row.value:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -2)
      row.value:SetTextColor(unpack(THEME.text))
      return row
    end

    win.analysisDiscountRow = CreateSmallMetric(notePanel, analysisHeader, 0)
    win.analysisROIRow = CreateSmallMetric(notePanel, analysisHeader, 120)
    win.analysisLiquidityRow = CreateSmallMetric(notePanel, analysisHeader, 240)
    win.analysisConfidenceRow = CreateSmallMetric(notePanel, analysisHeader, 360)

    local noteText = notePanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    noteText:SetPoint("TOPLEFT", win.analysisDiscountRow, "BOTTOMLEFT", 0, -8)
    noteText:SetPoint("TOPRIGHT", notePanel, "TOPRIGHT", -10, 0)
    noteText:SetPoint("BOTTOMRIGHT", notePanel, "BOTTOMRIGHT", -10, 8)
    noteText:SetJustifyH("LEFT")
    noteText:SetJustifyV("TOP")
    noteText:SetTextColor(unpack(THEME.goldDim))
    noteText:SetText("")
    win.noteText = noteText

    local confirmBtn = AuctionFlip.UI.CreateFlatButton(win, "Confirm", 110, 24)
    confirmBtn:SetPoint("BOTTOMRIGHT", -12, 16)
    confirmBtn:SetScript("OnClick", function()
      local cb = win.onConfirm
      win.onConfirm = nil
      win:Hide()
      if cb then
        cb()
      end
    end)
    win.confirmBtn = confirmBtn

    local cancelBtn = AuctionFlip.UI.CreateFlatButton(win, "Cancel", 90, 24)
    cancelBtn:SetPoint("RIGHT", confirmBtn, "LEFT", -8, 0)
    cancelBtn:SetScript("OnClick", function()
      win.onConfirm = nil
      win:Hide()
      AuctionFlip.UI.SetActivityMessage("Purchase canceled.")
    end)
    win.cancelBtn = cancelBtn

    local helpBtn = AuctionFlip.UI.CreateFlatButton(win, "Help", 70, 24)
    helpBtn:SetPoint("RIGHT", cancelBtn, "LEFT", -8, 0)
    helpBtn:SetScript("OnClick", function()
      AuctionFlip.UI.ShowBuyConfirmationHelpWindow()
    end)
    win.helpBtn = helpBtn

    local closeBtn = AuctionFlip.UI.CreateFlatButton(win, "X", 24, 22)
    closeBtn:SetPoint("TOPRIGHT", -8, -8)
    closeBtn:SetScript("OnClick", function()
      win.onConfirm = nil
      win:Hide()
      AuctionFlip.UI.SetActivityMessage("Purchase canceled.")
    end)
    win.closeBtn = closeBtn

    AuctionFlip.UI.BuyConfirmWindow = win
  end

  if preview.loading then
    win.previewData = nil
    if win.loadingText then
      win.loadingText:SetText(preview.loadingMessage or "Loading listings...")
      win.loadingText:Show()
    end
    if win.itemLine then win.itemLine:Hide() end
    if win.actionLine then win.actionLine:Hide() end
    if win.marketHeader then win.marketHeader:Hide() end
    if win.executionHeader then win.executionHeader:Hide() end
    if win.profitHeader then win.profitHeader:Hide() end
    if win.marketLeftPanel then win.marketLeftPanel:Hide() end
    if win.marketRightPanel then win.marketRightPanel:Hide() end
    if win.executionLeftPanel then win.executionLeftPanel:Hide() end
    if win.executionRightPanel then win.executionRightPanel:Hide() end
    if win.profitLeftPanel then win.profitLeftPanel:Hide() end
    if win.profitRightPanel then win.profitRightPanel:Hide() end
    if win.notePanel then win.notePanel:Hide() end
    if win.noteText then win.noteText:Hide() end
    local detailRows = {
      win.cheapestListingRow, win.cheapestTierQtyRow, win.cheapestTierRowsRow, win.cheapestTierSellersRow,
      win.highestBoughtRow, win.nextHigherRow, win.pricingRuleRow,
      win.buyQtyRow, win.averageBuyRow, win.totalCostRow, win.maxBuyRow,
      win.sellUnitRow, win.durationRow, win.sourceRowsRow,
      win.feeRow, win.depositRow, win.netRow,
    }
    for _, row in ipairs(detailRows) do
      if row then row:Hide() end
    end
  else
    win.previewData = preview
    local sourceLabel = "historical fallback"
    if preview.pricingSource == "next_tier" then
      sourceLabel = "next tier above bought listings"
    elseif preview.pricingSource == "historical_cap" then
      sourceLabel = "historical cap below next tier"
    elseif preview.pricingSource == "vendor" then
      sourceLabel = "vendor resale"
    end
    if win.loadingText then
      win.loadingText:Hide()
    end
    if win.itemLine then
      win.itemLine:SetText("Item: " .. tostring(preview.itemName or "Unknown Item"))
      win.itemLine:Show()
    end
    if win.itemIcon then
      win.itemIcon:SetTexture(preview.icon or 134400)
      win.itemIcon:Show()
    end
    if win.itemLine and preview.rarity and preview.rarity >= 2 then
      local r, g, b = GetItemQualityColor(preview.rarity)
      win.itemLine:SetTextColor(r, g, b)
    elseif win.itemLine then
      win.itemLine:SetTextColor(unpack(THEME.text))
    end
    if win.actionLine then
      win.actionLine:SetText(
        "Action: " .. tostring(preview.modeLabel or "Buy") ..
        "  |  Source: " .. tostring(preview.isCommodity and "Commodity market" or "Item listings") ..
        "  |  Listing rows loaded: " .. tostring(preview.marketListingCount or preview.sourceCount or 0)
      )
      win.actionLine:Show()
    end
    if win.marketHeader then win.marketHeader:Show() end
    if win.executionHeader then win.executionHeader:Show() end
    if win.profitHeader then win.profitHeader:Show() end
    if win.marketLeftPanel then win.marketLeftPanel:Show() end
    if win.marketRightPanel then win.marketRightPanel:Show() end
    if win.executionLeftPanel then win.executionLeftPanel:Show() end
    if win.executionRightPanel then win.executionRightPanel:Show() end
    if win.profitLeftPanel then win.profitLeftPanel:Show() end
    if win.profitRightPanel then win.profitRightPanel:Show() end
    if win.notePanel then win.notePanel:Show() end

    local cheapestSellerText = "--"
    if preview.isCommodity then
      cheapestSellerText = "anonymous commodity market"
    elseif preview.cheapestTierSellerKnown then
      cheapestSellerText = tostring(preview.cheapestTierSellerCount or preview.cheapestTierRows or 0)
    else
      cheapestSellerText = tostring(preview.cheapestTierRows or 0) .. " listing rows"
    end

    local rowValues = {
      { row = win.cheapestListingRow, label = "Cheapest:", value = AuctionFlip.Utilities.CreatePaddedMoneyString(preview.cheapestListing or 0) },
      { row = win.cheapestTierQtyRow, label = "Tier qty:", value = tostring(preview.cheapestTierQuantity or 0) },
      { row = win.cheapestTierRowsRow, label = "Tier rows:", value = tostring(preview.cheapestTierRows or 0) },
      { row = win.cheapestTierSellersRow, label = "Sellers:", value = cheapestSellerText },
      { row = win.highestBoughtRow, label = "Highest buy:", value = AuctionFlip.Utilities.CreatePaddedMoneyString(preview.highestBoughtUnit or 0) },
      { row = win.nextHigherRow, label = "Next tier:", value = preview.nextHigherListing and AuctionFlip.Utilities.CreatePaddedMoneyString(preview.nextHigherListing) or "--" },
      { row = win.pricingRuleRow, label = "Rule:", value = sourceLabel },
      { row = win.buyQtyRow, label = "Buy qty:", value = tostring(preview.quantity or 0) },
      { row = win.averageBuyRow, label = "Avg buy:", value = AuctionFlip.Utilities.CreatePaddedMoneyString(preview.averageUnit or 0) },
      { row = win.totalCostRow, label = "Total cost:", value = AuctionFlip.Utilities.CreatePaddedMoneyString(preview.totalCost or 0) },
      { row = win.maxBuyRow, label = "Max buy/unit:", value = AuctionFlip.Utilities.CreatePaddedMoneyString(preview.maxUnitBuy or 0) },
      { row = win.sellUnitRow, label = "Exec sell:", value = AuctionFlip.Utilities.CreatePaddedMoneyString(preview.executionSale or preview.expectedSale or 0) },
      { row = win.durationRow, label = "Duration:", value = tostring(preview.durationHours or 24) .. "h" },
      { row = win.sourceRowsRow, label = "Rows used:", value = tostring(preview.sourceCount or 0) },
      { row = win.feeRow, label = "AH fee:", value = AuctionFlip.Utilities.CreatePaddedMoneyString(preview.estimatedFeeTotal or 0) },
      { row = win.depositRow, label = "Deposit:", value = AuctionFlip.Utilities.CreatePaddedMoneyString(preview.estimatedDepositTotal or 0) },
      { row = win.netRow, label = "Est. net:", value = AuctionFlip.Utilities.CreatePaddedMoneyString(preview.expectedNetTotal or 0) },
    }
    for _, entry in ipairs(rowValues) do
      if entry.row then
        entry.row.label:SetText(entry.label)
        entry.row.value:SetText(entry.value)
        entry.row:Show()
      end
    end

    if win.netRow and win.netRow.value then
      if (preview.expectedNetTotal or 0) >= 0 then
        win.netRow.value:SetTextColor(unpack(THEME.green))
      else
        win.netRow.value:SetTextColor(unpack(THEME.red))
      end
    end
    if win.nextHigherRow and win.nextHigherRow.value then
      if preview.nextHigherListing and preview.nextHigherListing > 0 then
        win.nextHigherRow.value:SetTextColor(unpack(THEME.gold))
      else
        win.nextHigherRow.value:SetTextColor(unpack(THEME.textDim))
      end
    end

    if win.noteText then
      if win.analysisDiscountRow then
        win.analysisDiscountRow.label:SetText("Discount")
        win.analysisDiscountRow.value:SetText((preview.analysisDiscount or 0) > 0 and ("-" .. tostring(preview.analysisDiscount) .. "%") or "--")
        if (preview.analysisDiscount or 0) >= 20 then
          win.analysisDiscountRow.value:SetTextColor(unpack(THEME.green))
        else
          win.analysisDiscountRow.value:SetTextColor(unpack(THEME.text))
        end
      end
      if win.analysisROIRow then
        win.analysisROIRow.label:SetText("ROI")
        win.analysisROIRow.value:SetText(tostring(preview.analysisROI or 0) .. "%")
        win.analysisROIRow.value:SetTextColor(unpack(THEME.gold))
      end
      if win.analysisLiquidityRow then
        win.analysisLiquidityRow.label:SetText("Liquidity")
        win.analysisLiquidityRow.value:SetText(tostring(preview.analysisLiquidity or "?"))
        win.analysisLiquidityRow.value:SetTextColor(unpack(THEME.accentText))
      end
      if win.analysisConfidenceRow then
        win.analysisConfidenceRow.label:SetText("Confidence")
        win.analysisConfidenceRow.value:SetText(tostring(preview.analysisConfidence or 0) .. "%")
        win.analysisConfidenceRow.value:SetTextColor(unpack(THEME.text))
      end

      local notes = {}
      table.insert(notes, "Strategy: buy the cheapest tier(s), then reprice against the first tier above what we buy.")
      if not preview.nextHigherListing then
        table.insert(notes, "No higher tier found right now, so execution falls back to historical/value model.")
      end
      if preview.isCommodity then
        table.insert(notes, "Seller identities are not fully exposed on commodity markets.")
      end
      win.noteText:SetText(table.concat(notes, "\n"))
      win.noteText:Show()
    end
  end

  win.title:SetText(preview.modeLabel .. " Confirmation")
  win.onConfirm = onConfirm
  if onConfirm then
    win.confirmBtn:Enable()
    if win.confirmBtn.text then
      win.confirmBtn.text:SetText("Confirm")
    end
  else
    win.confirmBtn:Disable()
    if win.confirmBtn.text then
      win.confirmBtn.text:SetText(preview.loading and "Loading..." or "Confirm")
    end
  end
  win:ClearAllPoints()
  if AuctionFlip.UI and AuctionFlip.UI.Frame and AuctionFlip.UI.Frame:IsShown() then
    win:SetPoint("CENTER", AuctionFlip.UI.Frame, "CENTER", 0, 0)
  else
    win:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end
  win:Show()
  win:Raise()
end

local function ExecuteBuySingle(opportunity, strategy, listings, isCommodity)
  local target = listings[1]
  if not target then
    AuctionFlip.Utilities.Print("No listing available for this item.")
    return false, 0, 0
  end
  if (target.unitPrice or 0) > (strategy.maxUnitBuy or 0) then
    AuctionFlip.Utilities.Print("Current cheapest listing is above your max buy/unit.")
    return false, 0, 0
  end

  if isCommodity and C_AuctionHouse.StartCommoditiesPurchase and C_AuctionHouse.ConfirmCommoditiesPurchase then
    local qty = 1
    local okStart, startErr = pcall(C_AuctionHouse.StartCommoditiesPurchase, opportunity.itemId, qty)
    if not okStart then
      AuctionFlip.Utilities.Print("Commodity buy start failed: " .. tostring(startErr))
      return false, 0, 0
    end
    local spent = target.unitPrice * qty
    local token = QueuePendingPurchase(opportunity, target.unitPrice, qty, spent, "single", true)
    AuctionFlip.UI.ActiveCommodityPurchase = {
      token = token,
      itemId = opportunity.itemId,
      quantity = qty,
      stage = "started",
      startedAt = time(),
    }
    AuctionFlip.Utilities.Print("Buy 1 started for " .. (opportunity.itemName or "item") .. ". Awaiting commodity price confirmation...")
    return true, qty, spent
  elseif (not isCommodity) and C_AuctionHouse.PlaceBid and target.auctionID then
    local okBid, bidErr = pcall(C_AuctionHouse.PlaceBid, target.auctionID, target.totalPrice)
    if okBid then
      local qty = target.quantity or 1
      QueuePendingPurchase(opportunity, target.unitPrice, qty, target.totalPrice or 0, "single", false)
      AuctionFlip.Utilities.Print("Buy 1 submitted for " .. (opportunity.itemName or "item") .. ". Awaiting purchase confirmation...")
      return true, target.quantity or 1, target.totalPrice or 0
    end
    AuctionFlip.Utilities.Print("Item buy failed: " .. tostring(bidErr))
  end

  AuctionFlip.Utilities.Print("Direct buy could not be executed by API constraints.")
  return false, 0, 0
end

local function ExecuteBuyAll(opportunity, strategy, listings, isCommodity)
  if #listings == 0 then
    AuctionFlip.Utilities.Print("No qualifying cheap listings available for this item.")
    return false, 0, 0
  end

  local totalQty = 0
  local totalCost = 0
  for _, listing in ipairs(listings) do
    totalQty = totalQty + (listing.quantity or 0)
    totalCost = totalCost + (listing.totalPrice or 0)
  end

  local itemBudget = strategy.itemBudget or 0
  if totalCost > itemBudget then
    AuctionFlip.Utilities.Print("Buy blocked by budget: required " ..
      AuctionFlip.Utilities.CreatePaddedMoneyString(totalCost) ..
      " exceeds item budget " .. AuctionFlip.Utilities.CreatePaddedMoneyString(itemBudget) .. ".")
    return false, 0, 0
  end

  local maxActions = AuctionFlip.Config.Get("max_buy_actions_per_click") or 5
  if (not isCommodity) and #listings > maxActions then
    AuctionFlip.Utilities.Print("Buy-all blocked: " .. #listings .. " auctions exceeds max actions (" .. maxActions .. ").")
    return false, 0, 0
  end

  local boughtQty = 0
  local spent = 0
  if isCommodity and C_AuctionHouse.StartCommoditiesPurchase and C_AuctionHouse.ConfirmCommoditiesPurchase then
    local okStart, startErr = pcall(C_AuctionHouse.StartCommoditiesPurchase, opportunity.itemId, totalQty)
    if not okStart then
      AuctionFlip.Utilities.Print("Commodity buy-all start failed: " .. tostring(startErr))
      return false, 0, 0
    end
    boughtQty = totalQty
    spent = totalCost
    local avgUnit = math.floor(spent / math.max(boughtQty, 1))
    local token = QueuePendingPurchase(opportunity, avgUnit, boughtQty, spent, "all", true)
    AuctionFlip.UI.ActiveCommodityPurchase = {
      token = token,
      itemId = opportunity.itemId,
      quantity = boughtQty,
      stage = "started",
      startedAt = time(),
    }
    AuctionFlip.Utilities.Print("Buy-all started for " .. (opportunity.itemName or "item") .. ". Awaiting commodity price confirmation...")
    return true, boughtQty, spent
  elseif (not isCommodity) and C_AuctionHouse.PlaceBid then
    for _, listing in ipairs(listings) do
      if listing.auctionID and listing.totalPrice and listing.totalPrice > 0 then
        local okBid, bidErr = pcall(C_AuctionHouse.PlaceBid, listing.auctionID, listing.totalPrice)
        if not okBid then
          AuctionFlip.Utilities.Print("Item buy-all step failed: " .. tostring(bidErr))
          break
        end
        boughtQty = boughtQty + (listing.quantity or 1)
        spent = spent + (listing.totalPrice or 0)
      end
    end
  end

  if boughtQty > 0 then
    local avgUnit = math.floor(spent / math.max(boughtQty, 1))
    QueuePendingPurchase(opportunity, avgUnit, boughtQty, spent, "all", false)
    AuctionFlip.Utilities.Print("Buy-all submitted for " .. (opportunity.itemName or "item") ..
      " (" .. tostring(boughtQty) .. " units). Awaiting purchase confirmation...")
    return true, boughtQty, spent
  else
    AuctionFlip.Utilities.Print("Buy-all could not be executed by API constraints.")
    return false, 0, 0
  end
end

function AuctionFlip.UI.BuySelectedOpportunity(mode)
  local opportunity = AuctionFlip.UI.SelectedOpportunity
  if not opportunity then
    AuctionFlip.Utilities.Print("Select an opportunity first.")
    return
  end

  local strategy = AuctionFlip.Opportunities.GetBuyStrategy(opportunity)
  if not strategy or (strategy.maxUnitBuy or 0) <= 0 then
    AuctionFlip.Utilities.Print("No safe buy strategy available for this item.")
    return
  end

  local itemKey = opportunity.itemKey or (opportunity.itemId and { itemID = opportunity.itemId }) or nil
  if not itemKey then
    AuctionFlip.Utilities.Print("No item key available for this opportunity.")
    return
  end

  local function ResolveListings()
    local itemListings = BuildItemSearchListings(itemKey)
    local commodityListings = BuildCommoditySearchListings(opportunity.itemId)
    local rawItemCount = (C_AuctionHouse and C_AuctionHouse.GetNumItemSearchResults and C_AuctionHouse.GetNumItemSearchResults(itemKey)) or 0
    local listings = itemListings
    local isCommodity = false
    if #listings == 0 and #commodityListings > 0 then
      listings = commodityListings
      isCommodity = true
    end
    return listings, isCommodity, itemListings, rawItemCount
  end

  local listings, isCommodity, itemListings, rawItemCount = ResolveListings()
  local qualifiedListings = SelectPurchasableListings(opportunity, strategy, listings, mode)

  if #listings == 0 then
    if rawItemCount > 0 and #itemListings == 0 then
      AuctionFlip.UI.PendingBuy = nil
      AuctionFlip.UI.SetActivityMessage("No instant buyout listings available right now for " .. (opportunity.itemName or "item") .. ".")
      AuctionFlip.Utilities.Print("No buyout listings available for direct purchase right now.")
      AuctionFlip.UI.ShowBuyConfirmation({
        mode = mode,
        modeLabel = mode == "all" and "Buy All" or "Buy 1",
        itemName = opportunity.itemName or "Unknown Item",
        loading = true,
        loadingMessage = "No buyout listing available right now.\nTry refreshing market data and scanning again.",
      }, nil)
      return
    end

    if C_AuctionHouse and C_AuctionHouse.SendSearchQuery then
      AuctionFlip.UI.ShowBuyConfirmation({
        mode = mode,
        modeLabel = mode == "all" and "Buy All" or "Buy 1",
        itemName = opportunity.itemName or "Unknown Item",
        loading = true,
        loadingMessage = "Loading live auction listings...\nPlease wait a moment.",
      }, nil)

      pcall(C_AuctionHouse.SendSearchQuery, itemKey, {}, true)
      AuctionFlip.UI.PendingBuy = {
        itemId = opportunity.itemId,
        mode = mode,
        requestedAt = GetTime and GetTime() or 0,
      }

      AuctionFlip.UI.SetActivityMessage("Loading buyout listings for " .. (opportunity.itemName or "item") .. "...")
      AuctionFlip.Utilities.Print("Loading buyout listings...")

      local attempts = 0
      local maxAttempts = 15
      local function pollListings()
        attempts = attempts + 1
        local currentListings, currentIsCommodity, currentItemListings, currentRawCount = ResolveListings()
        local candidateListings = SelectPurchasableListings(opportunity, strategy, currentListings, mode)
        if #candidateListings > 0 then
          local preview = BuildPurchasePreview(opportunity, strategy, candidateListings, currentIsCommodity, mode, currentListings)
          if preview then
            AuctionFlip.UI.SetActivityMessage("Review purchase confirmation for " .. (opportunity.itemName or "item") .. ".")
            AuctionFlip.UI.ShowBuyConfirmation(preview, function()
              local ok, boughtQty, spent
              if mode == "all" then
                ok, boughtQty, spent = ExecuteBuyAll(opportunity, strategy, candidateListings, currentIsCommodity)
              else
                ok, boughtQty, spent = ExecuteBuySingle(opportunity, strategy, candidateListings, currentIsCommodity)
              end

              AuctionFlip.UI.PendingBuy = nil
              if ok then
                AuctionFlip.UI.SetActivityMessage("Purchase submitted, awaiting confirmation: " .. (opportunity.itemName or "item") ..
                  " | Qty " .. tostring(boughtQty or 0))
              else
                AuctionFlip.UI.SetActivityMessage("Purchase could not be submitted for " .. (opportunity.itemName or "item") .. ".")
              end

              if AuctionFlip.UI.RefreshSelling then
                AuctionFlip.UI.RefreshSelling()
              end
            end)
            return
          end
        elseif #currentListings > 0 then
          AuctionFlip.UI.PendingBuy = nil
          AuctionFlip.UI.SetActivityMessage("No profitable cheap listings available right now for " .. (opportunity.itemName or "item") .. ".")
          AuctionFlip.UI.ShowBuyConfirmation({
            mode = mode,
            modeLabel = mode == "all" and "Buy All" or "Buy 1",
            itemName = opportunity.itemName or "Unknown Item",
            loading = true,
            loadingMessage = "No qualifying cheap listings available right now.\nTry another scan or adjust your thresholds.",
          }, nil)
          return
        end

        if currentRawCount > 0 and #currentItemListings == 0 then
          AuctionFlip.UI.PendingBuy = nil
          AuctionFlip.UI.SetActivityMessage("No instant buyout listings available right now for " .. (opportunity.itemName or "item") .. ".")
          AuctionFlip.UI.ShowBuyConfirmation({
            mode = mode,
            modeLabel = mode == "all" and "Buy All" or "Buy 1",
            itemName = opportunity.itemName or "Unknown Item",
            loading = true,
            loadingMessage = "No buyout listing available right now.\nTry refreshing market data and scanning again.",
          }, nil)
          return
        end

        if attempts >= maxAttempts then
          AuctionFlip.UI.PendingBuy = nil
          AuctionFlip.UI.SetActivityMessage("Timed out loading listings for " .. (opportunity.itemName or "item") .. ".")
          AuctionFlip.UI.ShowBuyConfirmation({
            mode = mode,
            modeLabel = mode == "all" and "Buy All" or "Buy 1",
            itemName = opportunity.itemName or "Unknown Item",
            loading = true,
            loadingMessage = "Could not load listings in time.\nTry again in a few seconds.",
          }, nil)
          return
        end

        C_Timer.After(0.20, pollListings)
      end

      C_Timer.After(0.15, pollListings)
    else
      AuctionFlip.Utilities.Print("Auction House API unavailable for direct buy.")
    end
    return
  end

  if #qualifiedListings == 0 then
    AuctionFlip.UI.SetActivityMessage("No profitable cheap listings available right now for " .. (opportunity.itemName or "item") .. ".")
    AuctionFlip.Utilities.Print("No qualifying listings found within your profitable buy range.")
    AuctionFlip.UI.ShowBuyConfirmation({
      mode = mode,
      modeLabel = mode == "all" and "Buy All" or "Buy 1",
      itemName = opportunity.itemName or "Unknown Item",
      loading = true,
      loadingMessage = "No qualifying cheap listings available right now.\nTry another scan or adjust your thresholds.",
    }, nil)
    return
  end

  if AuctionFlip.UI.PendingBuy and (AuctionFlip.UI.PendingBuy.itemId ~= opportunity.itemId or AuctionFlip.UI.PendingBuy.mode ~= mode) then
    AuctionFlip.UI.PendingBuy = nil
  end

  local preview = BuildPurchasePreview(opportunity, strategy, qualifiedListings, isCommodity, mode, listings)
  if not preview then
    AuctionFlip.Utilities.Print("Could not build purchase confirmation data.")
    return
  end

  AuctionFlip.UI.SetActivityMessage("Review purchase confirmation for " .. (opportunity.itemName or "item") .. ".")
  AuctionFlip.UI.ShowBuyConfirmation(preview, function()
    local ok, boughtQty, spent
    if mode == "all" then
      ok, boughtQty, spent = ExecuteBuyAll(opportunity, strategy, qualifiedListings, isCommodity)
    else
      ok, boughtQty, spent = ExecuteBuySingle(opportunity, strategy, qualifiedListings, isCommodity)
    end

    AuctionFlip.UI.PendingBuy = nil
    if ok then
      AuctionFlip.UI.SetActivityMessage("Purchase submitted, awaiting confirmation: " .. (opportunity.itemName or "item") ..
        " | Qty " .. tostring(boughtQty or 0))
    else
      AuctionFlip.UI.SetActivityMessage("Purchase could not be submitted for " .. (opportunity.itemName or "item") .. ".")
    end

    if AuctionFlip.UI.RefreshSelling then
      AuctionFlip.UI.RefreshSelling()
    end
  end)
end

local SELL_DURATIONS = {
  { hours = 12, enumValue = 1, label = "12h" },
  { hours = 24, enumValue = 2, label = "24h" },
  { hours = 48, enumValue = 3, label = "48h" },
}

local function NormalizeAuctionPrice(price)
  local value = math.max(math.floor(tonumber(price) or 0), 0)
  if WOW_PROJECT_ID and WOW_PROJECT_MAINLINE and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
    if value > 0 and value < 100 then
      value = 100
    end
    if value % 100 ~= 0 then
      value = value + (100 - (value % 100))
    end
  elseif value < 1 then
    value = 1
  end
  return value
end

local function GetDurationEnum(hours)
  for _, d in ipairs(SELL_DURATIONS) do
    if d.hours == hours then
      return d.enumValue
    end
  end
  return 2
end

local function GetContainerStackCount(bag, slot)
  if C_Container and C_Container.GetContainerItemInfo then
    local info = C_Container.GetContainerItemInfo(bag, slot)
    return (info and (info.stackCount or info.quantity)) or 1
  end
  if GetContainerItemInfo then
    local _, count = GetContainerItemInfo(bag, slot)
    return count or 1
  end
  return 1
end

local function BuildSellContext(entry, mode)
  if not entry or not entry.itemId then
    return nil, "Select a valid item first."
  end

  local bagCount = AuctionFlip.Portfolio.GetBagCount(entry.itemId)
  if bagCount <= 0 then
    return nil, "Item not found in your bags."
  end

  local bag, slot = AuctionFlip.Portfolio.FindItemBagSlot(entry.itemId)
  if not bag or not slot then
    return nil, "Could not find item bag slot."
  end

  local modernPosting = C_AuctionHouse and (C_AuctionHouse.PostItem or C_AuctionHouse.PostCommodity)
  local location = nil
  local isCommodity = false
  if modernPosting then
    if not ItemLocation or not ItemLocation.CreateFromBagAndSlot then
      return nil, "ItemLocation API unavailable."
    end
    location = ItemLocation:CreateFromBagAndSlot(bag, slot)
    if not location then
      return nil, "Could not create item location."
    end

    local commodityStatus = Enum and Enum.ItemCommodityStatus and Enum.ItemCommodityStatus.None or nil
    if C_AuctionHouse and C_AuctionHouse.GetItemCommodityStatus then
      commodityStatus = C_AuctionHouse.GetItemCommodityStatus(location)
    end
    isCommodity = Enum and Enum.ItemCommodityStatus and commodityStatus == Enum.ItemCommodityStatus.Commodity
  end

  local desiredQty = mode == "all" and math.max(bagCount, 1) or 1
  local stackCount = math.max(GetContainerStackCount(bag, slot), 1)
  local postLimit = desiredQty
  if modernPosting and C_AuctionHouse and C_AuctionHouse.GetAvailablePostCount then
    postLimit = math.max(C_AuctionHouse.GetAvailablePostCount(location) or desiredQty, 1)
  else
    postLimit = math.max(stackCount, 1)
  end

  local postQty = math.min(desiredQty, postLimit)
  if not isCommodity then
    postQty = math.min(postQty, stackCount)
  end
  postQty = math.max(postQty, 1)

  local suggested = entry.recommendedPrice or entry.suggestedPrice or 0
  if suggested <= 0 then
    local minProfit = AuctionFlip.Config.Get("profit_threshold") or 0
    suggested = (entry.purchasePrice or 0) + minProfit
  end
  suggested = NormalizeAuctionPrice(suggested)
  if suggested <= 0 then
    suggested = NormalizeAuctionPrice((entry.purchasePrice or 0) + 100)
  end

  return {
    entry = entry,
    itemId = entry.itemId,
    itemName = entry.itemName or ("Item " .. tostring(entry.itemId)),
    icon = entry.icon or 134400,
    location = location,
    bag = bag,
    slot = slot,
    legacyMode = not modernPosting,
    bagCount = bagCount,
    stackCount = stackCount,
    desiredQty = desiredQty,
    postQty = postQty,
    partial = postQty < desiredQty,
    unitBuyout = suggested,
    mode = mode or "single",
    isCommodity = isCommodity and true or false,
  }, nil
end

local function ComputeSellDeposit(context, durationHours)
  if not context then
    return 0
  end
  local durationEnum = GetDurationEnum(durationHours or 24)

  local deposit = 0
  if context.legacyMode and GetAuctionDeposit then
    deposit = GetAuctionDeposit(durationEnum, context.postQty, 1) or 0
  elseif context.isCommodity and C_AuctionHouse and C_AuctionHouse.CalculateCommodityDeposit then
    deposit = C_AuctionHouse.CalculateCommodityDeposit(context.itemId, durationEnum, context.postQty) or 0
  elseif C_AuctionHouse and C_AuctionHouse.CalculateItemDeposit then
    deposit = C_AuctionHouse.CalculateItemDeposit(context.location, durationEnum, context.postQty) or 0
  end

  return math.max(math.floor(tonumber(deposit) or 0), 0)
end

local function PlaySaleSuccessSound()
  if PlaySound then
    if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
      PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "Master")
      return
    end
    PlaySound(856)
  end
end

local function ConfirmPendingSale(quantityPosted, source)
  local pending = AuctionFlip.UI.PendingSale
  if not pending then
    return false
  end

  local qty = math.max(math.floor(tonumber(quantityPosted) or pending.quantity or 1), 1)
  AuctionFlip.UI.PendingSale = nil

  if AuctionFlip.Portfolio and AuctionFlip.Portfolio.MarkPosted then
    AuctionFlip.Portfolio.MarkPosted(pending.itemId, qty)
  end
  if AuctionFlip.UI.RefreshSelling then
    AuctionFlip.UI.RefreshSelling()
  end

  AuctionFlip.UI.SetActivityMessage("Sale posted: " .. (pending.itemName or "item") .. " | Qty " .. tostring(qty))
  AuctionFlip.Utilities.Print("Sale confirmed for " .. (pending.itemName or "item") ..
    " (" .. tostring(qty) .. " units)." .. (source and (" [" .. tostring(source) .. "]") or ""))
  PlaySaleSuccessSound()
  return true
end

local function FailPendingSale(reason)
  local pending = AuctionFlip.UI.PendingSale
  if not pending then
    return false
  end

  AuctionFlip.UI.PendingSale = nil
  local message = reason and tostring(reason) or "Could not post auction."
  AuctionFlip.UI.SetActivityMessage("Sale failed: " .. (pending.itemName or "item") .. ". " .. message)
  AuctionFlip.Utilities.Print("Sale failed for " .. (pending.itemName or "item") .. ": " .. message)
  return true
end

local function CheckPendingSaleByBagDelta(source)
  local pending = AuctionFlip.UI.PendingSale
  if not pending or not pending.itemId then
    return false
  end

  local beforeCount = math.max(tonumber(pending.beforeBagCount) or 0, 0)
  local currentCount = AuctionFlip.Portfolio.GetBagCount(pending.itemId)
  local delta = math.max(beforeCount - currentCount, 0)
  if delta > 0 then
    local qty = math.min(delta, math.max(tonumber(pending.quantity) or delta, 1))
    return ConfirmPendingSale(qty, source or "BAG_UPDATE_DELAYED")
  end

  return false
end

local function SubmitSaleContext(context, durationHours)
  if not context then
    return false, "No sale context."
  end

  local quantity = math.max(math.floor(tonumber(context.postQty) or 1), 1)
  local buyout = NormalizeAuctionPrice(context.unitBuyout or 0)
  if buyout <= 0 then
    return false, "Buyout price must be greater than zero."
  end

  local durationEnum = GetDurationEnum(durationHours or 24)

  local okCall, postResult = false, nil
  if context.legacyMode then
    if not StartAuction or not PickupContainerItem then
      return false, "Legacy auction APIs unavailable."
    end
    okCall, postResult = pcall(function()
      if ClearCursor then
        ClearCursor()
      end
      PickupContainerItem(context.bag, context.slot)
      if ClickAuctionSellItemButton then
        ClickAuctionSellItemButton()
      end
      StartAuction(buyout, buyout, durationEnum, quantity, 1)
    end)
  elseif context.isCommodity then
    if not C_AuctionHouse or not C_AuctionHouse.PostCommodity then
      return false, "PostCommodity API unavailable."
    end
    okCall, postResult = pcall(C_AuctionHouse.PostCommodity, context.location, durationEnum, quantity, buyout)
  else
    if not C_AuctionHouse or not C_AuctionHouse.PostItem then
      return false, "PostItem API unavailable."
    end
    okCall, postResult = pcall(C_AuctionHouse.PostItem, context.location, durationEnum, quantity, nil, buyout)
  end

  if not okCall then
    return false, tostring(postResult)
  end
  if postResult == false then
    return false, "Auction House rejected the post request."
  end

  AuctionFlip.UI.PendingSale = {
    itemId = context.itemId,
    itemName = context.itemName,
    quantity = quantity,
    unitBuyout = buyout,
    mode = context.mode,
    beforeBagCount = AuctionFlip.Portfolio.GetBagCount(context.itemId),
    submittedAt = time(),
  }

  C_Timer.After(1.0, function()
    CheckPendingSaleByBagDelta("post_check_1s")
  end)
  C_Timer.After(3.0, function()
    CheckPendingSaleByBagDelta("post_check_3s")
  end)

  return true, nil
end

local function ParseGoldInputToCopper(text)
  local raw = tostring(text or "")
  if raw == "" then
    return nil
  end

  local compact = string.lower(raw):gsub("%s+", "")
  local g = compact:match("([%d%.%,]+)g")
  local s = compact:match("([%d%.%,]+)s")
  local c = compact:match("([%d%.%,]+)c")
  if g or s or c then
    local goldText = (g or "0"):gsub(",", ".")
    local silverText = (s or "0"):gsub(",", ".")
    local copperText = (c or "0"):gsub(",", ".")
    local gold = tonumber(goldText) or 0
    local silver = tonumber(silverText) or 0
    local copper = tonumber(copperText) or 0
    return NormalizeAuctionPrice(math.floor((gold * 10000) + (silver * 100) + copper + 0.5))
  end

  local numericText = raw:gsub(",", ".")
  local numeric = tonumber(numericText)
  if not numeric then
    return nil
  end
  return NormalizeAuctionPrice(math.floor((numeric * 10000) + 0.5))
end

local function CopperToGoldInput(copper)
  local value = math.max(tonumber(copper) or 0, 0) / 10000
  return string.format("%.2f", value)
end

local function GetSuggestedUnitBuyoutForContext(context)
  if not context or not context.entry then
    return 0
  end

  local suggested = context.entry.recommendedPrice or context.entry.suggestedPrice or context.unitBuyout or 0
  if suggested <= 0 then
    local minProfit = AuctionFlip.Config.Get("profit_threshold") or 0
    suggested = (context.entry.purchasePrice or 0) + minProfit
  end
  return NormalizeAuctionPrice(suggested)
end

local function ComputeSellNetProfit(context, durationHours)
  if not context then
    return 0, 0, 0, 0
  end

  local qty = math.max(math.floor(tonumber(context.postQty) or 1), 1)
  local unit = NormalizeAuctionPrice(context.unitBuyout or 0)
  local saleRevenue = unit * qty
  local ahCutPercent = AuctionFlip.Config.Get("ah_cut_percent") or 5
  local ahFee = math.floor(saleRevenue * (ahCutPercent / 100))
  local deposit = ComputeSellDeposit(context, durationHours)
  local costBasis = math.max(math.floor(tonumber(context.entry and context.entry.purchasePrice or 0) or 0), 0) * qty
  local net = saleRevenue - ahFee - deposit - costBasis
  return net, ahFee, deposit, costBasis
end

local function FormatMarketUpdateTimestamp(epochSeconds)
  local ts = tonumber(epochSeconds)
  if not ts or ts <= 0 then
    return "--"
  end

  local clock = date("%H:%M:%S", ts) or "--:--:--"
  local now = time()
  local age = math.max((now or ts) - ts, 0)
  if age < 60 then
    return string.format("%s (%ds ago)", clock, age)
  end
  local minutes = math.floor(age / 60)
  return string.format("%s (%dm ago)", clock, minutes)
end

function AuctionFlip.UI.ShowSellConfirmation(context, onConfirm)
  if not context then
    return
  end

  local win = AuctionFlip.UI.SellConfirmWindow
  if not win then
    win = CreateFrame("Frame", "AuctionFlipSellConfirmWindow", UIParent, "BackdropTemplate")
    win:SetSize(470, 390)
    win:SetFrameStrata("TOOLTIP")
    win:SetFrameLevel((AuctionFlip.UI.Frame and AuctionFlip.UI.Frame:GetFrameLevel() or 100) + 92)
    win:SetToplevel(true)
    win:EnableMouse(true)
    win:SetMovable(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", function(self) self:StartMoving() end)
    win:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    win:SetClampedToScreen(true)
    win:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    win:SetBackdropColor(0.03, 0.03, 0.05, 0.98)
    win:SetBackdropBorderColor(unpack(THEME.border))

    local title = win:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetTextColor(unpack(THEME.gold))
    ApplyNeonFont(title, 13, "OUTLINE")
    win.title = title

    local itemLine = win:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    itemLine:SetPoint("TOPLEFT", 12, -36)
    itemLine:SetPoint("RIGHT", -12, 0)
    itemLine:SetJustifyH("LEFT")
    itemLine:SetTextColor(unpack(THEME.text))
    win.itemLine = itemLine

    local modeLine = win:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    modeLine:SetPoint("TOPLEFT", itemLine, "BOTTOMLEFT", 0, -4)
    modeLine:SetPoint("RIGHT", -12, 0)
    modeLine:SetJustifyH("LEFT")
    modeLine:SetTextColor(unpack(THEME.textDim))
    win.modeLine = modeLine

    local durationLabel = win:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    durationLabel:SetPoint("TOPLEFT", modeLine, "BOTTOMLEFT", 0, -12)
    durationLabel:SetText("Duration")
    durationLabel:SetTextColor(unpack(THEME.gold))

    win.durationButtons = {}
    local prevBtn = nil
    for i, d in ipairs(SELL_DURATIONS) do
      local btn = AuctionFlip.UI.CreateFlatButton(win, d.label, 52, 22)
      if i == 1 then
        btn:SetPoint("LEFT", durationLabel, "RIGHT", 14, 0)
      else
        btn:SetPoint("LEFT", prevBtn, "RIGHT", 6, 0)
      end
      btn.hours = d.hours
      btn:SetScript("OnClick", function(self)
        win.selectedDuration = self.hours
        for _, entry in ipairs(win.durationButtons) do
          entry._isActive = entry.hours == win.selectedDuration
          if entry._paint then
            entry._paint(entry, false, false)
          end
        end
        if win.RefreshData then
          win.RefreshData()
        end
      end)
      table.insert(win.durationButtons, btn)
      prevBtn = btn
    end

    local buyoutLabel = win:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    buyoutLabel:SetPoint("TOPLEFT", durationLabel, "BOTTOMLEFT", 0, -14)
    buyoutLabel:SetText("Sell / unit (gold):")
    buyoutLabel:SetTextColor(unpack(THEME.textDim))

    local buyoutEdit = CreateFrame("EditBox", nil, win, "InputBoxTemplate")
    buyoutEdit:SetSize(90, 22)
    buyoutEdit:SetAutoFocus(false)
    buyoutEdit:SetPoint("LEFT", buyoutLabel, "RIGHT", 10, 0)
    win.buyoutEdit = buyoutEdit

    local suggestedBtn = AuctionFlip.UI.CreateFlatButton(win, "Use Suggested", 110, 22)
    suggestedBtn:SetPoint("LEFT", buyoutEdit, "RIGHT", 8, 0)
    win.useSuggestedBtn = suggestedBtn

    local buyoutValue = win:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    buyoutValue:SetPoint("TOPLEFT", buyoutLabel, "BOTTOMLEFT", 0, -6)
    buyoutValue:SetTextColor(unpack(THEME.gold))
    win.buyoutValue = buyoutValue

    local qtyLabel = win:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    qtyLabel:SetPoint("TOPLEFT", buyoutValue, "BOTTOMLEFT", 0, -10)
    qtyLabel:SetText("Quantity to post:")
    qtyLabel:SetTextColor(unpack(THEME.textDim))

    local qtyValue = win:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    qtyValue:SetPoint("LEFT", qtyLabel, "RIGHT", 10, 0)
    qtyValue:SetTextColor(unpack(THEME.text))
    win.qtyValue = qtyValue

    local cheapestLabel = win:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    cheapestLabel:SetPoint("TOPLEFT", qtyLabel, "BOTTOMLEFT", 0, -8)
    cheapestLabel:SetText("Cheapest AH listing:")
    cheapestLabel:SetTextColor(unpack(THEME.textDim))

    local cheapestValue = win:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    cheapestValue:SetPoint("LEFT", cheapestLabel, "RIGHT", 10, 0)
    cheapestValue:SetTextColor(unpack(THEME.text))
    win.cheapestValue = cheapestValue

    local refreshMinBtn = AuctionFlip.UI.CreateFlatButton(win, "Refresh AH Min", 110, 22)
    refreshMinBtn:SetPoint("LEFT", cheapestValue, "RIGHT", 8, 0)
    win.refreshMinBtn = refreshMinBtn

    local lastUpdateLabel = win:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    lastUpdateLabel:SetPoint("TOPLEFT", cheapestLabel, "BOTTOMLEFT", 0, -8)
    lastUpdateLabel:SetText("Last AH min update:")
    lastUpdateLabel:SetTextColor(unpack(THEME.textDim))

    local lastUpdateValue = win:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    lastUpdateValue:SetPoint("LEFT", lastUpdateLabel, "RIGHT", 10, 0)
    lastUpdateValue:SetTextColor(unpack(THEME.text))
    win.lastUpdateValue = lastUpdateValue

    local depositLabel = win:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    depositLabel:SetPoint("TOPLEFT", lastUpdateLabel, "BOTTOMLEFT", 0, -8)
    depositLabel:SetText("Deposit:")
    depositLabel:SetTextColor(unpack(THEME.textDim))

    local depositValue = win:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    depositValue:SetPoint("LEFT", depositLabel, "RIGHT", 10, 0)
    depositValue:SetTextColor(unpack(THEME.text))
    win.depositValue = depositValue

    local feeLabel = win:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    feeLabel:SetPoint("TOPLEFT", depositLabel, "BOTTOMLEFT", 0, -8)
    feeLabel:SetText("AH fee:")
    feeLabel:SetTextColor(unpack(THEME.textDim))

    local feeValue = win:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    feeValue:SetPoint("LEFT", feeLabel, "RIGHT", 10, 0)
    feeValue:SetTextColor(unpack(THEME.text))
    win.feeValue = feeValue

    local costLabel = win:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    costLabel:SetPoint("TOPLEFT", feeLabel, "BOTTOMLEFT", 0, -8)
    costLabel:SetText("Cost basis:")
    costLabel:SetTextColor(unpack(THEME.textDim))

    local costValue = win:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    costValue:SetPoint("LEFT", costLabel, "RIGHT", 10, 0)
    costValue:SetTextColor(unpack(THEME.text))
    win.costValue = costValue

    local totalLabel = win:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    totalLabel:SetPoint("TOPLEFT", costLabel, "BOTTOMLEFT", 0, -8)
    totalLabel:SetText("Total buyout:")
    totalLabel:SetTextColor(unpack(THEME.textDim))

    local totalValue = win:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    totalValue:SetPoint("LEFT", totalLabel, "RIGHT", 10, 0)
    totalValue:SetTextColor(unpack(THEME.green))
    win.totalValue = totalValue

    local profitLabel = win:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    profitLabel:SetPoint("TOPLEFT", totalLabel, "BOTTOMLEFT", 0, -8)
    profitLabel:SetText("Estimated net profit:")
    profitLabel:SetTextColor(unpack(THEME.textDim))

    local profitValue = win:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    profitValue:SetPoint("LEFT", profitLabel, "RIGHT", 10, 0)
    profitValue:SetTextColor(unpack(THEME.green))
    win.profitValue = profitValue

    local warning = win:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    warning:SetPoint("TOPLEFT", profitLabel, "BOTTOMLEFT", 0, -10)
    warning:SetPoint("RIGHT", -12, 0)
    warning:SetJustifyH("LEFT")
    warning:SetTextColor(unpack(THEME.red))
    warning:SetText("")
    win.warningText = warning

    local confirmBtn = AuctionFlip.UI.CreateFlatButton(win, "Confirm Sell", 120, 24)
    confirmBtn:SetPoint("BOTTOMRIGHT", -12, 12)
    confirmBtn:SetScript("OnClick", function()
      local cb = win.onConfirm
      local ctx = win.context
      local duration = win.selectedDuration or 24
      win.onConfirm = nil
      win:Hide()
      if cb and ctx then
        cb(ctx, duration)
      end
    end)
    win.confirmBtn = confirmBtn

    local cancelBtn = AuctionFlip.UI.CreateFlatButton(win, "Cancel", 90, 24)
    cancelBtn:SetPoint("RIGHT", confirmBtn, "LEFT", -8, 0)
    cancelBtn:SetScript("OnClick", function()
      win.onConfirm = nil
      win:Hide()
      AuctionFlip.UI.SetActivityMessage("Sale canceled.")
    end)
    win.cancelBtn = cancelBtn

    local helpBtn = AuctionFlip.UI.CreateFlatButton(win, "Help", 70, 24)
    helpBtn:SetPoint("RIGHT", cancelBtn, "LEFT", -8, 0)
    helpBtn:SetScript("OnClick", function()
      AuctionFlip.UI.ShowContextHelpWindow(
        "sell_confirm",
        "Sell Confirmation Help",
        "Guide to sell pricing, market refresh, costs and net profit fields.",
        SELL_CONFIRM_HELP_TEXT,
        AuctionFlip.UI.SellConfirmWindow or AuctionFlip.UI.Frame,
        560,
        500
      )
    end)
    win.helpBtn = helpBtn

    local closeBtn = AuctionFlip.UI.CreateFlatButton(win, "X", 24, 22)
    closeBtn:SetPoint("TOPRIGHT", -8, -8)
    closeBtn:SetScript("OnClick", function()
      win.onConfirm = nil
      win:Hide()
      AuctionFlip.UI.SetActivityMessage("Sale canceled.")
    end)
    win.closeBtn = closeBtn

    local function RefreshSuggestedButtonState()
      if not win.useSuggestedBtn then
        return
      end
      if win.userEditedPrice then
        if win.useSuggestedBtn.text then
          win.useSuggestedBtn.text:SetText("Use Suggested")
        end
      else
        if win.useSuggestedBtn.text then
          win.useSuggestedBtn.text:SetText("Auto Suggested")
        end
      end
    end

    suggestedBtn:SetScript("OnClick", function()
      local ctx = win.context
      if not ctx then
        return
      end
      ctx.autoPrice = true
      ctx.unitBuyout = GetSuggestedUnitBuyoutForContext(ctx)
      win.userEditedPrice = false
      RefreshSuggestedButtonState()
      if win.RefreshData then
        win.RefreshData()
      end
    end)

    refreshMinBtn:SetScript("OnClick", function()
      local ctx = win.context
      if not ctx or not ctx.entry then
        return
      end
      if not AuctionFlip.Portfolio or not AuctionFlip.Portfolio.UpdateMarketForEntry then
        return
      end

      AuctionFlip.UI.SetActivityMessage("Refreshing AH min for " .. (ctx.itemName or "item") .. "...")
      AuctionFlip.Portfolio.UpdateMarketForEntry(ctx.entry, function()
        if win:IsShown() and win.RefreshData then
          if ctx.autoPrice and not win.userEditedPrice then
            ctx.unitBuyout = GetSuggestedUnitBuyoutForContext(ctx)
          end
          win.RefreshData()
        end
        local cheapestNow = ctx.entry and ctx.entry.currentMinPrice or nil
        if cheapestNow and cheapestNow > 0 then
          AuctionFlip.UI.SetActivityMessage("AH min updated: " .. AuctionFlip.Utilities.CreatePaddedMoneyString(cheapestNow))
        else
          AuctionFlip.UI.SetActivityMessage("AH min unavailable right now for " .. (ctx.itemName or "item") .. ".")
        end
      end)
    end)

    buyoutEdit:SetScript("OnTextChanged", function(self, userInput)
      if not userInput or win._syncingBuyoutEdit then
        return
      end
      local parsed = ParseGoldInputToCopper(self:GetText())
      local ctx = win.context
      if parsed and ctx then
        ctx.unitBuyout = parsed
        ctx.autoPrice = false
        win.userEditedPrice = true
        RefreshSuggestedButtonState()
        if win.RefreshData then
          win.RefreshData()
        end
      end
    end)
    buyoutEdit:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
      if win.RefreshData then
        win.RefreshData()
      end
    end)
    buyoutEdit:SetScript("OnEscapePressed", function(self)
      self:ClearFocus()
      local ctx = win.context
      if ctx then
        win._syncingBuyoutEdit = true
        self:SetText(CopperToGoldInput(ctx.unitBuyout or 0))
        self:HighlightText(0, 0)
        win._syncingBuyoutEdit = false
      end
    end)

    win.RefreshData = function()
      local ctx = win.context
      if not ctx then
        return
      end
      local duration = win.selectedDuration or 24
      for _, btn in ipairs(win.durationButtons) do
        btn._isActive = btn.hours == duration
        if btn._paint then
          btn._paint(btn, false, false)
        end
      end

      if ctx.autoPrice and not win.userEditedPrice then
        ctx.unitBuyout = GetSuggestedUnitBuyoutForContext(ctx)
      end

      local qty = math.max(ctx.postQty or 1, 1)
      local total = (ctx.unitBuyout or 0) * qty
      local netProfit, ahFee, deposit, costBasis = ComputeSellNetProfit(ctx, duration)
      local cheapest = ctx.entry and ctx.entry.currentMinPrice or nil
      local lastCheckAt = ctx.entry and ctx.entry.lastMarketCheckAt or nil

      win.title:SetText((ctx.mode == "all" and "Sell All" or "Sell 1") .. " Confirmation")
      win.itemLine:SetText("Item: " .. (ctx.itemName or "Unknown Item"))
      win.modeLine:SetText(
        (ctx.isCommodity and "Commodity market" or "Item listing") ..
        " | Bags: " .. tostring(ctx.bagCount or 0) ..
        " | Stack: " .. tostring(ctx.stackCount or 0)
      )
      if win.buyoutEdit then
        win._syncingBuyoutEdit = true
        win.buyoutEdit:SetText(CopperToGoldInput(ctx.unitBuyout or 0))
        win.buyoutEdit:HighlightText(0, 0)
        win._syncingBuyoutEdit = false
      end
      RefreshSuggestedButtonState()
      win.buyoutValue:SetText(AuctionFlip.Utilities.CreatePaddedMoneyString(ctx.unitBuyout or 0))
      win.qtyValue:SetText(tostring(qty))
      win.cheapestValue:SetText(cheapest and AuctionFlip.Utilities.CreatePaddedMoneyString(cheapest) or "--")
      win.lastUpdateValue:SetText(FormatMarketUpdateTimestamp(lastCheckAt))
      win.depositValue:SetText(AuctionFlip.Utilities.CreatePaddedMoneyString(deposit))
      win.feeValue:SetText(AuctionFlip.Utilities.CreatePaddedMoneyString(ahFee))
      win.costValue:SetText(AuctionFlip.Utilities.CreatePaddedMoneyString(costBasis))
      win.totalValue:SetText(AuctionFlip.Utilities.CreatePaddedMoneyString(total))
      if netProfit >= 0 then
        win.profitValue:SetTextColor(unpack(THEME.green))
        win.profitValue:SetText("+" .. AuctionFlip.Utilities.CreatePaddedMoneyString(netProfit))
      else
        win.profitValue:SetTextColor(unpack(THEME.red))
        win.profitValue:SetText(AuctionFlip.Utilities.CreatePaddedMoneyString(netProfit))
      end

      local warningLines = {}
      local severeWarning = false
      if ctx.partial then
        table.insert(warningLines, "Note: Only " .. tostring(ctx.postQty or 0) ..
          " units can be posted now (bag/stack/AH post limit).")
      end
      if cheapest and cheapest > 0 and (ctx.unitBuyout or 0) > cheapest then
        table.insert(warningLines, "Warning: Your sell price is above current AH cheapest listing.")
      end
      if netProfit < 0 then
        severeWarning = true
        table.insert(warningLines, "Warning: Estimated loss at this price: " .. AuctionFlip.Utilities.CreatePaddedMoneyString(netProfit) .. ".")
      end

      if #warningLines > 0 then
        if severeWarning then
          win.warningText:SetTextColor(unpack(THEME.red))
        else
          win.warningText:SetTextColor(unpack(THEME.goldDim))
        end
        win.warningText:SetText(table.concat(warningLines, "\n"))
      else
        win.warningText:SetText("")
      end
    end

    AuctionFlip.UI.SellConfirmWindow = win
  end

  win.context = context
  win.context.autoPrice = true
  win.userEditedPrice = false
  win.selectedDuration = 24
  win.onConfirm = onConfirm
  if win.RefreshData then
    win.RefreshData()
  end

  if context.entry and AuctionFlip.Portfolio and AuctionFlip.Portfolio.UpdateMarketForEntry then
    AuctionFlip.Portfolio.UpdateMarketForEntry(context.entry, function()
      if win:IsShown() and win.RefreshData then
        if context.autoPrice and not win.userEditedPrice then
          context.unitBuyout = GetSuggestedUnitBuyoutForContext(context)
        end
        win.RefreshData()
      end
    end)
  end

  win.marketRefreshSeq = (win.marketRefreshSeq or 0) + 1
  local refreshSeq = win.marketRefreshSeq
  local function refreshMarketLoop()
    if not win:IsShown() or win.marketRefreshSeq ~= refreshSeq then
      return
    end

    local ctx = win.context
    if ctx and ctx.entry and AuctionFlip.Portfolio and AuctionFlip.Portfolio.UpdateMarketForEntry then
      AuctionFlip.Portfolio.UpdateMarketForEntry(ctx.entry, function()
        if not win:IsShown() or win.marketRefreshSeq ~= refreshSeq then
          return
        end
        if ctx.autoPrice and not win.userEditedPrice then
          ctx.unitBuyout = GetSuggestedUnitBuyoutForContext(ctx)
        end
        if win.RefreshData then
          win.RefreshData()
        end
      end)
    end

    C_Timer.After(8, refreshMarketLoop)
  end
  C_Timer.After(8, refreshMarketLoop)

  win:ClearAllPoints()
  if AuctionFlip.UI and AuctionFlip.UI.Frame and AuctionFlip.UI.Frame:IsShown() then
    win:SetPoint("CENTER", AuctionFlip.UI.Frame, "CENTER", 0, 0)
  else
    win:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end
  win:Show()
  win:Raise()
end

function AuctionFlip.UI.OpenSellConfirmation(mode)
  local entry = AuctionFlip.Portfolio.GetSelectedEntry and AuctionFlip.Portfolio.GetSelectedEntry() or nil
  if not entry then
    AuctionFlip.Utilities.Print("Select a purchased item in Selling tab first.")
    return
  end

  local context, contextErr = BuildSellContext(entry, mode or "single")
  if not context then
    AuctionFlip.Utilities.Print(contextErr or "Could not prepare sale.")
    return
  end

  AuctionFlip.UI.SetActivityMessage("Review sale confirmation for " .. (context.itemName or "item") .. ".")
  AuctionFlip.UI.ShowSellConfirmation(context, function(ctx, durationHours)
    local ok, err = SubmitSaleContext(ctx, durationHours)
    if not ok then
      AuctionFlip.UI.SetActivityMessage("Sale could not be submitted for " .. (ctx.itemName or "item") .. ".")
      AuctionFlip.Utilities.Print("Sale failed: " .. tostring(err or "unknown error"))
      return
    end

    local durationLabel = tostring(durationHours or 24) .. "h"
    AuctionFlip.UI.SetActivityMessage("Sale submitted: " .. (ctx.itemName or "item") ..
      " | Qty " .. tostring(ctx.postQty or 1) .. " | Duration " .. durationLabel .. ". Waiting confirmation...")
    AuctionFlip.Utilities.Print("Sell submitted for " .. (ctx.itemName or "item") ..
      " (" .. tostring(ctx.postQty or 1) .. " units, " .. durationLabel .. ").")
  end)
end

function AuctionFlip.UI.RunGuidedPosting()
  AuctionFlip.UI.OpenSellConfirmation("all")
end

local function RegisterEventSafe(frame, eventName)
  local ok = pcall(frame.RegisterEvent, frame, eventName)
  if not ok and AuctionFlip.Utilities and AuctionFlip.Utilities.Debug then
    AuctionFlip.Utilities.Debug("Skipping unavailable event: " .. tostring(eventName))
  end
end

local saleEventFrame = CreateFrame("Frame")
RegisterEventSafe(saleEventFrame, "AUCTION_MULTISELL_START")
RegisterEventSafe(saleEventFrame, "AUCTION_MULTISELL_UPDATE")
RegisterEventSafe(saleEventFrame, "AUCTION_MULTISELL_FAILURE")
RegisterEventSafe(saleEventFrame, "BAG_UPDATE_DELAYED")
RegisterEventSafe(saleEventFrame, "UI_ERROR_MESSAGE")
saleEventFrame:SetScript("OnEvent", function(_, event, ...)
  if event == "AUCTION_MULTISELL_START" then
    return
  end

  if event == "AUCTION_MULTISELL_UPDATE" then
    local posted, total = ...
    local qty = math.max(tonumber(posted) or tonumber(total) or 0, 0)
    if qty > 0 then
      ConfirmPendingSale(qty, "AUCTION_MULTISELL_UPDATE")
    else
      CheckPendingSaleByBagDelta("AUCTION_MULTISELL_UPDATE")
    end
    return
  end

  if event == "AUCTION_MULTISELL_FAILURE" then
    FailPendingSale("Auction post failed.")
    return
  end

  if event == "BAG_UPDATE_DELAYED" then
    CheckPendingSaleByBagDelta("BAG_UPDATE_DELAYED")
    return
  end

  if event == "UI_ERROR_MESSAGE" then
    local _, errorText = ...
    if AuctionFlip.UI.PendingSale then
      local text = tostring(errorText or "")
      if text ~= "" then
        FailPendingSale(text)
      end
    end
  end
end)

local purchaseEventFrame = CreateFrame("Frame")
RegisterEventSafe(purchaseEventFrame, "COMMODITY_PRICE_UPDATED")
RegisterEventSafe(purchaseEventFrame, "COMMODITY_PRICE_UNAVAILABLE")
RegisterEventSafe(purchaseEventFrame, "COMMODITY_PURCHASE_SUCCEEDED")
RegisterEventSafe(purchaseEventFrame, "COMMODITY_PURCHASE_FAILED")
RegisterEventSafe(purchaseEventFrame, "COMMODITY_PURCHASED")
RegisterEventSafe(purchaseEventFrame, "ITEM_PURCHASED")
RegisterEventSafe(purchaseEventFrame, "UI_ERROR_MESSAGE")
purchaseEventFrame:SetScript("OnEvent", function(_, event, ...)
  if event == "COMMODITY_PRICE_UPDATED" then
    local active = AuctionFlip.UI.ActiveCommodityPurchase
    if active and active.stage == "started" and C_AuctionHouse and C_AuctionHouse.ConfirmCommoditiesPurchase then
      local okConfirm, confirmErr = pcall(C_AuctionHouse.ConfirmCommoditiesPurchase, active.itemId, active.quantity)
      if okConfirm then
        active.stage = "confirm_sent"
        AuctionFlip.UI.SetActivityMessage("Commodity confirmation sent for item " .. tostring(active.itemId) .. ".")
      else
        FailPendingPurchase(active.token, "Commodity confirm failed: " .. tostring(confirmErr), true)
      end
    end
    return
  end

  if event == "COMMODITY_PRICE_UNAVAILABLE" then
    local active = AuctionFlip.UI.ActiveCommodityPurchase
    if active then
      FailPendingPurchase(active.token, "Commodity price unavailable.", true)
    end
    return
  end

  if event == "COMMODITY_PURCHASED" then
    local itemId, quantity = ...
    if type(itemId) == "table" and itemId.itemID then
      itemId = itemId.itemID
    end
    if itemId then
      if not ConfirmPendingPurchase(itemId, quantity, "COMMODITY_PURCHASED", false, true) then
        local active = AuctionFlip.UI.ActiveCommodityPurchase
        if active then
          ConfirmPendingPurchase(active.token, quantity, "COMMODITY_PURCHASED", true)
        end
      end
    else
      local active = AuctionFlip.UI.ActiveCommodityPurchase
      if active then
        ConfirmPendingPurchase(active.token, nil, "COMMODITY_PURCHASED", true)
      end
    end
    return
  end

  if event == "COMMODITY_PURCHASE_SUCCEEDED" then
    local itemId, quantity = ...
    if type(itemId) == "table" and itemId.itemID then
      itemId = itemId.itemID
    end
    if itemId then
      if not ConfirmPendingPurchase(itemId, quantity, "COMMODITY_PURCHASE_SUCCEEDED", false, true) then
        local active = AuctionFlip.UI.ActiveCommodityPurchase
        if active then
          ConfirmPendingPurchase(active.token, quantity, "COMMODITY_PURCHASE_SUCCEEDED", true)
        end
      end
    else
      local active = AuctionFlip.UI.ActiveCommodityPurchase
      if active then
        ConfirmPendingPurchase(active.token, nil, "COMMODITY_PURCHASE_SUCCEEDED", true)
      end
    end
    return
  end

  if event == "COMMODITY_PURCHASE_FAILED" then
    local itemId = ...
    if type(itemId) == "table" and itemId.itemID then
      itemId = itemId.itemID
    end
    if itemId then
      if not FailPendingPurchase(itemId, "Commodity purchase failed.", false, true) then
        local active = AuctionFlip.UI.ActiveCommodityPurchase
        if active then
          FailPendingPurchase(active.token, "Commodity purchase failed.", true)
        end
      end
    else
      local active = AuctionFlip.UI.ActiveCommodityPurchase
      if active then
        FailPendingPurchase(active.token, "Commodity purchase failed.", true)
      end
    end
    return
  end

  if event == "ITEM_PURCHASED" then
    local itemId, quantity = ...
    if type(itemId) == "table" and itemId.itemID then
      itemId = itemId.itemID
    end
    if itemId then
      ConfirmPendingPurchase(itemId, quantity, "ITEM_PURCHASED", false, false)
    end
    return
  end

  if event == "UI_ERROR_MESSAGE" then
    local _, errorText = ...
    local active = AuctionFlip.UI.ActiveCommodityPurchase
    if active then
      local text = tostring(errorText or "")
      if text ~= "" then
        FailPendingPurchase(active.token, text, true)
      end
    end
  end
end)

function AuctionFlip.UI.RefreshSelling()
  if not AuctionFlip.UI.Frame then return end
  local content = AuctionFlip.UI.Frame.mainTabContents[2]
  if not content or not content.sellingRows or not content.sellingScrollFrame then return end

  local items = AuctionFlip.Portfolio.GetItems()
  local selectedEntry = items[AuctionFlip.Portfolio.SelectedIndex or 0]
  local canSell = selectedEntry and (selectedEntry.bagCount or 0) > 0
  if content.sellOneBtn then
    if canSell then content.sellOneBtn:Enable() else content.sellOneBtn:Disable() end
  end
  if content.sellAllBtn then
    if canSell then content.sellAllBtn:Enable() else content.sellAllBtn:Disable() end
  end
  if content.sellingInfoText then
    if selectedEntry then
      content.sellingInfoText:SetText(
        "Selected: " .. (selectedEntry.itemName or "item") ..
        " | Bags: " .. tostring(selectedEntry.bagCount or 0) ..
        " | Suggested: " .. AuctionFlip.Utilities.CreateCompactMoneyString(selectedEntry.recommendedPrice or selectedEntry.suggestedPrice or 0)
      )
    else
      content.sellingInfoText:SetText("Select an item, refresh AH min, then open Sell 1 or Sell All confirmation.")
    end
  end

  FauxScrollFrame_Update(content.sellingScrollFrame, #items, 11, 22)
  local offset = FauxScrollFrame_GetOffset(content.sellingScrollFrame)

  for i = 1, 11 do
    local row = content.sellingRows[i]
    local index = i + offset
    local entry = items[index]
    if row and entry then
      local displayName = entry.itemName or "Unknown"
      if (entry.quantity or 1) > 1 then
        displayName = displayName .. " x" .. tostring(entry.quantity)
      end

      row.icon:SetTexture(entry.icon or 134400)
      row.itemText:SetText(AuctionFlip.Utilities.TruncateText(displayName, 29))
      row.bagsText:SetText(tostring(entry.bagCount or 0))
      row.buyText:SetText(AuctionFlip.Utilities.CreateCompactMoneyString(entry.purchasePrice or 0))
      row.suggestedText:SetText(AuctionFlip.Utilities.CreateCompactMoneyString(entry.recommendedPrice or entry.suggestedPrice or 0))
      row.minText:SetText(entry.currentMinPrice and AuctionFlip.Utilities.CreateCompactMoneyString(entry.currentMinPrice) or "--")
      row.statusText:SetText(AuctionFlip.Utilities.TruncateText(entry.status or "-", 26))

      if AuctionFlip.Portfolio.SelectedIndex == index then
        row.bg:SetColorTexture(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.20)
      else
        row.bg:SetColorTexture(0, 0, 0, 0)
      end

      row:SetScript("OnEnter", function(self)
        if AuctionFlip.Portfolio.SelectedIndex ~= index then
          self.bg:SetColorTexture(unpack(THEME.highlight))
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if entry.itemId then
          GameTooltip:SetHyperlink("item:" .. entry.itemId)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Status: " .. (entry.status or "-"), 1, 1, 1, true)
        GameTooltip:AddLine("Buy: " .. AuctionFlip.Utilities.CreatePaddedMoneyString(entry.purchasePrice or 0), 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Suggested: " .. AuctionFlip.Utilities.CreatePaddedMoneyString(entry.recommendedPrice or entry.suggestedPrice or 0), 0.8, 0.8, 0.8)
        if entry.currentMinPrice then
          GameTooltip:AddLine("Current AH Min: " .. AuctionFlip.Utilities.CreatePaddedMoneyString(entry.currentMinPrice), 0.8, 0.8, 0.8)
        end
        GameTooltip:Show()
      end)
      row:SetScript("OnLeave", function(self)
        if AuctionFlip.Portfolio.SelectedIndex == index then
          self.bg:SetColorTexture(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.20)
        else
          self.bg:SetColorTexture(0, 0, 0, 0)
        end
        GameTooltip:Hide()
      end)
      row:SetScript("OnClick", function()
        AuctionFlip.Portfolio.SelectedIndex = index
        AuctionFlip.UI.RefreshSelling()
      end)

      row:Show()
    elseif row then
      row:Hide()
    end
  end
end

-- REFRESH FUNCTIONS
function AuctionFlip.UI.RefreshResults()
  if not AuctionFlip.UI.Frame then return end

  local content = AuctionFlip.UI.Frame.mainTabContents[1]
  if not content or not content.subTabContents then return end

  local resultsContent = content.subTabContents[2]
  if not resultsContent or not resultsContent.resultRows then return end

  local opportunities = AuctionFlip.Opportunities.GetList()
  local filter = AuctionFlip.UI.CurrentFilter or "all"

  local filteredResults = {}
  for _, opp in ipairs(opportunities) do
    if filter == "all" or opp.type == filter then
      table.insert(filteredResults, opp)
    end
  end

  if AuctionFlip.UI.SelectedOpportunity then
    local stillVisible = false
    for _, opp in ipairs(filteredResults) do
      if opp == AuctionFlip.UI.SelectedOpportunity then
        stillVisible = true
        break
      end
    end
    if not stillVisible then
      AuctionFlip.UI.SelectedOpportunity = nil
    end
  end

  if resultsContent.countText then
    resultsContent.countText:SetText(#filteredResults .. " items")
  end
  if resultsContent.activityText then
    resultsContent.activityText:SetText(tostring(AuctionFlip.UI.ActivityMessage or ""))
  end

  -- Calculate total net profit
  local totalNetProfit = 0
  for _, opp in ipairs(filteredResults) do
    if opp.score then
      totalNetProfit = totalNetProfit + (opp.score.netProfitTotal or 0)
    else
      totalNetProfit = totalNetProfit + AuctionFlip.Opportunities.GetTotalOpportunityProfit(opp)
    end
  end
  if resultsContent.totalProfitDisplay then
    resultsContent.totalProfitDisplay:SetText(AuctionFlip.Utilities.CreateCompactMoneyString(totalNetProfit))
    resultsContent.totalProfitDisplay:SetTextColor(unpack(THEME.green))
  end

  if resultsContent.buyOneBtn then
    if AuctionFlip.UI.SelectedOpportunity then
      resultsContent.buyOneBtn:Enable()
    else
      resultsContent.buyOneBtn:Disable()
    end
  end
  if resultsContent.buyAllBtn then
    if AuctionFlip.UI.SelectedOpportunity then
      resultsContent.buyAllBtn:Enable()
    else
      resultsContent.buyAllBtn:Disable()
    end
  end

  FauxScrollFrame_Update(resultsContent.scrollFrame, #filteredResults, 12, 22)
  local offset = FauxScrollFrame_GetOffset(resultsContent.scrollFrame)

  for i = 1, 12 do
    local row = resultsContent.resultRows[i]
    local index = i + offset

    if row then
      if filteredResults[index] then
        local opp = filteredResults[index]
        local s = opp.score or {}

        -- Icon & name
        row.icon:SetTexture(opp.icon or 134400)
        row.nameText:SetText(AuctionFlip.Utilities.TruncateText(opp.itemName or "Unknown", 38))

        if opp.rarity and opp.rarity >= 2 then
          local _, _, _, hex = GetItemQualityColor(opp.rarity)
          row.nameText:SetTextColor(tonumber("0x"..hex:sub(1,2))/255, tonumber("0x"..hex:sub(3,4))/255, tonumber("0x"..hex:sub(5,6))/255)
        else
          row.nameText:SetTextColor(unpack(THEME.text))
        end

        -- Type
        row.typeText:SetText(opp.type == "vendor_flip" and "Vendor Flip" or "Underpriced")
        row.typeText:SetTextColor(opp.type == "vendor_flip" and 0.5 or 0.3, opp.type == "vendor_flip" and 1 or 0.7, opp.type == "vendor_flip" and 0.5 or 1)

        -- Buy price
        row.buyText:SetText(AuctionFlip.Utilities.CreateCompactMoneyString(opp.buyPrice))

        -- Market/sell price
        local sellPrice = s.executionSalePrice or opp.verifiedTargetSellPrice or s.fairPrice or opp.sellPrice or opp.marketPrice or 0
        row.sellText:SetText(AuctionFlip.Utilities.CreateCompactMoneyString(sellPrice))

        -- Qty
        local qty = math.max(opp.quantity or 1, 1)
        row.qtyText:SetText(AuctionFlip.Utilities.CreateCompactNumberString(qty))
        row.qtyText:SetTextColor(unpack(THEME.text))

        -- Discount%
        local discPct = s.discountPercent or opp.discount or 0
        if discPct > 0 then
          row.discountText:SetText("-" .. discPct .. "%")
          if discPct >= 30 then
            row.discountText:SetTextColor(unpack(THEME.green))
          elseif discPct >= 15 then
            row.discountText:SetTextColor(1, 1, 0)
          else
            row.discountText:SetTextColor(1, 0.8, 0.4)
          end
        else
          row.discountText:SetText("--")
          row.discountText:SetTextColor(unpack(THEME.textDim))
        end

        -- Net Profit
        local netProfit = s.netProfitTotal or AuctionFlip.Opportunities.GetTotalOpportunityProfit(opp)
        row.netProfitText:SetText(AuctionFlip.Utilities.CreateCompactMoneyString(netProfit))
        if netProfit > 100000 then
          row.netProfitText:SetTextColor(unpack(THEME.green))
        elseif netProfit > 50000 then
          row.netProfitText:SetTextColor(1, 1, 0)
        else
          row.netProfitText:SetTextColor(1, 0.8, 0.4)
        end

        -- ROI%
        local roiPct = s.roiPercent or 0
        if roiPct > 0 then
          row.roiText:SetText(roiPct .. "%")
          if roiPct >= 50 then
            row.roiText:SetTextColor(unpack(THEME.green))
          elseif roiPct >= 20 then
            row.roiText:SetTextColor(1, 1, 0)
          else
            row.roiText:SetTextColor(1, 0.8, 0.4)
          end
        else
          row.roiText:SetText("--")
          row.roiText:SetTextColor(unpack(THEME.textDim))
        end

        -- Liquidity
        local liqLabel = s.liquidityLabel or "?"
        row.liqText:SetText(liqLabel:sub(1, 1))  -- "H", "M", "L"
        if liqLabel == "High" then
          row.liqText:SetTextColor(unpack(THEME.green))
        elseif liqLabel == "Medium" then
          row.liqText:SetTextColor(1, 1, 0)
        else
          row.liqText:SetTextColor(1, 0.5, 0.3)
        end

        -- Confidence
        local confPct = s.confidencePercent or opp.marketConfidence or 0
        row.confText:SetText(confPct .. "%")
        if confPct >= 75 then
          row.confText:SetTextColor(unpack(THEME.green))
        elseif confPct >= 50 then
          row.confText:SetTextColor(1, 1, 0)
        else
          row.confText:SetTextColor(1, 0.5, 0.3)
        end

        -- Row background and tooltip
        if AuctionFlip.UI.SelectedOpportunity == opp then
          row.bg:SetColorTexture(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.20)
        else
          row.bg:SetColorTexture(0, 0, 0, 0)
        end
        row:SetScript("OnEnter", function(self)
          if AuctionFlip.UI.SelectedOpportunity ~= opp then
            self.bg:SetColorTexture(unpack(THEME.highlight))
          end
          AuctionFlip.UI.ShowOpportunityTooltip(self, opp)
        end)
        row:SetScript("OnLeave", function(self)
          if AuctionFlip.UI.SelectedOpportunity == opp then
            self.bg:SetColorTexture(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.20)
          else
            self.bg:SetColorTexture(0, 0, 0, 0)
          end
          GameTooltip:Hide()
        end)
        row:SetScript("OnClick", function()
          AuctionFlip.UI.SelectedOpportunity = opp
          AuctionFlip.UI.RefreshResults()
        end)

        row:Show()
      else
        row:SetScript("OnClick", nil)
        row:Hide()
      end
    end
  end
end

--- Rich tooltip for an opportunity row.
function AuctionFlip.UI.ShowOpportunityTooltip(anchor, opp)
  GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")

  -- Item link tooltip
  if opp.itemLink then
    GameTooltip:SetHyperlink(opp.itemLink)
  end

  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("AuctionFlip Analysis", 1, 0.84, 0)

  local s = opp.score or {}
  local money = AuctionFlip.Utilities.CreatePaddedMoneyString

  -- Prices
  GameTooltip:AddDoubleLine("Buy Price:", money(opp.buyPrice), 0.7, 0.7, 0.7, 1, 1, 1)
  local qty = math.max(opp.quantity or 1, 1)
  GameTooltip:AddDoubleLine("Quantity:", tostring(qty), 0.7, 0.7, 0.7, 1, 1, 1)
  local totalBuyCost = (s.totalBuyCost and s.totalBuyCost > 0) and s.totalBuyCost or ((opp.buyPrice or 0) * qty)
  GameTooltip:AddDoubleLine("Cost to Buy:", money(totalBuyCost), 0.7, 0.7, 0.7, 1, 1, 1)
  if s.fairPrice and s.fairPrice > 0 then
    local srcLabel = s.fairPriceSource == "median" and "median" or (s.fairPriceSource == "vendor" and "vendor" or "mean")
    GameTooltip:AddDoubleLine("Fair Price (" .. srcLabel .. "):", money(s.fairPrice), 0.7, 0.7, 0.7, 1, 1, 1)
  end
  if (s.executionSalePrice or 0) > 0 then
    GameTooltip:AddDoubleLine("Execution Sell/Unit:", money(s.executionSalePrice), 0.7, 0.7, 0.7, 0.4, 1, 0.9)
  end
  if (opp.verifiedHighestBoughtPrice or 0) > 0 then
    GameTooltip:AddDoubleLine("Highest Bought Tier:", money(opp.verifiedHighestBoughtPrice), 0.7, 0.7, 0.7, 1, 1, 1)
  end
  if (opp.verifiedNextHigherPrice or 0) > 0 then
    GameTooltip:AddDoubleLine("Next Higher Tier:", money(opp.verifiedNextHigherPrice), 0.7, 0.7, 0.7, 1, 1, 1)
  end
  if opp.verifiedSourceRows and opp.verifiedSourceRows > 0 then
    GameTooltip:AddDoubleLine("Cheap Listing Tiers:", tostring(opp.verifiedSourceRows), 0.7, 0.7, 0.7, 1, 1, 1)
  end
  if opp.verifiedDurationHours then
    GameTooltip:AddDoubleLine("Duration Model:", tostring(opp.verifiedDurationHours) .. "h", 0.7, 0.7, 0.7, 1, 1, 1)
  end
  if opp.verifiedPricingSource then
    local pricingLabel = "Historical fallback"
    if opp.verifiedPricingSource == "next_tier" then
      pricingLabel = "Next tier above bought listings"
    elseif opp.verifiedPricingSource == "historical_cap" then
      pricingLabel = "Historical cap below next tier"
    end
    GameTooltip:AddDoubleLine("Pricing Rule:", pricingLabel, 0.7, 0.7, 0.7, 0.8, 0.95, 1)
  end

  -- Discount
  if (s.discountPercent or 0) > 0 then
    GameTooltip:AddDoubleLine("Discount:", "-" .. s.discountPercent .. "% below market", 0.7, 0.7, 0.7, 0, 0.85, 0.35)
  end

  GameTooltip:AddLine(" ")

  -- Profit breakdown
  GameTooltip:AddDoubleLine("Gross Profit (total):", money(s.grossProfitTotal or 0), 0.7, 0.7, 0.7, 1, 1, 1)
  GameTooltip:AddDoubleLine("AH Fee (" .. (AuctionFlip.Config.Get("ah_cut_percent") or 5) .. "%):", "-" .. money(s.ahFeeTotal or 0), 0.7, 0.7, 0.7, 0.9, 0.2, 0.2)
  if (s.depositTotal or 0) > 0 then
    GameTooltip:AddDoubleLine("Deposit Model:", "-" .. money(s.depositTotal or 0), 0.7, 0.7, 0.7, 0.9, 0.5, 0.2)
  end
  GameTooltip:AddDoubleLine("Net Profit:", money(s.netProfitTotal or 0), 0.7, 0.7, 0.7, 0, 0.85, 0.35)

  if (s.roiPercent or 0) > 0 then
    GameTooltip:AddDoubleLine("ROI:", s.roiPercent .. "%", 0.7, 0.7, 0.7, 1, 1, 0)
  end

  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Buy All Rule:", 1, 0.84, 0)
  GameTooltip:AddLine("Buys only the cheapest qualifying listing tiers within profitable max buy/unit.", 0.8, 0.85, 0.95, true)
  GameTooltip:AddLine("Resale is priced from the first tier above what we buy; history is fallback only when needed.", 0.8, 0.85, 0.95, true)

  GameTooltip:AddLine(" ")

  -- Historical summary (multi-window if available)
  if opp.stats then
    local multiStats = AuctionFlip.Analysis.GetItemStatsMultiWindow(opp.itemId)
    GameTooltip:AddLine("Price History:", 1, 0.84, 0)
    if multiStats.d7 then
      GameTooltip:AddDoubleLine("  Median (7d):", money(multiStats.d7.median), 0.55, 0.55, 0.55, 1, 1, 1)
    end
    if multiStats.d14 then
      GameTooltip:AddDoubleLine("  Median (14d):", money(multiStats.d14.median), 0.55, 0.55, 0.55, 1, 1, 1)
    end
    if multiStats.d30 then
      GameTooltip:AddDoubleLine("  Median (30d):", money(multiStats.d30.median), 0.55, 0.55, 0.55, 1, 1, 1)
    end
    if opp.stats.p25 and opp.stats.p75 then
      GameTooltip:AddDoubleLine("  p25 / p75:", money(opp.stats.p25) .. " / " .. money(opp.stats.p75), 0.55, 0.55, 0.55, 0.8, 0.8, 0.8)
    end
  end

  -- Volume & liquidity
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Liquidity & Volume:", 1, 0.84, 0)
  local volPerDay = s.volumePerDay or 0
  local volStr = volPerDay >= 1 and string.format("%.0f units/day", volPerDay) or string.format("%.1f units/day", volPerDay)
  GameTooltip:AddDoubleLine("  Volume:", volStr, 0.55, 0.55, 0.55, 1, 1, 1)
  GameTooltip:AddDoubleLine("  Liquidity:", (s.liquidityLabel or "?") .. " (" .. string.format("%.2f", s.liquidity or 0) .. ")", 0.55, 0.55, 0.55, 1, 1, 1)
  GameTooltip:AddDoubleLine("  Confidence:", (s.confidencePercent or 0) .. "%", 0.55, 0.55, 0.55, 1, 1, 1)
  if opp.stats then
    GameTooltip:AddDoubleLine("  Data Points:", tostring(opp.stats.samples or 0), 0.55, 0.55, 0.55, 0.8, 0.8, 0.8)
  end

  -- Capital risk warning
  if s.totalBuyCost and s.totalBuyCost > 0 then
    local withinBudget, capitalPct = AuctionFlip.Analysis.CheckCapitalBudget(s.totalBuyCost)
    if not withinBudget then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine("Warning: " .. capitalPct .. "% of spendable gold", 0.9, 0.2, 0.2)
    elseif capitalPct > 30 then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine("Note: " .. capitalPct .. "% of spendable gold", 1, 0.8, 0.4)
    end
  end

  -- Summary line
  if opp.type == "underpriced" and s.discountPercent and s.discountPercent > 0 then
    GameTooltip:AddLine(" ")
    local summary = string.format("Price is %d%% below %dd median. %s liquidity. Confidence: %d%%.",
      s.discountPercent,
      opp.marketWindowDays or 7,
      s.liquidityLabel or "?",
      s.confidencePercent or 0
    )
    GameTooltip:AddLine(summary, 0.5, 0.8, 1, true)
  end

  GameTooltip:Show()
end

function AuctionFlip.UI.RefreshStats()
  if not AuctionFlip.UI.Frame then return end
  
  local content = AuctionFlip.UI.Frame.mainTabContents[1]
  if not content or not content.subTabContents then return end
  
  local statsContent = content.subTabContents[3]
  if not statsContent or not statsContent.statsFrame then return end
  
  local sf = statsContent.statsFrame
  sf.totalProfit:SetText(AuctionFlip.Utilities.CreateCompactMoneyString(AuctionFlip.Stats.GetTotalProfit()))
  sf.totalFlips:SetText(tostring(AuctionFlip.Stats.GetTotalFlips()))
  sf.successRate:SetText(AuctionFlip.Stats.GetSuccessRate() .. "%")
  sf.avgProfit:SetText(AuctionFlip.Utilities.CreatePaddedMoneyString(AuctionFlip.Stats.GetAverageProfit()))
  sf.scansCompleted:SetText(tostring(AuctionFlip.Stats.GetScansCompleted()))
  sf.bestFlip:SetText(tostring(AuctionFlip.Stats.GetBestScanOpportunities()))

  local history = AuctionFlip.Stats.GetRecentScanHistory and AuctionFlip.Stats.GetRecentScanHistory(16) or {}
  if statsContent.insightPanel then
    local insight = statsContent.insightPanel
    insight.lastScan:SetText(AuctionFlip.Stats.GetLastScanTimeText and AuctionFlip.Stats.GetLastScanTimeText() or "Never")
    insight.lastItems:SetText(tostring(AuctionFlip.Stats.GetLastScanItems and AuctionFlip.Stats.GetLastScanItems() or 0))
    insight.lastOpps:SetText(tostring(AuctionFlip.Stats.GetLastScanOpportunities and AuctionFlip.Stats.GetLastScanOpportunities() or 0))
    insight.avgOpps:SetText(tostring(AuctionFlip.Stats.GetAverageOpportunitiesPerScan and AuctionFlip.Stats.GetAverageOpportunitiesPerScan() or 0))
    insight.bestOpps:SetText(tostring(AuctionFlip.Stats.GetBestScanOpportunities and AuctionFlip.Stats.GetBestScanOpportunities() or 0))
    insight.historyPoints:SetText(tostring(#history))
  end
  if statsContent.statsChartPanel then
    UpdateHistoryChart(statsContent.statsChartPanel, history)
  end
  
  -- Update quick stats on scan tab
  local scanContent = content.subTabContents[1]
  if scanContent and scanContent.quickStats then
    scanContent.quickStats.oppCount:SetText(tostring(AuctionFlip.Opportunities.GetCount()))
    scanContent.quickStats.totalProfit:SetText(AuctionFlip.Utilities.CreateCompactMoneyString(AuctionFlip.Opportunities.GetTotalProfit()))
    scanContent.quickStats.itemsScanned:SetText(tostring(AuctionFlip.Scan.GetResultCount()))
    if scanContent.quickStats.lastScan then
      scanContent.quickStats.lastScan:SetText(AuctionFlip.Stats.GetLastScanTimeText and AuctionFlip.Stats.GetLastScanTimeText() or "Never")
    end
  end
  if scanContent and scanContent.sessionPanel then
    local panel = scanContent.sessionPanel
    panel.totalProfit:SetText(AuctionFlip.Utilities.CreateCompactMoneyString(AuctionFlip.Stats.GetTotalProfit()))
    panel.totalFlips:SetText(tostring(AuctionFlip.Stats.GetTotalFlips()))
    panel.successRate:SetText(AuctionFlip.Stats.GetSuccessRate() .. "%")
    panel.avgProfit:SetText(AuctionFlip.Utilities.CreateCompactMoneyString(AuctionFlip.Stats.GetAverageProfit()))
    panel.scansCompleted:SetText(tostring(AuctionFlip.Stats.GetScansCompleted()))
    panel.bestScan:SetText(tostring(AuctionFlip.Stats.GetBestScanOpportunities()))
    panel.avgOpps:SetText(tostring(AuctionFlip.Stats.GetAverageOpportunitiesPerScan and AuctionFlip.Stats.GetAverageOpportunitiesPerScan() or 0))
    panel.lastItems:SetText(tostring(AuctionFlip.Stats.GetLastScanItems and AuctionFlip.Stats.GetLastScanItems() or 0))
  end
  if scanContent and scanContent.scanChartPanel then
    UpdateHistoryChart(scanContent.scanChartPanel, history)
  end
end

function AuctionFlip.UI.RefreshStatus()
  if not AuctionFlip.UI.Frame then return end
  
  local content = AuctionFlip.UI.Frame.mainTabContents[1]
  if not content or not content.subTabContents then return end
  
  local scanContent = content.subTabContents[1]
  if not scanContent then return end

  local mode = AuctionFlip.Config.Get("scan_mode") or "single"
  local modeLabel = "Single"
  if mode == "continuous" then
    modeLabel = "Continuous"
  elseif mode == "until_opportunities" then
    modeLabel = "Retry If 0"
  end
  local activeModeIndex = 1
  if mode == "continuous" then
    activeModeIndex = 2
  elseif mode == "until_opportunities" then
    activeModeIndex = 3
  end
  if scanContent.modeButtons then
    for i, btn in ipairs(scanContent.modeButtons) do
      if AuctionFlip.State.IsScanning then
        if i == activeModeIndex then
          btn:Show()
          btn:Disable()
          btn._isActive = true
        else
          btn:Hide()
        end
      else
        btn:Show()
        btn:Enable()
      end
      if btn._paint then
        btn._paint(btn, false, false)
      end
    end
  end
  
  if AuctionFlip.State.IsScanning then
    local phase = AuctionFlip.Scan.CurrentPhase or "scanning"
    local progressPct = AuctionFlip.Scan.GetProgressPercent() or 0
    local activityMessage = "[" .. modeLabel .. "] Scanning in progress..."
    if phase == "querying" then
      activityMessage = "[" .. modeLabel .. "] Sending browse query..."
    elseif phase == "collecting" then
      local expected = AuctionFlip.Scan.TotalExpected or 0
      if expected > 0 then
        activityMessage = string.format("[%s] Collecting browse results... %d/%d (%d%%)",
          modeLabel,
          AuctionFlip.Scan.ItemsProcessed or 0,
          expected,
          progressPct
        )
      else
        activityMessage = string.format("[%s] Collecting browse results... %d item types",
          modeLabel,
          AuctionFlip.Scan.ItemsProcessed or 0
        )
      end
    elseif phase == "analyzing" then
      activityMessage = string.format("[%s] Building opportunity candidates from %d item types...",
        modeLabel,
        AuctionFlip.Scan.ItemsProcessed or 0
      )
    elseif phase == "verifying" then
      local verification = AuctionFlip.Opportunities and AuctionFlip.Opportunities.Verification or nil
      local completed = verification and verification.Completed or 0
      local total = verification and verification.Total or 0
      local currentName = nil
      if verification and verification.Current then
        currentName = verification.Current.itemName or (verification.Current.itemId and ("Item " .. tostring(verification.Current.itemId))) or nil
      end
      if currentName and currentName ~= "" then
        activityMessage = string.format("[%s] Verifying candidate listings... %d/%d | %s",
          modeLabel,
          completed,
          total,
          currentName
        )
      else
        activityMessage = string.format("[%s] Verifying candidate listings... %d/%d",
          modeLabel,
          completed,
          total
        )
      end
    elseif phase == "retry_wait" then
      local retry = AuctionFlip.Scan.GetRetryRemainingSeconds and AuctionFlip.Scan.GetRetryRemainingSeconds() or 0
      activityMessage = string.format("[%s] Cycle complete. Next retry in %ss.", modeLabel, tostring(retry or 0))
    end

    if scanContent.scanBtn then scanContent.scanBtn:Hide() end
    if scanContent.cancelBtn then scanContent.cancelBtn:Show() end
    if scanContent.statusBar then
      scanContent.statusBar:Show()
      scanContent.statusBar:SetValue(progressPct)
    end
    if scanContent.statusText then
      scanContent.statusText:SetText(activityMessage)
    end
    if scanContent.scanInfoText then
      scanContent.scanInfoText:SetText("Mode: " .. mode .. "\nPhase: " .. phase .. "\nItems processed: " .. tostring(AuctionFlip.Scan.ItemsProcessed or 0))
      scanContent.scanInfoText:SetTextColor(unpack(THEME.text))
    end
    AuctionFlip.UI.SetActivityMessage(activityMessage)
  else
    if scanContent.scanBtn then scanContent.scanBtn:Show() end
    if scanContent.cancelBtn then scanContent.cancelBtn:Hide() end
    if scanContent.statusBar then scanContent.statusBar:Hide() end
    if scanContent.statusText then
      local count = AuctionFlip.Scan.GetResultCount()
      local opps = AuctionFlip.Opportunities.GetCount()
      scanContent.statusText:SetText("Done: " .. count .. " items, " .. opps .. " opportunities")
    end
    if scanContent.scanInfoText then
      local retry = AuctionFlip.Scan.GetRetryRemainingSeconds and AuctionFlip.Scan.GetRetryRemainingSeconds() or 0
      if retry and retry > 0 then
        scanContent.scanInfoText:SetText("Mode: " .. mode .. "\nCycle complete. Next retry in " .. tostring(retry) .. "s.")
      else
        scanContent.scanInfoText:SetText("Mode: " .. mode .. "\nReady to scan. Use Results tab to inspect opportunities.")
      end
      scanContent.scanInfoText:SetTextColor(unpack(THEME.textDim))
    end
    AuctionFlip.UI.SetActivityMessage("[" .. modeLabel .. "] Done! " .. tostring(AuctionFlip.Scan.GetResultCount()) .. " item types, " .. tostring(AuctionFlip.Opportunities.GetCount()) .. " opportunities")
    AuctionFlip.UI.UpdateModeButtons(scanContent)
  end
end

-- SETUP: called when AH opens. Creates the side panel + toggle button.
function AuctionFlip.UI.CreateTab()
  if not AuctionFlip.UI.Frame then
    AuctionFlip.UI.Initialize()
  end

  -- Create the toggle button on the AH title bar
  AuctionFlip.UI.CreateToggleButton()

  -- Auto-show the side panel when AH opens
  if AuctionFlip.UI.Frame and not AuctionFlip.UI.Frame:IsShown() then
    AuctionFlip.UI.Frame._userDragged = false
    AuctionFlip.UI.PositionBesideAH(AuctionFlip.UI.Frame)
    AuctionFlip.UI.Frame:Show()
    AuctionFlip.UI.SelectMainTab(1)
    local oppContent = AuctionFlip.UI.Frame.mainTabContents and AuctionFlip.UI.Frame.mainTabContents[1]
    if oppContent then
      AuctionFlip.UI.SelectSubTab(oppContent, 1)
    end
    AuctionFlip.UI.RefreshStats()
    AuctionFlip.UI.RefreshResults()
    if AuctionFlip.UI.RefreshSelling then
      AuctionFlip.UI.RefreshSelling()
    end
  end

  AuctionFlip.UI.UpdateToggleButton()
  AuctionFlip.UI.TabCreated = true
end

function AuctionFlip.UI.Toggle()
  if not AuctionFlip.UI.Frame then
    AuctionFlip.UI.Initialize()
  end

  if AuctionFlip.UI.Frame:IsShown() then
    AuctionFlip.UI.Frame:Hide()
  else
    AuctionFlip.UI.Frame._userDragged = false
    AuctionFlip.UI.PositionBesideAH(AuctionFlip.UI.Frame)
    AuctionFlip.UI.Frame:Show()
    AuctionFlip.UI.SelectMainTab(1)
    local oppContent = AuctionFlip.UI.Frame.mainTabContents and AuctionFlip.UI.Frame.mainTabContents[1]
    if oppContent then
      AuctionFlip.UI.SelectSubTab(oppContent, 1)
    end
    AuctionFlip.UI.RefreshStats()
    AuctionFlip.UI.RefreshResults()
    if AuctionFlip.UI.RefreshSelling then
      AuctionFlip.UI.RefreshSelling()
    end
  end

  AuctionFlip.UI.UpdateToggleButton()
end

function AuctionFlip.UI.IsAuctionHouseVisible()
  return AuctionHouseFrame and AuctionHouseFrame:IsShown()
end
