#!/usr/bin/env python3
"""Use the website's Lucide stethoscope artwork for both existing logo slots.
The original illustration generator and preserved bundle remain unchanged.
"""
from pathlib import Path
import hashlib, struct
root = Path(__file__).resolve().parent.parent
source = root / 'FergusonVetPilot/Resources/VetPilotStethoscope.png'
data = source.read_bytes()
assert data[:8] == b'\x89PNG\r\n\x1a\n'
assert struct.unpack('>IIBB', data[16:26]) == (1024, 1024, 8, 2), 'Expected opaque 1024px RGB artwork'
assert hashlib.sha256(data).hexdigest() == '007e0329810472d0718ef0f02d2fdb5833eb9cd0bc7e118a6fec709217d5fea4', 'Website-logo artwork changed unexpectedly'
assets = root / 'FergusonVetPilot/Resources/Assets.xcassets'
for relative in ['AppIcon.appiconset/AppIcon-1024.png', 'ShepherdIcon.imageset/ShepherdIcon.png']:
    target = assets / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
print('Prepared the website stethoscope app icon and in-app logo.')
