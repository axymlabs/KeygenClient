# Apple release handoff

The Mac app requires **macOS 14 Sonoma or later**, matching the current Xcode recommendation. Hardened runtime is enabled for all configurations.

The app is prepared locally as **Keygen Client 1.0.0 (1)**. `pubspec.yaml` is the single version source: `version: marketing.version.number+build`. Export options disable automatic version/build renumbering so packaging preserves these values. The installed version displayed in the app comes from the native package, including any Flutter build overrides. Native app and test targets use Flutter's build variables. Use a monotonically increasing build number for every upload, across versions for the Mac app.

## Prepared artifacts

- iOS App Store IPA: `build/ios/ipa/Keygen Client.ipa`
- macOS App Store installer: `build/macos/store/Keygen Client.pkg`
- iOS archive: `build/ios/archive/Runner.xcarchive`
- macOS archive: `build/macos/archive/Keygen Client.xcarchive` (prepared archive; exporter applies distribution signing)

Both packages were exported locally using team `27K26BJN5H`, identifier `com.axymlabs.keygenapp` and version `1.0.0 (1)`. Neither has been uploaded. The public Keygen Client privacy/support sections on axym.dev still need publication. Store metadata, screenshots and physical-device testing also remain before submission.

## Required publisher configuration

1. The configured bundle ID is `com.axymlabs.keygenapp` (with `.RunnerTests` for test targets) in `ios/Runner.xcodeproj/project.pbxproj`, `macos/Runner/Configs/AppInfo.xcconfig` and the Mac test targets. Register these identifiers under your Apple Developer account; do not change a previously uploaded app's identity. iOS and macOS can share the bundle identifier for a universal purchase when configured in App Store Connect.
2. Confirm team `27K26BJN5H` is the intended paid Apple Developer team. The Mac project now inherits the same team as iOS. Choose the correct team and automatic signing in Xcode for both apps; enable Keychain Sharing as required by the secure-storage plugin. Confirm distribution certificates and profiles are available.
3. The publisher copyright is Axym Labs in `macos/Runner/Configs/AppInfo.xcconfig`.
4. Publish [the prepared privacy/support section](privacy-policy-draft.md) on `https://axym.dev/apps`, using anchors `keygen-client-privacy` and `keygen-client-support`. The app defaults and local `release.json` use these destinations:

   ```json
   {
     "PRIVACY_POLICY_URL": "https://axym.dev/apps#keygen-client-privacy",
     "SUPPORT_URL": "https://axym.dev/apps#keygen-client-support"
   }
   ```

   Pass that file as `--dart-define-from-file=release.json` to every store build. Both links appear in About & privacy, available before login and under More. `release.json` is ignored by version control.

5. Run `python3 tool/check_release.py --strict --config release.json`. This fails if placeholder IDs or missing/invalid URL configuration are introduced. The destination content must be published and checked separately. It validates metadata; it does not verify Apple account membership, website availability, certificates or App Store Connect state.

## Validation and build

```sh
flutter pub get
flutter analyze
flutter test
python3 tool/check_release.py
flutter build ipa --release --dart-define-from-file=release.json --export-options-plist=ios/ExportOptions.plist
python3 tool/check_release.py --strict --config release.json --bundle build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app
flutter build macos --release --config-only --dart-define-from-file=release.json
xcodebuild -workspace macos/Runner.xcworkspace -scheme Runner -configuration Release -archivePath "build/macos/archive/Keygen Client.xcarchive" CODE_SIGNING_ALLOWED=NO archive
python3 tool/check_release.py --strict --config release.json --bundle "build/macos/archive/Keygen Client.xcarchive/Products/Applications/Keygen Client.app"
python3 tool/prepare_macos_archive.py "build/macos/archive/Keygen Client.xcarchive"
xcodebuild -exportArchive -archivePath "build/macos/archive/Keygen Client.xcarchive" -exportPath build/macos/store -exportOptionsPlist macos/ExportOptions.plist -allowProvisioningUpdates
```

Open `ios/Runner.xcworkspace` and `macos/Runner.xcworkspace` for signing and distribution. The Mac commands archive without development signing, normalize app/framework signing identifiers, then let Xcode apply App Store distribution signing during export. The normalization prevents Xcode from preserving a linker-generated framework requirement whose identifier differs from its Info.plist identifier. Verify exported app signatures with `codesign --verify --deep --strict` before distribution. This avoids requiring a registered development Mac just to package a store release. A normal signed development build still requires a Mac development provisioning profile. Validate the exported packages in Xcode/Transporter before submission. These commands prepare builds; nothing in this repository uploads or submits automatically. CI artifacts are unsigned validation builds and are not store-ready packages.

To regenerate the icon catalogs and launch artwork on macOS, run `swift tool/generate_brand.swift`.

## App Store Connect and device testing

Use [the prepared store copy](app-store-copy.md). Create the app records with the registered identifiers, add public privacy and support URLs, upload genuine screenshots with demo data, and provide a dedicated reviewer account and reachable test server. Complete privacy, age-rating, export-compliance, pricing and availability questions. The app uses HTTPS and requests server-signed licence files; the publisher must confirm the applicable encryption answers. No export exemption is asserted in Info.plist.

The app's privacy manifests declare access to app-private preferences (CA92.1). SDK manifests remain bundled by their native integrations. A manifest is separate from App Store privacy disclosures: assess what the publisher and service operators actually collect, including account data and server logs. Do not automatically select “Data Not Collected.”

Before submission, verify real sign-in/token login, Keychain persistence and removal across restarts, sign-out and forgetting a connection, server-error handling, resource create/edit/delete permissions, QR/file sharing on iPhone/iPad/Mac, light/dark mode, VoiceOver and enlarged text. Use an HTTPS server. HTTP self-hosted servers may be blocked by Apple's transport security; arbitrary network exceptions have not been enabled. Local-network servers also need device testing and a suitable local-network usage description if that deployment is supported.

The client uses an original key emblem. Confirm permission to use the Keygen name/service and keep the independent-client disclosure accurate.

## Official references

- [Flutter iOS distribution](https://docs.flutter.dev/deployment/ios)
- [Flutter macOS distribution](https://docs.flutter.dev/deployment/macos)
- [Apple submission requirements](https://developer.apple.com/app-store/submitting/)
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple version and build numbers](https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution)
