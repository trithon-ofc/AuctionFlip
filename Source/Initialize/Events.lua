local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
initFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")

initFrame:SetScript("OnEvent", function(self, event, arg1)
  if event == "ADDON_LOADED" and arg1 == "AuctionFlip" then
    AuctionFlip.Initialize()
    self:UnregisterEvent("ADDON_LOADED")
  elseif event == "AUCTION_HOUSE_SHOW" then
    C_Timer.After(0.5, function()
      if not AuctionFlip.UI.TabCreated then
        AuctionFlip.UI.CreateTab()
      end
    end)
  elseif event == "AUCTION_HOUSE_CLOSED" then
    -- Hide the side panel when AH closes
    if AuctionFlip.UI.Frame and AuctionFlip.UI.Frame:IsShown() then
      AuctionFlip.UI.Frame:Hide()
    end
  end
end)
