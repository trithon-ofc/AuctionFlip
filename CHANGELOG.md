# Changelog

## [0.3.17] - 2026-03-25

### Added
- Added Help buttons for Scan, Selling, Settings and Sell Confirmation
- Help UX now covers the addon's main workflows for release readiness

---

## [0.3.16] - 2026-03-25

### Added
- Buy Confirmation now includes a Help modal explaining each section, metric and strategy signal

---

## [0.3.15] - 2026-03-25

### Added
- Results tab now includes a Help modal explaining filters, risk profiles, columns, sorting and buy actions

---

## [0.3.14] - 2026-03-25

### Added
- Scan tab now includes session statistics and recent scan history chart
- Stats tab upgraded with dashboard panels and historical opportunities chart

### Changed
- Buy confirmation now opens centered on the AuctionFlip window, matching sell modal behavior

---

## [0.3.13] - 2026-03-25

### Fixed
- Buy confirmation layout re-anchored to keep right-side panels inside modal bounds

---

## [0.3.12] - 2026-03-25

### Fixed
- Buy confirmation modal spacing adjusted to prevent strategy text from overlapping action buttons

---

## [0.3.11] - 2026-03-25

### Added
- Buy confirmation now includes compact item-analysis metrics from the opportunity card/tooltip
- Buy modal item header now exposes native item tooltip on hover

### Changed
- Buy modal now shows icon, quality-colored item title and richer analysis context for speculation decisions

---

## [0.3.10] - 2026-03-25

### Changed
- Buy confirmation visual redesign with colored strategy panels and stronger emphasis on `Next tier` and `Est. net`

---

## [0.3.9] - 2026-03-25

### Added
- Buy confirmation now shows cheapest-tier quantity, number of listing rows and seller visibility for the cheapest price tier

### Changed
- Buy confirmation modal redesigned into structured strategy blocks for better readability
- Buy strategy notes now explain how resale is anchored to the next AH tier above bought listings

---

## [0.3.8] - 2026-03-25

### Added
- Buy confirmation now shows cheapest listing, highest bought tier, next higher tier and explicit pricing-rule source

### Changed
- Opportunities results grid widened and rebalanced to reduce truncation of prices, quantities and profit columns
- Main AuctionFlip window widened for better results readability
- Opportunity analysis UI now makes the resale rule clearer: price is anchored to the first tier above what we buy, with history only as fallback/cap

---

## [0.3.7] - 2026-03-25

### Added
- Sell confirmation modal now shows `Last AH min update` timestamp (clock + age) for better price confidence

---

## [0.3.6] - 2026-03-25

### Added
- `Refresh AH Min` button inside Sell Confirmation modal for manual market refresh

### Fixed
- `Cheapest AH listing` in Sell modal now resolves for commodity items as well (not only item listings)
- Modern AH market refresh now evaluates both item and commodity search results and uses the best valid unit price

---

## [0.3.5] - 2026-03-25

### Added
- Sell confirmation modal now shows cheapest AH listing, AH fee, cost basis and estimated net profit
- Sell unit price is now editable directly in the modal (gold input) with `Use Suggested` quick reset
- Auto-refresh loop while sell modal is open to recalc values with live market updates

### Changed
- Sell modal now opens centered over the main AuctionFlip window
- Duration changes (12/24/48h) immediately recalculate deposit and net profit
- Explicit warning displayed when selected sell price produces estimated loss vs purchase cost

---

## [0.3.4] - 2026-03-25

### Added
- Buy confirmation now shows AH duration model (12/24/48h), estimated fee and deposit for realistic net preview
- Verification strategy now respects full-row constraints for non-commodity auctions (no partial stack assumptions)

### Changed
- Opportunity validation now produces more realistic quantity/profit plans for item auctions where stack splitting is not possible
- Purchase preview net-profit estimate now subtracts AH fee and estimated deposit before confirmation

---

## [0.3.3] - 2026-03-25

### Added
- Verification strategy now builds a buy plan across multiple cheapest listing tiers
- Opportunity model now includes execution sell target (`undercut` of next tier) and listing-tier count
- New scanning setting: `Opportunity Duration` (duration model for AH cut/deposit net-profit estimates)

### Changed
- `Buy 1` / `Buy All` now consume only qualifying cheap listings within profitable max-buy range
- Underpriced verification now re-scores with realistic execution sale price and deposit estimate
- Vendor flips now use fee-free max-buy logic (no AH cut in vendor-resell strategy)

---

## [0.3.2] - 2026-03-25

### Added
- Selling actions `Sell 1` and `Sell All` with themed confirmation modal
- Sell confirmation details: suggested buyout, duration selector (12/24/48h), deposit and total buyout
- Explicit `Debug: ON/OFF` toggle button in Settings

### Changed
- Selling flow now posts directly from selected item using modern or legacy AH APIs
- Selling entries are automatically deduplicated by item and merged quantities
- New purchases of the same item now merge into one portfolio entry instead of creating duplicates

### Fixed
- Duplicate purchased rows from prior failed buy attempts are consolidated at startup
- Selling list now updates selection state and enables/disables sell buttons correctly

---

## [0.3.1] - 2026-03-25

### Added
- Main tabs updated to `Opportunities`, `Selling`, `Settings`, `About`
- Selling tab with purchased-items list, selection, market refresh and guided posting action
- About tab with developer/version info and changelog popup window
- Result actions: `Buy 1` and `Buy All`
- `Buy All` safety rule: only executes when every current listing is within profitable max buy/unit
- Theme selector in Settings (Neon Blue, Neon Green, Neon Red)

### Changed
- Updated close button styling to match selected neon theme
- Updated flat button styling to follow active theme accent
- Result list formatting now uses compact money values to avoid text overflow
- Item/status texts in list rows now truncate safely with ellipsis

---

## [0.3.0-alpha] - 2026-03-24

### Added
- Complete UI redesign with dark/gold theme
- Sub-tabs within main tabs (Scan, Results, Stats under Opportunities)
- Themed close button with hover effects
- Custom flat button style with borders
- Scan mode selector (Once, Continuous, Until Found)
- Quick stats dashboard on Scan tab
- Market confidence calculation
- Opportunity verification system
- Capital budget management
- Filter buttons (All, Vendor Flip, Underpriced)
- Profit color coding (green/yellow/orange)

### Changed
- Improved scanning with throttle and retry logic
- Better opportunity detection with market confidence
- More detailed tooltips with confidence percentage
- Compact information display
- Professional dark theme aesthetics

### Fixed
- SetPoint anchor error in fallback tab creation
- UI rendering issues
- Scan pagination stall detection

---

## [0.2.0-alpha] - 2026-03-24

### Added
- Full Auction House integration with LibAHTab
- Auto-creates tab when AH opens
- Fallback tab creation if LibAHTab fails
- C_AuctionHouse API scanning
- Price database with history
- Vendor flip detection
- Underpriced item detection
- Statistics tracking
- 4-tab interface (Opportunities, Farming, Stats, Settings)
- Filter system
- Tooltips with profit info

### Fixed
- LibStub initialization
- AH scanning API usage
- Opportunity detection logic

---

## [0.1.0-alpha] - 2026-03-24

### Added
- Initial project structure
- Basic UI frame
- Scan functionality (placeholder)
- Statistics module
- Slash commands (/flip, /afscan, /afstats)

---

## [0.0.0] - 2026-03-24

### Added
- Project concept
- Development plan
- Architecture design
