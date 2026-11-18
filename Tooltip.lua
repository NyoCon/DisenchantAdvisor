-- Tooltip lines: what disenchanting gives, the proceeds of each option and the recommendation.

local _, ns = ...

local T = {}
ns.tooltip = T

local L = ns.L

local GOLD = { 1, 0.82, 0 }
local TEXT = { 0.9, 0.9, 0.9 }
local DIM = { 0.6, 0.6, 0.6 }
local GOOD = { 0.3, 1, 0.3 }
local WARN = { 1, 0.6, 0.2 }
local BAD = { 1, 0.35, 0.35 }

local DISENCHANT_SPELL = 13262

local NameByID = C_Item and C_Item.GetItemNameByID
local IconByID = (C_Item and C_Item.GetItemIconByID) or _G.GetItemIcon

T.lastError = nil   -- last error while writing a tooltip, for /dadv

-- Amounts of a gold or more are rounded to whole silver: the copper of an estimate is noise.
function T.Money(copper)
    copper = math.floor((copper or 0) + 0.5)
    if copper >= 10000 then copper = math.floor(copper / 100 + 0.5) * 100 end
    if GetMoneyString then return GetMoneyString(copper, true) end
    return string.format("%dg %ds %dc", math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100)
end
local Money = T.Money

local function SpellName()
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, DISENCHANT_SPELL)
        if ok and name then return name end
    end
    return L["Disenchant"]
end

function T.Amount(drop)
    return drop.low == drop.high and tostring(drop.low) or (drop.low .. "-" .. drop.high)
end

function T.MaterialName(itemID)
    return (NameByID and NameByID(itemID)) or ns.bands.names[itemID] or ("item " .. itemID)
end

function T.OptionName(key)
    if key == "disenchant" then return L["Disenchanting"] end
    if key == "auction" then return L["Auction house"] end
    return L["Vendor"]
end

-- "Disenchant (+12s over auction house, close call)"
function T.RecommendationText(e)
    local best = e.best
    local action = best.key == "disenchant" and L["Disenchant"]
        or best.key == "auction" and L["Sell at the auction house"]
        or L["Sell to a vendor"]
    local notes = {}
    if e.declined then
        notes[#notes + 1] = string.format(L["disenchanting: +%s on average, %s loss risk"],
            Money(e.declined.lead), T.Percent(e.declined.loss))
    elseif e.runnerUp then
        notes[#notes + 1] = string.format(L["+%s over %s"], Money(e.margin), T.OptionName(e.runnerUp.key))
    end
    if e.closeCall then notes[#notes + 1] = L["close call"] end
    if e.risky then notes[#notes + 1] = L["risky"] end
    if e.uncertain then notes[#notes + 1] = L["prices missing"] end
    if best.key == "disenchant" and not ns.KnowsDisenchant() then
        notes[#notes + 1] = L["needs an enchanter"]
    end
    if #notes > 0 then action = action .. " (" .. table.concat(notes, ", ") .. ")" end
    return action
end

local function AuctionNote(e)
    if e.bound then return L["bound"] end
    if not e.auction then return L["no price"] end
    local notes = {}
    if not e.auctionExact then notes[#notes + 1] = L["base item"] end
    if e.auctionAge == nil then
        notes[#notes + 1] = L["over 3 weeks old"]
    elseif e.auctionAge >= 3 then
        notes[#notes + 1] = string.format(L["%d days old"], e.auctionAge)
    end
    if #notes == 0 then return nil end
    return table.concat(notes, ", ")
end

local function AddDrops(tooltip, e)
    for _, drop in ipairs(e.drops) do
        local icon = IconByID and IconByID(drop.itemID)
        local amount = T.Amount(drop)
        local left = string.format("  %s  %sx  %s%s",
            e.band.unconfirmed and "?" or (drop.chance .. "%"),
            amount,
            icon and ("|T" .. icon .. ":0|t ") or "",
            T.MaterialName(drop.itemID))
        if e.band.unconfirmed then
            left = left .. " |cff999999(" .. L["unconfirmed"] .. ")|r"
        end
        local right = ""
        if e.pricesAvailable then
            right = drop.price and Money(drop.price) or "?"
        end
        tooltip:AddDoubleLine(left, right, TEXT[1], TEXT[2], TEXT[3], DIM[1], DIM[2], DIM[3])
    end
end

local function AddComparison(tooltip, e)
    tooltip:AddLine(L["Proceeds after AH cut"], DIM[1], DIM[2], DIM[3])
    local best = e.best and e.best.key

    local function Row(key, label, value, note)
        local color = key == best and GOOD or TEXT
        local left = "  " .. label
        if note then left = left .. " |cff999999(" .. note .. ")|r" end
        tooltip:AddDoubleLine(left, value, color[1], color[2], color[3], color[1], color[2], color[3])
    end

    Row("vendor", L["Vendor"], e.vendor > 0 and Money(e.vendor) or "-")
    if not e.auctionOff then
        Row("auction", L["Auction house"], e.auction and Money(e.auction) or "-", AuctionNote(e))
    end
    local disenchant = e.disenchantGross > 0 and Money(e.disenchant) or "?"
    if e.disenchantGross > 0 and not e.disenchantComplete then disenchant = disenchant .. " +?" end
    Row("disenchant", L["Disenchanting"], disenchant)
end

-- "2g 38s - 11g 40s", or one amount if both ends match
function T.Range(low, high)
    if Money(low) == Money(high) then return Money(low) end
    return Money(low) .. " - " .. Money(high)
end

-- "10 %", "<1 %"
function T.Percent(fraction)
    local rounded = math.floor(fraction * 100 + 0.5)
    if rounded == 0 and fraction > 1e-9 then return "<1 %" end
    if rounded == 100 and fraction < 1 - 1e-9 then return ">99 %" end
    return string.format("%d %%", rounded)
end

-- Chance that disenchanting earns less than the best other option, and the range of one disenchant
local function AddRisk(tooltip, e, details)
    local risk = e.risk
    if not risk then return end
    local maxRisk = ns.advisor.MaxRisk()
    local color = risk.loss <= maxRisk / 2 and GOOD or risk.loss <= maxRisk + 1e-9 and WARN or BAD
    tooltip:AddDoubleLine("  " .. string.format(L["Loss risk (vs. %s)"], T.OptionName(risk.against)),
        T.Percent(risk.loss), DIM[1], DIM[2], DIM[3], color[1], color[2], color[3])
    if details then
        tooltip:AddDoubleLine("  " .. L["One disenchant gives"], T.Range(risk.worst, risk.best),
            DIM[1], DIM[2], DIM[3], DIM[1], DIM[2], DIM[3])
    end
end

-- Details (price comparison, range of one disenchant) always, or only while a modifier key is held
local KEY_DOWN = {
    CTRL = function() return IsControlKeyDown and IsControlKeyDown() end,
    SHIFT = function() return IsShiftKeyDown and IsShiftKeyDown() end,
    ALT = function() return IsAltKeyDown and IsAltKeyDown() end,
}
T.KEYS = { "none", "CTRL", "SHIFT", "ALT" }   -- order in the settings dropdown
T.KEY_NAMES = { none = "None", CTRL = "Ctrl", SHIFT = "Shift", ALT = "Alt" }

-- "none" | "CTRL" | "SHIFT" | "ALT"
function T.DetailsKey()
    local key = ns.db and ns.db.detailsKey
    if KEY_DOWN[key] then return key end
    return "none"
end

function T.DetailsShown()
    local key = T.DetailsKey()
    return key == "none" or KEY_DOWN[key]() == true
end

-- Adds the lines; returns true if anything was added.
function T.AddLines(tooltip, item, opts)
    local e = ns.advisor.Evaluate(item, opts)
    if not e then return false end

    tooltip:AddLine(" ")
    if e.ownLoot then
        tooltip:AddLine(SpellName(), GOLD[1], GOLD[2], GOLD[3])
        tooltip:AddLine("  " .. L["Gives its own items, not the usual materials"], TEXT[1], TEXT[2], TEXT[3])
        return true
    end

    local value = ""
    if e.disenchantGross > 0 then
        value = "Ø " .. Money(e.disenchantGross) .. (e.disenchantComplete and "" or " +?")
    end
    tooltip:AddDoubleLine(SpellName(), value, GOLD[1], GOLD[2], GOLD[3], TEXT[1], TEXT[2], TEXT[3])

    local details = T.DetailsShown()
    AddDrops(tooltip, e)   -- the drops are the main information: always shown

    if not e.pricesAvailable then
        tooltip:AddLine(L["Install Auctionator for prices and a recommendation"], DIM[1], DIM[2], DIM[3])
        return true
    end

    if details then AddComparison(tooltip, e) end

    if e.best then
        local color = (e.uncertain or e.closeCall or e.risky) and WARN or GOOD
        tooltip:AddLine("» " .. T.RecommendationText(e), color[1], color[2], color[3], true)
    end
    AddRisk(tooltip, e, details)
    if not details then
        tooltip:AddLine(string.format(L["Hold %s for details"], L[T.KEY_NAMES[T.DetailsKey()]]),
            DIM[1], DIM[2], DIM[3])
    end
    return true
end

-- ---------------------------------------------------------------- hooks

local BOUND_TEXTS   -- tooltip texts that mean "cannot be sold at the auction house"

local function Secret(value)
    return issecretvalue and issecretvalue(value)
end

-- Is the item in this tooltip bound? Asks the item itself (bags, bank, equipped), else reads the
-- binding line of the tooltip.
local function IsBound(data)
    if not data then return false end
    if data.guid and not Secret(data.guid) and C_Item and C_Item.GetItemLocation and C_Item.IsBound then
        local ok, location = pcall(C_Item.GetItemLocation, data.guid)
        if ok and location and location.IsValid and location:IsValid() then
            local ok2, bound = pcall(C_Item.IsBound, location)
            if ok2 and type(bound) == "boolean" then return bound end
        end
    end

    if not BOUND_TEXTS then
        BOUND_TEXTS = {}
        for _, name in ipairs({ "ITEM_SOULBOUND", "ITEM_BIND_ON_PICKUP", "ITEM_ACCOUNTBOUND",
                                "ITEM_BNETACCOUNTBOUND", "ITEM_BIND_QUEST", "ITEM_ACCOUNTBOUND_UNTIL_EQUIP" }) do
            if type(_G[name]) == "string" then BOUND_TEXTS[_G[name]] = true end
        end
    end
    for _, line in ipairs(data.lines or {}) do
        local text = line.leftText
        if text and not Secret(text) and BOUND_TEXTS[text] then return true end
    end
    return false
end

local function OnItemTooltip(tooltip, data)
    if not ns.db or not ns.db.enabled then return end
    if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end

    local ok, err = pcall(function()
        local _, link = tooltip:GetItem()
        if Secret(link) then return end   -- can happen in combat
        local item = link or (data and data.id)
        if item and T.AddLines(tooltip, item, { bound = IsBound(data) }) then tooltip:Show() end
    end)
    if not ok then T.lastError = err end
end

function T.Hook()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
    else
        for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
            tooltip:HookScript("OnTooltipSetItem", function(self) OnItemTooltip(self) end)
        end
    end
end

-- The modifier key toggles the details: redraw the tooltip that is open
function T.OnModifierChanged()
    if not ns.db or T.DetailsKey() == "none" then return end
    if GameTooltip and GameTooltip:IsShown() and GameTooltip.RefreshData then
        pcall(GameTooltip.RefreshData, GameTooltip)
    end
end
