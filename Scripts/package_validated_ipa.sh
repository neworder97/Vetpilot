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
ditto -c -k --keepParent "$STAGING/Payload" ReleaseArtifacts/VetPilot-0.8.5-Signulous.ipa
python3 - <<'PYTHON'
from pathlib import Path
import hashlib,json,os,plistlib,zipfile
r=Path('ReleaseArtifacts');ipa=r/'VetPilot-0.8.5-Signulous.ipa'
with zipfile.ZipFile(ipa) as z:
    assert z.testzip() is None
    infofiles=[n for n in z.namelist() if n.startswith('Payload/') and n.count('/')==2 and n.endswith('.app/Info.plist')]
    assert len(infofiles)==1,infofiles
    info=plistlib.loads(z.read(infofiles[0]))
    assert info['CFBundleIdentifier']=='com.ferguson.vetpilot'
    assert info['CFBundleDisplayName']=='VetPilot'
    assert info['CFBundleName']=='VetPilot'
    assert info['CFBundleShortVersionString']=='0.8.5', ('version',info['CFBundleShortVersionString'])
    assert info['CFBundleVersion']=='18', ('build',info['CFBundleVersion'])
    assert 'iPhoneOS' in info['CFBundleSupportedPlatforms']
    assert 'fetch' in info.get('UIBackgroundModes', [])
    assert 'com.ferguson.vetpilot.collection-refresh' in info.get('BGTaskSchedulerPermittedIdentifiers', [])
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
 'gates':['independent numeric and rendered oracles','extracted-core Swift tests including PNA nutrition vectors','iOS unit and UI simulator tests','iphoneos Release compile','original bundle resource byte comparisons','arm64 and IPA structure'],
 'limitations':['Source comparison and regression checks do not establish clinical clearance for every patient, product or medication regimen.','Four ambiguous or unsupported presets remain blocked; source-limited entries require an individualized plan.','My Clinic replaces the X-ray tab. User-created/imported content requires clinical review; signed-in My Clinic collections sync across devices, while exported files are copies.','Labwork contains 42 selected entries (29 IDEXX and 13 MSU), not complete provider directories.','Physical iPhone microphone, call interruptions, on-device speech/translation language assets and clinical performance require device validation.','Email Auth and note storage target the configured Supabase project; confirmation email delivery and physical cross-device login need user verification. Scribe was replaced with a labeled cytology image library; no recording or transcription UI is offered.','Nutrition uses the PNA calculator method checked 2026-09-23, not a universal nutrition prescription. Unsupported low BCS and below-floor calorie results require an individualized plan.']}
(r/'VetPilot-release-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(manifest,indent=2))
PYTHON
