import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../resources/kinds.dart';
import '../api/keygen_client.dart';
import '../state/session.dart';
import '../brand.dart';
import 'about_page.dart';
import 'resource_list_page.dart';
import 'template_pages.dart';
import 'util.dart';
import 'widgets.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  Future<void> _signOut(BuildContext context, {bool forget = false}) async {
    final ok = await confirm(
        context,
        forget ? 'Forget connection?' : 'Sign out?',
        forget
            ? 'Remove the saved access token, server address, account and email from this device?'
            : 'You can sign back in or connect to a different server.',
        action: forget ? 'Forget connection' : 'Sign out',
        destructive: true);
    if (!ok || !context.mounted) return;
    try {
      await context.read<Session>().signOut(forgetConnection: forget);
      if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final cs = Theme.of(context).colorScheme;
    final who =
        s.user?.str('email') ?? (s.email.isEmpty ? 'API token' : s.email);
    final host = Uri.tryParse(s.serverUrl)?.host ?? s.serverUrl;

    Widget nav(IconData icon, String title, String? sub, VoidCallback onTap) =>
        ListTile(
          leading: IconTile(icon, size: 36),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: sub == null ? null : Text(sub),
          trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          onTap: onTap,
        );

    return LargeTitleScroll(
      title: 'More',
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          sliver: SliverList.list(children: [
            RowsPanel([
              for (final k in ['machines', 'users', 'entitlements']
                  .map((e) => kinds[e]!))
                nav(
                    k.icon,
                    k.plural,
                    null,
                    () => _open(
                        context, ResourceListPage(kind: k, pushed: true))),
              nav(
                  Icons.qr_code_2,
                  'Licence file formats',
                  'Choose which fields go in a file or QR code',
                  () => _open(context, const TemplateListPage())),
            ]),
            const SectionHeader('Connection'),
            RowsPanel([
              DataRow2('Server', host, mono: true),
              DataRow2(
                  'Account', s.account.isEmpty ? 'Single account' : s.account,
                  mono: true),
              DataRow2('Signed in as', who),
            ]),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: Icon(Icons.logout, size: 18, color: cs.error),
              label: Text('Sign out', style: TextStyle(color: cs.error)),
              onPressed: () => _signOut(context),
            ),
            TextButton(
              onPressed: () => _signOut(context, forget: true),
              child: const Text('Forget connection'),
            ),
            const SizedBox(height: 16),
            nav(Icons.info_outline, 'About & privacy', AppBrand.name,
                () => _open(context, const AboutPage())),
            const SizedBox(height: 16),
            const Center(child: AppVersion()),
          ]),
        ),
      ],
    );
  }
}
