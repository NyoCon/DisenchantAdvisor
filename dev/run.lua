-- Dev harness: loads the addon with a small mock of the WoW API and prints the tooltip lines for a
-- few items. Catches Lua errors and shows the layout as text.
--
--     luajit dev/run.lua            (from the addon folder)
--
-- WoW only loads the files listed in the TOC, so this folder is ignored in game.

local ADDON = "DisenchantAdvisor"
local ns = {}

-- ------------------------------------------------------------------ mock

local items = {
    -- id = { name, quality, level, sellPrice, classID, bindType }
    [1001] = { "Green Armor 23", 2, 23, 1500, 4, 2 },
    [1002] = { "Green Weapon 47", 2, 47, 9000, 2, 2 },
    [1003] = { "Blue Ring 12", 3, 12, 300, 4, 2 },
    [1004] = { "Epic Sword 58", 4, 58, 80000, 2, 1 },
    [1005] = { "Grey Junk", 0, 20, 50, 4, 0 },
    [1006] = { "Green Armor 23 risky", 2, 23, 1500, 4, 2 },
    [1007] = { "Green Armor 47 (screenshot)", 2, 47, 6652, 4, 1 },
    [4614]  = { "No-DE Item", 2, 30, 100, 4, 1 },
    [242266] = { "Own Loot Item", 3, 30, 100, 4, 2 },
}
local auction = {
    [1001] = 25000, [1002] = 30000, [1006] = 4700,
    [10940] = 900, [10998] = 6000, [11082] = 15000, [10978] = 4000,  -- strange, l. astral, g. astral, small glimmering
    [11175] = 60000, [11176] = 25000, [11178] = 45000,                 -- g. nether, dream, l. radiant
    [20725] = 120000,                                                  -- nexus
}
local ages = { [1001] = 1, [1002] = 5 }
local shift = false

function GetLocale() return os.getenv("LOCALE") or "deDE" end
issecretvalue = function() return false end
C_Item = {
    GetItemInfo = function(item)
        local id = type(item) == "number" and item or tonumber(tostring(item):match("item:(%d+)"))
        local i = items[id]
        if not i then return nil end
        return i[1], "|Hitem:" .. id .. "|h", i[2], i[3], 0, "", "", 1, "", 0, i[4], i[5], 0, i[6]
    end,
    GetItemInfoInstant = function(item) return tonumber(tostring(item):match("item:(%d+)")) end,
    GetDetailedItemLevelInfo = function(item) return select(4, C_Item.GetItemInfo(item)) end,
    GetItemNameByID = function(id) return nil end,
    GetItemIconByID = function(id) return 134400 end,
    RequestLoadItemDataByID = function() end,
}
C_Spell = { GetSpellName = function() return "Entzaubern" end }
IsPlayerSpell = function() return true end
IsShiftKeyDown = function() return shift end
GetMoneyString = function(c)
    local g, s, k = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    local out = {}
    if g > 0 then out[#out + 1] = g .. "g" end
    if s > 0 then out[#out + 1] = s .. "s" end
    if k > 0 or #out == 0 then out[#out + 1] = k .. "c" end
    return table.concat(out, " ")
end
Auctionator = { API = { v1 = {
    GetAuctionPriceByItemID = function(_, id) return auction[id] end,
    GetAuctionPriceByItemLink = function(_, link) return auction[tonumber(link:match("item:(%d+)"))] end,
    GetAuctionAgeByItemID = function(_, id) return ages[id] end,
    GetAuctionAgeByItemLink = function(_, link) return ages[tonumber(link:match("item:(%d+)"))] end,
    IsAuctionDataExactByItemLink = function() return true end,
} } }
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) print("[chat] " .. m) end }
SlashCmdList = {}
local handlers = {}
function CreateFrame()
    return {
        RegisterEvent = function() end,
        SetScript = function(_, _, fn) handlers[#handlers + 1] = fn end,
    }
end
ITEM_SOULBOUND = "Soulbound"

-- Settings API: records what the options page registers
local registered = {}
local function Initializer() return { SetParentInitializer = function(self, _, pred) self.pred = pred end } end
Settings = {
    VarType = { Boolean = "boolean", String = "string", Number = "number" },
    RegisterVerticalLayoutCategory = function(name)
        return { GetID = function() return name end }, { AddInitializer = function() end }
    end,
    RegisterAddOnSetting = function(_, variable, key, tbl, varType, name, default)
        if tbl[key] == nil then tbl[key] = default end
        assert(type(tbl[key]) == varType, variable .. " has type " .. type(tbl[key]))
        registered[#registered + 1] = name .. " = " .. tostring(tbl[key])
        return { variable = variable }
    end,
    RegisterProxySetting = function(_, variable, varType, name, default, get, set)
        assert(type(get()) == varType)
        set(get())
        registered[#registered + 1] = name .. " = " .. tostring(get()) .. " (proxy)"
        return { variable = variable }
    end,
    CreateControlTextContainer = function()
        local data = {}
        return { Add = function(_, v, l) data[#data + 1] = v .. ":" .. l end, GetData = function() return data end }
    end,
    CreateSliderOptions = function() return { SetLabelFormatter = function(_, _, f) assert(f(10) == "10 %") end } end,
    CreateCheckbox = function() return Initializer() end,
    CreateSlider = function() return Initializer() end,
    CreateDropdown = function(_, _, options)
        registered[#registered + 1] = "  dropdown: " .. table.concat(options(), ", ")
        return Initializer()
    end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function(id) print("[settings] open " .. tostring(id)) end,
}
MinimalSliderWithSteppersMixin = { Label = { Right = 3 } }
CreateSettingsListSectionHeaderInitializer = function() return {} end

local Tooltip = {}
Tooltip.__index = Tooltip
function Tooltip.new() return setmetatable({ lines = {} }, Tooltip) end
function Tooltip:AddLine(t) self.lines[#self.lines + 1] = t end
function Tooltip:AddDoubleLine(l, r) self.lines[#self.lines + 1] = string.format("%-60s %s", l, r) end
function Tooltip:Show() end
function Tooltip:IsShown() return true end
GameTooltip = Tooltip.new()
ItemRefTooltip = Tooltip.new()
function Tooltip:HookScript() end

-- ------------------------------------------------------------------ load

local toc = io.open(ADDON .. ".toc"):read("*a")
for file in toc:gmatch("[^\r\n]+") do
    if not file:match("^##") and file:match("%S") then
        local chunk = assert(loadfile((file:gsub("\\", "/"))))
        chunk(ADDON, ns)
    end
end
for _, fn in ipairs(handlers) do fn(nil, "ADDON_LOADED", ADDON) end
for _, fn in ipairs(handlers) do fn(nil, "PLAYER_LOGIN") end

-- ------------------------------------------------------------------ run

local function Show(id, opts)
    local tip = Tooltip.new()
    local added = ns.tooltip.AddLines(tip, "|Hitem:" .. id .. "::|h[x]|h", opts)
    print(("== %d %s %s"):format(id, items[id] and items[id][1] or "?", added and "" or "(nothing)"))
    for _, line in ipairs(tip.lines) do print(line) end
end

for _, id in ipairs({ 1001, 1002, 1003, 1004, 1005, 1006, 4614, 242266 }) do Show(id) end
print("-- bound green")
Show(1001, { bound = true })
print("-- details on shift, not held / held")
DisenchantAdvisorDB.details = "shift"
Show(1002)
shift = true
Show(1002)
print("-- slash")
SlashCmdList.DISENCHANTADVISOR("")
SlashCmdList.DISENCHANTADVISOR("check |Hitem:1002::|h[Green Weapon 47]|h")
print("-- settings page")
for _, line in ipairs(registered) do print(line) end
SlashCmdList.DISENCHANTADVISOR("")
SlashCmdList.DISENCHANTADVISOR("status")
print("-- screenshot case per mode (bound, vendor 66s 52c)")
DisenchantAdvisorDB.details = "always"
auction[11176], auction[11175], auction[11178] = 2700, 10100, 19700
for _, mode in ipairs({ "safe", "balanced", "average" }) do
    DisenchantAdvisorDB.mode = mode
    print("mode " .. mode)
    Show(1007, { bound = true })
end
print("-- balanced, max risk 80 %: risk is fine now")
DisenchantAdvisorDB.mode, DisenchantAdvisorDB.maxRisk = "balanced", 80
Show(1007, { bound = true })
DisenchantAdvisorDB.mode, DisenchantAdvisorDB.maxRisk = "safe", 40
print("-- auction house switched off (1006: with it, the AH wins)")
DisenchantAdvisorDB.useAuction = false
Show(1006)
SlashCmdList.DISENCHANTADVISOR("status")
DisenchantAdvisorDB.useAuction = true
print("-- without Auctionator")
Auctionator = nil
Show(1001)
