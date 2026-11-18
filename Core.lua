-- Settings, events and the /dadv chat command.

local ADDON, ns = ...

local L = ns.L
local PREFIX = "|cffa335eeDisenchantAdvisor|r: "
local DISENCHANT_SPELL = 13262
local SKILL_ENCHANTING = 333

local DEFAULTS = {
    enabled = true,
    detailsKey = "none",  -- "none" | "CTRL" | "SHIFT" | "ALT": details always or only with that key held
    mode = ns.advisor.DEFAULT_MODE,         -- see Advisor.lua
    minLead = ns.advisor.DEFAULT_MIN_LEAD,  -- percent
    maxRisk = ns.advisor.DEFAULT_MAX_RISK,  -- percent
    useAuction = true,    -- false: selling the item at the auction house is not considered
}

local MODE_NAMES = { safe = "Safe", balanced = "Balanced", average = "Average (risky)" }

local function Say(text, ...)
    local message = L[text]
    if select("#", ...) > 0 then message = string.format(message, ...) end
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. message)
end

-- nil if the function is missing, fails or returns a secret value
local function Ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if not ok or (issecretvalue and issecretvalue(value)) then return nil end
    return value
end

local function HasEnchanting()
    if not GetProfessions then return nil end
    local first, second = GetProfessions()
    for _, index in pairs({ first, second }) do
        if select(7, GetProfessionInfo(index)) == SKILL_ENCHANTING then return true end
    end
    return false
end

-- Can this character disenchant? If nothing answers, assume yes rather than nag an enchanter.
function ns.KnowsDisenchant()
    local answered = false
    for _, check in ipairs({
        function() return Ask(_G.IsPlayerSpell, DISENCHANT_SPELL) end,
        function() return Ask(C_SpellBook and C_SpellBook.IsSpellKnown, DISENCHANT_SPELL) end,
        function() return Ask(HasEnchanting) end,
    }) do
        local known = check()
        if known == true then return true end
        if known ~= nil then answered = true end
    end
    return not answered
end

-- Ask the client to load the material names, so the tooltip does not show English fallbacks
local function PreloadMaterials()
    if not (C_Item and C_Item.RequestLoadItemDataByID) then return end
    for _, itemID in ipairs(ns.bands.materials) do
        pcall(C_Item.RequestLoadItemDataByID, itemID)
    end
end

-- ------------------------------------------------------------------ chat

local function PrintStatus()
    local key = ns.tooltip.DetailsKey()
    Say("Tooltip: %s, details: %s, prices: %s",
        ns.db.enabled and L["on"] or L["off"],
        key == "none" and L["always"] or string.format(L["with %s"], L[ns.tooltip.KEY_NAMES[key]]),
        ns.prices.Available() and "Auctionator" or L["none (Auctionator missing)"])
    Say("Recommendation: %s, minimum lead %d %%, maximum loss risk %d %%, auction house: %s",
        L[MODE_NAMES[ns.db.mode] or ns.db.mode], ns.db.minLead, ns.db.maxRisk,
        ns.db.useAuction and L["on"] or L["off"])
    if ns.tooltip.lastError then
        DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. "|cffff5555" .. tostring(ns.tooltip.lastError) .. "|r")
    end
end

local function PrintHelp()
    Say("Commands:")
    Say("  /dadv - settings (Esc > Options > AddOns)")
    Say("  /dadv status - current settings and the last tooltip error")
    Say("  /dadv details none|ctrl|shift|alt - price comparison always or only with that key held")
    Say("  /dadv on|off - tooltip lines on or off")
    Say("  /dadv check <item link> - evaluation of an item in the chat")
end

local function Check(link)
    local e = ns.advisor.Evaluate(link)
    if not e or e.ownLoot then
        Say("%s does not disenchant into the usual materials (or is not cached yet).", link)
        return
    end
    local T = ns.tooltip
    Say("%s: item level %d, band %d-%d", link, e.level, e.band.minLevel, e.band.maxLevel)
    for _, drop in ipairs(e.drops) do
        DEFAULT_CHAT_FRAME:AddMessage(string.format("   %d%%  %sx %s  %s%s", drop.chance, T.Amount(drop),
            T.MaterialName(drop.itemID), drop.price and T.Money(drop.price) or "?",
            drop.derived and " (3:1)" or ""))
    end
    for _, option in ipairs(e.options or {}) do
        DEFAULT_CHAT_FRAME:AddMessage(string.format("   %s: %s", T.OptionName(option.key), T.Money(option.value)))
    end
    Say("Recommendation: %s", e.best and T.RecommendationText(e) or L["no recommendation"])
    if e.risk then
        DEFAULT_CHAT_FRAME:AddMessage(string.format(L["   Loss risk vs. %s: %s, one disenchant gives %s"],
            T.OptionName(e.risk.against), T.Percent(e.risk.loss), T.Range(e.risk.worst, e.risk.best)))
    end
end

-- /dadv details <arg> -> detailsKey ("always" is the pre-0.5 spelling of "none")
local DETAILS_ARGS = { none = "none", always = "none", ctrl = "CTRL", shift = "SHIFT", alt = "ALT" }

SLASH_DISENCHANTADVISOR1 = "/dadv"
SLASH_DISENCHANTADVISOR2 = "/disenchantadvisor"
SlashCmdList.DISENCHANTADVISOR = function(input)
    input = input or ""
    local command, rest = input:match("^%s*(%S*)%s*(.-)%s*$")
    command = (command or ""):lower()

    if command == "on" or command == "off" then
        ns.db.enabled = command == "on"
        PrintStatus()
    elseif command == "details" and DETAILS_ARGS[rest:lower()] then
        ns.db.detailsKey = DETAILS_ARGS[rest:lower()]
        PrintStatus()
    elseif command == "check" and rest ~= "" then
        Check(rest)
    elseif command == "" and ns.options.Open() then
        return
    elseif command == "" or command == "status" then
        PrintStatus()
        PrintHelp()
    else
        PrintHelp()
    end
end

-- ---------------------------------------------------------------- events

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("MODIFIER_STATE_CHANGED")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        DisenchantAdvisorDB = DisenchantAdvisorDB or {}
        -- up to 0.4.1: details = "always" | "shift"
        if DisenchantAdvisorDB.details ~= nil then
            if DisenchantAdvisorDB.detailsKey == nil and DisenchantAdvisorDB.details == "shift" then
                DisenchantAdvisorDB.detailsKey = "SHIFT"
            end
            DisenchantAdvisorDB.details = nil
        end
        for key, value in pairs(DEFAULTS) do
            if DisenchantAdvisorDB[key] == nil then DisenchantAdvisorDB[key] = value end
        end
        ns.db = DisenchantAdvisorDB
        local ok, err = pcall(ns.options.Register)
        if not ok then ns.tooltip.lastError = err end
    elseif event == "PLAYER_LOGIN" then
        ns.tooltip.Hook()
        PreloadMaterials()
    elseif event == "MODIFIER_STATE_CHANGED" then
        ns.tooltip.OnModifierChanged()
    end
end)
