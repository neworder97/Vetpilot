# Prepared iOS validation — NOT RUN

This audit environment is Linux and cannot run Xcode/iOS Simulator. GitHub write attempts failed before deployment. These files are a reproducible next-step plan, not evidence of a successful iPhone test.

On a Mac with Xcode, an available iOS Simulator runtime and XcodeGen, run `bash ValidationPrepared/run_ios_validation.sh` from the corrected source root. It creates its own disposable simulator, requires a checksum-matching real canine radiograph, adds it to Photos, and runs both scheme test targets. It captures xcresult and a final simulator screenshot. No diagnosis/result is mocked and no IPA is released.

`vetpilot-safety-validation.yml` is a manual-only workflow template kept OUTSIDE `.github/workflows` so it does not silently replace existing release workflows. The source UI-test updates are syntax checked only; selector compatibility and live network behavior remain to be established by the actual run. A missing real-radiograph fixture now fails rather than being counted as a skipped success.

Physical camera capture, signing/installing on an actual iPhone, and clinical diagnostic accuracy remain separate checks even after simulator success.
