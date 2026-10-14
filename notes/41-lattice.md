# 41 · v0.52.0 "Lattice" (晶格工作台): cell parameters, periodic sites, and a phase for anything

The user's words: *"我们在构建一些复杂晶体的时候需要可以知道一些晶格参数，然后显示周期性位点，包括原子是否
放置在周期性边界条件上这种选项，否则构建晶格原子有些困难"*, and *"有些气液固还是没展示出来"*.

## What was missing
The sandbox editor had a cell — three lengths and a "显示 2×2×2 重复" preview — but:

- **no angles**, so only orthogonal cells could be expressed;
- **no fractional coordinates**: positions were absolute Å only, so "is this atom on the face?"
  could not be answered from the UI;
- **PBC was cosmetic**: `periodic` never wrapped an atom, and dragging outside the cell just left it
  outside with the cell lines sitting there;
- the two crystal baselines (钙钛矿, 钙钛矿氯化物) had **`fixed_display_cell: true`, which no script
  read** — so they opened as a blob of atoms with no cell at all;
- **phases**: the sourced table covers 17 compounds. Anything the player built showed 未鉴定, and
  `_build_phase_contents` returned immediately, so the chamber was empty for every custom structure.

## 1. The cell, properly (`structure_sandbox.gd`)
- **`cell_angles` [α, β, γ]**, validated 30–150°, defaulting to 90/90/90 so every existing structure,
  save and preset is unchanged.
- **`lattice(cell, angles)`** builds the standard basis (a along x, b in the xy plane). One matrix
  serves the drawing, the readout and the snap rule, so they can never disagree.
- **The convention is the one the presets already used: the cell is centred on the origin.** A corner
  atom at (a/2, b/2, c/2) is fractional (1,1,1) ≡ (0,0,0), and the body centre is (½,½,½). The first
  implementation assumed the cell started at 0 and put every perovskite site in the wrong class.
- `fractional()` / `cartesian()` convert both ways, wrapping into [0,1).
- **`site(frac)`** classifies a position: 角点 (equivalent to ⅛ of an atom), 棱心 (¼), 面心 (½), 胞内
  (1). That is the "is the atom on the periodic boundary?" answer, with the multiplicity it implies.
- **`snap_to_cell()`** pulls an atom within ~0.4 Å of the boundary onto it, and wraps anything
  further out back inside the cell — no more atoms silently living outside their own lattice.
- **Crystal baselines open as crystals**: `from_baseline` now carries `cell`, `occupancies` and
  `periodic` when the baseline declares a cell, and both perovskite baselines carry their 6.3 Å /
  6.0 Å cells and their 15 site occupancies.

## 2. The workbench UI (`sandbox_editor.gd`)
- **a/b/c and α/β/γ spin boxes** under 晶胞与重复, and a live **lattice readout**:
  `a=6.300 b=6.300 c=6.300 Å α=90° β=90° γ=90° V=250.0 Å³` (volume from the matrix determinant).
- A **site readout** for the selected atom: its **fractional coordinates**, whether it is on the cell
  or inside it, its site class, and how many atoms that site stands for —
  `分数坐标 (0.000, 0.500, 0.500)　在晶胞上：面心 · 等效原子 0.500 个`.
- **吸附到晶胞边界（周期位点）**: a toggle read by both dragging and the ±0.10 nudge buttons.
- The cell is **drawn from the matrix**, so a non-orthogonal cell is drawn as the parallelepiped it
  actually is (the old corner-bit shortcut could only draw a box).
- The readout line also names the **phase** of the build, so authoring and the reactor agree.

## 3. A phase for anything (`reactor_look.gd`)
- `estimate(work, reference_id)` answers for every structure:
  - a **known** compound uses its sourced phase and is marked exact;
  - a **periodic / lattice** build reads **固态 · 晶格（按你的晶胞推测，非实测）**;
  - a molecule with any metal reads solid; ≤6 atoms gas; 7–12 liquid; more solid —
    every one of them carrying the word **推测** and its reason.
- `reactor_views()` / `reactor_phase()` now use it, so the chamber is never empty and the badge
  (`main.gd`) shows the real sentence in its tooltip. The sourced 17 entries are untouched: this is
  a fallback for the player's own work, never presented as measured data.

## A bug this uncovered
The angle helper originally wrote `cell_angles` into the draft the first time it was read — and
`_rebuild` reads it for all three spin boxes every time the editor opens. So opening a structure the
player never touched made `draft != original` true, and closing it raised the "还有尚未保存的修改"
dialog instead of closing. For a reactor that means you could not leave the sandbox back to
production. `test_organic15_ui` caught it (it asserts that backing out of the editor returns to the
same first-person view); the helper is now a pure read.

## Verification
- **`tests/test_lattice.gd`** (33 checks):
  - a crystal baseline opens periodic with its cell and occupancies; a molecule baseline stays one;
  - a is along x; 90/90/90 gives volume abc; a hexagonal γ=60° cell gives a²c·sin60° with a tilted b;
  - fractional ↔ Cartesian round-trips; the perovskite corner / body / face / edge atoms classify as
    角点 ⅛ / 胞内 1 / 面心 ½ / 棱心 ¼;
  - wrapping keeps coordinates in [0,1); snapping lands an off-face atom on the face and leaves an
    interior atom alone; a whole cell outside wraps back inside;
  - impossible angles and lengths are rejected; a structure saved before angles existed still
    validates and defaults to 90/90/90;
  - phases: a periodic build is solid-by-estimate, water stays sourced liquid, a 3-atom unlisted
    molecule is gas, a metal-bearing molecule is solid, a 15-atom molecule is solid, empty is nothing.
- **`tests/capture_lattice.gd`:** the workbench in `docs/screenshots/v0.52.0/`.
- Full suite re-run for the release.

## Next (same request)
- Bronze (tech diffusion) and Clash (wars — abstract while you are away, real when you are there).
