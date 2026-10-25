import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'brand.dart';
import 'state/session.dart';
import 'theme.dart';
import 'state/templates.dart';
import 'ui/connect_screen.dart';
import 'ui/home_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => Session()..restore()),
      ChangeNotifierProvider(create: (_) => TemplateStore()..load()),
    ],
    child: const KeygenApp(),
  ));
}

class KeygenApp extends StatelessWidget {
  const KeygenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppBrand.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark),
      home: const _Root(),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: switch (session.state) {
        AuthState.loading => const Scaffold(
              body: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              BrandMark(size: 72),
              SizedBox(height: 24),
              CircularProgressIndicator.adaptive(),
            ]),
          )),
        AuthState.signedOut => const ConnectScreen(key: ValueKey('connect')),
        AuthState.signedIn =>
          HomeShell(key: ValueKey(session.serverUrl + session.account)),
      },
    );
  }
}
