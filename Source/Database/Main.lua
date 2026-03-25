AuctionFlip.Database = {
  Data = {},
}

function AuctionFlip.Database.Initialize()
  AUCTIONFLIP_PRICES = AUCTIONFLIP_PRICES or {}
  local realm = GetRealmName() or "Unknown"
  if not AUCTIONFLIP_PRICES[realm] then
    AUCTIONFLIP_PRICES[realm] = {}
  end
  AUCTIONFLIP_PRICES[realm].version = 2
  AuctionFlip.Database.Data = AUCTIONFLIP_PRICES[realm]
  AuctionFlip.Database.PruneAllHistory()
end

function AuctionFlip.Database.PruneAllHistory()
  local data = AuctionFlip.Database.Data or {}
  local retentionDays = AuctionFlip.Config.Get("history_retention_days") or 14
  local cutoff = time() - (retentionDays * 86400)
  local maxSamples = AuctionFlip.Config.Get("max_history_samples") or 300

  for key, value in pairs(data) do
    if type(key) == "string" and key:find("^item:") and type(value) == "table" and value.prices then
      while #value.prices > 0 and (value.prices[1].time or 0) < cutoff do
        table.remove(value.prices, 1)
      end
      while #value.prices > maxSamples do
        table.remove(value.prices, 1)
      end
    end
  end
end

function AuctionFlip.Database.RecordPrice(itemId, buyPrice, quantity)
  if not itemId or not buyPrice or buyPrice == 0 then return end

  local realm = GetRealmName() or "Unknown"
  if not AUCTIONFLIP_PRICES then AUCTIONFLIP_PRICES = {} end
  if not AUCTIONFLIP_PRICES[realm] then AUCTIONFLIP_PRICES[realm] = {} end

  local key = "item:" .. itemId

  if not AUCTIONFLIP_PRICES[realm][key] then
    AUCTIONFLIP_PRICES[realm][key] = {
      prices = {},
      lastUpdated = time(),
      lowestPrice = buyPrice,
    }
  end

  local data = AUCTIONFLIP_PRICES[realm][key]

  local minInterval = AuctionFlip.Config.Get("min_history_record_interval_seconds") or 30
  local lastEntry = data.prices[#data.prices]
  if lastEntry and (time() - (lastEntry.time or 0)) < minInterval then
    local lastPrice = lastEntry.price or 0
    if lastPrice > 0 then
      local variation = math.abs(buyPrice - lastPrice) / lastPrice
      if variation < 0.01 then
        data.lastUpdated = time()
        return
      end
    end
  end

  table.insert(data.prices, {
    price = buyPrice,
    quantity = quantity or 1,
    time = time(),
    date = date("%Y-%m-%d %H:%M"),
  })

  local retentionDays = AuctionFlip.Config.Get("history_retention_days") or 14
  local cutoff = time() - (retentionDays * 86400)
  while #data.prices > 0 and (data.prices[1].time or 0) < cutoff do
    table.remove(data.prices, 1)
  end

  local maxSamples = AuctionFlip.Config.Get("max_history_samples") or 300
  while #data.prices > maxSamples do
    table.remove(data.prices, 1)
  end

  if buyPrice < (data.lowestPrice or buyPrice) then
    data.lowestPrice = buyPrice
  end

  data.lastUpdated = time()
end

function AuctionFlip.Database.GetItemHistory(itemId)
  if not itemId then return nil end
  local realm = GetRealmName() or "Unknown"
  local key = "item:" .. itemId
  return AUCTIONFLIP_PRICES and AUCTIONFLIP_PRICES[realm] and AUCTIONFLIP_PRICES[realm][key]
end

function AuctionFlip.Database.GetAveragePrice(itemId, days)
  local history = AuctionFlip.Database.GetItemHistory(itemId)
  if not history or not history.prices or #history.prices == 0 then
    return nil
  end

  local cutoff = time() - (days or 7) * 86400
  local sum = 0
  local count = 0

  for _, entry in ipairs(history.prices) do
    if entry.time >= cutoff then
      sum = sum + entry.price
      count = count + 1
    end
  end

  if count == 0 then return nil end
  return math.floor(sum / count)
end

function AuctionFlip.Database.GetMarketSnapshot(itemId, days)
  local history = AuctionFlip.Database.GetItemHistory(itemId)
  if not history or not history.prices or #history.prices == 0 then
    return nil
  end

  local cutoff = time() - ((days or 7) * 86400)
  local prices = {}
  local sum = 0
  local oldest = nil
  local newest = nil

  for _, entry in ipairs(history.prices) do
    if entry.time and entry.time >= cutoff and entry.price and entry.price > 0 then
      table.insert(prices, entry.price)
      sum = sum + entry.price
      if not oldest or entry.time < oldest then
        oldest = entry.time
      end
      if not newest or entry.time > newest then
        newest = entry.time
      end
    end
  end

  if #prices == 0 then
    return nil
  end

  table.sort(prices)
  local minPrice = prices[1]
  local maxPrice = prices[#prices]
  local average = math.floor(sum / #prices)

  local mid = math.floor(#prices / 2)
  local median = nil
  if #prices % 2 == 0 then
    median = math.floor((prices[mid] + prices[mid + 1]) / 2)
  else
    median = prices[mid + 1]
  end

  local volatilityRatio = 0
  if median and median > 0 then
    volatilityRatio = (maxPrice - minPrice) / median
  end

  return {
    samples = #prices,
    average = average,
    median = median,
    min = minPrice,
    max = maxPrice,
    oldest = oldest,
    newest = newest,
    spanSeconds = math.max((newest or 0) - (oldest or 0), 0),
    volatilityRatio = volatilityRatio,
  }
end

function AuctionFlip.Database.GetMedianPrice(itemId)
  local history = AuctionFlip.Database.GetItemHistory(itemId)
  if not history or not history.prices or #history.prices == 0 then
    return nil
  end

  local sortedPrices = {}
  for _, entry in ipairs(history.prices) do
    table.insert(sortedPrices, entry.price)
  end
  table.sort(sortedPrices)

  return sortedPrices[math.ceil(#sortedPrices / 2)]
end

function AuctionFlip.Database.GetLowestPrice(itemId)
  local history = AuctionFlip.Database.GetItemHistory(itemId)
  if not history then return nil end
  return history.lowestPrice
end

function AuctionFlip.Database.GetPriceHistory(itemId, count)
  local history = AuctionFlip.Database.GetItemHistory(itemId)
  if not history or not history.prices then return {} end

  count = count or 10
  local result = {}
  local start = math.max(1, #history.prices - count + 1)

  for i = start, #history.prices do
    table.insert(result, history.prices[i])
  end

  return result
end

function AuctionFlip.Database.GetItemPriceText(itemId)
  local history = AuctionFlip.Database.GetItemHistory(itemId)
  if not history then return "No history" end

  local avg = AuctionFlip.Database.GetAveragePrice(itemId, 7)
  local lowest = history.lowestPrice

  if avg and lowest then
    return "Avg: " .. AuctionFlip.Utilities.CreatePaddedMoneyString(avg) .. " | Lowest: " .. AuctionFlip.Utilities.CreatePaddedMoneyString(lowest)
  elseif avg then
    return "Avg: " .. AuctionFlip.Utilities.CreatePaddedMoneyString(avg)
  elseif lowest then
    return "Lowest: " .. AuctionFlip.Utilities.CreatePaddedMoneyString(lowest)
  end

  return "No data"
end

function AuctionFlip.Database.GetTrackedItemCount()
  local data = AuctionFlip.Database.Data or {}
  local count = 0

  for key, value in pairs(data) do
    if type(key) == "string" and key:find("^item:") and type(value) == "table" then
      count = count + 1
    end
  end

  return count
end

function AuctionFlip.Database.GetTotalSampleCount()
  local data = AuctionFlip.Database.Data or {}
  local count = 0

  for key, value in pairs(data) do
    if type(key) == "string" and key:find("^item:") and type(value) == "table" and value.prices then
      count = count + #value.prices
    end
  end

  return count
end
