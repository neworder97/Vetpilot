#!/usr/bin/env python3
"""Rebuild the saved arithmetic audit. Requires Python 3 and Swift; NOT iOS emulation."""
from pathlib import Path
import json,shutil,subprocess,sys,tempfile
r=Path(__file__).resolve().parent
if not shutil.which("swiftc") or not shutil.which("swift"):
    raise SystemExit("Swift toolchain required")
# Always test current checked-out production source, never a frozen candidate.
for name in ["candidate_harness", "harness", "swiftpm/Sources/FergusonVetPilot"]:
    (r/name).mkdir(parents=True,exist_ok=True)
shutil.copytree(r.parent/"FergusonVetPilot",r/"candidate/FergusonVetPilot",dirs_exist_ok=True)
def run(args,**kw):subprocess.run(args,cwd=r,check=True,**kw)
run([sys.executable,"prepare_harness.py"])
run([sys.executable,"build_candidate_probes.py"])
for version,folder in [("baseline","harness"),("candidate","candidate_harness")]:
    with tempfile.TemporaryDirectory() as temp:
        t=Path(temp);shutil.copy2(r/"harness/matrix-main.saved",t/"main.swift")
        names=["ClinicalData.swift","ProtocolCore.swift","AdministrationMath.swift","BuiltInProtocolCatalog.swift","NutritionMath.swift"]
        if version=="candidate":names.append("MedicationSafety.swift")
        run(["swiftc","-O",*[str(r/folder/n) for n in names],str(t/"main.swift"),"-o",str(t/"matrix")])
        with (r/(version+"-engine-results.json")).open("w") as output:
            run([str(t/"matrix")],stdout=output)
run([sys.executable,"check_oracle.py"])
run([sys.executable,"check_candidate_oracle.py"])
run([sys.executable,"check_rendered_oracle.py"])
for p in (r/"candidate_harness").glob("*.swift"):
    if p.name!="main.swift":shutil.copy2(p,r/"swiftpm/Sources/FergusonVetPilot"/p.name)
(r/"evidence").mkdir(exist_ok=True)
with (r/"evidence/candidate-swift-tests.log").open("w") as log:
    test_result = subprocess.run(["swift","test","-c","release","--jobs","1"],cwd=r/"swiftpm",stdout=log,stderr=subprocess.STDOUT)
if test_result.returncode:
    print((r/"evidence/candidate-swift-tests.log").read_text(), flush=True)
    raise SystemExit(test_result.returncode)
checks=json.loads((r/"candidate-independent-numeric-audit.json").read_text())
for field in ["numeric_mismatches","rounding_boundary_mismatches","nonzero_volumes_displayed_as_zero","amount_display_errors_over_5_percent"]:
    if checks[field]:raise SystemExit(f"Candidate audit failed: {field}")
if json.loads((r/"candidate-rendered-oracle.json").read_text())["failure_count"]:
    raise SystemExit("Candidate rendered-output audit failed")
print("Scoped local audit passed. Clinical validity and actual iOS end-to-end testing remain separate and unverified.")

