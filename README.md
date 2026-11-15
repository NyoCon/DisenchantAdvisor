# DisenchantAdvisor

Tooltip addon for World of Warcraft Forever (Interface 16001). On every uncommon, rare or epic
weapon and armor piece it shows:

- what disenchanting can give: each material with its chance, amount and auction price
- the expected value of disenchanting (Ø, before the auction house cut)
- what each option earns after the 5 % auction house cut: vendor, auction house, disenchanting
- a recommendation: disenchant, sell at the auction house or sell to a vendor, with the lead over
  the next best option

Prices come from [Auctionator](https://www.curseforge.com/wow/addons/auctionator) (optional).
Without it the tooltip shows only the materials and chances.

## Usage

Install, `/reload`, hover over an item. Chat commands:

| Command | Effect |
|---|---|
| `/dadv` | status and help (also shows the last tooltip error, if any) |
| `/dadv details always\|shift` | price comparison always (default) or only with Shift held; the materials and the recommendation are always shown |
| `/dadv on\|off` | tooltip lines on or off |
| `/dadv check <item link>` | the evaluation of a shift-clicked item in the chat |

Reading the tooltip:

- `+?` after a value: some material has no auction price, the real value is higher
- `?` as chance, `(unconfirmed)`: rare items of item level 5-15, a band that only exists in Forever;
  assumed to be like 16-20
- auction house `(bound)`: soulbound/bind on pickup, cannot be sold there
- auction house `(base item)`: Auctionator only has a price for the item without its random suffix
- auction house `(5 days old)` / `(over 3 weeks old)`: when Auctionator last saw the item
- recommendation in orange: `close call` (less than 10 % ahead) or `prices missing` (disenchanting
  lost, but some material prices are missing, so it might still be better)
- `needs an enchanter`: disenchanting wins but this character cannot disenchant

## How it works

- **Bands**: which materials an item can give depends on class (weapon/armor), quality and item
  level. The bands are Forever's client table `ItemDisenchantLoot`. The client does not contain
  what drops in a band; chances and amounts are Classic 1.12's as reproduced by vmangos
  (`disenchant_loot_template`), taken over from the addon Disenchant Forever (`Data/Bands.lua`).
- **Exceptions**: `Data/NoDisenchant.lua` (items flagged as not disenchantable) and
  `Data/OwnLoot.lua` (items with their own disenchant loot) are generated from the client's
  `ItemSparse`/`Item` tables by `tools/update_data.py` via wago.tools. Rerun it after a client
  patch: `python3 tools/update_data.py [build]`.
- **Material value**: Auctionator price. Lesser and greater essences convert 3:1 into each other, so
  each is worth at least its partner's price × 3 (or ÷ 3); the higher value counts.
- **Disenchanting value**: Σ chance × average amount × material price, minus 5 % auction house cut
  (the materials have to be sold too).
- **Auction house value**: Auctionator's price for the item link, minus 5 % cut. The deposit and
  the risk of the item not selling are not counted.
- **Bound items**: `C_Item.IsBound` for items in bags/bank/equipped, else the binding line of the
  tooltip; bind on pickup items are always bound. Bound items have no auction house option.
- Tooltip hook: `TooltipDataProcessor.AddTooltipPostCall` for item tooltips (GameTooltip and
  ItemRefTooltip); errors are caught and shown by `/dadv`.

## Development

`luajit dev/run.lua` loads the addon with a small mock of the WoW API and prints the tooltip lines
of a few test items as text (`LOCALE=enUS luajit dev/run.lua` for English).
