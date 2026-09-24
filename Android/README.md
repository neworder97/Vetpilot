# VetPilot for Android

Android tablet/phone application sharing the iPhone production calculation engine.
Minimum Android 8.0 (API 26), 64-bit ARM or x86-64. Use an updated Android System
WebView. No network connection is required for calculations or clinic storage.

## Build

Requirements: matching Swift 6.4.0 host and official Android Swift SDK, Android NDK
r30 (`ANDROID_NDK_HOME`), JDK 17, Android SDK platform 35/build tools 35.0.0
(`ANDROID_HOME`), Python 3, Gradle 8.9 (optional for the dependency-free SDK build).

```sh
python3 Android/scripts/prepare_core.py
cd Android/SwiftCore
swift build -c release --product CoreCLI
swift build -c release --swift-sdk swift-6.4.0-RELEASE_android --triple aarch64-unknown-linux-android26 --product VetPilotCore
swift build -c release --swift-sdk swift-6.4.0-RELEASE_android --triple x86_64-unknown-linux-android26 --product VetPilotCore
cd ../..
python3 Android/scripts/package_native.py
python3 Android/scripts/build_apk.py
# Sign app/build/manual/release/aligned.apk with your private release key.
```

Alternatively, from Android/, run Gradle 8.9 `:app:assembleRelease`. Signing keys
and native build products are intentionally excluded from source control. Keep
the release signing key backed up privately: Android updates require the same key.

## Validation

`prepare_core.py` extracts unchanged calculation bodies from the iPhone source,
records source hashes and copies the shared clinical catalogs. Dose equations
are not reimplemented in JavaScript or Java. UI requests go through a UTF-8 JNI
bridge with strict input checks. The debug-only test runner compares every
medication/protocol against host Swift results, then exercises actual WebView
screens, invalid-input clearing, settings persistence, clinic import and PDF
pagination. Generate vectors with `python3 Android/scripts/parity_vectors.py`.
Build a debug APK, install in an emulator, then run:

```sh
adb shell am instrument -w com.vetpilot.android/.AndroidTestRunner
```

The existing independent numeric/display oracle is run separately with
`python3 ValidationArithmetic/run_local_audit.py`. Passing software tests does
not constitute clinical sign-off. Existing withheld protocols remain withheld.

## Offline storage and sharing

My Clinic, custom medications, dose overrides and recipient defaults are stored
atomically in app-private files. Uninstalling removes these files; export editable
`.vetpilot` files for backup. Package schema matches the iPhone app. Imports are
previewed and added as new copies. Export includes readable multipage PDF or
editable files via Android's share sheet, email/messaging apps, or Save to Files.
Accounts are configured in those apps, not in VetPilot. Some receiving apps ignore
recipient defaults; standard SMS cannot carry attachments. Actual delivery needs
a configured receiving application and connection. The app never sends silently.

Only local packaged assets can access the native bridge. No Internet permission,
file browsing permission or account credentials are requested. Export URIs grant
read access to individual cached exports; the provider rejects writes and traversal.
External references open in the user's browser.
