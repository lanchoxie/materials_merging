"""v0.30 Fabricator: build data/fabricator.json (rules, reference hardness, Shockley–Queisser table).

Run: python dev/fabricator/build_rules.py
Everything numeric that is science comes with its source; values marked "game" are balance choices.
"""
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "data" / "fabricator.json"

# Detailed balance (Shockley & Queisser 1961): blackbody sun, unconcentrated, cell at 300 K, one junction,
# every photon above the gap absorbed and each gives one electron; only radiative recombination.
K_B = 8.617333262e-5          # eV/K
T_SUN = 5778.0                # K, effective temperature of the Sun
T_CELL = 300.0                # K
F_SUN = (6.957e8 / 1.495978707e11) ** 2   # (solar radius / 1 au)^2, the solid-angle factor


def _integral(power, lower, kt, mu=0.0, upper=12.0, steps=6000):
    """Simpson integral of E^power / (exp((E - mu)/kT) - 1) from `lower` to `upper` (eV)."""
    if lower >= upper:
        return 0.0
    h = (upper - lower) / steps
    total = 0.0
    for i in range(steps + 1):
        e = lower + i * h
        x = (e - mu) / kt
        f = e ** power / math.expm1(x) if x < 700 else 0.0
        total += f * (1 if i in (0, steps) else (4 if i % 2 else 2))
    return total * h / 3.0


def sq_efficiency(gap):
    kt_s, kt_c = K_B * T_SUN, K_B * T_CELL
    incident = F_SUN * _integral(3, 1e-6, kt_s, upper=30.0, steps=30000)
    absorbed = F_SUN * _integral(2, gap, kt_s)
    dark = _integral(2, gap, kt_c, upper=gap + 40 * kt_c, steps=4000)  # cell emission at V = 0
    best = 0.0
    v = 0.0
    while v < gap:
        current = absorbed - dark * math.expm1(v / kt_c)
        if current <= 0:
            break
        best = max(best, current * v)
        v += 0.0005
    return best / incident


def main():
    table = [[round(g, 2), round(sq_efficiency(g), 4)] for g in [x / 20 for x in range(4, 81)]]
    peak = max(table, key=lambda r: r[1])
    rules = {
        "version": 1,
        "note": "v0.30 制造台. Science inputs are sourced below; costs, caps, gains and the starter pick are game values (marked).",
        "sources": [
            {"id": "chen2011", "name": "Chen, Niu, Li & Li, Modeling hardness of polycrystalline materials and bulk metallic glasses, Intermetallics 19, 1275–1281 (2011)", "url": "https://doi.org/10.1016/j.intermet.2011.03.026", "scope": "Hv = 2(k²G)^0.585 − 3，k = G/B（Pugh 比）；对低 k 的金属和离子盐偏差大"},
            {"id": "pugh1954", "name": "Pugh, Relations between the elastic moduli and the plastic properties of polycrystalline pure metals, Phil. Mag. 45, 823–843 (1954)", "url": "https://doi.org/10.1080/14786440808520496", "scope": "B/G > 1.75 偏韧，< 1.75 偏脆（经验判据）"},
            {"id": "broz2006", "name": "Broz, Cook & Whitney, Microhardness, toughness, and modulus of Mohs scale minerals, American Mineralogist 91, 135–142 (2006), Table 3", "url": "https://doi.org/10.2138/am.2006.1844", "scope": "莫氏 1–9 标准矿物的维氏显微硬度（GPa）"},
            {"id": "sq1961", "name": "Shockley & Queisser, Detailed Balance Limit of Efficiency of p‐n Junction Solar Cells, J. Appl. Phys. 32, 510–519 (1961)", "url": "https://doi.org/10.1063/1.1736034", "scope": "细致平衡效率上限；这里用 5778 K 黑体太阳、无聚光、电池 300 K 数值计算（dev/fabricator/build_rules.py）"},
            {"id": "mp", "name": "Materials Project (Jain et al. 2013) — elastic moduli (VRH) and band gaps (PBE/GGA)", "url": "https://doi.org/10.1063/1.4812323", "scope": "体模量、剪切模量、带隙；GGA 带隙通常低估"},
            {"id": "mindat", "name": "mindat.org — Mohs hardness of the rock-forming minerals", "url": "https://www.mindat.org/", "scope": "花岗岩、玄武岩按主要造岩矿物取值"},
        ],
        # Broz et al. 2006, Table 3, Vickers microhardness (GPa) of the Mohs minerals 1–9.
        "mohs_reference": [
            [1, "滑石", 0.14], [2, "石膏", 0.61], [3, "方解石", 1.49], [4, "萤石", 2.00], [5, "磷灰石", 5.43],
            [6, "正长石", 6.87], [7, "石英", 12.2], [8, "黄玉", 17.6], [9, "刚玉", 19.6],
        ],
        # Rocks that are mixtures get the Mohs value of their main minerals (mindat); loose material ignores hardness.
        "rock_mohs": {
            "granite": {"mohs": 6.5, "why": "长石 6 与石英 7 组成"},
            "basalt": {"mohs": 6.0, "why": "斜长石 6–6.5 与辉石 5.5–6 组成"},
            "coal": {"mohs": 2.5, "why": "烟煤约 2–3"},
        },
        "loose": ["topsoil", "sand", "clay"],
        "starter_pick": {"name": "起步镐", "hv": 5.43, "note": "游戏设定：硬度取莫氏 5 标准矿物磷灰石（5.43 GPa），大约是一把钢刀"},
        "pick": {
            "units": 3, "coins": 60,                      # game
            "max_slowdown": 3.0,                          # game: a pick softer than the rock needs up to 3× the hits
            "no_alkali": ["Li", "Na", "Cs"],
            "no_anions": ["F", "Cl", "Br", "H"],
            "min_pugh_k": 0.4,                            # Chen et al. 2011: the model fails for low-k metallic crystals
        },
        "panel": {
            "units": 4, "coins": 80,                      # game
            "slots": 3,                                   # game
            "speed_gain": 2.0,                            # game: refinery speed +2 × efficiency per installed panel
        },
        "max_items": 24,                                  # game
        "sq_model": {"t_sun_k": T_SUN, "t_cell_k": T_CELL, "concentration": 1, "peak_gap_ev": peak[0], "peak_efficiency": peak[1]},
        "sq_table": table,
    }
    OUT.write_text(json.dumps(rules, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)}: SQ peak {peak[1]*100:.1f}% at {peak[0]} eV; 1.1 eV {dict(map(tuple, table))[1.1]*100:.1f}%")


if __name__ == "__main__":
    main()
