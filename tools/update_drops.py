#!/usr/bin/env python3
"""Regenerates Data/Drops.lua: what disenchanting gives per item class, quality and level band.

The bands (class, quality, item level range) are Forever's own client table ItemDisenchantLoot
(wago.tools, newest `wowf` build). The client does not say what drops in a band, so chances and
amounts come from the vmangos world database (Classic 1.12, GPL-2.0, https://github.com/vmangos/core):
for each band the items of that class, quality and item level give the disenchant loot entry
(item_template.disenchant_id), whose rows in disenchant_loot_template are the drops. A band
vmangos has no items for gets the drops of the next band and is marked unconfirmed.

    python3 tools/update_drops.py [path to vmangos mangos.sql or db zip] [wowf build]

Without a path the newest vmangos database snapshot (release db_latest) is downloaded.
"""

import collections
import csv
import io
import json
import re
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path

WAGO = "https://wago.tools"
VMANGOS_RELEASE = "https://api.github.com/repos/vmangos/core/releases/tags/db_latest"
ROOT = Path(__file__).resolve().parent.parent
PATCH = 10   # vmangos content patch 1.12

# vmangos rows left out, with the reason. Everything else is taken as vmangos has it.
IGNORE = {
    # Epic 56-60 / 61+: vmangos also gives a Large Brilliant Shard at 100 % next to the Nexus
    # Crystal; cmangos classic-db (z2815) and Classic 1.12 give only the Nexus Crystal.
    (64, 14344): "only Nexus Crystals per cmangos",
    (65, 14344): "only Nexus Crystals per cmangos",
}

CLASSES = {2: "weapon", 4: "armor"}
QUALITIES = {2: "uncommon", 3: "rare", 4: "epic"}


def fetch(url, binary=False):
    request = urllib.request.Request(url, headers={"User-Agent": "DisenchantAdvisor data tool"})
    with urllib.request.urlopen(request, timeout=600) as response:
        data = response.read()
    return data if binary else data.decode("utf-8")


def forever_bands(build):
    if not build:
        build = json.loads(fetch(f"{WAGO}/api/builds"))["wowf"][0]["version"]
    rows = csv.DictReader(io.StringIO(fetch(f"{WAGO}/db2/ItemDisenchantLoot/csv?build={build}")))
    bands = sorted({(int(r["Class"]), int(r["Quality"]), int(r["MinLevel"]), int(r["MaxLevel"])) for r in rows})
    return build, [b for b in bands if b[0] in CLASSES and b[1] in QUALITIES]


def vmangos_sql(path):
    if path is None:
        release = json.loads(fetch(VMANGOS_RELEASE))
        asset = next(a for a in release["assets"] if re.fullmatch(r"db-[0-9a-f]+\.zip", a["name"]))
        print(f"vmangos {asset['name']} ({release['name']})")
        path = Path(tempfile.gettempdir()) / asset["name"]
        if not path.exists():
            path.write_bytes(fetch(asset["browser_download_url"], binary=True))
        source = asset["name"]
    else:
        path = Path(path)
        source = path.name
    if path.suffix == ".zip":
        with zipfile.ZipFile(path) as z:
            name = next(n for n in z.namelist() if n.endswith("mangos.sql"))
            return z.read(name).decode("utf-8", "replace"), source
    return path.read_text(encoding="utf-8", errors="replace"), source


TOKEN = re.compile(r"'((?:[^'\\]|\\.)*)'|(NULL)|(-?[0-9.eE+-]+)")


def rows(sql, table):
    """Yields each row of a table as a dict, using the column order of its CREATE TABLE."""
    create = re.search(r"CREATE TABLE `%s` \((.*?)\n\)" % table, sql, re.S).group(1)
    columns = re.findall(r"^\s*`(\w+)`", create, re.M)
    for insert in re.finditer(r"INSERT INTO `%s` VALUES (.*?);\n" % table, sql, re.S):
        body = insert.group(1)
        i = 0
        while i < len(body):
            if body[i] != "(":
                i += 1
                continue
            values, i = [], i + 1
            while body[i] != ")":
                m = TOKEN.match(body, i)
                values.append(m.group(1) if m.group(1) is not None else None if m.group(2) else m.group(3))
                i = m.end()
                if body[i] == ",":
                    i += 1
            i += 1
            yield dict(zip(columns, values))


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else None
    build, bands = forever_bands(sys.argv[2] if len(sys.argv) > 2 else None)
    sql, source = vmangos_sql(path)
    print(f"wowf build {build}, {len(bands)} bands")

    items = {}   # entry -> newest version up to patch 1.12
    for r in rows(sql, "item_template"):
        if int(r["patch"]) <= PATCH:
            old = items.get(r["entry"])
            if not old or int(r["patch"]) > int(old["patch"]):
                items[r["entry"]] = r

    raw = collections.defaultdict(list)   # entry -> (group, chance, min, max, item)
    for r in rows(sql, "disenchant_loot_template"):
        entry, item = int(r["entry"]), int(r["item"])
        if (entry, item) in IGNORE or not int(r["patch_min"]) <= PATCH <= int(r["patch_max"]):
            continue
        raw[entry].append((int(r["groupid"]), float(r["ChanceOrQuestChance"]), int(r["mincountOrRef"]),
                           int(r["maxcount"]), item))

    # Loot groups: one roll per group, rows with chance 0 share what the others leave of 100 %.
    # Group 0 rows roll each on their own. The addon expects exactly one result per disenchant, so
    # an entry may have one group, or a single group 0 row.
    loot = {}
    for entry, entry_rows in raw.items():
        groups = {g for g, *_ in entry_rows}
        if len(groups) != 1 or (0 in groups and len(entry_rows) > 1):
            sys.exit(f"entry {entry}: more than one independent roll {entry_rows}, the addon cannot show that")
        rest = 100 - sum(c for _, c, *_ in entry_rows)
        zeros = sum(1 for _, c, *_ in entry_rows if c == 0)
        loot[entry] = [(c if c else rest / zeros, lo, hi, item) for _, c, lo, hi, item in entry_rows]
        if abs(sum(c for c, *_ in loot[entry]) - 100) > 1e-6:
            sys.exit(f"entry {entry}: chances do not add up to 100 % {entry_rows}")

    ids = collections.defaultdict(collections.Counter)   # (class, quality, level) -> disenchant ids
    for r in items.values():
        if int(r["disenchant_id"]) and int(r["class"]) in CLASSES:
            ids[(int(r["class"]), int(r["quality"]), int(r["item_level"]))][int(r["disenchant_id"])] += 1

    result = collections.defaultdict(list)
    for cls, quality, low, high in bands:
        found = collections.Counter()
        for level in range(low, high + 1):
            found.update(ids.get((cls, quality, level), {}))
        entry = found.most_common(1)[0][0] if found else None
        if len(found) > 1:
            print(f"  note: {CLASSES[cls]} {QUALITIES[quality]} {low}-{high} uses entries {dict(found)}, taking {entry}")
        drops = sorted(loot.get(entry, []), key=lambda d: (-d[0], d[3])) if entry else []
        result[(cls, quality)].append({"low": low, "high": high, "drops": drops, "entry": entry})

    # bands without vmangos items: take the next band's drops, marked unconfirmed
    for band_list in result.values():
        for i, band in enumerate(band_list):
            if not band["drops"]:
                donor = next((b for b in band_list[i + 1:] if b["drops"]), None)
                if donor:
                    band["drops"], band["unconfirmed"] = donor["drops"], True
                    print(f"  note: band {band['low']}-{band['high']} has no vmangos items, using {donor['low']}-{donor['high']}")

    def num(x):
        return str(int(x)) if x == int(x) else repr(x)

    lines = [
        "-- What disenchanting gives: drops[classID][quality] = { { min level, max level,",
        "-- { chance %, min amount, max amount, material itemID }, ... }, ... }",
        f"-- Bands from Forever's ItemDisenchantLoot (build {build}), drops from the vmangos world",
        f"-- database ({source}, Classic 1.12, GPL-2.0, github.com/vmangos/core).",
        "-- Generated by tools/update_drops.py: do not edit by hand.",
        "",
        "local _, ns = ...",
        "",
        "ns.drops = {",
    ]
    for cls in sorted(CLASSES):
        lines.append(f"    [{cls}] = {{ -- {CLASSES[cls]}")
        for quality in sorted(QUALITIES):
            band_list = result.get((cls, quality))
            if not band_list:
                continue
            lines.append(f"        [{quality}] = {{ -- {QUALITIES[quality]}")
            for band in band_list:
                drops = ", ".join(f"{{ {num(c)}, {lo}, {hi}, {item} }}" for c, lo, hi, item in band["drops"])
                extra = ", unconfirmed = true" if band.get("unconfirmed") else ""
                lines.append(f"            {{ {band['low']}, {band['high']}, {drops}{extra} }},")
            lines.append("        },")
        lines.append("    },")
    lines += ["}", ""]
    out = ROOT / "Data" / "Drops.lua"
    out.write_text("\n".join(lines), encoding="utf-8")
    print(f"{out.relative_to(ROOT)} written")


if __name__ == "__main__":
    main()
