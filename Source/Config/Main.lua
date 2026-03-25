AuctionFlip.Config.Defaults = {
  debug = false,
  profit_threshold = 50000,
  max_profit_threshold = 0,
  min_price = 100,
  max_price = 10000000,
  sound_alerts = true,
  show_notifications = true,
  auto_scan_on_open = false,
  auto_open_on_ah = true,
  rescan_interval_seconds = 15,
  browse_request_throttle_ms = 350,
  verification_query_throttle_ms = 600,
  opportunity_target_duration_hours = 24,
  scan_mode = "single",
  verify_candidates = true,
  max_verified_candidates = 10,
  verification_timeout = 1.5,
  history_retention_days = 14,
  max_history_samples = 300,
  min_history_record_interval_seconds = 30,
  market_window_days = 7,
  min_market_samples = 8,
  min_market_span_minutes = 60,
  max_market_volatility_percent = 120,
  min_confidence_percent = 55,
  capital_reserve_percent = 35,
  max_capital_per_item_percent = 15,
  ah_cut_percent = 5,
  max_buy_actions_per_click = 5,

  -- Advanced opportunity filters (used by Analysis.ScoreOpportunity)
  risk_profile = "balanced",              -- "conservative", "balanced", "aggressive"
  min_roi_percent = nil,                  -- nil = use risk profile default
  min_discount_percent = nil,             -- nil = use risk profile default
  min_confidence = nil,                   -- nil = use risk profile default (0-1)
  min_liquidity = nil,                    -- nil = use risk profile default (0-1)
  min_net_profit = nil,                   -- nil = use risk profile default (copper)
  min_volume_per_day = 0,                 -- 0 = no volume filter
  max_capital_per_item_gold = 0,          -- 0 = no absolute gold cap per item

  -- Liquidity scoring caps
  liquidity_volume_cap = 200,             -- units/day that maps to score 1.0
  liquidity_sample_cap = 30,              -- samples that maps to score 1.0

  -- Category filter (nil = allow all, otherwise table of classIDs)
  category_filter_enabled = false,
  category_filter_consumable = true,      -- classID 0
  category_filter_tradeskill = true,      -- classID 7
  category_filter_recipe = true,          -- classID 9
  category_filter_gem = true,             -- classID 3
  category_filter_enhancement = true,     -- classID 8
  category_filter_armor = false,          -- classID 4
  category_filter_weapon = false,         -- classID 2
  category_filter_misc = false,           -- classID 15

  -- Sort preference for results grid
  results_sort_field = "netProfit",       -- "netProfit", "roi", "discount", "liquidity", "confidence"
  results_sort_ascending = false,

  -- Visual theme
  theme_variant = "neon_blue",            -- "neon_blue", "neon_green", "neon_red"
}

function AuctionFlip.Config.Get(name)
  if AUCTIONFLIP_CONFIG and AUCTIONFLIP_CONFIG[name] ~= nil then
    return AUCTIONFLIP_CONFIG[name]
  end
  return AuctionFlip.Config.Defaults[name]
end

function AuctionFlip.Config.Set(name, value)
  if not AUCTIONFLIP_CONFIG then
    AUCTIONFLIP_CONFIG = {}
  end
  AUCTIONFLIP_CONFIG[name] = value
end

function AuctionFlip.Config.Initialize()
  AUCTIONFLIP_CONFIG = AUCTIONFLIP_CONFIG or {}
  for key, default in pairs(AuctionFlip.Config.Defaults) do
    if AUCTIONFLIP_CONFIG[key] == nil then
      AUCTIONFLIP_CONFIG[key] = default
    end
  end
end
