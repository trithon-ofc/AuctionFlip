function AuctionFlip.SlashCmd.Initialize()
  SlashCmdList["AUCTIONFLIP"] = function(msg)
    local cmd = msg:lower():trim()

    if cmd == "" or cmd == "flip" or cmd == "show" then
      AuctionFlip.UI.Toggle()
    elseif cmd == "tab" then
      AuctionFlip.UI.CreateTab()
    elseif cmd == "scan" then
      if not AuctionFlip.UI.IsAuctionHouseVisible() then
        AuctionFlip.Utilities.Print("Open the Auction House first!")
        return
      end
      AuctionFlip.Scan.Start()
    elseif cmd == "debug" or cmd == "debug on" then
      AuctionFlip.Config.Set("debug", true)
      AuctionFlip.Utilities.Print("Debug mode enabled.")
    elseif cmd == "debug off" then
      AuctionFlip.Config.Set("debug", false)
      AuctionFlip.Utilities.Print("Debug mode disabled.")
    elseif cmd == "debug status" then
      AuctionFlip.Utilities.Print("Debug mode is " .. (AuctionFlip.Config.Get("debug") and "ON" or "OFF") .. ".")
    elseif cmd == "stats" then
      print("=== AuctionFlip Statistics ===")
      print("Total Profit:", AuctionFlip.Utilities.CreatePaddedMoneyString(AuctionFlip.Stats.GetTotalProfit()))
      print("Total Flips:", AuctionFlip.Stats.GetTotalFlips())
      print("Success Rate:", AuctionFlip.Stats.GetSuccessRate() .. "%")
      print("Average Profit:", AuctionFlip.Utilities.CreatePaddedMoneyString(AuctionFlip.Stats.GetAverageProfit()))
      print("Scans Completed:", AuctionFlip.Stats.GetScansCompleted())
    elseif cmd == "reset" then
      AuctionFlip.Stats.Reset()
      AuctionFlip.Utilities.Print("Statistics reset.")
    elseif cmd == "version" or cmd == "ver" then
      AuctionFlip.Utilities.Print("Version " .. AuctionFlip.Utilities.GetAddonVersion() .. " | Developer: " .. AuctionFlip.Utilities.GetAddonAuthor())
    else
      print("|cFF00FFAA[AuctionFlip]|r Commands:")
      print("  /flip - Open AH tab or window")
      print("  /flip scan - Scan AH for opportunities")
      print("  /flip debug - Enable debug logging")
      print("  /flip debug off - Disable debug logging")
      print("  /flip debug status - Show debug state")
      print("  /flip version - Show addon version")
      print("  /flip stats - Show statistics")
      print("  /flip reset - Reset statistics")
    end
  end

  SLASH_AUCTIONFLIP1 = "/auctionflip"
  SLASH_AUCTIONFLIP2 = "/flip"
  SLASH_AUCTIONFLIP3 = "/af"
end
