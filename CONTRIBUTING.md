# Contributing to Keygen Client

This is an intentionally public project maintained by Axym Labs. Community contributions and independent code review are welcome, especially around the sensitive licensing operations the app performs. We want users to be able to understand and question what runs on their devices.

## Start a contribution

For a bug, describe the app version, platform, expected behaviour and steps to reproduce. For a substantial feature or change to authentication, storage or server mutations, open an issue to discuss the approach before implementing it. Report security vulnerabilities through the private channel in [SECURITY.md](SECURITY.md).

Fork the repository, create a focused branch and submit a pull request. Explain the problem, resulting behaviour and how you verified it. Include relevant tests for behaviour changes and screenshots for visual changes. Maintainers review contributions before merging; a pull request does not grant access to release credentials or production licensing systems.

## Develop with sample data

```sh
flutter pub get
flutter analyze
flutter test
python3 tool/check_release.py
python3 -m unittest discover -s tool/app_store -p 'test_*.py'
```

Choose **Explore with sample data** in the app to use the fictional in-memory workspace. Use mock HTTP clients or a server/account you control for integration tests. Use disposable resources for tests that create, edit, suspend, renew or delete licences. Never test destructive operations against someone else's server or customer data.

See the [Apple release handoff](docs/release/README.md) for native build requirements and the [marketing kit documentation](app-store/README.md) for generating screenshots and videos. Signing a native development build requires your own suitable Apple development setup; do not request or share a maintainer's signing identity.

## Review sensitive behaviour

- Preserve server-side permission checks. UI restrictions are not an authorization boundary, and a client change must not be presented as granting permissions the server has not issued.
- Keep passwords and tokens out of source files, logs, error reports, screenshots and fixtures. Access tokens belong in secure device storage, with no plaintext preference fallback.
- Make server mutations explicit and keep confirmations for destructive actions. Describe any changes to the requests or privileges an action requires.
- Use a trusted HTTPS endpoint for live credentials. Do not add broad transport-security exceptions or bypass certificate validation to make a test pass.
- Review the contents of copied data, QR codes and shared files. These can contain licence keys or customer metadata even when authentication tokens are absent.
- Keep marketing capture on fictional data. Release assets are public and are generated automatically from the tagged source.

## Repository hygiene and licensing

Do not commit `.env` files containing real values, API credentials, private keys, signing certificates with private keys, provisioning profiles or customer exports. Ignore rules help prevent accidental staging; inspect your diff before pushing. If a credential is exposed, revoke or rotate it and notify the maintainer privately. Deleting it in a later commit does not remove earlier copies.

No project-wide software licence has been selected yet. Public review and contribution are welcome; ask the maintainer before relying on broader reuse or redistribution rights. Do not add third-party code, artwork or data unless its licence permits inclusion and its attribution requirements are satisfied.
