import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../brand.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Future<void> _open(BuildContext context, String url) async {
    try {
      if (await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {}
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not open the link. Try again later.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('About & privacy')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BrandMark(size: 80),
                  const SizedBox(height: 24),
                  Text(AppBrand.name,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text(AppBrand.tagline),
                  const SizedBox(height: 16),
                  const AppVersion(),
                  const SizedBox(height: 24),
                  const Text(
                      'An independent client for Keygen Cloud and self-hosted Keygen servers. '
                      'Not affiliated with or endorsed by Keygen.'),
                  const SizedBox(height: 32),
                  Text('Your data & privacy',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  const Text(
                      'The app sends your login credentials and licensing requests directly '
                      'to the server you choose. Use a trusted HTTPS server. The server operator '
                      'is responsible for its own data handling and retention.'),
                  const SizedBox(height: 16),
                  const Text(
                      'Your password is never saved. Your access token is stored in the '
                      'device’s secure storage. The server address, account, email and licence-file '
                      'templates are saved locally so you can reconnect. Signing out removes '
                      'the saved access token; it does not revoke the token on your server.'),
                  const SizedBox(height: 16),
                  const Text(
                      'There are no advertising or analytics SDKs in this app. Licence data '
                      'is loaded from your server. Copying a licence places its contents on the '
                      'system clipboard; sharing a file writes a temporary copy and sends it to '
                      'the destination you select. Templates may contain any fixed text or '
                      'metadata you choose to include.'),
                  const SizedBox(height: 16),
                  const Text(
                      'Delete templates in Licence file formats. You can remove local '
                      'connection settings from the Connection section in More. To delete '
                      'server-side data or revoke tokens, contact your server administrator '
                      'or use your Keygen dashboard.'),
                  const SizedBox(height: 24),
                  if (AppBrand.privacyUrl.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => _open(context, AppBrand.privacyUrl),
                      icon: const Icon(Icons.privacy_tip_outlined),
                      label: const Text('Privacy policy'),
                    ),
                  if (AppBrand.supportUrl.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _open(context, AppBrand.supportUrl),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Support'),
                    ),
                  const SizedBox(height: 16),
                  const AboutListTile(
                    applicationName: AppBrand.name,
                    icon: Icon(Icons.description_outlined),
                    child: Text('Open source licences'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
