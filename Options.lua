-- Settings page under Esc > Options > AddOns (Blizzard's Settings API).
-- Values live in DisenchantAdvisorDB (ns.db) and are read on every tooltip, so changes apply at once.

local ADDON, ns = ...

local L = ns.L
local O = {}
ns.options = O

local function Percent(value)
    return string.format("%d %%", value)
end

-- Called once the saved variables are loaded (ADDON_LOADED).
function O.Register()
    if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnSetting) then return end
    local db = ns.db
    local category, layout = Settings.RegisterVerticalLayoutCategory("DisenchantAdvisor")

    local function Header(text)
        if layout and CreateSettingsListSectionHeaderInitializer then
            layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
        end
    end

    -- ---------------------------------------------------------- tooltip
    Header(L["Tooltip"])

    local enabled = Settings.RegisterAddOnSetting(category, "DisenchantAdvisor_enabled", "enabled", db,
        Settings.VarType.Boolean, L["Show in item tooltips"], true)
    Settings.CreateCheckbox(category, enabled,
        L["What disenchanting gives, the price comparison and the recommendation."])

    local detailsKey = Settings.RegisterAddOnSetting(category, "DisenchantAdvisor_detailsKey", "detailsKey", db,
        Settings.VarType.String, L["Modifier key for details"], "none")
    local function KeyOptions()
        local container = Settings.CreateControlTextContainer()
        for _, key in ipairs(ns.tooltip.KEYS) do
            container:Add(key, L[ns.tooltip.KEY_NAMES[key]])
        end
        return container:GetData()
    end
    Settings.CreateDropdown(category, detailsKey, KeyOptions,
        L["None: the details are always shown. Otherwise the proceeds of each option and the range of a single disenchant only while that key is held; materials and recommendation are always shown."])

    -- ---------------------------------------------------- recommendation
    Header(L["Recommendation"])

    local auction = Settings.RegisterAddOnSetting(category, "DisenchantAdvisor_useAuction", "useAuction", db,
        Settings.VarType.Boolean, L["Consider selling at the auction house"], true)
    Settings.CreateCheckbox(category, auction,
        L["Off: the item itself is only compared with the vendor price, e.g. if you do not want to sell items at the auction house. The materials are still valued at auction prices."])

    local mode = Settings.RegisterAddOnSetting(category, "DisenchantAdvisor_mode", "mode", db,
        Settings.VarType.String, L["Recommendation style"], ns.advisor.DEFAULT_MODE)
    local function ModeOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add("safe", L["Safe"],
            L["Disenchant only if it earns at least the minimum lead more on average AND loses against selling in at most the maximum loss risk of the cases."])
        container:Add("balanced", L["Balanced"],
            L["Disenchant if it earns at least the minimum lead more on average OR rarely loses (at most the maximum loss risk)."])
        container:Add("average", L["Average (risky)"],
            L["Always recommend what earns most on average, however often a single disenchant earns less. Pays off over many items."])
        return container:GetData()
    end
    local modeInitializer = Settings.CreateDropdown(category, mode, ModeOptions,
        L["When should disenchanting be recommended over selling? Selling to a vendor pays a fixed amount; a single disenchant can give much less or much more than its average."])

    local function Slider(key, default, label, tooltip)
        local setting = Settings.RegisterAddOnSetting(category, "DisenchantAdvisor_" .. key, key, db,
            Settings.VarType.Number, label, default)
        local options = Settings.CreateSliderOptions(0, 100, 5)
        if MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label then
            options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, Percent)
        end
        local initializer = Settings.CreateSlider(category, setting, options, tooltip)
        -- greyed out in "average" mode, where only the notes use them
        if initializer and initializer.SetParentInitializer and modeInitializer then
            initializer:SetParentInitializer(modeInitializer, function() return db.mode ~= "average" end)
        end
    end
    Slider("minLead", ns.advisor.DEFAULT_MIN_LEAD, L["Minimum lead"],
        L["How much more disenchanting has to earn on average than the best way of selling, in percent of that sale. Below it the recommendation is a close call."])
    Slider("maxRisk", ns.advisor.DEFAULT_MAX_RISK, L["Maximum loss risk"],
        L["In how many of the cases a single disenchant may earn less than the best way of selling. Above it disenchanting counts as risky."])

    Settings.RegisterAddOnCategory(category)
    O.category = category
end

function O.Open()
    if O.category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(O.category:GetID())
        return true
    end
    return false
end
