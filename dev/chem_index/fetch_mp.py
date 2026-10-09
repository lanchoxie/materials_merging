"""v0.29 chemistry index, step 1: fetch Materials Project crystals for the game's elements.

Offline, build-time only. The game ships the output JSON; no key or network at runtime.

    python dev/chem_index/fetch_mp.py            # fetch (cached) + build data/chem_index/crystals.json
    python dev/chem_index/fetch_mp.py --offline  # rebuild from the cache only

The API key comes from the MP_API_KEY environment variable or `.runtime/secrets/mp_api_key`
(gitignored). It is never printed, logged or written anywhere else.
Raw responses are cached under `.runtime/chem_index_cache/` (gitignored).
Data licence: Materials Project, CC BY 4.0 (attribution in data/chem_index/sources.json).
"""
import itertools, json, os, sys, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CACHE = ROOT / ".runtime" / "chem_index_cache" / "mp"
OUT = ROOT / "data" / "chem_index" / "crystals.json"
URL = "https://api.materialsproject.org/materials/summary/"
MAX_SITES = 24          # a unit cell the atom editor could plausibly hold
MAX_HULL = 0.1          # eV/atom above the convex hull
MAX_ELEMENTS = 5        # chemical systems up to quinary
BATCH = 100             # chemsys values per request (URL stays ~2 kB)
FIELDS = ",".join([
    "material_id", "formula_pretty", "chemsys", "nsites", "symmetry", "density", "volume",
    "energy_above_hull", "formation_energy_per_atom", "band_gap", "is_gap_direct", "is_metal",
    "is_magnetic", "ordering", "total_magnetization", "theoretical", "database_IDs",
    "bulk_modulus", "shear_modulus", "structure", "deprecated", "composition_reduced",
    "homogeneous_poisson", "n",
])


def api_key() -> str:
    key = os.environ.get("MP_API_KEY", "").strip()
    if not key:
        path = ROOT / ".runtime" / "secrets" / "mp_api_key"
        if path.exists():
            key = path.read_text(encoding="utf-8").strip()
    if not key:
        sys.exit("No MP API key: set MP_API_KEY or write .runtime/secrets/mp_api_key")
    return key


def game_elements() -> list:
    data = json.loads((ROOT / "data" / "elements.json").read_text(encoding="utf-8"))
    return sorted(data["elements"].keys())


def systems(elements: list) -> list:
    out = []
    for k in range(1, MAX_ELEMENTS + 1):
        out += ["-".join(sorted(c)) for c in itertools.combinations(elements, k)]
    return out


def fetch_batch(index: int, chemsys: list, offline: bool) -> list:
    path = CACHE / ("batch_%03d.json" % index)
    signature = {"chemsys": chemsys, "nsites_max": MAX_SITES, "energy_above_hull_max": MAX_HULL, "fields": FIELDS}
    if path.exists():
        cached = json.loads(path.read_text(encoding="utf-8"))
        if cached.get("signature") == signature:
            return cached["data"]
    if offline:
        sys.exit("cache miss for batch %d in --offline mode" % index)
    import requests
    docs, skip = [], 0
    while True:
        params = {"chemsys": ",".join(chemsys), "nsites_max": MAX_SITES, "energy_above_hull_max": MAX_HULL,
                  "_fields": FIELDS, "_limit": 500, "_skip": skip}
        for attempt in range(4):
            r = requests.get(URL, headers={"X-API-KEY": api_key()}, params=params, timeout=180)
            if r.status_code == 200:
                break
            print("  batch %d: HTTP %d, retrying" % (index, r.status_code))
            time.sleep(3 * (attempt + 1))
        r.raise_for_status()
        body = r.json()
        docs += body["data"]
        skip += len(body["data"])
        if not body["data"] or skip >= int(body["meta"]["total_doc"]):
            break
    CACHE.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({"signature": signature, "data": docs}), encoding="utf-8")
    return docs


def r(x, n):
    return None if x is None else round(float(x), n)


def compact(doc: dict) -> dict:
    sym = doc.get("symmetry") or {}
    st = doc.get("structure") or {}
    lattice = st.get("lattice", {})
    sites = []
    for site in st.get("sites", []):
        species = site.get("species", [])
        # Disordered sites keep their majority species; MP summary structures are ordered in practice.
        el = max(species, key=lambda s: s.get("occu", 0))["element"] if species else "X"
        sites.append([el] + [round(float(v) % 1.0, 4) for v in site["abc"]])
    ids = doc.get("database_IDs") or {}
    entry = {
        "id": doc["material_id"],
        "formula": doc["formula_pretty"],
        "chemsys": doc["chemsys"],
        "nsites": doc["nsites"],
        "spacegroup": sym.get("symbol"),
        "sg_number": sym.get("number"),
        "crystal_system": sym.get("crystal_system"),
        "density": r(doc.get("density"), 3),
        "volume": r(doc.get("volume"), 2),
        "e_hull": r(doc.get("energy_above_hull"), 4),
        "e_form": r(doc.get("formation_energy_per_atom"), 4),
        "band_gap": r(doc.get("band_gap"), 3),
        "direct_gap": bool(doc.get("is_gap_direct")),
        "metal": bool(doc.get("is_metal")),
        "magnetic": bool(doc.get("is_magnetic")),
        "experimental": not bool(doc.get("theoretical", True)),
        "icsd": len(ids.get("icsd", []) or []),
        "lattice": [[round(float(v), 4) for v in row] for row in lattice.get("matrix", [])],
        "sites": sites,
    }
    for key, name in (("bulk_modulus", "bulk_gpa"), ("shear_modulus", "shear_gpa")):
        value = (doc.get(key) or {}).get("vrh")
        if value is not None and 0.0 < float(value) < 1000.0:
            entry[name] = round(float(value), 1)
    # v0.37 material model: Poisson's ratio (toughness proxy) and the refractive index (glass).
    poisson = doc.get("homogeneous_poisson")
    if poisson is not None and -1.0 < float(poisson) < 0.5:
        entry["poisson"] = round(float(poisson), 3)
    n = doc.get("n")
    if n is not None and 1.0 < float(n) < 6.0:
        entry["n"] = round(float(n), 3)
    return entry


def main():
    offline = "--offline" in sys.argv
    elements = game_elements()
    todo = systems(elements)
    print("elements: %s  ·  chemical systems: %d" % (" ".join(elements), len(todo)))
    docs = []
    for i in range(0, len(todo), BATCH):
        batch = fetch_batch(i // BATCH, todo[i:i + BATCH], offline)
        docs += batch
        print("  batch %d: %d docs" % (i // BATCH, len(batch)))
    entries, seen = [], set()
    for doc in docs:
        if doc.get("deprecated") or doc["material_id"] in seen:
            continue
        if not set(doc["chemsys"].split("-")) <= set(elements):
            continue
        seen.add(doc["material_id"])
        entries.append(compact(doc))
    # Stable order: formula, then most stable polymorph first.
    entries.sort(key=lambda e: (e["chemsys"], e["formula"], e["e_hull"] if e["e_hull"] is not None else 9, e["id"]))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "version": 1,
        "source": "materials_project",
        "db_version": fetch_db_version(offline),
        "filter": {"elements": elements, "nsites_max": MAX_SITES, "e_hull_max": MAX_HULL, "max_elements": MAX_ELEMENTS},
        "units": {"density": "g/cm3", "volume": "A3", "e_hull": "eV/atom", "e_form": "eV/atom", "band_gap": "eV",
                  "bulk_gpa": "GPa (VRH)", "shear_gpa": "GPa (VRH)", "lattice": "A, rows are lattice vectors", "sites": "fractional"},
        "entries": entries,
    }
    OUT.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    exp = sum(1 for e in entries if e["experimental"])
    print("wrote %s: %d entries (%d experimentally observed), %d formulas, %.1f kB" % (
        OUT.relative_to(ROOT), len(entries), exp, len({e["formula"] for e in entries}), OUT.stat().st_size / 1024))


def fetch_db_version(offline: bool) -> str:
    path = CACHE / "heartbeat.json"
    if not offline:
        import requests
        try:
            body = requests.get("https://api.materialsproject.org/heartbeat", timeout=30).json()
            CACHE.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(body), encoding="utf-8")
        except Exception:
            pass
    if path.exists():
        return str(json.loads(path.read_text(encoding="utf-8")).get("db_version", "unknown"))
    return "unknown"


if __name__ == "__main__":
    main()
