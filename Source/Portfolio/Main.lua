AuctionFlip.Portfolio = {
  Data = nil,
  SelectedIndex = nil,
}

local function EnsureData()
  AUCTIONFLIP_PORTFOLIO = AUCTIONFLIP_PORTFOLIO or {
    purchases = {},
    version = 1,
  }
  AuctionFlip.Portfolio.Data = AUCTIONFLIP_PORTFOLIO
end

local function NormalizeEntry(raw)
  if type(raw) ~= "table" then
    return nil
  end

  local itemId = tonumber(raw.itemId)
  if not itemId then
    return nil
  end

  local quantity = math.max(math.floor(tonumber(raw.quantity) or 1), 1)
  local purchasePrice = math.max(math.floor(tonumber(raw.purchasePrice) or 0), 0)
  local bagCount = math.max(math.floor(tonumber(raw.bagCount) or 0), 0)

  return {
    itemId = itemId,
    itemKey = raw.itemKey or { itemID = itemId },
    itemName = raw.itemName or ("Item " .. tostring(itemId)),
    icon = raw.icon or 134400,
    purchasePrice = purchasePrice,
    quantity = quantity,
    purchasedAt = tonumber(raw.purchasedAt) or 0,
    inBags = raw.inBags and true or false,
    bagCount = bagCount,
    suggestedPrice = math.max(math.floor(tonumber(raw.suggestedPrice) or 0), 0),
    currentMinPrice = raw.currentMinPrice and math.max(math.floor(tonumber(raw.currentMinPrice) or 0), 0) or nil,
    recommendedPrice = raw.recommendedPrice and math.max(math.floor(tonumber(raw.recommendedPrice) or 0), 0) or nil,
    status = raw.status or "Pending bag update",
    lastMarketCheckAt = tonumber(raw.lastMarketCheckAt) or nil,
  }
end

local function MergeEntry(existing, incoming)
  local qtyA = math.max(tonumber(existing.quantity) or 1, 1)
  local qtyB = math.max(tonumber(incoming.quantity) or 1, 1)
  local totalQty = qtyA + qtyB

  local totalSpent = (math.max(tonumber(existing.purchasePrice) or 0, 0) * qtyA) +
    (math.max(tonumber(incoming.purchasePrice) or 0, 0) * qtyB)
  existing.purchasePrice = math.floor(totalSpent / math.max(totalQty, 1))
  existing.quantity = totalQty
  existing.purchasedAt = math.max(tonumber(existing.purchasedAt) or 0, tonumber(incoming.purchasedAt) or 0)

  if (not existing.itemName or existing.itemName == "") and incoming.itemName then
    existing.itemName = incoming.itemName
  end
  if not existing.itemKey and incoming.itemKey then
    existing.itemKey = incoming.itemKey
  end
  if (not existing.icon or existing.icon == 0) and incoming.icon then
    existing.icon = incoming.icon
  end
end

function AuctionFlip.Portfolio.NormalizePurchases()
  EnsureData()

  local merged = {}
  local byItemId = {}

  for _, raw in ipairs(AuctionFlip.Portfolio.Data.purchases or {}) do
    local entry = NormalizeEntry(raw)
    if entry then
      local existing = byItemId[entry.itemId]
      if existing then
        MergeEntry(existing, entry)
      else
        table.insert(merged, entry)
        byItemId[entry.itemId] = entry
      end
    end
  end

  AuctionFlip.Portfolio.Data.purchases = merged

  if AuctionFlip.Portfolio.SelectedIndex and AuctionFlip.Portfolio.SelectedIndex > #merged then
    AuctionFlip.Portfolio.SelectedIndex = nil
  end
end

function AuctionFlip.Portfolio.Initialize()
  EnsureData()
  AuctionFlip.Portfolio.NormalizePurchases()
  AuctionFlip.Portfolio.RefreshBagStates()
end

function AuctionFlip.Portfolio.GetItems()
  EnsureData()
  return AuctionFlip.Portfolio.Data.purchases
end

function AuctionFlip.Portfolio.GetSelectedEntry()
  local items = AuctionFlip.Portfolio.GetItems()
  return items[AuctionFlip.Portfolio.SelectedIndex or 0]
end

local function GetPlayerBagMaxIndex()
  local maxBag = NUM_BAG_SLOTS or 4
  if NUM_TOTAL_EQUIPPED_BAG_SLOTS and NUM_TOTAL_EQUIPPED_BAG_SLOTS > maxBag then
    maxBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS
  end

  -- Retail reagent bag index (safe on older clients: empty/non-existent bag returns 0 slots).
  if maxBag < 5 then
    maxBag = 5
  end

  return maxBag
end

local function GetBagSlotCount(bag)
  if C_Container and C_Container.GetContainerNumSlots then
    return C_Container.GetContainerNumSlots(bag) or 0
  end
  if GetContainerNumSlots then
    return GetContainerNumSlots(bag) or 0
  end
  return 0
end

local function GetBagSlotItemId(bag, slot)
  if C_Container and C_Container.GetContainerItemID then
    return C_Container.GetContainerItemID(bag, slot)
  end
  if GetContainerItemID then
    return GetContainerItemID(bag, slot)
  end
  return nil
end

local function GetBagSlotStackCount(bag, slot)
  if C_Container and C_Container.GetContainerItemInfo then
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if info then
      return info.stackCount or info.quantity or 0
    end
    return 0
  end

  if GetContainerItemInfo then
    local _, count = GetContainerItemInfo(bag, slot)
    return count or 0
  end

  return 0
end

function AuctionFlip.Portfolio.FindItemBagSlot(itemId)
  if not itemId then
    return nil, nil
  end

  local maxBag = GetPlayerBagMaxIndex()
  for bag = 0, maxBag do
    local slotCount = GetBagSlotCount(bag)

    for slot = 1, slotCount do
      local slotItemId = GetBagSlotItemId(bag, slot)

      if slotItemId and slotItemId == itemId then
        return bag, slot
      end
    end
  end

  return nil, nil
end

function AuctionFlip.Portfolio.AddPurchase(opportunity, purchasePrice, quantity)
  if not opportunity or not opportunity.itemId then
    return
  end

  EnsureData()

  local newEntry = {
    itemId = opportunity.itemId,
    itemKey = opportunity.itemKey,
    itemName = opportunity.itemName or ("Item " .. tostring(opportunity.itemId)),
    icon = opportunity.icon or 134400,
    purchasePrice = purchasePrice or opportunity.buyPrice or 0,
    quantity = quantity or opportunity.quantity or 1,
    purchasedAt = time(),
    inBags = false,
    bagCount = 0,
    suggestedPrice = 0,
    currentMinPrice = nil,
    recommendedPrice = nil,
    status = "Pending bag update",
  }

  for _, existing in ipairs(AuctionFlip.Portfolio.Data.purchases) do
    if existing.itemId == newEntry.itemId then
      MergeEntry(existing, newEntry)
      AuctionFlip.Portfolio.RefreshEntry(existing)
      if AuctionFlip.UI and AuctionFlip.UI.RefreshSelling then
        AuctionFlip.UI.RefreshSelling()
      end
      return
    end
  end

  table.insert(AuctionFlip.Portfolio.Data.purchases, 1, newEntry)
  AuctionFlip.Portfolio.RefreshEntry(newEntry)
  if AuctionFlip.UI and AuctionFlip.UI.RefreshSelling then
    AuctionFlip.UI.RefreshSelling()
  end
end

function AuctionFlip.Portfolio.MarkPosted(itemId, quantityPosted)
  if not itemId then
    return false
  end

  local remainingToApply = math.max(math.floor(tonumber(quantityPosted) or 1), 1)
  local items = AuctionFlip.Portfolio.GetItems()
  local changed = false

  for i = #items, 1, -1 do
    local entry = items[i]
    if entry and entry.itemId == itemId then
      local owned = math.max(math.floor(tonumber(entry.quantity) or 1), 1)
      local used = math.min(owned, remainingToApply)
      entry.quantity = math.max(owned - used, 0)
      remainingToApply = math.max(remainingToApply - used, 0)
      changed = true

      if entry.quantity <= 0 then
        table.remove(items, i)
      else
        entry.purchasedAt = time()
      end

      if remainingToApply <= 0 then
        break
      end
    end
  end

  if changed then
    if AuctionFlip.Portfolio.SelectedIndex and AuctionFlip.Portfolio.SelectedIndex > #items then
      AuctionFlip.Portfolio.SelectedIndex = #items > 0 and #items or nil
    end
    AuctionFlip.Portfolio.RefreshBagStates()
  end

  return changed
end

function AuctionFlip.Portfolio.GetBagCount(itemId)
  if not itemId then
    return 0
  end

  local total = 0
  local maxBag = GetPlayerBagMaxIndex()
  for bag = 0, maxBag do
    local slotCount = GetBagSlotCount(bag)
    for slot = 1, slotCount do
      local slotItemId = GetBagSlotItemId(bag, slot)
      if slotItemId and slotItemId == itemId then
        total = total + math.max(GetBagSlotStackCount(bag, slot), 0)
      end
    end
  end

  return total
end

function AuctionFlip.Portfolio.GetSuggestedSalePrice(entry)
  local windowDays = AuctionFlip.Config.Get("market_window_days") or 7
  local market = AuctionFlip.Database.GetMarketSnapshot(entry.itemId, windowDays)
  local avg = market and market.median or AuctionFlip.Database.GetAveragePrice(entry.itemId, windowDays)
  local minProfit = AuctionFlip.Config.Get("profit_threshold") or 0
  local base = (entry.purchasePrice or 0) + minProfit

  if avg and avg > 0 then
    if avg > base then
      return avg
    end
    return base
  end

  if base > 0 then
    return base
  end

  return math.floor((entry.purchasePrice or 0) * 1.20)
end

function AuctionFlip.Portfolio.GetRecommendedSalePrice(entry)
  local suggested = entry.suggestedPrice or AuctionFlip.Portfolio.GetSuggestedSalePrice(entry)
  local minProfit = AuctionFlip.Config.Get("profit_threshold") or 0
  local minAllowed = (entry.purchasePrice or 0) + minProfit

  if entry.currentMinPrice and entry.currentMinPrice > 0 and entry.currentMinPrice < suggested then
    local candidate = math.max(entry.currentMinPrice - 1, minAllowed)
    return candidate
  end

  return math.max(suggested, minAllowed)
end

function AuctionFlip.Portfolio.RefreshEntry(entry)
  if not entry then
    return
  end

  entry.bagCount = AuctionFlip.Portfolio.GetBagCount(entry.itemId)
  entry.inBags = entry.bagCount > 0
  entry.suggestedPrice = AuctionFlip.Portfolio.GetSuggestedSalePrice(entry)
  entry.recommendedPrice = AuctionFlip.Portfolio.GetRecommendedSalePrice(entry)

  if not entry.inBags then
    entry.status = "Item not found in bags"
  elseif entry.currentMinPrice and entry.currentMinPrice > 0 and entry.currentMinPrice < (entry.suggestedPrice or 0) then
    entry.status = "Undercut detected"
  else
    entry.status = "Ready to sell"
  end
end

function AuctionFlip.Portfolio.RefreshBagStates()
  local items = AuctionFlip.Portfolio.GetItems()
  for _, entry in ipairs(items) do
    AuctionFlip.Portfolio.RefreshEntry(entry)
  end
end

function AuctionFlip.Portfolio.UpdateMarketForEntry(entry, callback)
  if not entry then
    if callback then callback(false) end
    return
  end

  local function applyPrice(price)
    entry.currentMinPrice = price
    entry.lastMarketCheckAt = time()
    AuctionFlip.Portfolio.RefreshEntry(entry)
    if callback then callback(true) end
  end

  if AuctionFrame and AuctionFrame:IsShown() and QueryAuctionItems and GetNumAuctionItems and GetAuctionItemInfo then
    QueryAuctionItems(entry.itemName, nil, nil, 0, false, nil, false, false)
    C_Timer.After(0.8, function()
      local num = GetNumAuctionItems("list") or 0
      local best = nil
      for index = 1, num do
        local name, _, _, _, _, _, _, _, _, buyoutPrice, _, _, _, _, _, itemId = GetAuctionItemInfo("list", index)
        if buyoutPrice and buyoutPrice > 0 then
          local matches = (itemId and entry.itemId and itemId == entry.itemId) or (name and name == entry.itemName)
          if matches and (not best or buyoutPrice < best) then
            best = buyoutPrice
          end
        end
      end
      applyPrice(best)
    end)
    return
  end

  local itemKey = entry.itemKey
  if not itemKey and entry.itemId then
    itemKey = { itemID = entry.itemId }
  end

  if C_AuctionHouse and C_AuctionHouse.SendSearchQuery and C_AuctionHouse.GetNumItemSearchResults and C_AuctionHouse.GetItemSearchResultInfo and itemKey then
    C_AuctionHouse.SendSearchQuery(itemKey, {}, true)

    local function poll(attempt)
      local itemBest = nil
      local itemCount = C_AuctionHouse.GetNumItemSearchResults(itemKey) or 0
      if itemCount > 0 then
        for index = 1, itemCount do
          local result = C_AuctionHouse.GetItemSearchResultInfo(itemKey, index)
          local totalPrice = result and (result.buyoutAmount or result.bidAmount) or nil
          local qty = math.max((result and (result.quantity or result.totalQuantity)) or 1, 1)
          local unitPrice = totalPrice and math.floor(totalPrice / qty) or nil
          if unitPrice and unitPrice > 0 and (not itemBest or unitPrice < itemBest) then
            itemBest = unitPrice
          end
        end
      end

      local commodityBest = nil
      if entry.itemId and C_AuctionHouse.GetNumCommoditySearchResults and C_AuctionHouse.GetCommoditySearchResultInfo then
        local commodityCount = C_AuctionHouse.GetNumCommoditySearchResults(entry.itemId) or 0
        if commodityCount > 0 then
          for index = 1, commodityCount do
            local result = C_AuctionHouse.GetCommoditySearchResultInfo(entry.itemId, index)
            local unitPrice = result and result.unitPrice or nil
            if unitPrice and unitPrice > 0 and (not commodityBest or unitPrice < commodityBest) then
              commodityBest = unitPrice
            end
          end
        end
      end

      local best = nil
      if itemBest and commodityBest then
        best = math.min(itemBest, commodityBest)
      else
        best = itemBest or commodityBest
      end

      if best and best > 0 then
        applyPrice(best)
        return
      end

      if attempt < 8 then
        C_Timer.After(0.4, function()
          poll(attempt + 1)
        end)
      else
        applyPrice(nil)
      end
    end

    C_Timer.After(0.3, function()
      poll(1)
    end)
    return
  end

  if callback then callback(false) end
end

function AuctionFlip.Portfolio.UpdateSelectedMarket(callback)
  local items = AuctionFlip.Portfolio.GetItems()
  local entry = items[AuctionFlip.Portfolio.SelectedIndex or 0]
  AuctionFlip.Portfolio.UpdateMarketForEntry(entry, callback)
end

local bagFrame = CreateFrame("Frame")
bagFrame:RegisterEvent("BAG_UPDATE_DELAYED")
bagFrame:SetScript("OnEvent", function(_, event)
  if event ~= "BAG_UPDATE_DELAYED" then
    return
  end

  if not AuctionFlip.Portfolio or not AuctionFlip.Portfolio.RefreshBagStates then
    return
  end

  AuctionFlip.Portfolio.RefreshBagStates()
  if AuctionFlip.UI and AuctionFlip.UI.RefreshSelling then
    AuctionFlip.UI.RefreshSelling()
  end
end)
