-- Evaluates an item: what disenchanting gives, what each way of getting rid of it earns, and
-- which one is best. No UI here; Tooltip.lua and the /dadv check command show the result.

local _, ns = ...

local A = {}
ns.advisor = A

A.AH_CUT = 0.05        -- the auction house keeps 5 % of every sale

-- How disenchanting is weighed against the best other option (settings page, ns.db):
--   mode "average":  whatever earns most on average, however often a single disenchant loses
--   mode "balanced": disenchant only if it leads by minLead % on average OR loses in at most maxRisk %
--   mode "safe":     disenchant only if both hold (default)
-- minLead and maxRisk also decide the "close call" and "risky" notes.
A.DEFAULT_MODE, A.DEFAULT_MIN_LEAD, A.DEFAULT_MAX_RISK = "safe", 10, 40

local function Setting(key, default)
    local value = ns.db and ns.db[key]
    if value == nil then return default end
    return value
end

function A.Mode() return Setting("mode", A.DEFAULT_MODE) end
function A.MinLead() return Setting("minLead", A.DEFAULT_MIN_LEAD) / 100 end
function A.MaxRisk() return Setting("maxRisk", A.DEFAULT_MAX_RISK) / 100 end
-- false: selling the item at the auction house is left out (material prices still count)
function A.UseAuction() return Setting("useAuction", true) end

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
--   auctionOff                         selling at the auction house is switched off in the settings
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
        auctionOff = not A.UseAuction(),
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

    if not e.bound and not e.auctionOff and e.pricesAvailable then
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

    A.AddRisk(e)
    A.Decide(e)
    return e
end

-- Picks the recommendation from e.options (sorted by value) according to the mode.
-- Sets best, runnerUp, margin, closeCall, risky, uncertain and, if disenchanting earned most on
-- average but was turned down, declined = { lead = copper, loss = chance }.
function A.Decide(e)
    local options = e.options
    if not options or not options[1] then return end
    local minLead, maxRisk = A.MinLead(), A.MaxRisk()

    local best, runnerUp = options[1], options[2]
    if best.key == "disenchant" and e.risk then
        local alternative = e.risk.alternative
        local leadOK = best.value >= alternative * (1 + minLead)
        local riskOK = e.risk.loss <= maxRisk + 1e-9
        local mode = A.Mode()
        local accept = mode == "average"
            or (mode == "balanced" and (leadOK or riskOK))
            or (leadOK and riskOK)
        if not accept then
            e.declined = { lead = best.value - alternative, loss = e.risk.loss }
            -- the alternative is the best non-disenchant option, i.e. the second entry
            best, runnerUp = runnerUp, best
        end
    end

    e.best, e.runnerUp = best, runnerUp
    e.margin = best.value - (runnerUp and runnerUp.value or 0)
    e.closeCall = not e.declined and runnerUp ~= nil and runnerUp.value > 0
        and e.margin < runnerUp.value * minLead
    e.risky = best.key == "disenchant" and e.risk ~= nil and e.risk.loss > maxRisk + 1e-9
    -- Missing material prices make disenchanting look worse than it is. If it wins anyway the
    -- advice stands; if something else wins, disenchanting might still be better.
    e.uncertain = best.key ~= "disenchant" and not e.disenchantComplete
end

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
