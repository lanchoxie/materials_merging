"""Validate design data only; does not certify physical models or modify the game."""
import json
import math
from collections import Counter
from pathlib import Path

BASE = Path(__file__).resolve().parent


def require(condition, message):
    if not condition:
        raise ValueError(message)


def read(name):
    data = json.loads((BASE / name).read_text(encoding="utf-8"))
    require(data["status"] == "design_only", f"{name}: design status missing")
    require(data["runtime_import_enabled"] is False, f"{name}: premature runtime import")
    return data


def indexed(rows):
    result = {row["id"]: row for row in rows}
    require(len(result) == len(rows), "Duplicate IDs")
    return result


def main():
    properties = read("property_seed.json")
    sources = indexed(properties["sources"])
    records = indexed(properties["records"])
    units = {"thermal_conductivity": "W/(m*K)", "density": "kg/m3",
             "electrical_resistivity": "ohm*m", "electrical_conductivity": "S/m",
             "lower_heating_value": "J/kg"}
    conversions = {"identity": (1, None), "multiply_1000": (1000, "g/mL"),
                   "multiply_1e-8": (1e-8, "microohm*cm"), "multiply_1e6": (1e6, "MJ/kg")}
    for record in records.values():
        tag = record["id"]
        source = sources[record["source_id"]]
        require(source["rights_status"] == "redistribution_review_required", f"{tag}: rights need review")
        require(source["locator"] and source["retrieved_on"], f"{tag}: missing provenance")
        require(record["uncertainty"] is None and record["uncertainty_note"], f"{tag}: uncertainty policy")
        require(record["scope"] and record["conditions"], f"{tag}: missing scope")
        actual = record["normalized"]["value"]
        require(math.isfinite(actual) and actual > 0, f"{tag}: invalid value")
        require(record["normalized"]["unit"] == units[record["property"]], f"{tag}: dimension mismatch")
        conversion = record["conversion"]
        if conversion == "reciprocal_normalized_record":
            parent = records[record["derived_from"]]
            require(parent["property"] == "electrical_resistivity", f"{tag}: incorrect reciprocal parent")
            require(parent["conditions"] == record["conditions"], f"{tag}: condition mismatch")
            require(parent["material_id"] == record["material_id"], f"{tag}: identity mismatch")
            expected = 1 / parent["normalized"]["value"]
        else:
            factor, original_unit = conversions[conversion]
            if original_unit:
                require(record["original"]["unit"] == original_unit, f"{tag}: original unit mismatch")
            else:
                require(record["original"]["unit"] == record["normalized"]["unit"], f"{tag}: identity conversion mismatch")
            expected = record["original"]["value"] * factor
        require(math.isclose(actual, expected, rel_tol=1e-10), f"{tag}: conversion should be {expected}, got {actual}")

    blueprints = read("recipe_blueprints.json")
    items = indexed(blueprints["items"])
    recipes = indexed(blueprints["recipes"])
    require("electricity" not in items and "useful_heat" not in items, "Energy services cannot be inventory items")
    for recipe in recipes.values():
        tag = recipe["id"]
        for field in ("inputs", "outputs", "waste", "flow_inputs", "flow_outputs"):
            registry = blueprints["flow_units"] if field.startswith("flow_") else items
            for key, count in recipe[field].items():
                require(key in registry, f"{tag}: unknown {field} ID {key}")
                require(isinstance(count, (int, float)) and math.isfinite(count) and count > 0,
                        f"{tag}: invalid count {key}")
        require(recipe["equipment"] and recipe["qualification"] and recipe["release_gate"], f"{tag}: missing gates")
        require(0 < recipe["seconds"] <= 45, f"{tag}: draft timing outside first-loop budget")
        for ref in recipe["evidence_refs"]:
            require(ref in records, f"{tag}: missing evidence {ref}")
        for item in recipe["waste"]:
            require(items[item]["kind"] == "waste", f"{tag}: waste not classified")

    # Check the explicitly defined toy loop, not arbitrary real chemistry.
    net_items = Counter()
    net_electricity = 0
    for key in ("electrolysis_demo_cycle", "fuel_cell_demo_cycle"):
        recipe = recipes[key]
        net_items.update(recipe["outputs"])
        net_items.subtract(recipe["inputs"])
        net_electricity += recipe["flow_outputs"].get("electricity", 0)
        net_electricity -= recipe["flow_inputs"].get("electricity", 0)
    require(all(value == 0 for value in net_items.values()), "Toy loop duplicates material kits")
    require(net_electricity < 0, "Toy loop creates free electricity")

    balance = read("balance_draft.json")
    worlds = balance["worlds"]
    require(worlds["slots"] == worlds["career_slots"] + worlds["experiment_slots"], "Slot mismatch")
    require(not worlds["experiment_export_to_career"], "Experiment inventory export must be disabled")
    require(not balance["transactions"]["snapshot_copies_global_wallet"], "World clone duplicates wallet")
    require(balance["transactions"]["reward_idempotent"], "Reward deduplication must be required")
    require(balance["water_tutorial"]["currency_reward_cap_coins"] == 0, "Tutorial reward must not form cash loop")
    print(f"PASS: {len(records)} sourced property records, {len(recipes)} recipe blueprints, "
          f"{len(items)} item IDs; conversions, references, toy energy loop and branch policies consistent.")
    print("Design validation only: no game integration, ecological calibration or real-device certification asserted.")


if __name__ == "__main__":
    main()
