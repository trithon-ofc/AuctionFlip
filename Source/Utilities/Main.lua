AuctionFlip.Utilities = {}

function AuctionFlip.Utilities.CreatePaddedMoneyString(copper)
  if not copper or copper == 0 then return "0g 0s 0c" end
  local isNegative = copper < 0
  copper = math.abs(copper)
  local gold = math.floor(copper / 10000)
  local silver = math.floor((copper % 10000) / 100)
  local copperPart = copper % 100
  local str = ""
  if gold > 0 then str = str .. gold .. "g " end
  if silver > 0 or gold > 0 then str = str .. silver .. "s " end
  str = str .. copperPart .. "c"
  if isNegative then str = "-" .. str end
  return str
end

function AuctionFlip.Utilities.FormatProfit(copper)
  if not copper then return "+0g 0s 0c" end
  local prefix = copper >= 0 and "+" or ""
  return prefix .. AuctionFlip.Utilities.CreatePaddedMoneyString(copper)
end

function AuctionFlip.Utilities.CreateCompactMoneyString(copper)
  if not copper or copper == 0 then
    return "0g"
  end

  local isNegative = copper < 0
  local absCopper = math.abs(copper)
  local gold = absCopper / 10000
  local text = nil

  if gold >= 1000000 then
    text = string.format("%.1fM g", gold / 1000000)
  elseif gold >= 1000 then
    text = string.format("%.1fk g", gold / 1000)
  elseif gold >= 1 then
    text = string.format("%.1f g", gold)
  else
    local silver = math.floor((absCopper % 10000) / 100)
    local copperPart = absCopper % 100
    text = tostring(silver) .. "s " .. tostring(copperPart) .. "c"
  end

  if isNegative then
    text = "-" .. text
  end

  return text
end

function AuctionFlip.Utilities.CreateCompactNumberString(value)
  local n = tonumber(value) or 0
  local absValue = math.abs(n)
  local text = nil

  if absValue >= 1000000 then
    text = string.format("%.1fM", absValue / 1000000)
  elseif absValue >= 1000 then
    text = string.format("%.1fk", absValue / 1000)
  else
    text = tostring(math.floor(absValue + 0.5))
  end

  if n < 0 then
    text = "-" .. text
  end

  return text
end

function AuctionFlip.Utilities.TruncateText(text, maxChars)
  text = tostring(text or "")
  maxChars = tonumber(maxChars) or 0
  if maxChars <= 0 or string.len(text) <= maxChars then
    return text
  end
  if maxChars <= 3 then
    return string.sub(text, 1, maxChars)
  end
  return string.sub(text, 1, maxChars - 3) .. "..."
end

function AuctionFlip.Utilities.GetDBKeyFromLink(link)
  if not link then return nil end
  local itemId = link:match("item:(%d+)")
  if itemId then
    return "i" .. itemId
  end
  local commodityId = link:match("battlepet:(%d+)")
  if commodityId then
    return "p" .. commodityId
  end
  return nil
end

function AuctionFlip.Utilities.GetItemKeyString(itemKey)
  if not itemKey then
    return ""
  end

  return table.concat({
    tostring(itemKey.itemID or 0),
    tostring(itemKey.itemLevel or 0),
    tostring(itemKey.itemSuffix or 0),
    tostring(itemKey.battlePetSpeciesID or 0),
  }, ":")
end

function AuctionFlip.Utilities.GetItemIdFromLink(link)
  if not link then return nil end
  return tonumber(link:match("item:(%d+)"))
end

function AuctionFlip.Utilities.GetVendorPrice(itemId)
  if not itemId or itemId == 0 then return 0 end
  local _, _, _, _, _, _, _, _, _, _, sellPrice = GetItemInfo(itemId)
  return sellPrice or 0
end

function AuctionFlip.Utilities.GetItemInfoFromLink(link)
  if not link then return nil end
  local itemId = AuctionFlip.Utilities.GetItemIdFromLink(link)
  if not itemId then return nil end

  local name, itemLink, quality, level, minLevel, class, subclass, maxStack, equipLoc, icon, sellPrice, classID, subclassID, bindType = GetItemInfo(link)

  return {
    itemId = itemId,
    name = name or "Unknown",
    link = itemLink or link,
    quality = quality or 0,
    level = level or 0,
    minLevel = minLevel or 0,
    class = class or "",
    subclass = subclass or "",
    maxStack = maxStack or 1,
    equipLoc = equipLoc or "",
    icon = icon or 134400,
    sellPrice = sellPrice or 0,
    classID = classID or 0,
    subclassID = subclassID or 0,
    bindType = bindType or 0,
  }
end

function AuctionFlip.Utilities.Print(...)
  print("|cFF00FFAA[AuctionFlip]|r", ...)
end

function AuctionFlip.Utilities.GetAddonVersion()
  local version = nil
  if C_AddOns and C_AddOns.GetAddOnMetadata then
    version = C_AddOns.GetAddOnMetadata("AuctionFlip", "Version")
  end
  if (not version or version == "") and GetAddOnMetadata then
    version = GetAddOnMetadata("AuctionFlip", "Version")
  end
  if version and version ~= "" then
    return version
  end
  if AuctionFlip.State and AuctionFlip.State.Version and AuctionFlip.State.Version ~= "dev" then
    return AuctionFlip.State.Version
  end
  return "0.3.0"
end

function AuctionFlip.Utilities.GetAddonAuthor()
  local author = nil
  if C_AddOns and C_AddOns.GetAddOnMetadata then
    author = C_AddOns.GetAddOnMetadata("AuctionFlip", "Author")
  end
  if (not author or author == "") and GetAddOnMetadata then
    author = GetAddOnMetadata("AuctionFlip", "Author")
  end
  if author and author ~= "" then
    return author
  end
  if AuctionFlip.State and AuctionFlip.State.Author and AuctionFlip.State.Author ~= "Unknown" then
    return AuctionFlip.State.Author
  end
  return "Trithon"
end

function AuctionFlip.Utilities.Debug(...)
  if not AuctionFlip.Config or not AuctionFlip.Config.Get or not AuctionFlip.Config.Get("debug") then
    return
  end

  print("|cFFFFAA00[AuctionFlip:Debug]|r", ...)
end
