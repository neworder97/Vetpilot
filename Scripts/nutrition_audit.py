#!/usr/bin/env python3
import json
import math
import sys
from pathlib import Path

root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
errors = []
checks = []


def check(name, condition, detail=None):
    checks.append({"name": name, "pass": bool(condition), "detail": detail})
    if not condition:
        errors.append(name if detail is None else f"{name}: {detail}")


def rer(kg):
    return 70.0 * (kg ** 0.75)


def ideal_weight(current_kg, bcs):
    if not (current_kg > 0 and math.isfinite(current_kg) and 1 <= bcs <= 9):
        return None
    if bcs in (4, 5):
        return current_kg
    if bcs >= 6:
        return current_kg / (1.0 + 0.10 * (bcs - 5))
    return None


def estimate(species, current_kg, bcs):
    if not (current_kg > 0 and math.isfinite(current_kg) and 1 <= bcs <= 9):
        return None
    current_rer = rer(current_kg)
    if bcs >= 6:
        ideal = ideal_weight(current_kg, bcs)
        planning = rer(ideal)
        factor = 1.0 if species == "dog" else 0.8
        return {"goal": "lose", "ideal": ideal, "target": planning * factor,
                "low": planning * factor, "high": planning * factor}
    if bcs in (4, 5):
        low_factor, high_factor = ((1.4, 1.6) if species == "dog" else (1.2, 1.4))
        return {"goal": "maintain", "ideal": current_kg,
                "target": current_rer * ((low_factor + high_factor) / 2),
                "low": current_rer * low_factor, "high": current_rer * high_factor}
    low_factor, high_factor = ((1.6, 1.8) if species == "dog" else (1.4, 1.6))
    return {"goal": "gain", "ideal": None,
            "target": current_rer * ((low_factor + high_factor) / 2),
            "low": current_rer * low_factor, "high": current_rer * high_factor}


def close(a, b, tol=1e-9):
    return math.isclose(a, b, rel_tol=tol, abs_tol=tol)


check("RER 10 kg", close(rer(10), 393.6389276, 1e-9), rer(10))

dog_loss = estimate("dog", 30, 7)
check("dog BCS7 goal", dog_loss["goal"] == "lose", dog_loss)
check("dog BCS7 ideal 25kg", close(dog_loss["ideal"], 25), dog_loss)
check("dog loss = 1.0x ideal RER", close(dog_loss["target"], rer(25)), dog_loss)

cat_loss = estimate("cat", 6, 7)
check("cat BCS7 goal", cat_loss["goal"] == "lose", cat_loss)
check("cat BCS7 ideal 5kg", close(cat_loss["ideal"], 5), cat_loss)
check("cat loss = 0.8x ideal RER", close(cat_loss["target"], rer(5) * 0.8), cat_loss)

for species in ("dog", "cat"):
    for bcs in (4, 5):
        result = estimate(species, 8, bcs)
        check(f"{species} BCS{bcs} ideal category", result["goal"] == "maintain", result)
        check(f"{species} BCS{bcs} keeps current ideal weight", close(result["ideal"], 8), result)

under_dog = estimate("dog", 10, 3)
check("dog underweight does not infer ideal weight", under_dog["ideal"] is None, under_dog)
check("dog gain range 1.6-1.8x current RER",
      close(under_dog["low"], rer(10) * 1.6) and close(under_dog["high"], rer(10) * 1.8), under_dog)

under_cat = estimate("cat", 3.2, 3)
check("cat underweight does not infer ideal weight", under_cat["ideal"] is None, under_cat)
check("cat gain range 1.4-1.6x current RER",
      close(under_cat["low"], rer(3.2) * 1.4) and close(under_cat["high"], rer(3.2) * 1.6), under_cat)

for species in ("dog", "cat"):
    for bcs in range(1, 10):
        result = estimate(species, 8, bcs)
        check(f"finite positive {species} BCS{bcs}",
              result is not None and result["target"] > 0 and math.isfinite(result["target"]) and (result["ideal"] is None or result["ideal"] > 0), result)

required_files = [
    root / "FergusonVetPilot" / "NutritionMath.swift",
    root / "FergusonVetPilot" / "NutritionView.swift",
    root / "FergusonVetPilot" / "ContentView.swift",
    root / "FergusonVetPilotTests" / "NutritionMathTests.swift",
]
for path in required_files:
    check(f"file exists: {path.relative_to(root)}", path.exists())

if all(path.exists() for path in required_files):
    content_view = (root / "FergusonVetPilot" / "ContentView.swift").read_text()
    nutrition_view = (root / "FergusonVetPilot" / "NutritionView.swift").read_text()
    nutrition_math = (root / "FergusonVetPilot" / "NutritionMath.swift").read_text()
    check("Nutrition tab wired", "NutritionView()" in content_view and 'Label("Nutrition"' in content_view)
    check("Dog/Cat species selector present", "ForEach(Species.allCases)" in nutrition_view)
    check("1-9 BCS selector present", "ForEach(1...9" in nutrition_view)
    check("dog weight-loss factor source present", "species == .dog ? 1.0 : 0.8" in nutrition_math)
    check("dog/cat gain ranges differ", "(1.6, 1.8)" in nutrition_math and "(1.4, 1.6)" in nutrition_math)

report = {
    "status": "PASS" if not errors else "FAIL",
    "errors": errors,
    "checks_run": len(checks),
    "critical_examples": {
        "dog_30kg_bcs7": dog_loss,
        "cat_6kg_bcs7": cat_loss,
        "dog_10kg_bcs3": under_dog,
        "cat_3_2kg_bcs3": under_cat,
    },
}
print(json.dumps(report, indent=2, sort_keys=True))
sys.exit(1 if errors else 0)
