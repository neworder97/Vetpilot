#!/usr/bin/env python3
"""Dependency-free Android SDK build for the Java shell (Gradle is also supported)."""
import os,subprocess,shutil,zipfile,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1];sdk=Path(os.environ['ANDROID_HOME']);tools=sdk/'build-tools/35.0.0';android=sdk/'platforms/android-35/android.jar'
debug='--debug' in sys.argv;mode='debug' if debug else 'release';out=root/'app/build/manual'/mode
out.mkdir(parents=True,exist_ok=True)
def run(*args):subprocess.run(list(map(str,args)),check=True)
for name in ['classes','generated','assets']:
 p=out/name
 if p.exists():shutil.rmtree(p)
 p.mkdir()
shutil.copytree(root/'app/src/main/assets',out/'assets',dirs_exist_ok=True)
if debug:shutil.copytree(root/'app/src/debug/assets',out/'assets',dirs_exist_ok=True)
manifest=(root/'app/src/main/AndroidManifest.xml').read_text().replace('<manifest xmlns:android=', '<manifest package="com.vetpilot.android" android:versionCode="1" android:versionName="0.5.0-android.1" xmlns:android=')
manifest=manifest.replace('<application ',f'<uses-sdk android:minSdkVersion="26" android:targetSdkVersion="35"/><application android:debuggable="{str(debug).lower()}" ')
if debug:manifest=manifest.replace('</manifest>','<instrumentation android:name="com.vetpilot.android.AndroidTestRunner" android:targetPackage="com.vetpilot.android"/></manifest>')
(out/'AndroidManifest.xml').write_text(manifest)
run(tools/'aapt2','compile','--dir',root/'app/src/main/res','-o',out/'resources.zip')
run(tools/'aapt2','link','-o',out/'resources.apk','--manifest',out/'AndroidManifest.xml','-I',android,'--java',out/'generated','-A',out/'assets',out/'resources.zip')
(root/'app/src/main/java/com/vetpilot/android').mkdir(parents=True,exist_ok=True)
(out/'generated/BuildConfig.java').write_text('package com.vetpilot.android; public final class BuildConfig { public static final boolean DEBUG = '+str(debug).lower()+'; }')
sources=list((root/'app/src/main/java').rglob('*.java'))+list((out/'generated').rglob('*.java'))
if debug:sources+=list((root/'app/src/debug/java').rglob('*.java'))
run('javac','-source','17','-target','17','-cp',android,'-d',out/'classes',*sources)
run('jar','cf',out/'classes.jar','-C',out/'classes','.')
run(tools/'d8','--lib',android,'--min-api','26','--output',out/'dex.zip',out/'classes.jar')
shutil.copyfile(out/'resources.apk',out/'unsigned.apk')
with zipfile.ZipFile(out/'unsigned.apk','a') as apk:
 with zipfile.ZipFile(out/'dex.zip') as dex:
  for name in dex.namelist():apk.writestr(name,dex.read(name),compress_type=zipfile.ZIP_DEFLATED)
 for f in (root/'app/src/main/jniLibs').rglob('*.so'):apk.write(f,'lib/'+str(f.relative_to(root/'app/src/main/jniLibs')),compress_type=zipfile.ZIP_STORED)
run(tools/'zipalign','-P','16','-f','4',out/'unsigned.apk',out/'aligned.apk')
if debug:
 key=root/'app/build/debug.keystore'
 if not key.exists():run('keytool','-genkeypair','-keystore',key,'-storepass','android','-keypass','android','-alias','androiddebugkey','-dname','CN=Android Debug','-keyalg','RSA','-validity','10000')
 run(tools/'apksigner','sign','--ks',key,'--ks-pass','pass:android','--out',out/'VetPilot-debug.apk',out/'aligned.apk')
 print(out/'VetPilot-debug.apk')
else:print('Unsigned aligned release: '+str(out/'aligned.apk'))
