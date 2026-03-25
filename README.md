# AuctionFlip

AuctionFlip is a World of Warcraft Auction House addon focused on market speculation. It scans the Auction House, identifies profitable flipping opportunities, helps validate purchase decisions, and supports guided resale workflows.

## Core Purpose

AuctionFlip is designed for players who want to:

- scan the Auction House for underpriced items
- compare cheap listings against the next higher market tier
- estimate realistic resale profit after Auction House costs
- buy selectively or clear cheap tiers when the strategy still makes sense
- track purchased items and repost them with guided selling tools

## Main Features

- Auction House scanning with `Single`, `Continuous`, and `Retry If 0` modes
- Opportunity detection for underpriced items and vendor-related flips
- Results analysis with discount, net profit, ROI, liquidity, and confidence metrics
- Risk profiles: `Safe`, `Balanced`, and `Aggro`
- Buy confirmation modal with tier-based market analysis
- Selling tab with guided repost workflow
- Sell confirmation modal with live AH minimum tracking, fee/deposit estimates, and net profit projection
- Historical price dataset and session statistics
- Neon UI theme with selectable accent colors
- Built-in contextual help across the addon's main workflows

## How It Works

AuctionFlip does not rely on unrealistic pricing assumptions.

When possible, it evaluates:

1. the cheapest valid listing or tier
2. the quantity available at that cheap level
3. the first meaningful price tier above what you would buy
4. the expected resale outcome after AH cut and deposit modeling

This makes the addon better suited for practical flipping decisions instead of simple “lowest price vs average price” comparisons.

## Main Tabs

### Opportunities

- `Scan`: control scan execution, review scan activity, and monitor session dashboards
- `Results`: inspect opportunities, filter by type, apply risk profile, sort results, and open buy confirmation
- `Stats`: review session statistics and recent opportunity history

### Selling

- tracks purchased items
- checks whether items are currently in bags
- refreshes current AH minimum prices
- supports `Sell 1` and `Sell All` flows through a confirmation modal

### Settings

- profit thresholds
- opportunity filters
- market confidence controls
- scanning verification and pacing controls
- capital protection rules
- display/theme settings

### About

- version
- developer
- changelog access

## Usage Flow

1. Open the Auction House.
2. Open AuctionFlip.
3. Run a scan from the `Scan` subtab.
4. Review candidates in `Results`.
5. Open `Buy Confirmation` before purchasing.
6. After purchase, use the `Selling` tab to refresh market conditions and repost with guided pricing.

## Installation

1. Download the addon package.
2. Extract the `AuctionFlip` folder to:
   `World of Warcraft/_retail_/Interface/AddOns/`
3. Restart the game or reload the UI.
4. Open the Auction House and load AuctionFlip.

## Current Version

`v0.3.17`

## Developer

Trithon

## Notes

- AuctionFlip is intended to assist decision-making, not replace player judgment.
- Real market conditions can change between scan, buy, and resale.
- Always review the confirmation modals before submitting purchases or posts.
