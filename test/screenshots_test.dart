// Renders key screens to PNGs for visual review.
// Run: SHOTS_DIR=/some/dir flutter test test/screenshots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keygen_app/resources/kinds.dart';
import 'package:keygen_app/state/session.dart';
import 'package:keygen_app/state/templates.dart';
import 'package:keygen_app/theme.dart';
import 'package:keygen_app/ui/connect_screen.dart';
import 'package:keygen_app/ui/home_shell.dart';
import 'package:keygen_app/ui/resource_detail_page.dart';
import 'package:keygen_app/ui/share_license_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    l.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await l.load();
}

final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '';

void main() {
  final dir = Platform.environment['SHOTS_DIR'];
  final brightness =
      Platform.environment['SHOTS_LIGHT'] == '1' ? Brightness.light : Brightness.dark;

  testWidgets('screenshots', (tester) async {
    if (dir == null) return;
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await _font('SF', ['/System/Library/Fonts/SFNS.ttf']);
    await _font('Menlo', ['/System/Library/Fonts/SFNSMono.ttf']);
    await _font('Roboto', [
      '$flutterRoot/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
      '$flutterRoot/bin/cache/artifacts/material_fonts/Roboto-Medium.ttf',
      '$flutterRoot/bin/cache/artifacts/material_fonts/Roboto-Bold.ttf',
    ]);
    await _font('MaterialIcons',
        ['$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);

    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    final session = Session();
    final store = TemplateStore();
    await tester.runAsync(() async {
      await store.load();
      await session.startDemo();
    });

    Future<void> shot(String name) async {
      for (var i = 0; i < 30; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.runAsync(() async {
        final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 1.5);
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        Directory(dir).createSync(recursive: true);
        File('$dir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
      });
    }

    Future<void> app(Widget home, {Session? s}) async {
      final theme = AppTheme.build(brightness, fontFamily: 'SF');
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: s ?? session),
          ChangeNotifierProvider.value(value: store),
        ],
        child: RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: home,
          ),
        ),
      ));
    }

    final signedOut = Session()..state = AuthState.signedOut;
    await app(const ConnectScreen(), s: signedOut);
    await shot('01_connect');

    await app(const HomeShell());
    await shot('02_dashboard');

    // Scroll dashboard
    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -700));
    await shot('03_dashboard_scrolled');

    await tester.tap(find.text('Licences').last);
    await shot('04_licences');

    final lic = (await tester.runAsync(() => session.api.list('licenses', size: 5)))!.items.first;
    await app(ResourceDetailPage(kind: kinds['licenses']!, resource: lic));
    await shot('05_licence_detail');

    await app(ShareLicensePage(license: lic));
    await shot('06_share');
  });
}
