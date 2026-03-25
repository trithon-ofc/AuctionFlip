function AuctionFlip.Initialize()
  AuctionFlip.Config.Initialize()
  AuctionFlip.Database.Initialize()
  AuctionFlip.Portfolio.Initialize()
  AuctionFlip.Stats.Initialize()
  AuctionFlip.Scan.Initialize()
  AuctionFlip.SlashCmd.Initialize()

  AuctionFlip.State.Version = AuctionFlip.Utilities.GetAddonVersion()
  AuctionFlip.State.Author = AuctionFlip.Utilities.GetAddonAuthor()

  print("|cFF00FF00[AuctionFlip] v" .. AuctionFlip.State.Version .. " loaded!|r")
  print("|cFF00FFAA[AuctionFlip]|r Open Auction House to see the AuctionFlip tab!")
end
