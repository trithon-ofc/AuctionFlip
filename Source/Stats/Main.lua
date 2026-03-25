function AuctionFlip.Stats.Initialize()
  AUCTIONFLIP_STATS = AUCTIONFLIP_STATS or {
    totalProfit = 0,
    totalFlips = 0,
    successfulFlips = 0,
    failedFlips = 0,
    lastReset = time(),
    scansCompleted = 0,
    lastScanTime = 0,
    lastScanItems = 0,
    lastScanOpportunities = 0,
    bestScanOpportunities = 0,
    scanHistory = {},
  }
  AUCTIONFLIP_STATS.scanHistory = AUCTIONFLIP_STATS.scanHistory or {}
end

function AuctionFlip.Stats.GetTotalProfit()
  return AUCTIONFLIP_STATS and AUCTIONFLIP_STATS.totalProfit or 0
end

function AuctionFlip.Stats.GetTotalFlips()
  return AUCTIONFLIP_STATS and AUCTIONFLIP_STATS.totalFlips or 0
end

function AuctionFlip.Stats.GetSuccessRate()
  if not AUCTIONFLIP_STATS then return 0 end
  local total = AUCTIONFLIP_STATS.totalFlips or 0
  if total == 0 then return 0 end
  return math.floor((AUCTIONFLIP_STATS.successfulFlips or 0) / total * 100)
end

function AuctionFlip.Stats.GetAverageProfit()
  if not AUCTIONFLIP_STATS then return 0 end
  local total = AUCTIONFLIP_STATS.totalFlips or 0
  if total == 0 then return 0 end
  return math.floor((AUCTIONFLIP_STATS.totalProfit or 0) / total)
end

function AuctionFlip.Stats.GetScansCompleted()
  return AUCTIONFLIP_STATS and AUCTIONFLIP_STATS.scansCompleted or 0
end

function AuctionFlip.Stats.GetLastScanItems()
  return AUCTIONFLIP_STATS and AUCTIONFLIP_STATS.lastScanItems or 0
end

function AuctionFlip.Stats.GetLastScanOpportunities()
  return AUCTIONFLIP_STATS and AUCTIONFLIP_STATS.lastScanOpportunities or 0
end

function AuctionFlip.Stats.GetBestScanOpportunities()
  return AUCTIONFLIP_STATS and AUCTIONFLIP_STATS.bestScanOpportunities or 0
end

function AuctionFlip.Stats.GetLastScanTimeText()
  if not AUCTIONFLIP_STATS or not AUCTIONFLIP_STATS.lastScanTime or AUCTIONFLIP_STATS.lastScanTime == 0 then
    return "Never"
  end

  return date("%Y-%m-%d %H:%M", AUCTIONFLIP_STATS.lastScanTime)
end

function AuctionFlip.Stats.RecordFlip(profit, success)
  if not AUCTIONFLIP_STATS then return end
  AUCTIONFLIP_STATS.totalFlips = (AUCTIONFLIP_STATS.totalFlips or 0) + 1
  AUCTIONFLIP_STATS.totalProfit = (AUCTIONFLIP_STATS.totalProfit or 0) + profit
  if success then
    AUCTIONFLIP_STATS.successfulFlips = (AUCTIONFLIP_STATS.successfulFlips or 0) + 1
  else
    AUCTIONFLIP_STATS.failedFlips = (AUCTIONFLIP_STATS.failedFlips or 0) + 1
  end
end

function AuctionFlip.Stats.RecordScan(itemCount, opportunityCount)
  if not AUCTIONFLIP_STATS then return end
  AUCTIONFLIP_STATS.scansCompleted = (AUCTIONFLIP_STATS.scansCompleted or 0) + 1
  AUCTIONFLIP_STATS.lastScanTime = time()
  AUCTIONFLIP_STATS.lastScanItems = itemCount or 0
  AUCTIONFLIP_STATS.lastScanOpportunities = opportunityCount or 0
  AUCTIONFLIP_STATS.scanHistory = AUCTIONFLIP_STATS.scanHistory or {}
  table.insert(AUCTIONFLIP_STATS.scanHistory, {
    time = AUCTIONFLIP_STATS.lastScanTime,
    items = itemCount or 0,
    opportunities = opportunityCount or 0,
  })
  while #AUCTIONFLIP_STATS.scanHistory > 24 do
    table.remove(AUCTIONFLIP_STATS.scanHistory, 1)
  end
  if (opportunityCount or 0) > (AUCTIONFLIP_STATS.bestScanOpportunities or 0) then
    AUCTIONFLIP_STATS.bestScanOpportunities = opportunityCount or 0
  end
end

function AuctionFlip.Stats.GetRecentScanHistory(count)
  local history = (AUCTIONFLIP_STATS and AUCTIONFLIP_STATS.scanHistory) or {}
  local take = math.max(math.floor(tonumber(count) or #history), 0)
  if take <= 0 or #history == 0 then
    return {}
  end

  local result = {}
  local startIndex = math.max(1, #history - take + 1)
  for index = startIndex, #history do
    table.insert(result, history[index])
  end
  return result
end

function AuctionFlip.Stats.GetAverageOpportunitiesPerScan()
  local scans = AuctionFlip.Stats.GetScansCompleted()
  if scans <= 0 then
    return 0
  end
  local history = AuctionFlip.Stats.GetRecentScanHistory(24)
  if #history == 0 then
    return 0
  end
  local total = 0
  for _, entry in ipairs(history) do
    total = total + math.max(tonumber(entry.opportunities) or 0, 0)
  end
  return math.floor((total / #history) + 0.5)
end

function AuctionFlip.Stats.Reset()
  AUCTIONFLIP_STATS = {
    totalProfit = 0,
    totalFlips = 0,
    successfulFlips = 0,
    failedFlips = 0,
    lastReset = time(),
    scansCompleted = 0,
    lastScanTime = 0,
    lastScanItems = 0,
    lastScanOpportunities = 0,
    bestScanOpportunities = 0,
    scanHistory = {},
  }
  AuctionFlip.Utilities.Print("Statistics reset.")
end
