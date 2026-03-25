AuctionFlip.Opportunities = {
  List = {},
  Verification = {
    Queue = {},
    Active = false,
    Callback = nil,
    Current = nil,
    Completed = 0,
    Total = 0,
    Sequence = 0,
    LastProgressAt = 0,
  },
}

function AuctionFlip.Opportunities.Detect(callback)
  return AuctionFlip.Opportunities.DetectWithCallback(callback)
end

function AuctionFlip.Opportunities.DetectWithCallback(callback)
  local scanResults = AuctionFlip.Scan.GetResults()
  if not scanResults or not next(scanResults) then
    if callback then
      callback(AuctionFlip.Opportunities.List)
    end
    return AuctionFlip.Opportunities.List
  end

  local threshold = AuctionFlip.Config.Get("profit_threshold") or 50000
  if AuctionFlip.UI and AuctionFlip.UI.SetActivityMessage then
    AuctionFlip.UI.SetActivityMessage("Building opportunity candidates from " .. tostring(AuctionFlip.Scan.GetResultCount() or 0) .. " item types...")
  end

  C_Timer.After(0.5, function()
    local result = AuctionFlip.Opportunities.AnalyzeItems(scanResults, threshold)
    if AuctionFlip.Config.Get("verify_candidates") and AuctionFlip.Opportunities.CanVerifyCandidates() then
      if AuctionFlip.UI and AuctionFlip.UI.SetActivityMessage then
        AuctionFlip.UI.SetActivityMessage("Verifying candidate listings...")
      end
      AuctionFlip.Opportunities.VerifyTopCandidates(result, threshold, callback)
    elseif callback then
      callback(result)
    end
  end)

  return AuctionFlip.Opportunities.List
end

function AuctionFlip.Opportunities.GetMarketConfidence(snapshot)
  if not snapshot then
    return 0, nil
  end

  local minSamples = AuctionFlip.Config.Get("min_market_samples") or 8
  local minSpanSeconds = (AuctionFlip.Config.Get("min_market_span_minutes") or 60) * 60
  local maxVolatilityPercent = AuctionFlip.Config.Get("max_market_volatility_percent") or 120

  local sampleScore = 1
  if minSamples > 0 then
    sampleScore = math.min((snapshot.samples or 0) / minSamples, 1)
  end

  local spanScore = 1
  if minSpanSeconds > 0 then
    spanScore = math.min((snapshot.spanSeconds or 0) / minSpanSeconds, 1)
  end

  local volatilityPercent = math.floor(((snapshot.volatilityRatio or 0) * 100) + 0.5)
  local volScore = 1
  if maxVolatilityPercent > 0 and volatilityPercent > maxVolatilityPercent then
    volScore = math.max(0, 1 - ((volatilityPercent - maxVolatilityPercent) / maxVolatilityPercent))
  end

  local confidence = math.floor((sampleScore * 0.45 + spanScore * 0.25 + volScore * 0.30) * 100 + 0.5)
  if confidence < 0 then confidence = 0 end
  if confidence > 100 then confidence = 100 end
  return confidence, volatilityPercent
end

function AuctionFlip.Opportunities.GetExpectedSalePrice(opportunity)
  if not opportunity then
    return 0
  end

  if opportunity.verifiedTargetSellPrice and opportunity.verifiedTargetSellPrice > 0 then
    return opportunity.verifiedTargetSellPrice
  end

  if opportunity.type == "vendor_flip" then
    return opportunity.sellPrice or 0
  end

  return opportunity.marketMedianPrice or opportunity.marketPrice or opportunity.marketAveragePrice or 0
end

function AuctionFlip.Opportunities.GetUnitProfit(opportunity)
  if not opportunity then
    return 0
  end

  if opportunity.unitProfit ~= nil then
    return opportunity.unitProfit
  end

  return opportunity.profit or 0
end

function AuctionFlip.Opportunities.GetTotalOpportunityProfit(opportunity)
  if not opportunity then
    return 0
  end

  if opportunity.totalProfit ~= nil then
    return opportunity.totalProfit
  end

  local quantity = math.max(opportunity.quantity or 1, 1)
  return AuctionFlip.Opportunities.GetUnitProfit(opportunity) * quantity
end

function AuctionFlip.Opportunities.GetMaxBuyUnitPrice(opportunity)
  local expectedSale = AuctionFlip.Opportunities.GetExpectedSalePrice(opportunity)
  local minProfit = AuctionFlip.Config.Get("profit_threshold") or 0

  if expectedSale <= 0 then
    return 0, expectedSale
  end

  local maxBuy = 0
  if opportunity and opportunity.type == "vendor_flip" then
    maxBuy = expectedSale - minProfit
  else
    local ahCutPercent = AuctionFlip.Config.Get("ah_cut_percent") or 5
    local netAfterFee = math.floor(expectedSale * ((100 - ahCutPercent) / 100))
    maxBuy = netAfterFee - minProfit
  end
  if maxBuy < 0 then
    maxBuy = 0
  end

  return maxBuy, expectedSale
end

function AuctionFlip.Opportunities.GetCapitalBudgetState()
  local gold = GetMoney() or 0
  local reservePercent = AuctionFlip.Config.Get("capital_reserve_percent") or 35
  local perItemPercent = AuctionFlip.Config.Get("max_capital_per_item_percent") or 15

  local spendable = math.floor(gold * ((100 - reservePercent) / 100))
  if spendable < 0 then spendable = 0 end

  local perItemCap = math.floor(spendable * (perItemPercent / 100))
  if perItemCap < 0 then perItemCap = 0 end

  return {
    totalGold = gold,
    spendable = spendable,
    perItemCap = perItemCap,
  }
end

function AuctionFlip.Opportunities.GetBuyStrategy(opportunity)
  local budget = AuctionFlip.Opportunities.GetCapitalBudgetState()
  local maxUnitBuy, expectedSale = AuctionFlip.Opportunities.GetMaxBuyUnitPrice(opportunity)
  local itemBudget = math.min(budget.spendable or 0, budget.perItemCap or 0)

  return {
    totalGold = budget.totalGold or 0,
    spendable = budget.spendable or 0,
    itemBudget = itemBudget or 0,
    maxUnitBuy = maxUnitBuy or 0,
    expectedSale = expectedSale or 0,
  }
end

function AuctionFlip.Opportunities.AnalyzeItems(scanResults, threshold)
  local analyzedList = {}
  local maxThreshold = AuctionFlip.Config.Get("max_profit_threshold") or 0
  local marketWindowDays = AuctionFlip.Config.Get("market_window_days") or 7
  local minMarketSamples = AuctionFlip.Config.Get("min_market_samples") or 8
  local minMarketSpanSeconds = (AuctionFlip.Config.Get("min_market_span_minutes") or 60) * 60
  local minConfidence = AuctionFlip.Config.Get("min_confidence_percent") or 55
  local ahCutPercent = AuctionFlip.Config.Get("ah_cut_percent") or 5
  local insufficientMarketData = 0

  -- Get active risk profile for advanced filtering
  local riskProfile = AuctionFlip.Analysis.GetActiveRiskProfile()

  for itemId, data in pairs(scanResults) do
    if data.minPrice and data.minPrice > 0 then
      local itemName, itemLink, itemRarity, _, _, _, _, _, _, itemIcon, itemSellPrice, itemClassID = GetItemInfo(itemId)
      local resolvedName = itemName or data.itemName or ("Item " .. itemId)
      if (not itemName or itemName == "") and AuctionFlip.Scan and AuctionFlip.Scan.RequestItemData then
        AuctionFlip.Scan.RequestItemData(itemId)
      end

      -- Category filter check
      local passesCategory = true
      if AuctionFlip.Config.Get("category_filter_enabled") and itemClassID then
        passesCategory = AuctionFlip.Opportunities.PassesCategoryFilter(itemClassID)
      end

      if passesCategory and itemSellPrice and itemSellPrice > 0 then
        local profit = itemSellPrice - data.minPrice

        if profit >= threshold and (maxThreshold <= 0 or profit <= maxThreshold) then
          local quantity = data.quantity or 1
          local totalProfit = profit * quantity
          table.insert(analyzedList, {
            type = "vendor_flip",
            itemId = itemId,
            itemKey = data.itemKey,
            itemLink = itemLink or ("item:" .. itemId),
            itemName = resolvedName,
            icon = itemIcon or 134400,
            buyPrice = data.minPrice,
            sellPrice = itemSellPrice,
            vendorPrice = itemSellPrice,
            profit = profit,
            unitProfit = profit,
            totalProfit = totalProfit,
            quantity = quantity,
            rarity = itemRarity or 0,
            classID = itemClassID or 0,
            source = "Vendor",
            scanStage = "summary",
            verified = false,
            marketConfidence = 100,
            -- Advanced metrics (vendor flips: full confidence, no market risk)
            score = {
              fairPrice = itemSellPrice,
              fairPriceSource = "vendor",
              discount = 0,
              discountPercent = 0,
              grossProfitUnit = profit,
              grossProfitTotal = totalProfit,
              netProfitUnit = profit,
              netProfitTotal = totalProfit,
              totalBuyCost = data.minPrice * quantity,
              ahFeeTotal = 0,
              depositTotal = 0,
              roi = (data.minPrice > 0) and (profit / data.minPrice) or 0,
              roiPercent = (data.minPrice > 0) and math.floor((profit / data.minPrice) * 100 + 0.5) or 0,
              liquidity = 1,
              liquidityLabel = "High",
              confidence = 1,
              confidencePercent = 100,
              volumePerDay = 0,
            },
          })
        end
      end

      if not passesCategory then
        -- skip market analysis for filtered categories
      else
        local stats = AuctionFlip.Analysis.GetItemStats(itemId, marketWindowDays)
        local market = AuctionFlip.Database.GetMarketSnapshot(itemId, marketWindowDays)
        local marketPrice = market and market.median or nil
        local confidence, volatilityPercent = AuctionFlip.Opportunities.GetMarketConfidence(market)

        if marketPrice and marketPrice > 0 and
           market.samples >= minMarketSamples and
           market.spanSeconds >= minMarketSpanSeconds and
           confidence >= minConfidence then
          local priceRatio = data.minPrice / marketPrice

          if priceRatio < 0.7 then
            local profit = marketPrice - data.minPrice

            if profit >= threshold and (maxThreshold <= 0 or profit <= maxThreshold) then
              local isDuplicate = false
              for _, opp in ipairs(analyzedList) do
                if opp.itemId == itemId then
                  isDuplicate = true
                  break
                end
              end

              if not isDuplicate then
                local quantity = data.quantity or 1
                local totalProfit = profit * quantity

                local summaryDeposit = AuctionFlip.Opportunities.EstimateDepositCost(
                  { itemId = itemId, vendorPrice = itemSellPrice or 0 },
                  quantity,
                  AuctionFlip.Opportunities.GetVerificationDurationHours(),
                  false,
                  marketPrice
                )

                -- Compute advanced scoring via Analysis module
                local oppScore = AuctionFlip.Analysis.ScoreOpportunity(
                  stats, data.minPrice, quantity, ahCutPercent, summaryDeposit
                )

                -- Check risk profile filters for underpriced items
                local passesRisk = AuctionFlip.Analysis.PassesRiskProfile(oppScore, itemClassID, riskProfile)

                if passesRisk then
                  table.insert(analyzedList, {
                    type = "underpriced",
                    itemId = itemId,
                    itemKey = data.itemKey,
                    itemLink = itemLink or ("item:" .. itemId),
                    itemName = resolvedName,
                    icon = itemIcon or 134400,
                    buyPrice = data.minPrice,
                    vendorPrice = itemSellPrice or 0,
                    marketPrice = marketPrice,
                    marketAveragePrice = market.average,
                    marketMedianPrice = market.median,
                    marketSamples = market.samples,
                    marketSpanSeconds = market.spanSeconds,
                    marketWindowDays = marketWindowDays,
                    marketVolatilityPercent = volatilityPercent,
                    marketConfidence = confidence,
                    profit = oppScore.netProfitUnit or profit,
                    unitProfit = oppScore.netProfitUnit or profit,
                    totalProfit = oppScore.netProfitTotal or totalProfit,
                    quantity = quantity,
                    rarity = itemRarity or 0,
                    classID = itemClassID or 0,
                    discount = math.floor((1 - priceRatio) * 100),
                    source = "Dataset",
                    scanStage = "summary",
                    verified = false,
                    estimatedDeposit = summaryDeposit,
                    -- Advanced metrics from Analysis
                    score = oppScore,
                    stats = stats,
                  })
                end
              end
            end
          end
        elseif market then
          insufficientMarketData = insufficientMarketData + 1
        end
      end
    end
  end

  -- Sort using configurable sort field
  AuctionFlip.Opportunities.SortList(analyzedList)

  AuctionFlip.Opportunities.List = analyzedList

  local count = #analyzedList
  if count > 0 then
    if AuctionFlip.Config.Get("show_notifications") then
      AuctionFlip.Utilities.Print("Found " .. count .. " opportunities! Total potential: " .. AuctionFlip.Utilities.CreatePaddedMoneyString(AuctionFlip.Opportunities.GetTotalProfit()))
    end
    if AuctionFlip.Config.Get("sound_alerts") then
      PlaySound(SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_3 or 15275, "master")
    end
  end

  if AuctionFlip.Config.Get("debug") and insufficientMarketData > 0 then
    AuctionFlip.Utilities.Debug("Items skipped due insufficient market dataset:", tostring(insufficientMarketData))
  end

  AuctionFlip.UI.RefreshResults()

  return AuctionFlip.Opportunities.List
end

--- Checks if an item classID passes the category filter.
function AuctionFlip.Opportunities.PassesCategoryFilter(classID)
  if not classID then return true end
  local map = {
    [0]  = "category_filter_consumable",
    [2]  = "category_filter_weapon",
    [3]  = "category_filter_gem",
    [4]  = "category_filter_armor",
    [7]  = "category_filter_tradeskill",
    [8]  = "category_filter_enhancement",
    [9]  = "category_filter_recipe",
    [15] = "category_filter_misc",
  }
  local configKey = map[classID]
  if not configKey then
    return true  -- unknown categories pass by default
  end
  return AuctionFlip.Config.Get(configKey) ~= false
end

--- Sorts the opportunity list by the user-configured sort field.
function AuctionFlip.Opportunities.SortList(list)
  local sortField = AuctionFlip.Config.Get("results_sort_field") or "netProfit"
  local ascending = AuctionFlip.Config.Get("results_sort_ascending") or false

  local function getSortValue(opp)
    local s = opp.score
    if sortField == "netProfit" then
      return s and s.netProfitTotal or AuctionFlip.Opportunities.GetTotalOpportunityProfit(opp)
    elseif sortField == "roi" then
      return s and s.roiPercent or 0
    elseif sortField == "discount" then
      return opp.discount or (s and s.discountPercent or 0)
    elseif sortField == "liquidity" then
      return s and s.liquidity or 0
    elseif sortField == "confidence" then
      return s and s.confidencePercent or (opp.marketConfidence or 0)
    else
      return AuctionFlip.Opportunities.GetTotalOpportunityProfit(opp)
    end
  end

  table.sort(list, function(a, b)
    local va = getSortValue(a)
    local vb = getSortValue(b)
    if va == vb then
      -- tiebreaker: total profit descending
      local pa = AuctionFlip.Opportunities.GetTotalOpportunityProfit(a)
      local pb = AuctionFlip.Opportunities.GetTotalOpportunityProfit(b)
      return pa > pb
    end
    if ascending then
      return va < vb
    else
      return va > vb
    end
  end)
end

function AuctionFlip.Opportunities.CanVerifyCandidates()
  return C_AuctionHouse ~= nil and
    C_AuctionHouse.SendSearchQuery ~= nil and
    C_AuctionHouse.GetNumItemSearchResults ~= nil and
    C_AuctionHouse.GetItemSearchResultInfo ~= nil
end

function AuctionFlip.Opportunities.GetVerifiedBuyPrice(itemKey)
  local resultCount = C_AuctionHouse.GetNumItemSearchResults(itemKey)
  if not resultCount or resultCount == 0 then
    return nil
  end

  local firstResult = C_AuctionHouse.GetItemSearchResultInfo(itemKey, 1)
  if not firstResult then
    return nil
  end

  return firstResult.buyoutAmount or firstResult.bidAmount
end

function AuctionFlip.Opportunities.GetVerificationDurationHours()
  local configured = tonumber(AuctionFlip.Config.Get("opportunity_target_duration_hours")) or 24
  if configured < 18 then
    return 12
  elseif configured < 36 then
    return 24
  else
    return 48
  end
end

function AuctionFlip.Opportunities.EstimateDepositCost(opportunity, quantity, durationHours, isCommodity, saleUnitPrice)
  quantity = math.max(math.floor(tonumber(quantity) or 0), 0)
  if quantity <= 0 then
    return 0
  end

  local durationMap = { [12] = 1, [24] = 2, [48] = 3 }
  local durationEnum = durationMap[durationHours] or 2

  if isCommodity and C_AuctionHouse and C_AuctionHouse.CalculateCommodityDeposit and opportunity.itemId then
    local ok, deposit = pcall(C_AuctionHouse.CalculateCommodityDeposit, opportunity.itemId, durationEnum, quantity)
    if ok and deposit and deposit > 0 then
      return math.floor(deposit)
    end
  end

  local vendorPrice = opportunity.vendorPrice or select(11, GetItemInfo(opportunity.itemId))
  if vendorPrice and vendorPrice > 0 then
    local multiplier = (durationHours == 12 and 0.15) or (durationHours == 48 and 0.60) or 0.30
    return math.floor((vendorPrice * quantity * multiplier) + 0.5)
  end

  local fallbackRate = (durationHours == 12 and 0.005) or (durationHours == 48 and 0.02) or 0.01
  return math.floor((math.max(saleUnitPrice or 0, 0) * quantity * fallbackRate) + 0.5)
end

function AuctionFlip.Opportunities.GetVerifiedListings(itemKey, itemId)
  if not C_AuctionHouse then
    return {}, false
  end

  local itemListings = {}
  if C_AuctionHouse.GetNumItemSearchResults and C_AuctionHouse.GetItemSearchResultInfo and itemKey then
    local itemCount = C_AuctionHouse.GetNumItemSearchResults(itemKey) or 0
    for index = 1, itemCount do
      local result = C_AuctionHouse.GetItemSearchResultInfo(itemKey, index)
      local totalPrice = result and (result.buyoutAmount or result.bidAmount) or nil
      local qty = math.max((result and (result.quantity or result.totalQuantity)) or 0, 0)
      if totalPrice and totalPrice > 0 and qty > 0 then
        table.insert(itemListings, {
          unitPrice = math.floor(totalPrice / qty),
          totalPrice = totalPrice,
          quantity = qty,
          auctionID = result.auctionID,
          commodity = false,
        })
      end
    end
  end

  local commodityListings = {}
  if C_AuctionHouse.GetNumCommoditySearchResults and C_AuctionHouse.GetCommoditySearchResultInfo and itemId then
    local commodityCount = C_AuctionHouse.GetNumCommoditySearchResults(itemId) or 0
    for index = 1, commodityCount do
      local result = C_AuctionHouse.GetCommoditySearchResultInfo(itemId, index)
      local unitPrice = result and result.unitPrice or nil
      local qty = math.max((result and result.quantity) or 0, 0)
      if unitPrice and unitPrice > 0 and qty > 0 then
        table.insert(commodityListings, {
          unitPrice = unitPrice,
          totalPrice = unitPrice * qty,
          quantity = qty,
          auctionID = nil,
          commodity = true,
        })
      end
    end
  end

  local listings = #itemListings > 0 and itemListings or commodityListings
  table.sort(listings, function(a, b)
    if (a.unitPrice or 0) == (b.unitPrice or 0) then
      return (a.quantity or 0) > (b.quantity or 0)
    end
    return (a.unitPrice or 0) < (b.unitPrice or 0)
  end)

  local isCommodity = #itemListings == 0 and #commodityListings > 0
  return listings, isCommodity
end

function AuctionFlip.Opportunities.BuildVerifiedBuyPlan(opportunity, listings, isCommodity, threshold)
  if not opportunity then
    return nil
  end
  if not listings or #listings == 0 then
    opportunity.verificationFailed = true
    return nil
  end

  local maxThreshold = AuctionFlip.Config.Get("max_profit_threshold") or 0
  local ahCutPercent = AuctionFlip.Config.Get("ah_cut_percent") or 5
  local maxUnitBuy, fallbackSale = AuctionFlip.Opportunities.GetMaxBuyUnitPrice(opportunity)
  local strategy = AuctionFlip.Opportunities.GetBuyStrategy(opportunity)
  local itemBudget = strategy.itemBudget or 0
  local expectedSale = AuctionFlip.Opportunities.GetExpectedSalePrice(opportunity)
  if expectedSale <= 0 then
    expectedSale = fallbackSale or 0
  end
  local durationHours = AuctionFlip.Opportunities.GetVerificationDurationHours()

  local runningQty = 0
  local runningCost = 0
  local sourceRows = 0
  local minBuyUnit = nil
  local firstAuctionID = nil
  local bestPlan = nil
  local maxBoughtUnit = nil

  for index, listing in ipairs(listings) do
    local unitPrice = listing.unitPrice or 0
    local listingQty = math.max(math.floor(tonumber(listing.quantity) or 0), 0)
    if unitPrice > 0 and listingQty > 0 and unitPrice <= maxUnitBuy then
      local affordableQty = listingQty
      if itemBudget > 0 then
        local remainingBudget = itemBudget - runningCost
        if remainingBudget <= 0 then
          break
        end
        affordableQty = math.min(affordableQty, math.floor(remainingBudget / unitPrice))
      end

      if (not isCommodity) and affordableQty > 0 and affordableQty < listingQty then
        -- Item auctions are bought as full rows; cannot partially buy stack quantity.
        affordableQty = 0
      end

      if affordableQty > 0 then
        runningQty = runningQty + affordableQty
        runningCost = runningCost + (unitPrice * affordableQty)
        sourceRows = sourceRows + 1
        minBuyUnit = minBuyUnit and math.min(minBuyUnit, unitPrice) or unitPrice
        maxBoughtUnit = maxBoughtUnit and math.max(maxBoughtUnit, unitPrice) or unitPrice
        if not firstAuctionID and listing.auctionID then
          firstAuctionID = listing.auctionID
        end

        local targetSellUnit = expectedSale
        local ahFee = 0
        local deposit = 0
        local nextUnitPrice = nil
        local pricingSource = "historical"

        if opportunity.type == "vendor_flip" then
          if targetSellUnit <= 0 then
            targetSellUnit = unitPrice
          end
        else
          for lookAhead = index + 1, #listings do
            local nextListing = listings[lookAhead]
            if nextListing and (nextListing.unitPrice or 0) > 0 then
              nextUnitPrice = nextListing.unitPrice
              break
            end
          end

          if targetSellUnit <= 0 then
            targetSellUnit = unitPrice
          end
          if nextUnitPrice and nextUnitPrice > 1 then
            pricingSource = "next_tier"
            targetSellUnit = math.min(targetSellUnit, nextUnitPrice - 1)
          end
          if nextUnitPrice and expectedSale > 0 and expectedSale < nextUnitPrice then
            pricingSource = "historical_cap"
          elseif not nextUnitPrice then
            pricingSource = "historical"
          end
          if targetSellUnit < unitPrice then
            targetSellUnit = unitPrice
          end

          deposit = AuctionFlip.Opportunities.EstimateDepositCost(
            opportunity,
            runningQty,
            durationHours,
            isCommodity,
            targetSellUnit
          )
        end

        local saleRevenue = targetSellUnit * runningQty
        if opportunity.type ~= "vendor_flip" then
          ahFee = math.floor(saleRevenue * (ahCutPercent / 100))
        end
        local netTotal = saleRevenue - ahFee - runningCost - deposit
        local netUnit = math.floor(netTotal / math.max(runningQty, 1))

        if netUnit >= threshold and (maxThreshold <= 0 or netUnit <= maxThreshold) and netTotal > 0 then
          if not bestPlan or netTotal > (bestPlan.netProfitTotal or 0) then
            bestPlan = {
              quantity = runningQty,
              totalBuyCost = runningCost,
              averageBuyUnit = math.floor(runningCost / math.max(runningQty, 1)),
              minBuyUnit = minBuyUnit or unitPrice,
              targetSellUnit = targetSellUnit,
              netProfitTotal = netTotal,
              netProfitUnit = netUnit,
              ahFeeTotal = ahFee,
              depositTotal = deposit,
              sourceRows = sourceRows,
              firstAuctionID = firstAuctionID,
              durationHours = durationHours,
              nextHigherUnit = nextUnitPrice,
              highestBoughtUnit = maxBoughtUnit or unitPrice,
              pricingSource = pricingSource,
            }
          end
        end
      end
    end
  end

  return bestPlan
end

function AuctionFlip.Opportunities.ApplyVerifiedPrice(opportunity, verifiedPlan, threshold)
  if not verifiedPlan then
    opportunity.verificationFailed = true
    return false
  end

  local quantity = math.max(verifiedPlan.quantity or 1, 1)
  local buyPrice = math.max(verifiedPlan.averageBuyUnit or 0, 0)
  local targetSell = math.max(verifiedPlan.targetSellUnit or 0, 0)
  if buyPrice <= 0 or targetSell <= 0 then
    opportunity.verificationFailed = true
    return false
  end

  local ahCutPercent = AuctionFlip.Config.Get("ah_cut_percent") or 5

  opportunity.buyPrice = buyPrice
  opportunity.scanStage = "verified"
  opportunity.verified = true
  opportunity.quantity = quantity
  opportunity.verifiedMinBuyPrice = verifiedPlan.minBuyUnit
  opportunity.verifiedTargetSellPrice = targetSell
  opportunity.verifiedSourceRows = verifiedPlan.sourceRows
  opportunity.verifiedDurationHours = verifiedPlan.durationHours
  opportunity.verifiedAuctionID = verifiedPlan.firstAuctionID
  opportunity.verifiedNextHigherPrice = verifiedPlan.nextHigherUnit
  opportunity.verifiedHighestBoughtPrice = verifiedPlan.highestBoughtUnit
  opportunity.verifiedPricingSource = verifiedPlan.pricingSource

  if opportunity.type == "underpriced" and opportunity.marketPrice and opportunity.marketPrice > 0 then
    opportunity.discount = math.floor((1 - (buyPrice / opportunity.marketPrice)) * 100)
  end

  opportunity.profit = verifiedPlan.netProfitUnit
  opportunity.unitProfit = verifiedPlan.netProfitUnit
  opportunity.totalProfit = verifiedPlan.netProfitTotal

  local oppScore = nil
  if opportunity.type == "vendor_flip" then
    local totalBuy = verifiedPlan.totalBuyCost or (buyPrice * quantity)
    local roi = 0
    if totalBuy > 0 then
      roi = verifiedPlan.netProfitTotal / totalBuy
    end
    oppScore = {
      fairPrice = targetSell,
      fairPriceSource = "vendor",
      discount = 0,
      discountPercent = 0,
      grossProfitUnit = verifiedPlan.netProfitUnit,
      grossProfitTotal = verifiedPlan.netProfitTotal,
      netProfitUnit = verifiedPlan.netProfitUnit,
      netProfitTotal = verifiedPlan.netProfitTotal,
      totalBuyCost = totalBuy,
      ahFeeTotal = 0,
      depositTotal = 0,
      roi = roi,
      roiPercent = math.floor((roi * 100) + 0.5),
      liquidity = 1,
      liquidityLabel = "High",
      confidence = 1,
      confidencePercent = 100,
      volumePerDay = 0,
      executionSalePrice = targetSell,
    }
  else
    oppScore = AuctionFlip.Analysis.ScoreOpportunity(
      opportunity.stats,
      buyPrice,
      quantity,
      ahCutPercent,
      verifiedPlan.depositTotal or 0
    )
    local saleRevenue = targetSell * quantity
    local ahFee = math.floor(saleRevenue * (ahCutPercent / 100))
    oppScore.executionSalePrice = targetSell
    oppScore.totalBuyCost = verifiedPlan.totalBuyCost or (buyPrice * quantity)
    oppScore.ahFeeTotal = ahFee
    oppScore.depositTotal = verifiedPlan.depositTotal or 0
    oppScore.netProfitTotal = verifiedPlan.netProfitTotal
    oppScore.netProfitUnit = verifiedPlan.netProfitUnit
    if oppScore.totalBuyCost > 0 then
      oppScore.roi = oppScore.netProfitTotal / oppScore.totalBuyCost
      oppScore.roiPercent = math.floor((oppScore.roi * 100) + 0.5)
    else
      oppScore.roi = 0
      oppScore.roiPercent = 0
    end
  end
  opportunity.score = oppScore

  if opportunity.type == "underpriced" then
    local riskProfile = AuctionFlip.Analysis.GetActiveRiskProfile()
    if not AuctionFlip.Analysis.PassesRiskProfile(oppScore, opportunity.classID, riskProfile) then
      return false
    end
  end

  return verifiedPlan.netProfitUnit >= threshold
end

function AuctionFlip.Opportunities.FinalizeVerification(threshold)
  local filtered = {}
  local maxThreshold = AuctionFlip.Config.Get("max_profit_threshold") or 0
  for _, opportunity in ipairs(AuctionFlip.Opportunities.List) do
    if opportunity.verified == false and not opportunity.verificationAttempted then
      table.insert(filtered, opportunity)
    elseif opportunity.verificationAttempted and opportunity.verificationFailed then
      opportunity.scanStage = "summary"
      opportunity.verified = false
      table.insert(filtered, opportunity)
    else
      local unitProfit = AuctionFlip.Opportunities.GetUnitProfit(opportunity)
      if opportunity.verified and unitProfit >= threshold and (maxThreshold <= 0 or unitProfit <= maxThreshold) then
        table.insert(filtered, opportunity)
      end
    end
  end

  AuctionFlip.Opportunities.List = filtered
  table.sort(AuctionFlip.Opportunities.List, function(a, b)
    local aTotal = AuctionFlip.Opportunities.GetTotalOpportunityProfit(a)
    local bTotal = AuctionFlip.Opportunities.GetTotalOpportunityProfit(b)
    if aTotal == bTotal then
      return AuctionFlip.Opportunities.GetUnitProfit(a) > AuctionFlip.Opportunities.GetUnitProfit(b)
    end
    return aTotal > bTotal
  end)

  local shouldCap = AuctionFlip.Config.Get("verify_candidates")
  local maxCandidates = AuctionFlip.Config.Get("max_verified_candidates") or 10
  if shouldCap and maxCandidates > 0 and #AuctionFlip.Opportunities.List > maxCandidates then
    while #AuctionFlip.Opportunities.List > maxCandidates do
      table.remove(AuctionFlip.Opportunities.List)
    end
  end
end

function AuctionFlip.Opportunities.CancelVerification()
  local verification = AuctionFlip.Opportunities.Verification
  verification.Queue = {}
  verification.Active = false
  verification.Callback = nil
  verification.Current = nil
  verification.Completed = 0
  verification.Total = 0
  verification.Sequence = (verification.Sequence or 0) + 1
  verification.LastProgressAt = 0
end

function AuctionFlip.Opportunities.GetVerificationThrottleSeconds()
  local throttleMs = AuctionFlip.Config.Get("verification_query_throttle_ms") or 600
  if throttleMs < 100 then
    throttleMs = 100
  end
  return throttleMs / 1000
end

function AuctionFlip.Opportunities.ScheduleNextVerification(threshold)
  local verification = AuctionFlip.Opportunities.Verification
  if not verification.Active then
    return
  end

  local delay = AuctionFlip.Opportunities.GetVerificationThrottleSeconds()
  AuctionFlip.Utilities.Debug("Queueing verification query in", string.format("%.2fs", delay))
  C_Timer.After(delay, function()
    if verification.Active then
      AuctionFlip.Opportunities.VerifyNextCandidate(threshold)
    end
  end)
end

function AuctionFlip.Opportunities.GetVerificationStallLimitSeconds()
  local timeout = AuctionFlip.Config.Get("verification_timeout") or 1.5
  local throttle = AuctionFlip.Opportunities.GetVerificationThrottleSeconds()
  local limit = timeout + throttle + 2
  if limit < 4 then
    limit = 4
  end
  return limit
end

function AuctionFlip.Opportunities.ScheduleVerificationWatchdog(sequence, threshold)
  C_Timer.After(2, function()
    local verification = AuctionFlip.Opportunities.Verification
    if not verification.Active or verification.Sequence ~= sequence then
      return
    end

    local stalledFor = time() - (verification.LastProgressAt or time())
    local stallLimit = AuctionFlip.Opportunities.GetVerificationStallLimitSeconds()
    if stalledFor >= stallLimit then
      AuctionFlip.Utilities.Debug("Verification watchdog recovered stalled step after", stalledFor .. "s")
      if verification.Current then
        local okResolve = pcall(AuctionFlip.Opportunities.ResolveCurrentVerification, threshold)
        if not okResolve then
          AuctionFlip.Opportunities.FinishVerification(threshold, "watchdog_resolve_error")
        end
      else
        local okNext = pcall(AuctionFlip.Opportunities.VerifyNextCandidate, threshold)
        if not okNext then
          AuctionFlip.Opportunities.FinishVerification(threshold, "watchdog_next_error")
        end
      end
      return
    end

    AuctionFlip.Opportunities.ScheduleVerificationWatchdog(sequence, threshold)
  end)
end

function AuctionFlip.Opportunities.GetVerificationMaxDurationSeconds(totalCandidates)
  local timeout = AuctionFlip.Config.Get("verification_timeout") or 1.5
  local throttle = AuctionFlip.Opportunities.GetVerificationThrottleSeconds()
  local perItem = timeout + throttle + 0.5
  local maxDuration = (totalCandidates or 0) * perItem + 6
  if maxDuration < 12 then
    maxDuration = 12
  end
  return maxDuration
end

function AuctionFlip.Opportunities.FinishVerification(threshold, reason)
  local verification = AuctionFlip.Opportunities.Verification
  if not verification.Active and not verification.Callback then
    return
  end

  verification.Active = false
  AuctionFlip.Opportunities.FinalizeVerification(threshold)
  AuctionFlip.UI.RefreshResults()

  local completed = verification.Completed or 0
  local total = verification.Total or 0
  local callback = verification.Callback
  verification.Callback = nil
  verification.Completed = 0
  verification.Total = 0
  verification.Current = nil

  if callback then
    callback(AuctionFlip.Opportunities.List)
  end

  if AuctionFlip.UI and AuctionFlip.UI.SetActivityMessage then
    local kept = AuctionFlip.Opportunities.GetCount and AuctionFlip.Opportunities.GetCount() or 0
    local msg = string.format("Verification finished (%d/%d). %d opportunities in list.",
      completed,
      total,
      kept
    )
    if reason and reason ~= "" then
      msg = msg .. " Reason: " .. tostring(reason)
    end
    AuctionFlip.UI.SetActivityMessage(msg)
  end

  if reason and reason ~= "" then
    AuctionFlip.Utilities.Debug("Verification finished with reason:", reason)
  end
end

function AuctionFlip.Opportunities.ResolveCurrentVerification(threshold)
  local verification = AuctionFlip.Opportunities.Verification
  local current = verification.Current

  if not verification.Active or not current then
    return
  end

  local listings, isCommodity = {}, false
  local okListings, listResult, commodityResult = pcall(AuctionFlip.Opportunities.GetVerifiedListings, current.itemKey, current.itemId)
  if okListings then
    listings = listResult or {}
    isCommodity = commodityResult and true or false
  end

  local verifiedPlan = nil
  if #listings > 0 then
    local okPlan, planResult = pcall(AuctionFlip.Opportunities.BuildVerifiedBuyPlan, current, listings, isCommodity, threshold)
    if okPlan then
      verifiedPlan = planResult
    end
  else
    local fallbackPrice = nil
    local okPrice, priceResult = pcall(AuctionFlip.Opportunities.GetVerifiedBuyPrice, current.itemKey)
    if okPrice then
      fallbackPrice = priceResult
    end
    if fallbackPrice and fallbackPrice > 0 then
      verifiedPlan = {
        quantity = 1,
        totalBuyCost = fallbackPrice,
        averageBuyUnit = fallbackPrice,
        minBuyUnit = fallbackPrice,
        targetSellUnit = AuctionFlip.Opportunities.GetExpectedSalePrice(current),
        netProfitTotal = 0,
        netProfitUnit = 0,
        ahFeeTotal = 0,
        depositTotal = 0,
        sourceRows = 1,
        firstAuctionID = nil,
        durationHours = AuctionFlip.Opportunities.GetVerificationDurationHours(),
      }
    end
  end

  local okApply, keepCandidate = pcall(AuctionFlip.Opportunities.ApplyVerifiedPrice, current, verifiedPlan, threshold)
  if not okApply or not keepCandidate then
    current.verified = false
  end

  verification.Completed = verification.Completed + 1
  verification.LastProgressAt = time()
  verification.Current = nil
  AuctionFlip.Opportunities.ScheduleNextVerification(threshold)
end

function AuctionFlip.Opportunities.VerifyNextCandidate(threshold)
  local verification = AuctionFlip.Opportunities.Verification
  local nextOpportunity = table.remove(verification.Queue, 1)

  if not nextOpportunity then
    AuctionFlip.Opportunities.FinishVerification(threshold, "queue_drained")
    return
  end

  verification.Current = nextOpportunity
  nextOpportunity.verificationAttempted = true
  verification.LastProgressAt = time()
  AuctionFlip.Scan.CurrentPhase = "verifying"
  if AuctionFlip.UI and AuctionFlip.UI.SetActivityMessage then
    local itemName = nextOpportunity.itemName or ("Item " .. tostring(nextOpportunity.itemId or "unknown"))
    local currentIndex = (verification.Completed or 0) + 1
    local total = verification.Total or 0
    AuctionFlip.UI.SetActivityMessage(string.format("Verifying candidate listings... %d/%d | %s", currentIndex, total, itemName))
  end
  AuctionFlip.UI.RefreshStatus()

  AuctionFlip.Utilities.Debug("SendSearchQuery for", tostring(nextOpportunity.itemId or "unknown"))
  local okSend = pcall(C_AuctionHouse.SendSearchQuery, nextOpportunity.itemKey, {}, true)
  if not okSend then
    C_Timer.After(0, function()
      if verification.Active and verification.Current == nextOpportunity then
        AuctionFlip.Opportunities.ResolveCurrentVerification(threshold)
      end
    end)
    return
  end

  C_Timer.After(AuctionFlip.Config.Get("verification_timeout") or 1.5, function()
    if verification.Active and verification.Current == nextOpportunity then
      AuctionFlip.Opportunities.ResolveCurrentVerification(threshold)
    end
  end)
end

function AuctionFlip.Opportunities.VerifyTopCandidates(opportunities, threshold, callback)
  local verification = AuctionFlip.Opportunities.Verification
  verification.Queue = {}
  verification.Active = true
  verification.Callback = callback
  verification.Current = nil
  verification.Completed = 0
  verification.Total = 0
  verification.Sequence = (verification.Sequence or 0) + 1
  verification.LastProgressAt = time()

  local maxCandidates = AuctionFlip.Config.Get("max_verified_candidates") or 10

  for _, opportunity in ipairs(opportunities) do
    if opportunity.itemKey and #verification.Queue < maxCandidates then
      table.insert(verification.Queue, opportunity)
    else
      opportunity.verified = true
      opportunity.scanStage = "summary"
    end
  end

  verification.Total = #verification.Queue

  if #verification.Queue == 0 then
    AuctionFlip.Opportunities.FinishVerification(threshold, "empty_queue")
    return
  end

  local sequence = verification.Sequence
  local maxDuration = AuctionFlip.Opportunities.GetVerificationMaxDurationSeconds(verification.Total)
  C_Timer.After(maxDuration, function()
    if verification.Active and verification.Sequence == sequence then
      AuctionFlip.Utilities.Debug("Verification max-duration timeout reached, forcing finalize.")
      AuctionFlip.Opportunities.FinishVerification(threshold, "max_duration_timeout")
    end
  end)

  AuctionFlip.Opportunities.ScheduleVerificationWatchdog(verification.Sequence, threshold)
  AuctionFlip.Opportunities.ScheduleNextVerification(threshold)
end

local verificationFrame = CreateFrame("Frame")
verificationFrame:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
verificationFrame:SetScript("OnEvent", function(_, event, itemKey)
  if event ~= "ITEM_SEARCH_RESULTS_UPDATED" then
    return
  end

  local verification = AuctionFlip.Opportunities.Verification
  local current = verification.Current
  if not verification.Active or not current or not current.itemKey then
    return
  end

  if AuctionFlip.Utilities.GetItemKeyString and AuctionFlip.Utilities.GetItemKeyString(itemKey) ~= AuctionFlip.Utilities.GetItemKeyString(current.itemKey) then
    return
  end

  local threshold = AuctionFlip.Config.Get("profit_threshold") or 50000
  local okResolve = pcall(AuctionFlip.Opportunities.ResolveCurrentVerification, threshold)
  if not okResolve then
    AuctionFlip.Opportunities.FinishVerification(threshold, "item_event_resolve_error")
  end
end)

function AuctionFlip.Opportunities.GetList()
  return AuctionFlip.Opportunities.List or {}
end

function AuctionFlip.Opportunities.GetCount()
  return #AuctionFlip.Opportunities.List
end

function AuctionFlip.Opportunities.GetTotalProfit()
  local total = 0
  for _, opp in ipairs(AuctionFlip.Opportunities.List) do
    total = total + AuctionFlip.Opportunities.GetTotalOpportunityProfit(opp)
  end
  return total
end

function AuctionFlip.Opportunities.GetVendorFlips()
  local flips = {}
  for _, opp in ipairs(AuctionFlip.Opportunities.List) do
    if opp.type == "vendor_flip" then
      table.insert(flips, opp)
    end
  end
  return flips
end

function AuctionFlip.Opportunities.GetUnderpriced()
  local items = {}
  for _, opp in ipairs(AuctionFlip.Opportunities.List) do
    if opp.type == "underpriced" then
      table.insert(items, opp)
    end
  end
  return items
end
