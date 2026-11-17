# DisenchantAdvisor

Tooltip addon for World of Warcraft Forever (Interface 16001). On every uncommon, rare or epic
weapon and armor piece it shows:

- what disenchanting can give: each material with its chance, amount and auction price
- the expected value of disenchanting (Ø, before the auction house cut)
- what each option earns after the 5 % auction house cut: vendor, auction house, disenchanting
- a recommendation: disenchant, sell at the auction house or sell to a vendor, with the lead over
  the next best option
- the loss risk: how often a single disenchant earns less than the best other option, and the
  range one disenchant can give

Prices come from [Auctionator](https://www.curseforge.com/wow/addons/auctionator) (optional).
Without it the tooltip shows only the materials and chances.

## Usage

Install, `/reload`, hover over an item.

### Settings

*Esc > Options > AddOns > DisenchantAdvisor* (or `/dadv`):

| Setting | Default | |
|---|---|---|
| Show in item tooltips | on | |
| Price comparison only with Shift | off | materials and recommendation stay visible |
| Consider selling at the auction house | on | off: the item is only compared with the vendor price; the materials are still valued at auction prices |
| Recommendation style | Safe | see below |
| Minimum lead | 10 % | how much more disenchanting has to earn on average than the best sale |
| Maximum loss risk | 40 % | in how many cases a single disenchant may earn less than the best sale |

Recommendation styles, when disenchanting earns most on average:

- **Safe**: recommend disenchanting only if it leads by the minimum lead **and** its loss risk is at
  most the maximum; otherwise recommend the sale and say why, e.g.
  `Sell to a vendor (disenchanting: +48c on average, 75 % loss risk)`
- **Balanced**: disenchant if the lead **or** the loss risk is good enough
- **Average (risky)**: always the highest average; the two values only add the `close call` and
  `risky` notes

### Chat commands

| Command | Effect |
|---|---|
| `/dadv` | opens the settings |
| `/dadv status` | settings and help (also shows the last tooltip error, if any) |
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
- recommendation in orange: `close call` (ahead by less than the minimum lead), `risky`
  (disenchanting recommended although its loss risk is above the maximum) or `prices missing`
  (disenchanting lost, but some material prices are missing, so it might still be better)
- loss risk: green up to half the maximum loss risk, orange up to it, red above. Shown whenever disenchanting has
  a value and there is another option to compare with; if disenchanting is not recommended, it
  tells how rarely it would still have paid off (100 % = never)
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
- **Loss risk**: one disenchant gives exactly one row of the band, its amount equally likely
  anywhere from min to max (how the loot of the Classic emulators works). Every outcome
  (row × amount, chance = row chance ÷ number of amounts) is valued after the cut and compared with
  the best non-disenchant option; the loss risk is the summed chance of the outcomes below it. Needs
  a price for every material, otherwise no risk is shown.
- **Decision** (`Advisor.lua`, `A.Decide`): options sorted by value; if disenchanting is first, the
  recommendation style checks lead (`disenchant ≥ best sale × (1 + minimum lead)`) and loss risk
  against the settings and may fall back to the best sale. Without a loss risk (missing material
  prices, nothing to sell) the highest average counts.
- **Auction house value**: Auctionator's price for the item link, minus 5 % cut. The deposit and
  the risk of the item not selling are not counted.
- **Bound items**: `C_Item.IsBound` for items in bags/bank/equipped, else the binding line of the
  tooltip; bind on pickup items are always bound. Bound items have no auction house option.
- Tooltip hook: `TooltipDataProcessor.AddTooltipPostCall` for item tooltips (GameTooltip and
  ItemRefTooltip); errors are caught and shown by `/dadv`.

## Development

`luajit dev/run.lua` loads the addon with a small mock of the WoW API and prints the tooltip lines
of a few test items as text (`LOCALE=enUS luajit dev/run.lua` for English).
