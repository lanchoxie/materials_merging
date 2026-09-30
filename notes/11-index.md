# 11 · v0.29 "Index": a real chemistry database inside the game

> v0.30 added Fe and Sn and rebuilt the crystal list with the same filters: 1 835 entries (682 observed), 949 formulas.
> The numbers below are the v0.29 build. See [12-fabricator.md](12-fabricator.md) §3.

The plan is in [08-chemistry-loop.md](08-chemistry-loop.md) §2. The user supplied a Materials Project API key on 2026-10-01.
The key lives only in `.runtime/secrets/mp_api_key` (gitignored). It is never committed, logged, or bundled.

## 1 · Offline pipeline (`dev/chem_index/`)
- `fetch_mp.py` queries the MP summary endpoint.
  - It covers every chemical system of the 14 game elements up to quinary (3 472 systems, 100 per request).
    `exclude_elements` is capped at 60 characters, so it can't express "only these 14".
  - Filters: `nsites ≤ 24`, `E_hull ≤ 0.1 eV/atom`. Deprecated entries are dropped.
  - Output: `data/chem_index/crystals.json`, with 1 090 entries (496 experimentally observed, i.e. `theoretical=false`) across 583 formulas. About 740 kB.
  - Kept per entry: id, formula, chemsys, space group, crystal system, density, volume, E_hull, formation energy, band gap (direct or not), metal, magnetic, ICSD count and VRH moduli (when present). It also keeps the lattice and fractional sites (for the 3D preview).
  - MP database version: 2026.04.13 (from `/heartbeat`).
- `fetch_pubchem.py` covers a curated list of 106 neutral molecules made only of game elements, each ≤ 20 atoms.
  - Output: `data/chem_index/molecules.json` (40 kB).
  - Data from PUG REST: CID, formula, weight, IUPAC name, XLogP, and the bond graph with explicit H and Kekulé orders.
  - Geometry comes from the 3D conformer (95), or the 2D record when PubChem has no conformer (9: radicals, some inorganics).
  - PubChem draws some neutral molecules with formal charges (CO as [C-]#[O+], nitro groups, O₃). Radicals include NO, NO₂ and ClO₂. The graph is kept and the entry is flagged; the game does not model formal charges.
- Both scripts cache raw responses under `.runtime/chem_index_cache/`. `--offline` rebuilds from the cache.
- Attribution: `data/chem_index/sources.json`.
  - MP: CC BY 4.0, Jain et al. 2013, doi 10.1063/1.4812323.
  - PubChem: NCBI policy, Kim et al. 2025, doi 10.1093/nar/gkae1059.
- COD (experimental CIFs) is deferred. MP's `theoretical=false` plus the ICSD count already marks experimentally observed crystals.

## 2 · Matching (`scripts/chem_index.gd`)
Matching is honest and narrow. Nothing is inferred beyond what the match supports.

| match | when | counts as a find |
|---|---|---|
| `graph` | the player's bond graph (elements, bonds, bond orders 1–3) equals a PubChem graph (`sandbox_reference.match_graph`) | yes |
| `prototype` | the reduced composition equals an MP entry whose space group is the template family's ideal one (rock salt Fm-3m 225, cubic perovskite Pm-3m 221) | yes |
| `composition` | the reduced composition equals an MP entry (periodic workshop cells, lattice templates); the most stable polymorph is shown, and the geometry is not claimed to match | yes |
| `isomer` | same atoms as a known molecule, different connectivity | no (hint only) |
| — | anything else | "未收录 · 假说" |

- Lattice templates use site occupancies (corner ⅛, face ½), so the perovskite cell reduces to CsPbBr₃.
- All 17 templates are in the index.
- Element substitution now reaches real compounds that no template covers, for example:
  - LiCl, NaF, CsCl … (rock-salt family)
  - HBr (from HCl)
  - thiourea (urea O→S)
  - ethanethiol (ethanol O→S)

## 3 · Gameplay
- `structure_data` / `sandbox_reference` attach `index` to every described structure.
  - An unknown structure that matches is named for what it is, for example "LiCl · Fm-3m 晶体 · 化学索引收录".
  - It stays an exploration sample for orders and quality.
- Unknown structures with an index match earn **2×** the exploration stipend (`INDEX_RATE_FACTOR`). A real compound beats a hypothesis, but stays far below a tuned template.
- The first harvest of each entry records it (`index_found`) and pays 30 coins for a molecule, or 45 for a crystal (+15 if experimentally observed). A "化学索引新收录" banner shows.
- Save v25 adds `index_found` (validated: ≤ 4096 strings ≤ 40 chars). Loading a v24 save settles what the reactors already hold, without a windfall.

## 4 · UI
- Codex → "化学索引 · 真实数据库" opens the browser.
  - Tabs: 分子 / 晶体.
  - Element chips (an entry must contain every chosen element), plus 只看已收录.
  - 16 cards per page, with a pager. Found cards are gold.
  - Tabs, chips and pages refill the same dialog, so the first-time tour keeps its targets.
- An entry page has:
  - a slowly turning 3D preview (`chem_index_view.gd`): the PubChem conformer with bond orders drawn, or the MP unit cell with gold cell edges, where atoms on faces, edges and corners are repeated like a textbook cell
  - the property rows; a missing value reads "未测"
  - how to make it in this game
  - a source line (the MP id with the database version and licence, or the PubChem CID)
- 数据来源与致谢: both databases, their licences, citations and what was changed. It is reachable from the browser, the entry pages and 怎么玩？.
- The reactor sidebar shows an index line with a "查看真实数据" link. The codex entry of a template links to its index entry.
- The structure workshop's reference text shows the live index result while you build.
- A new tour, `index` (4 steps), covers the databases, element filter, cards and sources.
- Help gains "07 化学索引".

## Tests
- `tests/test_chem_index.gd` (35 checks) covers:
  - data filters and provenance for every entry
  - composition keys and template identification
  - the substitution finds and the honest misses (NH₄, H–H–O, art mode)
  - either Kekulé benzene
  - economy, rewards, and the save v25 round trip with v24 settlement
- `tests/test_chem_index_ui.gd` (23 checks) covers:
  - the codex link, tabs, filters, pages and found-only view
  - entry previews (atom and bond counts), sources and credits
  - the sidebar link, the find banner, the tour and the workshop line
- Screenshot helper: `tests/capture_chem_index.gd`.

## Deferred
- A structure fingerprint for player-built periodic cells (RDF / coordination histogram), so that `composition` can become `prototype` for arbitrary cells.
- COD experimental CIFs.
- Future elements (Fe, Si, Ca, Sn, K, Mg, P): rerun the pipeline when they join `elements.json`.
- The v0.30 Fabricator will read gear stats from these properties (density, moduli, band gap).
