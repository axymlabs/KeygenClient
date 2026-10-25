# Keygen Client privacy policy — publication draft

**Prepared for Axym Labs. Publication required:** add the section below to https://axym.dev/apps before submitting. Confirm the operator and service practices before publication. Intended privacy anchor: `keygen-client-privacy`; support anchor: `keygen-client-support`.

Publisher: Axym Labs

Privacy contact: privacy@axym.dev

Support contact: support@axym.dev

Effective date: set to the publication date.

## Data handling

Keygen Client connects directly to the Keygen server selected by the user. Login credentials, access tokens and licensing requests are sent to that server to authenticate and perform the requested actions. The server operator handles the account information, licensing data and any server logs under its own policy. Axym Labs does not operate a licensing backend for this client. If Axym Labs later offers a server service for this app, this policy must be updated to describe it before that service is introduced.

The app contains no advertising or analytics SDKs. It does not send licensing data to a separate app-publisher backend.

## Device storage

Passwords are not saved. Access tokens are stored using the device's secure storage. The app saves the server address, account identifier, email address and custom licence-file templates in local preferences. Templates may contain user-supplied fixed text or metadata selections.

Licence records are loaded from the selected server. Copying information writes it to the system clipboard. Sharing creates a temporary file in the app's cache and sends it to the destination the user selects. The operating system manages temporary-file retention; recipients control their copies.

## Deletion and control

Signing out removes the saved access token from this device. “Forget connection” also removes the remembered server address, account and email. Templates can be deleted from Licence file formats. Removing a local token does not revoke it on the server. Users should use the Keygen dashboard or contact their server administrator to revoke tokens, delete server records or request account deletion.

Clipboard copies, previously shared files, backups and recipient copies must be removed separately using the relevant system or service controls.

## Contact

For privacy requests, contact privacy@axym.dev. Axym Labs can answer questions about the client; requests for data held by a chosen Keygen server must go to that server's operator.

## Keygen Client support

Email support@axym.dev. Include your platform, the app version and build shown in About & privacy, and the steps to reproduce the issue. Do not send passwords, access tokens, licence keys or customer data.

For connection problems, verify that the server address uses HTTPS, your account ID is correct and your token has the required permissions. If secure storage is unavailable, check that the app is properly signed. Sign out to remove the saved token, or choose Forget connection to remove the remembered connection details as well. Server administrators control server-side account deletion and token revocation.
