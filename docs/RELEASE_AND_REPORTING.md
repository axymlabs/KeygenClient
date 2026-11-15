# Releases and optional reporting

`pubspec.yaml` is the authority for `major.minor.patch+build`. Apple archives and exported packages preserve both values. Git tags use `vmajor.minor.patch`; mismatches fail before signing. Build numbers are never derived from GitHub run numbers.

Run `bash tool/prepare_release.sh patch` (or `minor`, `major`, `build`) from a clean working tree. Review the version commit, merge it into the repository default branch, tag that exact commit using the version shown, and push the tag. The Release workflow builds and signs iOS and macOS, retains packages and dSYMs, uploads to App Store Connect for TestFlight, then creates the matching GitHub Release. An upload does not submit the app for review or release it publicly. A manual Release run can build the current pubspec version without creating a release tag.

## GitHub Actions secrets

The five shared Apple certificate and App Store Connect secrets are AXYM Labs organisation secrets. Their visibility is restricted to RepoPermissionManager, KeygenClient, StarlinkMonitorApp and SnapVault. Repository copies have been removed. App-specific iOS/macOS profiles are also organisation secrets, named KEYGEN_CLIENT_IOS_BUILD_PROFILE_BASE64 and KEYGEN_CLIENT_MACOS_BUILD_PROFILE_BASE64, restricted to this repository. The shared certificate is a dedicated CI identity with matching profiles.


- APPLE_SIGNING_CERTIFICATE_BASE64: existing Apple Development identity exported as PKCS#12.
- APPLE_SIGNING_CERTIFICATE_PASSWORD: export password.
- IOS_BUILD_PROFILE_BASE64 / MACOS_BUILD_PROFILE_BASE64: matching development profiles where available. With no profile, automatic signing requests one using the existing API key.
- APP_STORE_CONNECT_PRIVATE_KEY / APP_STORE_CONNECT_KEY_ID / APP_STORE_CONNECT_ISSUER_ID: existing App Store Connect key, also used for automatic distribution export and upload.

Credentials are installed only in a temporary build keychain and removed in an always-run cleanup step. Cloud distribution export depends on the existing key's Apple permissions and account agreements; successful archival alone does not prove export or upload succeeded.

## Reporting

Firebase Crashlytics and Google Analytics are integrated on iOS, macOS and Android. Native collection starts disabled. Each user chooses crash reports and usage analytics separately, and can withdraw consent in Optional reporting. Debug/profile builds do not send reports. Other desktop platforms continue without Firebase reporting. Advertising consent is denied and advertising/IDFV collection disabled. Account data and app records are not deliberately attached to reports; Dart error messages are replaced with error types and stack traces.

A first real release-mode crash, followed by relaunch, is required to validate Crashlytics ingestion and symbolication. Use only a test installation and deliberately opt into reports before this check. Analytics ingestion also needs a running opted-in release build. Before App Store submission, update App Privacy disclosures for Diagnostics (crash/performance/other diagnostic data), Usage Data (product interaction), and installation identifiers as appropriate to the actual SDK data. Reports are for analytics/app functionality, not advertising or tracking. Existing published binaries are not changed by a source update.
