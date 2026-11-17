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
        ["disenchanting: +%s on average, %s loss risk"] = "Entzaubern: im Schnitt +%s, %s Verlustrisiko",
        -- settings page
        ["Tooltip"] = "Tooltip",
        ["Show in item tooltips"] = "Im Gegenstands-Tooltip anzeigen",
        ["What disenchanting gives, the price comparison and the recommendation."] =
            "Was beim Entzaubern herauskommt, Preisvergleich und Empfehlung.",
        ["Price comparison only with Shift"] = "Preisvergleich nur mit Shift",
        ["Materials and recommendation are always shown; the proceeds of each option and the range of a single disenchant only while Shift is held."] =
            "Materialien und Empfehlung stehen immer da; der Erlös jeder Option und die Spanne einer Entzauberung nur bei gedrückter Shift-Taste.",
        ["Recommendation"] = "Empfehlung",
        ["Consider selling at the auction house"] = "Verkauf im Auktionshaus berücksichtigen",
        ["Off: the item itself is only compared with the vendor price, e.g. if you do not want to sell items at the auction house. The materials are still valued at auction prices."] =
            "Aus: Der Gegenstand selbst wird nur mit dem Händlerpreis verglichen, z. B. wenn du keine Gegenstände im Auktionshaus verkaufen willst. Die Materialien werden weiter mit Auktionspreisen bewertet.",
        ["Recommendation style"] = "Empfehlungsstil",
        ["When should disenchanting be recommended over selling? Selling to a vendor pays a fixed amount; a single disenchant can give much less or much more than its average."] =
            "Wann soll Entzaubern statt Verkaufen empfohlen werden? Der Händler zahlt einen festen Betrag, eine einzelne Entzauberung kann deutlich weniger oder mehr bringen als ihr Durchschnitt.",
        ["Safe"] = "Sicher",
        ["Disenchant only if it earns at least the minimum lead more on average AND loses against selling in at most the maximum loss risk of the cases."] =
            "Entzaubern nur, wenn es im Schnitt mindestens den Mindestvorsprung mehr bringt UND höchstens im maximalen Verlustrisiko der Fälle weniger als Verkaufen.",
        ["Balanced"] = "Ausgewogen",
        ["Disenchant if it earns at least the minimum lead more on average OR rarely loses (at most the maximum loss risk)."] =
            "Entzaubern, wenn es im Schnitt mindestens den Mindestvorsprung mehr bringt ODER selten verliert (höchstens das maximale Verlustrisiko).",
        ["Average (risky)"] = "Durchschnitt (riskant)",
        ["Always recommend what earns most on average, however often a single disenchant earns less. Pays off over many items."] =
            "Immer empfehlen, was im Schnitt am meisten bringt, egal wie oft eine einzelne Entzauberung weniger bringt. Lohnt sich über viele Gegenstände.",
        ["Minimum lead"] = "Mindestvorsprung",
        ["How much more disenchanting has to earn on average than the best way of selling, in percent of that sale. Below it the recommendation is a close call."] =
            "Wie viel mehr Entzaubern im Schnitt bringen muss als der beste Verkauf, in Prozent dieses Verkaufs. Darunter ist die Empfehlung knapp.",
        ["Maximum loss risk"] = "Maximales Verlustrisiko",
        ["In how many of the cases a single disenchant may earn less than the best way of selling. Above it disenchanting counts as risky."] =
            "In wie vielen Fällen eine einzelne Entzauberung weniger bringen darf als der beste Verkauf. Darüber gilt Entzaubern als riskant.",
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
        ["Recommendation: %s, minimum lead %d %%, maximum loss risk %d %%, auction house: %s"] =
            "Empfehlung: %s, Mindestvorsprung %d %%, maximales Verlustrisiko %d %%, Auktionshaus: %s",
        ["  /dadv - settings (Esc > Options > AddOns)"] = "  /dadv - Einstellungen (Esc > Optionen > AddOns)",
        ["  /dadv status - current settings and the last tooltip error"] =
            "  /dadv status - aktuelle Einstellungen und letzter Tooltip-Fehler",
        ["no recommendation"] = "keine Empfehlung",
    },
}

for key, value in pairs(translations[GetLocale and GetLocale() or "enUS"] or {}) do
    rawset(L, key, value)
end
