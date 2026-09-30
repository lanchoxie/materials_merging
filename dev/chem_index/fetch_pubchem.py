"""v0.29 chemistry index, step 2: fetch small molecules from PubChem (PUG REST, no key needed).

    python dev/chem_index/fetch_pubchem.py            # fetch (cached) + build data/chem_index/molecules.json
    python dev/chem_index/fetch_pubchem.py --offline  # rebuild from the cache only

Each molecule keeps its PubChem CID, formula, weight, IUPAC name and the bond graph (explicit H,
Kekulé bond orders 1-3) from the PubChem 3D conformer (2D record when no conformer exists).
The game matches a player's build against this graph exactly, so the list is curated: real,
neutral molecules made only of the game's elements and small enough to build (<= 20 atoms).
PubChem data: NCBI, public domain for most records; attribution in data/chem_index/sources.json.
"""
import json, sys, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CACHE = ROOT / ".runtime" / "chem_index_cache" / "pubchem"
OUT = ROOT / "data" / "chem_index" / "molecules.json"
BASE = "https://pubchem.ncbi.nlm.nih.gov/rest/pug"
MAX_ATOMS = 20

# (PubChem name, Chinese name, group)
MOLECULES = [
    ("hydrogen", "氢气", "单质"), ("oxygen", "氧气", "单质"), ("ozone", "臭氧", "单质"),
    ("nitrogen", "氮气", "单质"), ("fluorine", "氟气", "单质"), ("chlorine", "氯气", "单质"),
    ("bromine", "溴", "单质"),
    ("water", "水", "无机分子"), ("hydrogen peroxide", "过氧化氢", "无机分子"),
    ("ammonia", "氨", "无机分子"), ("hydrazine", "肼", "无机分子"), ("hydroxylamine", "羟胺", "无机分子"),
    ("nitric oxide", "一氧化氮", "无机分子"), ("nitrogen dioxide", "二氧化氮", "无机分子"),
    ("nitrous oxide", "一氧化二氮", "无机分子"), ("dinitrogen tetroxide", "四氧化二氮", "无机分子"),
    ("nitric acid", "硝酸", "无机分子"), ("nitrous acid", "亚硝酸", "无机分子"),
    ("carbon monoxide", "一氧化碳", "无机分子"), ("carbon dioxide", "二氧化碳", "无机分子"),
    ("carbonic acid", "碳酸", "无机分子"), ("hydrogen cyanide", "氰化氢", "无机分子"),
    ("isocyanic acid", "异氰酸", "无机分子"), ("cyanogen", "氰", "无机分子"),
    ("hydrogen sulfide", "硫化氢", "无机分子"), ("sulfur dioxide", "二氧化硫", "无机分子"),
    ("sulfur trioxide", "三氧化硫", "无机分子"), ("sulfuric acid", "硫酸", "无机分子"),
    ("carbon disulfide", "二硫化碳", "无机分子"), ("carbonyl sulfide", "羰基硫", "无机分子"),
    ("hydrogen fluoride", "氟化氢", "卤化物"), ("hydrogen chloride", "氯化氢", "卤化物"),
    ("hydrogen bromide", "溴化氢", "卤化物"), ("bromine chloride", "氯化溴", "卤化物"),
    ("chlorine monofluoride", "一氟化氯", "卤化物"), ("chlorine trifluoride", "三氟化氯", "卤化物"),
    ("chlorine dioxide", "二氧化氯", "卤化物"), ("hypochlorous acid", "次氯酸", "卤化物"),
    ("nitrogen trifluoride", "三氟化氮", "卤化物"), ("nitrogen trichloride", "三氯化氮", "卤化物"),
    ("sulfur hexafluoride", "六氟化硫", "卤化物"), ("sulfur dichloride", "二氯化硫", "卤化物"),
    ("phosgene", "光气", "卤化物"), ("thionyl chloride", "氯化亚砜", "卤化物"),
    ("sulfuryl chloride", "硫酰氯", "卤化物"), ("cyanogen chloride", "氯化氰", "卤化物"),
    ("methane", "甲烷", "烃"), ("ethane", "乙烷", "烃"), ("propane", "丙烷", "烃"),
    ("butane", "丁烷", "烃"), ("isobutane", "异丁烷", "烃"), ("ethylene", "乙烯", "烃"),
    ("propylene", "丙烯", "烃"), ("acetylene", "乙炔", "烃"), ("propyne", "丙炔", "烃"),
    ("cyclopropane", "环丙烷", "烃"), ("1,3-butadiene", "1,3-丁二烯", "烃"), ("benzene", "苯", "烃"),
    ("methanol", "甲醇", "含氧有机物"), ("ethanol", "乙醇", "含氧有机物"), ("1-propanol", "正丙醇", "含氧有机物"),
    ("isopropanol", "异丙醇", "含氧有机物"), ("ethylene glycol", "乙二醇", "含氧有机物"),
    ("glycerol", "甘油", "含氧有机物"), ("dimethyl ether", "二甲醚", "含氧有机物"),
    ("ethylene oxide", "环氧乙烷", "含氧有机物"), ("formaldehyde", "甲醛", "含氧有机物"),
    ("acetaldehyde", "乙醛", "含氧有机物"), ("acetone", "丙酮", "含氧有机物"),
    ("formic acid", "甲酸", "含氧有机物"), ("acetic acid", "乙酸", "含氧有机物"),
    ("oxalic acid", "草酸", "含氧有机物"), ("methyl formate", "甲酸甲酯", "含氧有机物"),
    ("ketene", "乙烯酮", "含氧有机物"), ("glycolic acid", "乙醇酸", "含氧有机物"),
    ("lactic acid", "乳酸", "含氧有机物"), ("phenol", "苯酚", "含氧有机物"),
    ("methylamine", "甲胺", "含氮有机物"), ("dimethylamine", "二甲胺", "含氮有机物"),
    ("trimethylamine", "三甲胺", "含氮有机物"), ("ethylamine", "乙胺", "含氮有机物"),
    ("urea", "尿素", "含氮有机物"), ("formamide", "甲酰胺", "含氮有机物"),
    ("acetamide", "乙酰胺", "含氮有机物"), ("acetonitrile", "乙腈", "含氮有机物"),
    ("nitromethane", "硝基甲烷", "含氮有机物"), ("glycine", "甘氨酸", "含氮有机物"),
    ("alanine", "丙氨酸", "含氮有机物"), ("pyridine", "吡啶", "含氮有机物"),
    ("methanethiol", "甲硫醇", "含硫有机物"), ("ethanethiol", "乙硫醇", "含硫有机物"),
    ("thiourea", "硫脲", "含硫有机物"), ("dimethyl sulfide", "二甲硫醚", "含硫有机物"),
    ("dimethyl sulfoxide", "二甲基亚砜", "含硫有机物"), ("thiophene", "噻吩", "含硫有机物"),
    ("chloromethane", "一氯甲烷", "卤代烃"), ("dichloromethane", "二氯甲烷", "卤代烃"),
    ("chloroform", "三氯甲烷", "卤代烃"), ("carbon tetrachloride", "四氯化碳", "卤代烃"),
    ("fluoromethane", "一氟甲烷", "卤代烃"), ("tetrafluoromethane", "四氟甲烷", "卤代烃"),
    ("bromomethane", "溴甲烷", "卤代烃"), ("vinyl chloride", "氯乙烯", "卤代烃"),
    ("tetrafluoroethylene", "四氟乙烯", "卤代烃"), ("chloroethane", "氯乙烷", "卤代烃"),
    ("1,1,1,2-tetrafluoroethane", "1,1,1,2-四氟乙烷 (R-134a)", "卤代烃"),
]


def get(url: str, cache_name: str, offline: bool, text: bool = False):
    path = CACHE / cache_name
    if path.exists():
        raw = path.read_text(encoding="utf-8")
        return raw if text else json.loads(raw)
    if offline:
        sys.exit("cache miss: %s" % cache_name)
    import requests
    for attempt in range(4):
        time.sleep(0.25)  # PubChem asks for <= 5 requests per second
        r = requests.get(url, timeout=60)
        if r.status_code == 200:
            break
        if r.status_code == 404:
            return None
        time.sleep(2 * (attempt + 1))
    r.raise_for_status()
    CACHE.mkdir(parents=True, exist_ok=True)
    path.write_text(r.text, encoding="utf-8")
    return r.text if text else r.json()


def parse_sdf(sdf: str) -> tuple:
    lines = sdf.splitlines()
    counts = lines[3]
    n_atoms, n_bonds = int(counts[0:3]), int(counts[3:6])
    atoms, positions, bonds = [], [], []
    for line in lines[4:4 + n_atoms]:
        x, y, z = float(line[0:10]), float(line[10:20]), float(line[20:30])
        atoms.append(line[31:34].strip())
        positions.append([round(x, 3), round(y, 3), round(z, 3)])
    for line in lines[4 + n_atoms:4 + n_atoms + n_bonds]:
        a, b, order = int(line[0:3]) - 1, int(line[3:6]) - 1, int(line[6:9])
        bonds.append([a, b, order])
    # Formal charges (CO as [C-]#[O+], nitro groups) and radicals (NO, NO2) keep their bond graph;
    # the game does not model formal charges, so they are only flagged.
    notes = sorted({"formal_charges" if line.startswith("M  CHG") else "radical"
                    for line in lines[4 + n_atoms + n_bonds:] if line.startswith(("M  CHG", "M  RAD"))})
    return atoms, positions, bonds, notes


def main():
    offline = "--offline" in sys.argv
    elements = set(json.loads((ROOT / "data" / "elements.json").read_text(encoding="utf-8"))["elements"].keys())
    out, skipped = [], []
    for name, zh, group in MOLECULES:
        key = name.replace(" ", "_").replace(",", "")
        cids = get("%s/compound/name/%s/cids/JSON" % (BASE, name), key + ".cids.json", offline)
        if not cids:
            skipped.append((name, "no CID")); continue
        cid = cids["IdentifierList"]["CID"][0]
        props = get("%s/compound/cid/%d/property/MolecularFormula,MolecularWeight,IUPACName,Charge,XLogP/JSON" % (BASE, cid),
                    "%d.props.json" % cid, offline)["PropertyTable"]["Properties"][0]
        dim = "3d"
        sdf = get("%s/compound/cid/%d/record/SDF?record_type=3d" % (BASE, cid), "%d.3d.sdf" % cid, offline, text=True)
        if not sdf:
            dim = "2d"
            sdf = get("%s/compound/cid/%d/record/SDF?record_type=2d" % (BASE, cid), "%d.2d.sdf" % cid, offline, text=True)
        try:
            atoms, positions, bonds, notes = parse_sdf(sdf)
        except Exception as error:
            skipped.append((name, str(error))); continue
        if int(props.get("Charge", 0)) != 0 or not set(atoms) <= elements:
            skipped.append((name, "charge or element outside the game")); continue
        if len(atoms) > MAX_ATOMS or any(b[2] not in (1, 2, 3) for b in bonds):
            skipped.append((name, "too large or unsupported bond order")); continue
        entry = {"cid": cid, "name": zh, "name_en": name, "group": group, "formula": props["MolecularFormula"],
                 "weight": round(float(props["MolecularWeight"]), 3), "iupac": props.get("IUPACName", ""),
                 "atoms": atoms, "bonds": bonds, "positions": positions, "geometry": dim}
        if notes:
            entry["notes"] = notes
        if props.get("XLogP") is not None:
            entry["xlogp"] = props["XLogP"]
        out.append(entry)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    payload = {"version": 1, "source": "pubchem", "max_atoms": MAX_ATOMS,
               "units": {"weight": "g/mol", "positions": "A, PubChem conformer (2D records: flat layout)"},
               "entries": out}
    OUT.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print("wrote %s: %d molecules, %.1f kB" % (OUT.relative_to(ROOT), len(out), OUT.stat().st_size / 1024))
    for name, why in skipped:
        print("  skipped %s: %s" % (name, why))


if __name__ == "__main__":
    main()
