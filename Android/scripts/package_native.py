#!/usr/bin/env python3
"""Package only transitive Swift/NDK dependencies, fail on any missing .so."""
import os,re,shutil,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[1]
sdk=Path(os.environ.get('SWIFT_ANDROID_SDK',str(Path.home()/'.swiftpm/swift-sdks/swift-6.4.0-RELEASE_android.artifactbundle/swift-android')))
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
