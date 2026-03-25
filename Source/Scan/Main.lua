AuctionFlip.Scan = {}
AuctionFlip.Scan.Results = {}
AuctionFlip.Scan.IsRunning = false
AuctionFlip.Scan.ItemsProcessed = 0
AuctionFlip.Scan.Callbacks = {}
AuctionFlip.Scan.CurrentPhase = "idle"
AuctionFlip.Scan.RunCount = 0
AuctionFlip.Scan.PendingFinalize = 0
AuctionFlip.Scan.PendingRetry = false
AuctionFlip.Scan.LastOpportunityCount = 0
AuctionFlip.Scan.TotalExpected = 0
AuctionFlip.Scan.PendingMoreRequest = false
AuctionFlip.Scan.NextRetryAt = nil
AuctionFlip.Scan.RetryTickerActive = false
AuctionFlip.Scan.LastCycleItems = 0
AuctionFlip.Scan.LastCycleOpportunities = 0
AuctionFlip.Scan.MoreRequestNoProgress = 0
AuctionFlip.Scan.LastProcessedSnapshot = 0
AuctionFlip.Scan.BrowseRowsSeen = 0
AuctionFlip.Scan.BrowseSeenKeys = {}
AuctionFlip.Scan.PendingItemLoads = {}
AuctionFlip.Scan.LastItemInfoRefreshAt = 0

function AuctionFlip.Scan.Initialize()
  AuctionFlip.Scan.Results = {}
  AuctionFlip.Scan.IsRunning = false
  AuctionFlip.Scan.ItemsProcessed = 0
  AuctionFlip.Scan.CurrentPhase = "idle"
  AuctionFlip.Scan.RunCount = 0
  AuctionFlip.Scan.PendingFinalize = 0
  AuctionFlip.Scan.PendingRetry = false
  AuctionFlip.Scan.LastOpportunityCount = 0
  AuctionFlip.Scan.TotalExpected = 0
  AuctionFlip.Scan.PendingMoreRequest = false
  AuctionFlip.Scan.NextRetryAt = nil
  AuctionFlip.Scan.RetryTickerActive = false
  AuctionFlip.Scan.LastCycleItems = 0
  AuctionFlip.Scan.LastCycleOpportunities = 0
  AuctionFlip.Scan.MoreRequestNoProgress = 0
  AuctionFlip.Scan.LastProcessedSnapshot = 0
  AuctionFlip.Scan.BrowseRowsSeen = 0
  AuctionFlip.Scan.BrowseSeenKeys = {}
  AuctionFlip.Scan.PendingItemLoads = {}
  AuctionFlip.Scan.LastItemInfoRefreshAt = 0
end

function AuctionFlip.Scan.Start()
  if AuctionFlip.Scan.IsRunning then
    AuctionFlip.Utilities.Print("Already scanning!")
    return
  end

  if not AuctionFlip.UI.IsAuctionHouseVisible() then
    AuctionFlip.Utilities.Print("Open the Auction House first!")
    return
  end

  AuctionFlip.Scan.IsRunning = true
  AuctionFlip.State.IsScanning = true
  AuctionFlip.Opportunities.CancelVerification()
  AuctionFlip.Scan.Results = {}
  AuctionFlip.Scan.ItemsProcessed = 0
  AuctionFlip.Scan.CurrentPhase = "querying"
  AuctionFlip.Scan.RunCount = AuctionFlip.Scan.RunCount + 1
  AuctionFlip.Scan.PendingFinalize = AuctionFlip.Scan.PendingFinalize + 1
  AuctionFlip.Scan.PendingRetry = false
  AuctionFlip.Scan.LastOpportunityCount = 0
  AuctionFlip.Scan.TotalExpected = 0
  AuctionFlip.Scan.PendingMoreRequest = false
  AuctionFlip.Scan.NextRetryAt = nil
  AuctionFlip.Scan.MoreRequestNoProgress = 0
  AuctionFlip.Scan.LastProcessedSnapshot = 0
  AuctionFlip.Scan.BrowseRowsSeen = 0
  AuctionFlip.Scan.BrowseSeenKeys = {}
  AuctionFlip.Scan.PendingItemLoads = {}
  AuctionFlip.Scan.LastItemInfoRefreshAt = 0

  AuctionFlip.Utilities.Print("Starting market summary scan...")
  AuctionFlip.Utilities.Debug("Browse throttle:", tostring(AuctionFlip.Config.Get("browse_request_throttle_ms") or 350) .. "ms")
  AuctionFlip.Utilities.Debug("Scan run", tostring(AuctionFlip.Scan.RunCount), "started.")
  AuctionFlip.UI.RefreshStatus()

  C_AuctionHouse.SendBrowseQuery({
    searchString = "",
    sorts = {},
    filters = {},
    itemClassFilters = {},
    minLevel = 0,
    maxLevel = 0,
  })
end

function AuctionFlip.Scan.GetRetryRemainingSeconds()
  local nextRetryAt = AuctionFlip.Scan.NextRetryAt
  if not nextRetryAt then
    return nil
  end

  local remaining = math.ceil(nextRetryAt - time())
  if remaining < 0 then
    remaining = 0
  end
  return remaining
end

function AuctionFlip.Scan.StartRetryTicker()
  if AuctionFlip.Scan.RetryTickerActive then
    return
  end

  AuctionFlip.Scan.RetryTickerActive = true

  local function tick()
    if not AuctionFlip.Scan.PendingRetry then
      AuctionFlip.Scan.RetryTickerActive = false
      return
    end

    AuctionFlip.UI.RefreshStatus()
    C_Timer.After(1, tick)
  end

  tick()
end

function AuctionFlip.Scan.GetBrowseThrottleSeconds()
  local throttleMs = AuctionFlip.Config.Get("browse_request_throttle_ms") or 350
  if throttleMs < 100 then
    throttleMs = 100
  end
  return throttleMs / 1000
end

function AuctionFlip.Scan.QueueMoreBrowseResults()
  if AuctionFlip.Scan.PendingMoreRequest then
    return
  end

  AuctionFlip.Scan.PendingMoreRequest = true
  local delay = AuctionFlip.Scan.GetBrowseThrottleSeconds()
  AuctionFlip.Utilities.Debug("Queueing RequestMoreBrowseResults in", string.format("%.2fs", delay))

  C_Timer.After(delay, function()
    AuctionFlip.Scan.PendingMoreRequest = false
    if not AuctionFlip.Scan.IsRunning then
      return
    end

    if C_AuctionHouse.HasFullBrowseResults and not C_AuctionHouse.HasFullBrowseResults() then
      C_AuctionHouse.RequestMoreBrowseResults()
      AuctionFlip.UI.RefreshStatus()
      AuctionFlip.Scan.PendingFinalize = AuctionFlip.Scan.PendingFinalize + 1
      AuctionFlip.Scan.ScheduleFinalize(1.5 + delay)
    end
  end)
end

function AuctionFlip.Scan.ScheduleFinalize(delaySeconds)
  local finalizeToken = AuctionFlip.Scan.PendingFinalize
  C_Timer.After(delaySeconds or 1, function()
    if AuctionFlip.Scan.IsRunning and finalizeToken == AuctionFlip.Scan.PendingFinalize then
      AuctionFlip.Scan.Complete()
    end
  end)
end

function AuctionFlip.Scan.RequestItemData(itemId)
  if not itemId or itemId <= 0 then
    return
  end

  if AuctionFlip.Scan.PendingItemLoads[itemId] then
    return
  end
  AuctionFlip.Scan.PendingItemLoads[itemId] = true

  if C_Item and C_Item.RequestLoadItemDataByID then
    pcall(C_Item.RequestLoadItemDataByID, itemId)
  end
end

function AuctionFlip.Scan.ApplyResolvedItemInfo(itemId)
  if not itemId or itemId <= 0 then
    return false
  end

  local itemName, itemLink, _, _, _, _, _, _, _, itemIcon = GetItemInfo(itemId)
  if not itemName or itemName == "" then
    return false
  end

  local changed = false
  local scanEntry = AuctionFlip.Scan.Results and AuctionFlip.Scan.Results[itemId] or nil
  if scanEntry then
    if not scanEntry.itemName or scanEntry.itemName == "" or scanEntry.itemName:match("^Item %d+$") then
      scanEntry.itemName = itemName
      changed = true
    end
  end

  if AuctionFlip.Opportunities and AuctionFlip.Opportunities.List then
    for _, opp in ipairs(AuctionFlip.Opportunities.List) do
      if opp.itemId == itemId then
        if not opp.itemName or opp.itemName == "" or opp.itemName:match("^Item %d+$") then
          opp.itemName = itemName
          changed = true
        end
        if itemLink and opp.itemLink ~= itemLink then
          opp.itemLink = itemLink
          changed = true
        end
        if itemIcon and opp.icon ~= itemIcon then
          opp.icon = itemIcon
          changed = true
        end
      end
    end
  end

  if changed and AuctionFlip.UI and AuctionFlip.UI.RefreshResults then
    local nowTs = GetTime and GetTime() or 0
    if nowTs - (AuctionFlip.Scan.LastItemInfoRefreshAt or 0) > 0.2 then
      AuctionFlip.Scan.LastItemInfoRefreshAt = nowTs
      AuctionFlip.UI.RefreshResults()
    end
  end

  return changed
end

function AuctionFlip.Scan.ProcessBrowseBatch(browseResults)
  if not browseResults or type(browseResults) ~= "table" or #browseResults == 0 then
    return false
  end

  local hadProgress = false
  for _, result in ipairs(browseResults) do
    if result.itemKey and result.itemKey.itemID then
      local rowKey = AuctionFlip.Utilities.GetItemKeyString and AuctionFlip.Utilities.GetItemKeyString(result.itemKey) or tostring(result.itemKey.itemID)
      if rowKey and not AuctionFlip.Scan.BrowseSeenKeys[rowKey] then
        AuctionFlip.Scan.BrowseSeenKeys[rowKey] = true
        AuctionFlip.Scan.BrowseRowsSeen = (AuctionFlip.Scan.BrowseRowsSeen or 0) + 1
        hadProgress = true
      end

      local itemId = result.itemKey.itemID
      local itemName = result.itemName or select(1, GetItemInfo(itemId))
      local minPrice = result.minPrice or 0
      local quantity = result.totalQuantity or 0

      if minPrice > 0 then
        if not AuctionFlip.Scan.Results[itemId] then
          AuctionFlip.Scan.Results[itemId] = {
            itemId = itemId,
            itemName = itemName,
            minPrice = minPrice,
            quantity = quantity,
            containsOwnerItem = result.containsOwnerItem or false,
            itemKey = result.itemKey,
          }
          AuctionFlip.Scan.ItemsProcessed = AuctionFlip.Scan.ItemsProcessed + 1
          hadProgress = true
        end

        AuctionFlip.Database.RecordPrice(itemId, minPrice, quantity)
      end

      if not itemName or itemName == "" then
        AuctionFlip.Scan.RequestItemData(itemId)
      else
        AuctionFlip.Scan.PendingItemLoads[itemId] = nil
      end
    end
  end

  return hadProgress
end

function AuctionFlip.Scan.UpdateBrowsePaginationState(batchHadProgress)
  local hasProgress = batchHadProgress or ((AuctionFlip.Scan.BrowseRowsSeen or 0) > (AuctionFlip.Scan.LastProcessedSnapshot or 0))
  if hasProgress then
    AuctionFlip.Scan.LastProcessedSnapshot = AuctionFlip.Scan.BrowseRowsSeen or 0
    AuctionFlip.Scan.MoreRequestNoProgress = 0
  end

  local expected = AuctionFlip.Scan.TotalExpected or 0
  local needsMore = false
  if C_AuctionHouse.HasFullBrowseResults and not C_AuctionHouse.HasFullBrowseResults() then
    needsMore = true
  elseif expected > 0 and (AuctionFlip.Scan.BrowseRowsSeen or 0) < expected then
    needsMore = true
  end

  if needsMore then
    if not hasProgress then
      AuctionFlip.Scan.MoreRequestNoProgress = (AuctionFlip.Scan.MoreRequestNoProgress or 0) + 1
    end

    if (AuctionFlip.Scan.MoreRequestNoProgress or 0) >= 6 then
      AuctionFlip.Utilities.Debug("Browse pagination stalled; finalizing with", tostring(AuctionFlip.Scan.ItemsProcessed), "items.")
      AuctionFlip.Scan.ScheduleFinalize(0.3)
      return
    end

    AuctionFlip.Scan.QueueMoreBrowseResults()
    return
  end

  AuctionFlip.Scan.ScheduleFinalize(0.3)
end

function AuctionFlip.Scan.OnBrowseResultsUpdated()
  if not AuctionFlip.Scan.IsRunning then return end

  AuctionFlip.Scan.CurrentPhase = "collecting"

  if C_AuctionHouse.GetNumBrowseResults then
    local total = C_AuctionHouse.GetNumBrowseResults()
    if total and total > (AuctionFlip.Scan.TotalExpected or 0) then
      AuctionFlip.Scan.TotalExpected = total
    end
  end

  local browseResults = C_AuctionHouse.GetBrowseResults()
  local hadProgress = AuctionFlip.Scan.ProcessBrowseBatch(browseResults)
  AuctionFlip.Scan.UpdateBrowsePaginationState(hadProgress)
end

function AuctionFlip.Scan.OnBrowseResultsAdded(addedResults)
  if not AuctionFlip.Scan.IsRunning then
    return
  end

  AuctionFlip.Scan.CurrentPhase = "collecting"

  if C_AuctionHouse.GetNumBrowseResults then
    local total = C_AuctionHouse.GetNumBrowseResults()
    if total and total > (AuctionFlip.Scan.TotalExpected or 0) then
      AuctionFlip.Scan.TotalExpected = total
    end
  end

  local batch = nil
  if type(addedResults) == "table" then
    if addedResults[1] ~= nil then
      batch = addedResults
    elseif addedResults.itemKey then
      batch = { addedResults }
    end
  end
  if not batch then
    batch = C_AuctionHouse.GetBrowseResults and C_AuctionHouse.GetBrowseResults() or nil
  end
  local hadProgress = AuctionFlip.Scan.ProcessBrowseBatch(batch)
  AuctionFlip.Scan.UpdateBrowsePaginationState(hadProgress)
end

function AuctionFlip.Scan.Complete()
  if not AuctionFlip.Scan.IsRunning then
    return
  end

  AuctionFlip.Scan.IsRunning = false
  AuctionFlip.Scan.CurrentPhase = "analyzing"

  local count = AuctionFlip.Scan.ItemsProcessed

  AuctionFlip.UI.RefreshStatus()

  AuctionFlip.Opportunities.DetectWithCallback(function(opportunities)
    local opportunityCount = #opportunities
    AuctionFlip.Scan.LastOpportunityCount = opportunityCount
    AuctionFlip.Scan.LastCycleItems = count
    AuctionFlip.Scan.LastCycleOpportunities = opportunityCount
    AuctionFlip.Stats.RecordScan(count, opportunityCount)
    AuctionFlip.State.IsScanning = false
    AuctionFlip.Scan.CurrentPhase = "idle"

    AuctionFlip.Utilities.Print("Summary scan complete! Processed " .. count .. " item types, found " .. opportunityCount .. " opportunities.")
    AuctionFlip.Utilities.Debug("Scan run", tostring(AuctionFlip.Scan.RunCount), "finished.")
    AuctionFlip.Utilities.Debug(
      "Browse rows seen:",
      tostring(AuctionFlip.Scan.BrowseRowsSeen or 0),
      "Expected:",
      tostring(AuctionFlip.Scan.TotalExpected or 0),
      "Unique item IDs:",
      tostring(count)
    )
    if AuctionFlip.Config.Get("debug") then
      local names = {}
      local unresolved = 0
      for _, data in pairs(AuctionFlip.Scan.Results or {}) do
        if data and data.itemName and data.itemName ~= "" then
          table.insert(names, data.itemName)
          if data.itemName:match("^Item %d+$") then
            unresolved = unresolved + 1
          end
        else
          unresolved = unresolved + 1
        end
      end
      table.sort(names)
      if #names > 0 then
        AuctionFlip.Utilities.Debug("Name range:", names[1], "->", names[#names])
      end
      AuctionFlip.Utilities.Debug("Unresolved names:", tostring(unresolved))
    end

    AuctionFlip.UI.RefreshStatus()
    AuctionFlip.UI.RefreshResults()
    AuctionFlip.UI.RefreshStats()

    local scanMode = AuctionFlip.Config.Get("scan_mode")
    local retrySeconds = AuctionFlip.Config.Get("rescan_interval_seconds") or 15
    if retrySeconds < 2 then retrySeconds = 2 end

    if scanMode == "continuous" and AuctionFlip.UI.IsAuctionHouseVisible() then
      AuctionFlip.Scan.PendingRetry = true
      AuctionFlip.Scan.CurrentPhase = "retry_wait"
      AuctionFlip.Scan.NextRetryAt = time() + retrySeconds
      AuctionFlip.UI.RefreshStatus()
      AuctionFlip.Scan.StartRetryTicker()
      C_Timer.After(retrySeconds, function()
        if AuctionFlip.Scan.PendingRetry and not AuctionFlip.Scan.IsRunning and AuctionFlip.UI.IsAuctionHouseVisible() then
          AuctionFlip.Scan.PendingRetry = false
          AuctionFlip.Scan.NextRetryAt = nil
          AuctionFlip.Utilities.Print("Continuous mode: starting next scan...")
          AuctionFlip.Scan.Start()
        end
      end)
    elseif opportunityCount == 0 and scanMode == "until_opportunities" and AuctionFlip.UI.IsAuctionHouseVisible() then
      AuctionFlip.Scan.PendingRetry = true
      AuctionFlip.Scan.CurrentPhase = "retry_wait"
      AuctionFlip.Scan.NextRetryAt = time() + retrySeconds
      AuctionFlip.UI.RefreshStatus()
      AuctionFlip.Scan.StartRetryTicker()
      C_Timer.After(retrySeconds, function()
        if AuctionFlip.Scan.PendingRetry and not AuctionFlip.Scan.IsRunning and AuctionFlip.UI.IsAuctionHouseVisible() then
          AuctionFlip.Scan.PendingRetry = false
          AuctionFlip.Scan.NextRetryAt = nil
          AuctionFlip.Utilities.Print("No opportunities found. Retrying scan...")
          AuctionFlip.Scan.Start()
        end
      end)
    else
      AuctionFlip.Scan.PendingRetry = false
      AuctionFlip.Scan.NextRetryAt = nil
    end
  end)
end

function AuctionFlip.Scan.Cancel()
  AuctionFlip.Scan.IsRunning = false
  AuctionFlip.State.IsScanning = false
  AuctionFlip.Scan.PendingRetry = false
  AuctionFlip.Scan.PendingMoreRequest = false
  AuctionFlip.Scan.NextRetryAt = nil
  AuctionFlip.Scan.CurrentPhase = "idle"
  AuctionFlip.Opportunities.CancelVerification()
  AuctionFlip.Utilities.Print("Scan cancelled.")
  AuctionFlip.UI.RefreshStatus()
end

function AuctionFlip.Scan.GetResults()
  return AuctionFlip.Scan.Results or {}
end

function AuctionFlip.Scan.GetResultCount()
  return AuctionFlip.Scan.ItemsProcessed or 0
end

function AuctionFlip.Scan.GetLastOpportunityCount()
  return AuctionFlip.Scan.LastOpportunityCount or 0
end

function AuctionFlip.Scan.GetProgressPercent()
  local processed = AuctionFlip.Scan.ItemsProcessed or 0
  local expected = AuctionFlip.Scan.TotalExpected or 0
  if expected <= 0 then
    return nil
  end

  local percent = math.floor((processed / expected) * 100)
  if percent < 0 then percent = 0 end
  if percent > 100 then percent = 100 end
  return percent
end

local scanFrame = CreateFrame("Frame")
scanFrame:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
scanFrame:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_ADDED")
scanFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
scanFrame:SetScript("OnEvent", function(_, event, ...)
  if event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" then
    AuctionFlip.Scan.OnBrowseResultsUpdated()
  elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
    AuctionFlip.Scan.OnBrowseResultsAdded(...)
  elseif event == "GET_ITEM_INFO_RECEIVED" then
    local itemID = ...
    if itemID then
      AuctionFlip.Scan.PendingItemLoads[itemID] = nil
      AuctionFlip.Scan.ApplyResolvedItemInfo(itemID)
    end
  end
end)
