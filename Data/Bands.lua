-- What disenchanting gives, per item class, quality and item level.
--
-- The bands (class, quality, item level range) are Forever's own client table ItemDisenchantLoot
-- (build 1.60.1.70938, see tools/update_data.py). The client does not say what drops in a band:
-- chances and amounts are Classic 1.12's as reproduced by vmangos (disenchant_loot_template),
-- taken over from Disenchant Forever's tables.

local _, ns = ...

local B = {}
ns.bands = B

-- materials
local STRANGE, SOUL, VISION, DREAM, ILLUSION = 10940, 11083, 11137, 11176, 16204
local LESSER_MAGIC, GREATER_MAGIC = 10938, 10939
local LESSER_ASTRAL, GREATER_ASTRAL = 10998, 11082
local LESSER_MYSTIC, GREATER_MYSTIC = 11134, 11135
local LESSER_NETHER, GREATER_NETHER = 11174, 11175
local LESSER_ETERNAL, GREATER_ETERNAL = 16202, 16203
local SMALL_GLIMMERING, LARGE_GLIMMERING = 10978, 11084
local SMALL_GLOWING, LARGE_GLOWING = 11138, 11139
local SMALL_RADIANT, LARGE_RADIANT = 11177, 11178
local SMALL_BRILLIANT, LARGE_BRILLIANT = 14343, 14344
local NEXUS = 20725

B.materials = {
    STRANGE, SOUL, VISION, DREAM, ILLUSION,
    LESSER_MAGIC, GREATER_MAGIC, LESSER_ASTRAL, GREATER_ASTRAL, LESSER_MYSTIC, GREATER_MYSTIC,
    LESSER_NETHER, GREATER_NETHER, LESSER_ETERNAL, GREATER_ETERNAL,
    SMALL_GLIMMERING, LARGE_GLIMMERING, SMALL_GLOWING, LARGE_GLOWING,
    SMALL_RADIANT, LARGE_RADIANT, SMALL_BRILLIANT, LARGE_BRILLIANT, NEXUS,
}

-- English names, only shown while the client has not loaded the localized one yet
B.names = {
    [STRANGE] = "Strange Dust", [SOUL] = "Soul Dust", [VISION] = "Vision Dust",
    [DREAM] = "Dream Dust", [ILLUSION] = "Illusion Dust",
    [LESSER_MAGIC] = "Lesser Magic Essence", [GREATER_MAGIC] = "Greater Magic Essence",
    [LESSER_ASTRAL] = "Lesser Astral Essence", [GREATER_ASTRAL] = "Greater Astral Essence",
    [LESSER_MYSTIC] = "Lesser Mystic Essence", [GREATER_MYSTIC] = "Greater Mystic Essence",
    [LESSER_NETHER] = "Lesser Nether Essence", [GREATER_NETHER] = "Greater Nether Essence",
    [LESSER_ETERNAL] = "Lesser Eternal Essence", [GREATER_ETERNAL] = "Greater Eternal Essence",
    [SMALL_GLIMMERING] = "Small Glimmering Shard", [LARGE_GLIMMERING] = "Large Glimmering Shard",
    [SMALL_GLOWING] = "Small Glowing Shard", [LARGE_GLOWING] = "Large Glowing Shard",
    [SMALL_RADIANT] = "Small Radiant Shard", [LARGE_RADIANT] = "Large Radiant Shard",
    [SMALL_BRILLIANT] = "Small Brilliant Shard", [LARGE_BRILLIANT] = "Large Brilliant Shard",
    [NEXUS] = "Nexus Crystal",
}

-- Enchanters turn 3 lesser essences into 1 greater and back, so each one is worth at least
-- its partner's price times the factor.
B.pairs = {
    [LESSER_MAGIC] = { GREATER_MAGIC, 1 / 3 },     [GREATER_MAGIC] = { LESSER_MAGIC, 3 },
    [LESSER_ASTRAL] = { GREATER_ASTRAL, 1 / 3 },   [GREATER_ASTRAL] = { LESSER_ASTRAL, 3 },
    [LESSER_MYSTIC] = { GREATER_MYSTIC, 1 / 3 },   [GREATER_MYSTIC] = { LESSER_MYSTIC, 3 },
    [LESSER_NETHER] = { GREATER_NETHER, 1 / 3 },   [GREATER_NETHER] = { LESSER_NETHER, 3 },
    [LESSER_ETERNAL] = { GREATER_ETERNAL, 1 / 3 }, [GREATER_ETERNAL] = { LESSER_ETERNAL, 3 },
}

-- { min level, max level, { chance %, min amount, max amount, material }, ... }
local ARMOR_UNCOMMON = {
    { 5, 15,  { 80, 1, 2, STRANGE },  { 20, 1, 2, LESSER_MAGIC } },
    { 16, 20, { 75, 2, 3, STRANGE },  { 20, 1, 2, GREATER_MAGIC },   { 5, 1, 1, SMALL_GLIMMERING } },
    { 21, 25, { 75, 4, 6, STRANGE },  { 15, 1, 2, LESSER_ASTRAL },   { 10, 1, 1, SMALL_GLIMMERING } },
    { 26, 30, { 75, 1, 2, SOUL },     { 20, 1, 2, GREATER_ASTRAL },  { 5, 1, 1, LARGE_GLIMMERING } },
    { 31, 35, { 75, 2, 5, SOUL },     { 20, 1, 2, LESSER_MYSTIC },   { 5, 1, 1, SMALL_GLOWING } },
    { 36, 40, { 75, 1, 2, VISION },   { 20, 1, 2, GREATER_MYSTIC },  { 5, 1, 1, LARGE_GLOWING } },
    { 41, 45, { 75, 2, 5, VISION },   { 20, 1, 2, LESSER_NETHER },   { 5, 1, 1, SMALL_RADIANT } },
    { 46, 50, { 75, 1, 2, DREAM },    { 20, 1, 2, GREATER_NETHER },  { 5, 1, 1, LARGE_RADIANT } },
    { 51, 55, { 75, 2, 5, DREAM },    { 20, 1, 2, LESSER_ETERNAL },  { 5, 1, 1, SMALL_BRILLIANT } },
    { 56, 60, { 75, 1, 2, ILLUSION }, { 20, 1, 2, GREATER_ETERNAL }, { 5, 1, 1, LARGE_BRILLIANT } },
    { 61, 99, { 75, 2, 5, ILLUSION }, { 20, 2, 3, GREATER_ETERNAL }, { 5, 1, 1, LARGE_BRILLIANT } },
}

-- weapons give mostly essences
local WEAPON_UNCOMMON = {
    { 5, 15,  { 80, 1, 2, LESSER_MAGIC },    { 20, 1, 2, STRANGE } },
    { 16, 20, { 75, 1, 2, GREATER_MAGIC },   { 20, 2, 3, STRANGE },  { 5, 1, 1, SMALL_GLIMMERING } },
    { 21, 25, { 75, 1, 2, LESSER_ASTRAL },   { 15, 4, 6, STRANGE },  { 10, 1, 1, SMALL_GLIMMERING } },
    { 26, 30, { 75, 1, 2, GREATER_ASTRAL },  { 20, 1, 2, SOUL },     { 5, 1, 1, LARGE_GLIMMERING } },
    { 31, 35, { 75, 1, 2, LESSER_MYSTIC },   { 20, 2, 5, SOUL },     { 5, 1, 1, SMALL_GLOWING } },
    { 36, 40, { 75, 1, 2, GREATER_MYSTIC },  { 20, 1, 2, VISION },   { 5, 1, 1, LARGE_GLOWING } },
    { 41, 45, { 75, 1, 2, LESSER_NETHER },   { 20, 2, 5, VISION },   { 5, 1, 1, SMALL_RADIANT } },
    { 46, 50, { 75, 1, 2, GREATER_NETHER },  { 20, 1, 2, DREAM },    { 5, 1, 1, LARGE_RADIANT } },
    { 51, 55, { 75, 1, 2, LESSER_ETERNAL },  { 22, 2, 5, DREAM },    { 3, 1, 1, SMALL_BRILLIANT } },
    { 56, 60, { 75, 1, 2, GREATER_ETERNAL }, { 22, 1, 2, ILLUSION }, { 3, 1, 1, LARGE_BRILLIANT } },
    { 61, 99, { 75, 2, 3, GREATER_ETERNAL }, { 22, 2, 5, ILLUSION }, { 3, 1, 1, LARGE_BRILLIANT } },
}

-- rares are the same for weapons and armor
local RARE = {
    -- band new in Forever, no server data for it: assumed to be like 16-20
    { 5, 15,  { 100, 1, 1, SMALL_GLIMMERING }, unconfirmed = true },
    { 16, 20, { 100, 1, 1, SMALL_GLIMMERING } },
    { 21, 25, { 100, 1, 1, SMALL_GLIMMERING } },
    { 26, 30, { 100, 1, 1, LARGE_GLIMMERING } },
    { 31, 35, { 100, 1, 1, SMALL_GLOWING } },
    { 36, 40, { 100, 1, 1, LARGE_GLOWING } },
    { 41, 45, { 100, 1, 1, SMALL_RADIANT } },
    { 46, 50, { 100, 1, 1, LARGE_RADIANT } },
    { 51, 55, { 100, 1, 1, SMALL_BRILLIANT } },
    { 56, 60, { 100, 1, 1, LARGE_BRILLIANT } },
    { 61, 99, { 99, 1, 1, LARGE_BRILLIANT }, { 1, 1, 1, NEXUS } },
}

local EPIC = {
    { 40, 45, { 100, 2, 4, SMALL_RADIANT } },
    { 46, 50, { 100, 2, 4, LARGE_RADIANT } },
    { 51, 55, { 100, 2, 4, SMALL_BRILLIANT } },
    { 56, 60, { 100, 1, 1, NEXUS } },
    { 61, 99, { 100, 1, 2, NEXUS } },
}

local CLASS_WEAPON, CLASS_ARMOR = 2, 4
local QUALITY_UNCOMMON, QUALITY_RARE, QUALITY_EPIC = 2, 3, 4

local TABLES = {
    [CLASS_ARMOR]  = { [QUALITY_UNCOMMON] = ARMOR_UNCOMMON,  [QUALITY_RARE] = RARE, [QUALITY_EPIC] = EPIC },
    [CLASS_WEAPON] = { [QUALITY_UNCOMMON] = WEAPON_UNCOMMON, [QUALITY_RARE] = RARE, [QUALITY_EPIC] = EPIC },
}

-- The band of an item, or nil if it does not disenchant into the usual materials.
-- Returns { minLevel, maxLevel, unconfirmed, drops = { { itemID, chance, low, high }, ... } }.
local cache = {}
function B.Find(classID, quality, level)
    local byQuality = TABLES[classID]
    local rows = byQuality and quality and byQuality[quality]
    if not rows or not level then return nil end
    for _, row in ipairs(rows) do
        if level >= row[1] and level <= row[2] then
            if not cache[row] then
                local band = { minLevel = row[1], maxLevel = row[2], unconfirmed = row.unconfirmed, drops = {} }
                for i = 3, #row do
                    local chance, low, high, itemID = unpack(row[i])
                    band.drops[#band.drops + 1] = { itemID = itemID, chance = chance, low = low, high = high }
                end
                cache[row] = band
            end
            return cache[row]
        end
    end
    return nil
end
