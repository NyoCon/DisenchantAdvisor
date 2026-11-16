-- Evaluates an item: what disenchanting gives, what each way of getting rid of it earns, and
-- which one is best. No UI here; Tooltip.lua and the /dadv check command show the result.

local _, ns = ...

local A = {}
ns.advisor = A

A.AH_CUT = 0.05        -- the auction house keeps 5 % of every sale
A.CLOSE_CALL = 0.10    -- best option less than 10 % ahead of the next one: "close call"

local GetInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
local GetInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
local DetailedLevel = (C_Item and C_Item.GetDetailedItemLevelInfo) or _G.GetDetailedItemLevelInfo

local BIND_ON_PICKUP, BIND_QUEST = 1, 4

function A.ItemID(item)
    if type(item) == "number" then return item end
    if type(item) ~= "string" then return nil end
    local id = GetInfoInstant and GetInfoInstant(item)
    return id or tonumber(item:match("item:(%d+)"))
end

-- Returns nil if the item does not disenchant (or is not cached yet), else a table:
--   ownLoot = true                     disenchants into its own items, nothing else is filled
--   itemID, level, band                band = ns.bands.Find(...)
--   drops[i] = { itemID, chance, low, high, price, derived }
--   disenchantGross                    expected material value before the AH cut (copper)
--   disenchant, disenchantComplete     after the AH cut; complete = every material has a price
--   vendor                             vendor price (0 if it cannot be sold to a vendor)
--   bound                              cannot be sold at the auction house
--   auction, auctionExact, auctionAge  auction price after the cut, exact link match, age in days
--   options = sorted list { key = "disenchant"|"auction"|"vendor", value }
--   best, runnerUp, margin, closeCall, uncertain
-- opts.bound: the tooltip already knows the item is soulbound
function A.Evaluate(item, opts)
    opts = opts or {}
    local itemID = A.ItemID(item)
    if not itemID or not GetInfo then return nil end
    if ns.noDisenchant[itemID] then return nil end

    local _, _, quality, level, _, _, _, _, _, _, sellPrice, classID, _, bindType = GetInfo(item)
    if not quality then return nil end

    if ns.ownLoot[itemID] then return { itemID = itemID, ownLoot = true } end

    if DetailedLevel then
        local ok, detailed = pcall(DetailedLevel, item)
        if ok and type(detailed) == "number" and detailed > 0 then level = detailed end
    end

    local band = ns.bands.Find(classID, quality, level)
    if not band then return nil end

    local e = {
        itemID = itemID,
        level = level,
        band = band,
        drops = {},
        vendor = sellPrice or 0,
        bound = opts.bound or bindType == BIND_ON_PICKUP or bindType == BIND_QUEST,
        pricesAvailable = ns.prices.Available(),
    }

    -- expected material value: chance x average amount x price
    local gross, complete = 0, not band.unconfirmed
    for i, drop in ipairs(band.drops) do
        local price, derived = ns.prices.Material(drop.itemID)
        e.drops[i] = {
            itemID = drop.itemID, chance = drop.chance, low = drop.low, high = drop.high,
            price = price, derived = derived,
        }
        if price then
            gross = gross + drop.chance / 100 * (drop.low + drop.high) / 2 * price
        else
            complete = false
        end
    end
    e.disenchantGross = gross
    e.disenchant = gross * (1 - A.AH_CUT)
    e.disenchantComplete = complete and e.pricesAvailable

    if not e.bound and e.pricesAvailable then
        local price, exact, age = ns.prices.Item(item)
        if price then
            e.auction = price * (1 - A.AH_CUT)
            e.auctionExact = exact
            e.auctionAge = age
        end
    end

    -- without auction prices there is nothing to compare
    if not e.pricesAvailable then return e end

    local options = {}
    if e.vendor > 0 then options[#options + 1] = { key = "vendor", value = e.vendor } end
    if e.auction then options[#options + 1] = { key = "auction", value = e.auction } end
    if gross > 0 then options[#options + 1] = { key = "disenchant", value = e.disenchant } end
    table.sort(options, function(a, b) return a.value > b.value end)
    e.options = options

    e.best, e.runnerUp = options[1], options[2]
    if e.best then
        e.margin = e.best.value - (e.runnerUp and e.runnerUp.value or 0)
        e.closeCall = e.runnerUp ~= nil and e.margin < e.best.value * A.CLOSE_CALL
        -- Missing material prices make disenchanting look worse than it is. If it wins anyway the
        -- advice stands; if something else wins, disenchanting might still be better.
        e.uncertain = e.best.key ~= "disenchant" and not e.disenchantComplete
    end

    A.AddRisk(e)
    if e.risk and e.best and e.best.key == "disenchant" and e.risk.loss >= A.RISKY then
        e.risky = true
    end
    return e
end

A.RISKY = 0.40   -- disenchanting recommended, but loses against the alternative this often: "risky"

-- Every possible result of one disenchant: one row of the band drops, its amount is equally
-- likely anywhere from low to high. Needs a price for every material.
-- Returns { { chance = 0..1, value = copper after AH cut, itemID, amount }, ... } or nil.
function A.Outcomes(e)
    local outcomes = {}
    for _, drop in ipairs(e.drops) do
        if not drop.price then return nil end
        local each = drop.chance / 100 / (drop.high - drop.low + 1)
        for amount = drop.low, drop.high do
            outcomes[#outcomes + 1] = {
                chance = each, itemID = drop.itemID, amount = amount,
                value = amount * drop.price * (1 - A.AH_CUT),
            }
        end
    end
    return outcomes
end

-- Compares every outcome of disenchanting with the best other option (vendor or auction house):
-- e.risk = { against = "vendor"|"auction", alternative = copper,
--            loss = chance 0..1 that disenchanting earns less, worst, best = copper }
function A.AddRisk(e)
    if not e.options then return end
    local alternative
    for _, option in ipairs(e.options) do
        if option.key ~= "disenchant" then alternative = option; break end   -- sorted: first is best
    end
    if not alternative or alternative.value <= 0 then return end

    local outcomes = A.Outcomes(e)
    if not outcomes or #outcomes == 0 then return end

    local loss, worst, best = 0, math.huge, 0
    for _, outcome in ipairs(outcomes) do
        if outcome.value < alternative.value then loss = loss + outcome.chance end
        worst = math.min(worst, outcome.value)
        best = math.max(best, outcome.value)
    end
    e.risk = { against = alternative.key, alternative = alternative.value, loss = loss, worst = worst, best = best }
end
