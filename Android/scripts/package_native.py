#!/usr/bin/env python3
"""Package only transitive Swift/NDK dependencies, fail on any missing .so."""
import os,re,shutil,subprocess,json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
if os.environ.get('SWIFT_ANDROID_SDK'):
 sdk=Path(os.environ['SWIFT_ANDROID_SDK'])
else:
 candidates=[]
 for base in [Path.home()/'.swiftpm/swift-sdks',Path.home()/'.local/share/org.swift.swiftpm/swift-sdks']:
  for info in base.glob('*/info.json'):
   meta=json.loads(info.read_text())
   if 'swift-6.4.0-RELEASE_android' in meta.get('artifacts',{}):
    candidates.append(info.parent/'swift-android')
 candidates=list(dict.fromkeys(p.resolve() for p in candidates))
 if len(candidates)!=1:raise SystemExit(f'Set SWIFT_ANDROID_SDK to the installed Swift 6.4 Android SDK directory; found {candidates}')
 sdk=candidates[0]
print('Packaging Swift runtime from',sdk)
ndk=Path(os.environ['ANDROID_NDK_HOME'])/'toolchains/llvm/prebuilt/linux-x86_64'
for arch,abi in [('aarch64','arm64-v8a'),('x86_64','x86_64')]:
 lib=root/f'SwiftCore/.build/out/Products/Release-android-{arch}/libVetPilotCore.so'
 dest=root/'app/src/main/jniLibs'/abi;dest.mkdir(parents=True,exist_ok=True)
 sources={p.name:p for p in (sdk/f'swift-resources/usr/lib/swift-{arch}/android').glob('*.so')}
 sources['libc++_shared.so']=ndk/f'sysroot/usr/lib/{arch}-linux-android/libc++_shared.so'
 sources[lib.name]=lib
 queue=[lib.name];seen=set();system={'libc.so','libm.so','libdl.so','liblog.so','libandroid.so'}
 while queue:
  name=queue.pop()
  if name in seen or name in system:continue
  if name not in sources:raise SystemExit(f'Missing dependency: {name}')
  seen.add(name);src=sources[name];shutil.copy2(src,dest/name)
  dependencies=re.findall(r'Shared library: \[(.*?)\]',subprocess.check_output(['readelf','-d',str(src)],text=True))
  queue.extend(dependencies)
  subprocess.run([str(ndk/'bin/llvm-strip'),'--strip-unneeded',str(dest/name)],check=True)
 print(abi,len(seen),'native libraries',sum(p.stat().st_size for p in dest.glob('*.so')),'bytes')
