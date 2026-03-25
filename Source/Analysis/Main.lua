-- AuctionFlip.Analysis
-- Pure statistics and opportunity scoring functions.
-- No side effects, no UI, no SavedVariables access.

AuctionFlip.Analysis = {}

---------------------------------------------------------------------------
-- Statistical helpers (operate on plain numeric arrays)
---------------------------------------------------------------------------

--- Returns a sorted copy of the input array.
function AuctionFlip.Analysis.SortedCopy(values)
  local copy = {}
  for i = 1, #values do
    copy[i] = values[i]
  end
  table.sort(copy)
  return copy
end

--- Arithmetic mean.
function AuctionFlip.Analysis.Mean(values)
  if not values or #values == 0 then return 0 end
  local sum = 0
  for i = 1, #values do
    sum = sum + values[i]
  end
  return sum / #values
end

--- Median (middle value of a sorted set).
function AuctionFlip.Analysis.Median(values)
  if not values or #values == 0 then return 0 end
  local sorted = AuctionFlip.Analysis.SortedCopy(values)
  local n = #sorted
  if n % 2 == 0 then
    return (sorted[n / 2] + sorted[n / 2 + 1]) / 2
  else
    return sorted[math.ceil(n / 2)]
  end
end

--- Percentile using nearest-rank method.
-- @param p  percentile 0-100 (e.g. 25 for p25)
function AuctionFlip.Analysis.Percentile(values, p)
  if not values or #values == 0 then return 0 end
  local sorted = AuctionFlip.Analysis.SortedCopy(values)
  local n = #sorted
  local rank = math.ceil((p / 100) * n)
  if rank < 1 then rank = 1 end
  if rank > n then rank = n end
  return sorted[rank]
end

--- Population standard deviation.
function AuctionFlip.Analysis.StdDev(values)
  if not values or #values < 2 then return 0 end
  local mean = AuctionFlip.Analysis.Mean(values)
  local sumSq = 0
  for i = 1, #values do
    local diff = values[i] - mean
    sumSq = sumSq + diff * diff
  end
  return math.sqrt(sumSq / #values)
end

--- Coefficient of variation (stddev / mean). Returns 0 when mean is 0.
function AuctionFlip.Analysis.CoefficientOfVariation(values)
  if not values or #values < 2 then return 0 end
  local mean = AuctionFlip.Analysis.Mean(values)
  if mean == 0 then return 0 end
  return AuctionFlip.Analysis.StdDev(values) / math.abs(mean)
end

---------------------------------------------------------------------------
-- GetItemStats  --  fetches history from Database and computes full stats
---------------------------------------------------------------------------

--- Computes advanced statistics for an item over a given time window.
-- @param itemID       number   WoW item ID
-- @param windowDays   number   how many days of history to consider (default 14)
-- @return table|nil   stats object or nil if insufficient data
function AuctionFlip.Analysis.GetItemStats(itemID, windowDays)
  windowDays = windowDays or 14

  local history = AuctionFlip.Database.GetItemHistory(itemID)
  if not history or not history.prices or #history.prices == 0 then
    return nil
  end

  local cutoff = time() - (windowDays * 86400)
  local prices = {}
  local quantities = {}
  local timestamps = {}
  local oldest, newest

  for _, entry in ipairs(history.prices) do
    if entry.time and entry.time >= cutoff and entry.price and entry.price > 0 then
      prices[#prices + 1] = entry.price
      quantities[#quantities + 1] = entry.quantity or 1
      timestamps[#timestamps + 1] = entry.time
      if not oldest or entry.time < oldest then oldest = entry.time end
      if not newest or entry.time > newest then newest = entry.time end
    end
  end

  if #prices == 0 then
    return nil
  end

  local A = AuctionFlip.Analysis

  local median  = A.Median(prices)
  local mean    = A.Mean(prices)
  local stddev  = A.StdDev(prices)
  local cv      = A.CoefficientOfVariation(prices)
  local p10     = A.Percentile(prices, 10)
  local p25     = A.Percentile(prices, 25)
  local p75     = A.Percentile(prices, 75)
  local p90     = A.Percentile(prices, 90)

  local sorted  = A.SortedCopy(prices)
  local minPrice = sorted[1]
  local maxPrice = sorted[#sorted]

  local spanSeconds = math.max((newest or 0) - (oldest or 0), 0)
  local spanDays = spanSeconds / 86400

  -- Volume estimation: total quantity observed / span in days
  local totalQty = 0
  for i = 1, #quantities do
    totalQty = totalQty + quantities[i]
  end
  local volumePerDay = 0
  if spanDays > 0 then
    volumePerDay = totalQty / spanDays
  elseif #prices > 0 then
    volumePerDay = totalQty -- single-day snapshot
  end

  return {
    samples        = #prices,
    windowDays     = windowDays,
    spanSeconds    = spanSeconds,
    spanDays       = spanDays,

    -- Central tendency
    median         = math.floor(median),
    mean           = math.floor(mean),

    -- Dispersion
    stddev         = stddev,
    cv             = cv,            -- coefficient of variation (0-N)
    min            = minPrice,
    max            = maxPrice,

    -- Percentiles
    p10            = math.floor(p10),
    p25            = math.floor(p25),
    p75            = math.floor(p75),
    p90            = math.floor(p90),

    -- Volume / liquidity raw data
    totalQuantity  = totalQty,
    volumePerDay   = volumePerDay,

    -- Timestamps
    oldest         = oldest,
    newest         = newest,
  }
end

---------------------------------------------------------------------------
-- GetItemStatsMultiWindow  --  stats for 7d, 14d, 30d in one call
---------------------------------------------------------------------------

function AuctionFlip.Analysis.GetItemStatsMultiWindow(itemID)
  return {
    d7  = AuctionFlip.Analysis.GetItemStats(itemID, 7),
    d14 = AuctionFlip.Analysis.GetItemStats(itemID, 14),
    d30 = AuctionFlip.Analysis.GetItemStats(itemID, 30),
  }
end

---------------------------------------------------------------------------
-- Liquidity score  (0 to 1)
---------------------------------------------------------------------------

--- Computes a liquidity score from 0 (illiquid) to 1 (very liquid).
-- Based on volume per day and number of data points.
-- @param stats  table  output of GetItemStats
-- @return number  score 0-1
-- @return string  label "Low"/"Medium"/"High"
function AuctionFlip.Analysis.LiquidityScore(stats)
  if not stats then return 0, "Low" end

  -- Volume component: 0-1, saturates at ~200 units/day
  local volCap = AuctionFlip.Config.Get("liquidity_volume_cap") or 200
  local volScore = math.min((stats.volumePerDay or 0) / volCap, 1)

  -- Data density component: 0-1, saturates at 30 samples
  local sampleCap = AuctionFlip.Config.Get("liquidity_sample_cap") or 30
  local sampleScore = math.min((stats.samples or 0) / sampleCap, 1)

  -- Weighted combination
  local score = volScore * 0.65 + sampleScore * 0.35
  score = math.floor(score * 100 + 0.5) / 100  -- round to 2 decimals

  local label = "Low"
  if score >= 0.65 then
    label = "High"
  elseif score >= 0.35 then
    label = "Medium"
  end

  return score, label
end

---------------------------------------------------------------------------
-- Market confidence score  (0 to 1)
---------------------------------------------------------------------------

--- Computes confidence in the fair-price estimate.
-- Based on sample count, time span, and price volatility.
-- @param stats  table  output of GetItemStats
-- @return number  score 0-1
function AuctionFlip.Analysis.ConfidenceScore(stats)
  if not stats then return 0 end

  local minSamples = AuctionFlip.Config.Get("min_market_samples") or 8
  local minSpanSeconds = (AuctionFlip.Config.Get("min_market_span_minutes") or 60) * 60
  local maxCV = (AuctionFlip.Config.Get("max_market_volatility_percent") or 120) / 100

  -- Sample score
  local sampleScore = math.min((stats.samples or 0) / minSamples, 1)

  -- Span score
  local spanScore = math.min((stats.spanSeconds or 0) / minSpanSeconds, 1)

  -- Volatility score: penalize when CV exceeds maxCV
  local volScore = 1
  if maxCV > 0 and (stats.cv or 0) > maxCV then
    volScore = math.max(0, 1 - ((stats.cv - maxCV) / maxCV))
  end

  local score = sampleScore * 0.45 + spanScore * 0.25 + volScore * 0.30
  return math.floor(score * 100 + 0.5) / 100  -- 0.00 to 1.00
end

---------------------------------------------------------------------------
-- ScoreOpportunity  --  the main scoring function
---------------------------------------------------------------------------

--- Scores a buying opportunity with all advanced metrics.
-- @param stats            table   output of GetItemStats (can be nil for vendor flips)
-- @param currentUnitPrice number  current AH unit price in copper
-- @param qty              number  quantity available
-- @param ahCutPercent     number  AH cut percentage (default 5)
-- @param depositCost      number  estimated deposit cost in copper (default 0)
-- @return table  scored opportunity object
function AuctionFlip.Analysis.ScoreOpportunity(stats, currentUnitPrice, qty, ahCutPercent, depositCost)
  ahCutPercent = ahCutPercent or (AuctionFlip.Config.Get("ah_cut_percent") or 5)
  depositCost  = depositCost or 0
  qty          = math.max(qty or 1, 1)

  local result = {
    fairPrice       = 0,
    fairPriceSource = "none",
    discount        = 0,        -- 0.0 to 1.0 (e.g. 0.35 = 35% below fair)
    discountPercent = 0,        -- integer 0-100

    grossProfitUnit  = 0,
    grossProfitTotal = 0,
    netProfitUnit    = 0,
    netProfitTotal   = 0,

    totalBuyCost    = 0,
    ahFeeTotal      = 0,
    depositTotal    = depositCost,

    roi             = 0,        -- 0.0 to N (e.g. 0.45 = 45% ROI)
    roiPercent      = 0,        -- integer

    liquidity       = 0,        -- 0.0 to 1.0
    liquidityLabel  = "Low",
    confidence      = 0,        -- 0.0 to 1.0
    confidencePercent = 0,      -- integer 0-100

    volumePerDay    = 0,
  }

  -- Determine fair price (median > mean > fallback)
  if stats then
    if stats.median and stats.median > 0 then
      result.fairPrice = stats.median
      result.fairPriceSource = "median"
    elseif stats.mean and stats.mean > 0 then
      result.fairPrice = stats.mean
      result.fairPriceSource = "mean"
    end
    result.volumePerDay = stats.volumePerDay or 0
  end

  if result.fairPrice <= 0 then
    -- Cannot score without fair price
    return result
  end

  -- Discount
  if currentUnitPrice > 0 and result.fairPrice > 0 then
    result.discount = 1 - (currentUnitPrice / result.fairPrice)
    result.discountPercent = math.floor(result.discount * 100 + 0.5)
  end

  -- Gross profit (before fees)
  result.grossProfitUnit  = result.fairPrice - currentUnitPrice
  result.grossProfitTotal = result.grossProfitUnit * qty

  -- Net profit (after AH cut + deposit)
  local saleRevenue = result.fairPrice * qty
  local ahFee = math.floor(saleRevenue * (ahCutPercent / 100))
  result.ahFeeTotal = ahFee

  result.totalBuyCost = currentUnitPrice * qty
  result.netProfitTotal = saleRevenue - ahFee - result.totalBuyCost - depositCost
  result.netProfitUnit = math.floor(result.netProfitTotal / qty)

  -- ROI
  if result.totalBuyCost > 0 then
    result.roi = result.netProfitTotal / result.totalBuyCost
    result.roiPercent = math.floor(result.roi * 100 + 0.5)
  end

  -- Liquidity & confidence (from Analysis functions)
  if stats then
    result.liquidity, result.liquidityLabel = AuctionFlip.Analysis.LiquidityScore(stats)
    result.confidence = AuctionFlip.Analysis.ConfidenceScore(stats)
    result.confidencePercent = math.floor(result.confidence * 100 + 0.5)
  end

  return result
end

---------------------------------------------------------------------------
-- Risk profile presets
---------------------------------------------------------------------------

AuctionFlip.Analysis.RiskProfiles = {
  conservative = {
    min_roi_percent         = 30,
    min_discount_percent    = 20,
    min_confidence          = 0.70,
    min_liquidity           = 0.50,
    min_net_profit          = 100000,   -- 10g in copper
    allowed_categories      = {         -- classID whitelist (nil = all)
      [0]  = true,  -- Consumable
      [7]  = true,  -- Tradeskill (materials)
      [9]  = true,  -- Recipe
    },
  },
  balanced = {
    min_roi_percent         = 20,
    min_discount_percent    = 15,
    min_confidence          = 0.50,
    min_liquidity           = 0.30,
    min_net_profit          = 50000,    -- 5g
    allowed_categories      = nil,      -- all categories
  },
  aggressive = {
    min_roi_percent         = 10,
    min_discount_percent    = 10,
    min_confidence          = 0.30,
    min_liquidity           = 0.10,
    min_net_profit          = 10000,    -- 1g
    allowed_categories      = nil,
  },
}

--- Returns the active risk profile table (merged with user overrides).
function AuctionFlip.Analysis.GetActiveRiskProfile()
  local profileName = AuctionFlip.Config.Get("risk_profile") or "balanced"
  local base = AuctionFlip.Analysis.RiskProfiles[profileName]
    or AuctionFlip.Analysis.RiskProfiles.balanced

  -- Allow per-field user overrides from config
  return {
    min_roi_percent      = AuctionFlip.Config.Get("min_roi_percent")      or base.min_roi_percent,
    min_discount_percent = AuctionFlip.Config.Get("min_discount_percent") or base.min_discount_percent,
    min_confidence       = AuctionFlip.Config.Get("min_confidence")       or base.min_confidence,
    min_liquidity        = AuctionFlip.Config.Get("min_liquidity")        or base.min_liquidity,
    min_net_profit       = AuctionFlip.Config.Get("min_net_profit")       or base.min_net_profit,
    allowed_categories   = base.allowed_categories,
  }
end

--- Checks whether a scored opportunity passes the active risk profile filters.
-- @param score    table   output of ScoreOpportunity
-- @param classID  number  item classID (from GetItemInfo)
-- @param profile  table   optional risk profile override
-- @return boolean  true if opportunity passes all filters
function AuctionFlip.Analysis.PassesRiskProfile(score, classID, profile)
  profile = profile or AuctionFlip.Analysis.GetActiveRiskProfile()

  if score.roiPercent < (profile.min_roi_percent or 0) then
    return false
  end
  if score.discountPercent < (profile.min_discount_percent or 0) then
    return false
  end
  if score.confidence < (profile.min_confidence or 0) then
    return false
  end
  if score.liquidity < (profile.min_liquidity or 0) then
    return false
  end
  if score.netProfitTotal < (profile.min_net_profit or 0) then
    return false
  end
  if profile.allowed_categories and classID then
    if not profile.allowed_categories[classID] then
      return false
    end
  end

  return true
end

--- Checks capital budget constraint for an opportunity.
-- @param totalBuyCost  number  total copper needed to buy
-- @return boolean  withinBudget
-- @return number   capitalPercent  percentage of spendable gold this represents
function AuctionFlip.Analysis.CheckCapitalBudget(totalBuyCost)
  local budget = AuctionFlip.Opportunities.GetCapitalBudgetState()
  local perItemCap = budget.perItemCap or 0

  local withinBudget = totalBuyCost <= perItemCap
  local capitalPercent = 0
  if budget.spendable > 0 then
    capitalPercent = math.floor((totalBuyCost / budget.spendable) * 100 + 0.5)
  end

  return withinBudget, capitalPercent
end
