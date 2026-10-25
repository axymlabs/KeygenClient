# Security policy

Keygen Client is intentionally public so the community can inspect its handling of sensitive licensing operations. Independent review and reports of reproducible vulnerabilities are welcome. Public availability and passing automated checks are not an independent security audit or a guarantee of security.

## Report a vulnerability privately

Use [GitHub private vulnerability reporting](https://github.com/axymlabs/KeygenClient/security/advisories/new). Private reporting is enabled for this repository. If the form is unavailable, contact **support@axym.dev** with the subject **Keygen Client security report**.

Include the affected version or commit, platform, impact and a minimal reproduction using fictional data or disposable resources you control. For the initial report, omit live tokens, passwords, customer records, private licence-signing keys and Apple signing credentials. Coordinate any additional sensitive evidence privately with the maintainer. Please allow the issue to be assessed and a fix coordinated before publishing exploit details in an issue, pull request or release asset. No response-time commitment or bounty is implied by this policy.

## Security boundaries

The app sends authentication and licensing requests to the server chosen by the user. That server must authenticate and authorize protected operations and enforce the caller's permissions. A modified client must not be able to bypass those server checks. Do not use the secrecy of this repository, its UI or its binaries as an access-control mechanism. [Keygen documents its authorization model and token permissions](https://keygen.sh/docs/api/authorization/).

The current implementation stores access tokens using `flutter_secure_storage` and does not save passwords. Server address, account, email and custom licence-file templates are kept in local preferences. Signing out removes the locally saved token; it does not revoke that token at the server. Use the server's administration tools to revoke a token or change its permissions.

An operator-provided token can permit sensitive modifications or deletions. Use only a trusted device and server, prefer HTTPS, and choose the narrowest server-supported permissions appropriate for the task. The current UI can accept HTTP addresses for local/self-hosted setups; that does not make sending live credentials over an unencrypted network safe. Tokens must never be embedded in distributed source, builds or public release assets. See [Keygen's authentication guidance](https://keygen.sh/docs/api/authentication/).

Server-signed licence files are requested from the connected server. Private licence-signing keys do not belong in the client. Copying or sharing licence information intentionally sends it to the system clipboard, a temporary file or a user-selected recipient; review the included fields before sharing. Local secure storage does not protect a copy that has been exported elsewhere.

## Useful review locations

| Area | Source |
| --- | --- |
| Authentication headers, endpoints and HTTP requests | [lib/api/keygen_client.dart](lib/api/keygen_client.dart) |
| Credential persistence, migration, sign-in and sign-out | [lib/state/session.dart](lib/state/session.dart) |
| Resource creation and editing | [lib/ui/resource_form_page.dart](lib/ui/resource_form_page.dart) |
| Resource actions, deletion and confirmations | [lib/ui/resource_detail_page.dart](lib/ui/resource_detail_page.dart) |
| Licence templates and rendered fields | [lib/state/templates.dart](lib/state/templates.dart) |
| QR codes, shared files and clipboard content | [lib/ui/share_license_page.dart](lib/ui/share_license_page.dart) |
| Public release generation and publication | [tool/app_store](tool/app_store), [.github/workflows/app-store-assets.yml](.github/workflows/app-store-assets.yml) |

The marketing pipeline uses fictional sample data and publishes to GitHub Releases. Treat its output as public. It uses the workflow's short-lived GitHub token; it does not require production licensing credentials or Apple upload credentials.

## If a secret is exposed

Revoke or rotate the affected credential at its issuing service first. Notify the maintainer privately, identify the affected commit or asset without reposting the secret, and coordinate removal from history, artifacts and releases where appropriate. A later deletion alone cannot recover copies already downloaded or forked.
