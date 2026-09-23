#!/bin/bash
set -euo pipefail
APP=$(find .build/Build/Products/Release-iphoneos -maxdepth 1 -name '*.app' -print -quit)
test -n "$APP"
EXECUTABLE=$(/usr/libexec/PlistBuddy -c 'Print CFBundleExecutable' "$APP/Info.plist")
lipo "$APP/$EXECUTABLE" -verify_arch arm64
for F in PreservedOriginalBundleResources/*; do cmp "$F" "$APP/$(basename "$F")"; done
mkdir -p ReleaseArtifacts
STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT
mkdir "$STAGING/Payload"
ditto "$APP" "$STAGING/Payload/$(basename "$APP")"
ditto -c -k --keepParent "$STAGING/Payload" ReleaseArtifacts/VetPilot-0.4.0-Signulous.ipa
python3 - <<'PYTHON'
from pathlib import Path
import hashlib,json,os,plistlib,zipfile
r=Path('ReleaseArtifacts');ipa=r/'VetPilot-0.4.0-Signulous.ipa'
with zipfile.ZipFile(ipa) as z:
    assert z.testzip() is None
    infofiles=[n for n in z.namelist() if n.startswith('Payload/') and n.count('/')==2 and n.endswith('.app/Info.plist')]
    assert len(infofiles)==1,infofiles
    info=plistlib.loads(z.read(infofiles[0]))
    assert info['CFBundleIdentifier']=='com.ferguson.vetpilot'
    assert info['CFBundleShortVersionString']=='0.4.0', ('version',info['CFBundleShortVersionString'])
    assert info['CFBundleVersion']=='4', ('build',info['CFBundleVersion'])
    assert 'iPhoneOS' in info['CFBundleSupportedPlatforms']
    assert z.getinfo(infofiles[0].rsplit('/',1)[0]+'/'+info['CFBundleExecutable']).file_size>0
numeric=json.loads(Path('ValidationArithmetic/candidate-independent-numeric-audit.json').read_text())
rendered=json.loads(Path('ValidationArithmetic/candidate-rendered-oracle.json').read_text())
for key in ['numeric_mismatches','rounding_boundary_mismatches','nonzero_volumes_displayed_as_zero','amount_display_errors_over_5_percent']:
    assert not numeric[key],key
assert not rendered['failure_count']
manifest={'source_commit':os.environ['GITHUB_SHA'],'workflow_run':os.environ['GITHUB_RUN_ID'],
 'version':info['CFBundleShortVersionString'],'build':info['CFBundleVersion'],
 'bundle_identifier':info['CFBundleIdentifier'],'ipa':ipa.name,
 'sha256':hashlib.sha256(ipa.read_bytes()).hexdigest(),
 'signing':'Unsigned device build; Signulous or another authorized signing service is required before installation.',
 'gates':['independent numeric and rendered oracles','extracted-core Swift tests','iOS unit and UI simulator tests','iphoneos Release compile','original bundle resource byte comparisons','arm64 and IPA structure'],
 'limitations':['Source comparison and regression checks do not establish clinical clearance for every patient, product or medication regimen.','Four ambiguous or unsupported presets remain blocked; source-limited entries require an individualized plan.','X-ray high/low confidence is exploratory and uncalibrated.','Labwork contains 28 selected entries, not complete provider directories.','Physical iPhone installation, camera capture and clinical performance have not been tested.']}
(r/'VetPilot-release-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(manifest,indent=2))
PYTHON
