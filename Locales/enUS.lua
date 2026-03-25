local L = LibStub("AceLocale-3.0"):NewLocale("AuctionFlip", "enUS", true)

if L then
  L.SCAN_BUTTON = "Scan AH"
  L.STATUS_SCANNING = "Scanning..."
  L.STATUS_COMPLETE = "Scan complete"
  L.STATUS_READY = "Ready"
  
  L.OPP_VENDOR_FLIP = "Vendor Flip"
  L.OPP_UNDERPRICED = "Underpriced"
  L.OPP_CRAFTING = "Crafting Profit"
  
  L.STATS_TOTAL_PROFIT = "Total Profit"
  L.STATS_TOTAL_FLIPS = "Total Flips"
  L.STATS_SUCCESS_RATE = "Success Rate"
  L.STATS_AVG_PROFIT = "Average Profit"
  
  L.SETTINGS_GENERAL = "General"
  L.SETTINGS_SCANNING = "Scanning"
  L.SETTINGS_ALERTS = "Alerts"
  
  L.PROFIT_THRESHOLD = "Minimum Profit Threshold"
  L.ENABLE_SOUNDS = "Enable Sound Alerts"
  L.ENABLE_NOTIFICATIONS = "Enable Notifications"
  
  L.TAB_OPPORTUNITIES = "Opportunities"
  L.TAB_STATS = "Statistics"
  L.TAB_SETTINGS = "Settings"

  -- Advanced metrics columns
  L.COL_DISCOUNT = "Disc%"
  L.COL_NET_PROFIT = "Net Profit"
  L.COL_ROI = "ROI%"
  L.COL_LIQUIDITY = "Liq."
  L.COL_CONFIDENCE = "Conf"
  L.COL_MARKET = "Market"

  -- Risk profiles
  L.RISK_PROFILE = "Risk Profile"
  L.RISK_CONSERVATIVE = "Safe"
  L.RISK_BALANCED = "Balanced"
  L.RISK_AGGRESSIVE = "Aggro"

  -- Tooltip labels
  L.TT_FAIR_PRICE = "Fair Price"
  L.TT_DISCOUNT = "Discount"
  L.TT_GROSS_PROFIT = "Gross Profit (total)"
  L.TT_AH_FEE = "AH Fee"
  L.TT_NET_PROFIT = "Net Profit"
  L.TT_ROI = "ROI"
  L.TT_VOLUME = "Volume"
  L.TT_LIQUIDITY = "Liquidity"
  L.TT_CONFIDENCE = "Confidence"
  L.TT_DATA_POINTS = "Data Points"
  L.TT_PRICE_HISTORY = "Price History"
  L.TT_CAPITAL_WARNING = "Warning: %d%% of spendable gold"
  L.TT_CAPITAL_NOTE = "Note: %d%% of spendable gold"

  -- Settings labels
  L.SET_MIN_ROI = "Min ROI%"
  L.SET_MIN_DISCOUNT = "Min Discount%"
  L.SET_MIN_VOLUME = "Min Volume/Day"
  L.SET_MARKET_WINDOW = "Market Window"
  L.SET_CATEGORY_FILTER = "Enable Category Filter"
  L.SET_CAT_CONSUMABLE = "Consumables"
  L.SET_CAT_TRADESKILL = "Tradeskill Materials"
  L.SET_CAT_RECIPE = "Recipes"
  L.SET_CAT_GEM = "Gems"
  L.SET_CAT_ENHANCEMENT = "Enhancements"
  L.SET_CAT_ARMOR = "Armor (Transmog)"
  L.SET_CAT_WEAPON = "Weapons (Transmog)"
  L.SET_CAT_MISC = "Miscellaneous"

  -- Liquidity labels
  L.LIQ_HIGH = "High"
  L.LIQ_MEDIUM = "Medium"
  L.LIQ_LOW = "Low"
end
