-- Texts. The key is the English text; a missing translation shows the key.

local _, ns = ...

local L = setmetatable({}, { __index = function(_, key) return key end })
ns.L = L

local translations = {
    deDE = {
        ["Disenchant"] = "Entzaubern",
        ["Vendor"] = "Händler",
        ["Auction house"] = "Auktionshaus",
        ["Disenchanting"] = "Entzaubern",
        ["Proceeds after AH cut"] = "Erlös nach AH-Gebühr",
        ["bound"] = "gebunden",
        ["no price"] = "kein Preis",
        ["%d days old"] = "%d Tage alt",
        ["over 3 weeks old"] = "über 3 Wochen alt",
        ["base item"] = "Grundgegenstand",
        ["unconfirmed"] = "unbestätigt",
        ["Gives its own items, not the usual materials"] = "Ergibt eigene Gegenstände statt der üblichen Materialien",
        ["Install Auctionator for prices and a recommendation"] = "Für Preise und Empfehlung Auctionator installieren",
        ["Sell at the auction house"] = "Im Auktionshaus verkaufen",
        ["Sell to a vendor"] = "Beim Händler verkaufen",
        ["+%s over %s"] = "+%s ggü. %s",
        ["close call"] = "knapp",
        ["risky"] = "riskant",
        ["Loss risk (vs. %s)"] = "Verlustrisiko (ggü. %s)",
        ["One disenchant gives"] = "Eine Entzauberung bringt",
        ["   Loss risk vs. %s: %s, one disenchant gives %s"] =
            "   Verlustrisiko ggü. %s: %s, eine Entzauberung bringt %s",
        ["prices missing"] = "Preise fehlen",
        ["needs an enchanter"] = "braucht einen Verzauberer",
        ["Hold Shift for details"] = "Shift für Details",
        -- chat
        ["Commands:"] = "Befehle:",
        ["  /dadv details always|shift - drops and price comparison always or only with Shift"] =
            "  /dadv details always|shift - Materialien und Preisvergleich immer oder nur mit Shift",
        ["  /dadv on|off - tooltip lines on or off"] = "  /dadv on|off - Tooltip-Zeilen an oder aus",
        ["  /dadv check <item link> - evaluation of an item in the chat"] =
            "  /dadv check <Gegenstandslink> - Bewertung eines Gegenstands im Chat",
        ["Tooltip: %s, details: %s, prices: %s"] = "Tooltip: %s, Details: %s, Preise: %s",
        ["on"] = "an",
        ["off"] = "aus",
        ["always"] = "immer",
        ["with Shift"] = "mit Shift",
        ["none (Auctionator missing)"] = "keine (Auctionator fehlt)",
        ["%s does not disenchant into the usual materials (or is not cached yet)."] =
            "%s lässt sich nicht in die üblichen Materialien entzaubern (oder ist noch nicht geladen).",
        ["%s: item level %d, band %d-%d"] = "%s: Gegenstandsstufe %d, Stufe %d-%d",
        ["Recommendation: %s"] = "Empfehlung: %s",
        ["no recommendation"] = "keine Empfehlung",
    },
}

for key, value in pairs(translations[GetLocale and GetLocale() or "enUS"] or {}) do
    rawset(L, key, value)
end
