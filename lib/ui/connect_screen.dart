import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/keygen_client.dart';
import '../brand.dart';
import '../state/session.dart';
import 'about_page.dart';
import 'widgets.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _url;
  late final TextEditingController _account;
  late final TextEditingController _email;
  final _password = TextEditingController();
  final _token = TextEditingController();
  bool _useToken = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = context.read<Session>();
    _url = TextEditingController(text: s.serverUrl);
    _account = TextEditingController(text: s.account);
    _email = TextEditingController(text: s.email);
  }

  @override
  void dispose() {
    for (final c in [_url, _account, _email, _password, _token]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = context.read<Session>();
    try {
      if (_useToken) {
        await session.signInWithToken(
            url: _url.text, account: _account.text, token: _token.text);
      } else {
        await session.signIn(
            url: _url.text,
            account: _account.text,
            email: _email.text,
            password: _password.text);
      }
      HapticFeedback.mediumImpact();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.isUnauthorized
          ? 'Those credentials were not accepted.'
          : e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  Widget _eye() => IconButton(
        icon: Icon(_obscure
            ? Icons.visibility_outlined
            : Icons.visibility_off_outlined),
        onPressed: () => setState(() => _obscure = !_obscure),
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    return Scaffold(
      body: Stack(children: [
        const Positioned.fill(child: Glow(height: 560)),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _form,
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                    color: cs.primary.withValues(alpha: 0.35),
                                    blurRadius: 28,
                                    spreadRadius: -6),
                              ],
                            ),
                            child: const BrandMark(size: 56),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(AppBrand.name,
                                  style: t.textTheme.titleLarge),
                              const SizedBox(height: 4),
                              Text('LICENSING, CONNECTED',
                                  style: t.textTheme.labelSmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      letterSpacing: 1.4)),
                            ],
                          )),
                        ]),
                        const SizedBox(height: 40),
                        Text(AppBrand.tagline,
                            style: t.textTheme.headlineMedium),
                        const SizedBox(height: 10),
                        Text(
                            'Connect to Keygen Cloud or your own server. Manage your licensing from one place.',
                            style: t.textTheme.bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant)),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _url,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                              labelText: 'Server address',
                              hintText: 'api.keygen.sh',
                              helperText:
                                  'Hostname or URL of your Keygen server'),
                          validator: _required,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _account,
                          autocorrect: false,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                              labelText: 'Account ID or slug',
                              helperText:
                                  'Leave empty for single-account servers'),
                        ),
                        const SizedBox(height: 24),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: false, label: Text('Email')),
                            ButtonSegment(
                                value: true, label: Text('API token')),
                          ],
                          selected: {_useToken},
                          showSelectedIcon: false,
                          onSelectionChanged: (s) =>
                              setState(() => _useToken = s.first),
                        ),
                        const SizedBox(height: 16),
                        if (_useToken)
                          TextFormField(
                            controller: _token,
                            autocorrect: false,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                                labelText: 'Admin token',
                                helperText:
                                    'Create one under Tokens in your Keygen dashboard',
                                suffixIcon: _eye()),
                            validator: _required,
                            onFieldSubmitted: (_) => _submit(),
                          )
                        else ...[
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [
                              AutofillHints.username,
                              AutofillHints.email
                            ],
                            autocorrect: false,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                                labelText: 'Email',
                                helperText:
                                    'The admin account you sign in to Keygen with'),
                            validator: _required,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            autofillHints: const [AutofillHints.password],
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                                labelText: 'Password',
                                helperText:
                                    'Never stored. Only the access token is kept',
                                suffixIcon: _eye()),
                            validator: _required,
                            onFieldSubmitted: (_) => _submit(),
                          ),
                        ],
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          child: _error == null
                              ? const SizedBox(width: double.infinity)
                              : Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.error_outline,
                                          size: 18, color: cs.error),
                                      const SizedBox(width: 8),
                                      Expanded(
                                          child: Text(_error!,
                                              style: TextStyle(
                                                  color: cs.error,
                                                  fontSize: 13))),
                                    ],
                                  ),
                                ),
                        ),
                        const SizedBox(height: 28),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52)),
                          child: _busy
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5, color: cs.onPrimary))
                              : const Text('Connect'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => context.read<Session>().startDemo(),
                          child: const Text('Explore with sample data'),
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const AboutPage())),
                          child: const Text('About & privacy'),
                        ),
                        const AppVersion(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
