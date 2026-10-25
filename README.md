# Keygen Client

A Flutter client for Keygen Cloud and self-hosted licensing servers, with iPhone, iPad, Mac and Android targets. Manage licences, policies, products, machines and users, and share licence files or QR codes.

An independent client; not affiliated with or endorsed by Keygen.

## Development

```sh
flutter pub get
flutter run -d macos
flutter analyze
flutter test
python3 tool/check_release.py
```

The brand uses a mint key emblem over deep navy, with matching light and dark themes. Regenerate all platform icons with `swift tool/generate_brand.swift` on macOS.

The app version comes from `pubspec.yaml`; About reads the installed package's marketing version and build number. Tokens use secure storage, and passwords are never saved. A correctly signed app and working Keychain are required to remember an access token.

See the [Apple release handoff](docs/release/README.md) for signing, public privacy/support links, store copy, validation commands and remaining submission requirements.

## Release marketing

Edit [app-store/content.json](app-store/content.json), then run `python3 tool/app_store/generate.py` on macOS to build the screenshot, video and store-copy kit. Publishing a matching GitHub Release regenerates and attaches the assets automatically. See [app-store/README.md](app-store/README.md).
