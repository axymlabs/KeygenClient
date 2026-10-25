# Keygen Client

A Flutter client for Keygen Cloud and self-hosted licensing servers, with iPhone, iPad, Mac and Android targets. Manage licences, policies, products, machines and users, and share licence files or QR codes.

An independent client; not affiliated with or endorsed by Keygen.

## Public source and community review

[This repository is intentionally public](https://github.com/axymlabs/KeygenClient). Keygen Client handles sensitive licensing operations, so users and contributors should be able to inspect how it authenticates, stores credentials, changes server resources and shares licence data. Code review, bug reports and pull requests from the community are welcome.

The security of a licensing system must come from server-enforced authentication and permissions, private credentials and private signing keys. It must not depend on keeping this client's implementation secret. Public source makes inspection possible; it does not establish that the app has received an independent security audit.

See [CONTRIBUTING.md](CONTRIBUTING.md) for development and review guidance, and [SECURITY.md](SECURITY.md) to report a vulnerability privately. Use fictional sample data in public issues, screenshots and test cases. Never publish live API tokens, passwords, customer records or private signing material.

The repository currently has no project-wide software licence. Public visibility should not be interpreted as an open-source licence or a grant of broader reuse rights. Dependency licences remain applicable to their respective components. See [GitHub's licensing guidance](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository).

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
