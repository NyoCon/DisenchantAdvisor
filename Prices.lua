-- Prices from Auctionator's public API (Auctionator.API.v1). Without Auctionator there are no
-- auction prices; vendor prices come from the game itself.

local _, ns = ...

local P = {}
ns.prices = P

local CALLER = "DisenchantAdvisor"   -- Auctionator wants to know who is asking

local function API()
    return Auctionator and Auctionator.API and Auctionator.API.v1
end

function P.Available()
    return API() ~= nil
end

-- nil if the function is missing or fails
local function Call(name, ...)
    local api = API()
    local fn = api and api[name]
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, CALLER, ...)
    if ok then return value end
    return nil
end

local function Positive(value)
    if type(value) == "number" and value > 0 then return value end
    return nil
end

-- Auction price of an item ID, or nil
function P.ByID(itemID)
    return Positive(Call("GetAuctionPriceByItemID", itemID))
end

-- Days since Auctionator last saw the item, or nil if never or over 21 days ago
function P.AgeByID(itemID)
    return Call("GetAuctionAgeByItemID", itemID)
end

-- What one material is worth: its own price, or what it converts to (3 lesser essences <-> 1
-- greater), whichever is higher. Second return: true if the value comes from the partner.
function P.Material(itemID)
    local own = P.ByID(itemID)
    local pair = ns.bands.pairs[itemID]
    local partner = pair and P.ByID(pair[1])
    local converted = partner and partner * pair[2]
    if converted and (not own or converted > own) then
        return converted, true
    end
    return own, false
end

-- Auction price of an item link: price, exact (false = price of the base item, e.g. without its
-- random suffix), age in days (nil = never seen or over 21 days ago)
function P.Item(link)
    if type(link) == "number" then
        local price = P.ByID(link)
        return price, price ~= nil, P.AgeByID(link)
    end
    if type(link) ~= "string" then return nil end
    local price = Positive(Call("GetAuctionPriceByItemLink", link))
    if not price then return nil end
    local exact = Call("IsAuctionDataExactByItemLink", link)
    return price, exact ~= false, Call("GetAuctionAgeByItemLink", link)
end
