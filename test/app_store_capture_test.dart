// Generates real Flutter screen renders for the App Store marketing pipeline.
// Invoked by tool/app_store/generate.py; ordinary `flutter test` skips this.
import 'dart:convert';
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
import 'package:keygen_app/ui/home_shell.dart';
import 'package:keygen_app/ui/resource_detail_page.dart';
import 'package:keygen_app/ui/resource_list_page.dart';
import 'package:keygen_app/ui/share_license_page.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    loader.addFont(
        Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  final planPath = Platform.environment['APP_STORE_CAPTURE_PLAN'];
  testWidgets('capture release marketing screens', (tester) async {
    final plan =
        jsonDecode(File(planPath!).readAsStringSync()) as Map<String, dynamic>;
    final sdk = plan['flutter_root'] as String;
    final fontRoot = '$sdk/bin/cache/artifacts/material_fonts';
    // Use system UI fonts on macOS and SDK fonts everywhere else.
    final sf = File('/System/Library/Fonts/SFNS.ttf');
    await loadFont(
        'MarketingUI',
        sf.existsSync()
            ? [sf.path]
            : [
                '$fontRoot/Roboto-Regular.ttf',
                '$fontRoot/Roboto-Medium.ttf',
                '$fontRoot/Roboto-Bold.ttf',
              ]);
    await loadFont('Roboto', [
      '$fontRoot/Roboto-Regular.ttf',
      '$fontRoot/Roboto-Medium.ttf',
      '$fontRoot/Roboto-Bold.ttf',
    ]);
    await loadFont('Menlo', [
      File('/System/Library/Fonts/SFNSMono.ttf').existsSync()
          ? '/System/Library/Fonts/SFNSMono.ttf'
          : '$fontRoot/Roboto-Regular.ttf'
    ]);
    await loadFont('MaterialIcons', ['$fontRoot/MaterialIcons-Regular.otf']);
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
        appName: 'Keygen Client',
        packageName: 'com.axymlabs.keygenapp',
        version: plan['version'] as String,
        buildNumber: plan['build'] as String,
        buildSignature: '');
    final session = Session();
    final store = TemplateStore();
    await tester.runAsync(() async {
      await store.load();
      await session.startDemo();
    });
    final license =
        (await tester.runAsync(() => session.api.list('licenses', size: 1)))!
            .items
            .first;
    addTearDown(tester.view.reset);
    for (final device in plan['devices'] as List) {
      final width = (device['width'] as num).toDouble();
      final height = (device['height'] as num).toDouble();
      final scale = (device['scale'] as num).toDouble();
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = scale;
      for (final appearance in ['dark', 'light']) {
        final brightness =
            appearance == 'dark' ? Brightness.dark : Brightness.light;
        for (final scene in [
          'dashboard',
          'licences',
          'detail',
          'share',
          'products'
        ]) {
          final boundary = GlobalKey();
          final Widget home = switch (scene) {
            'dashboard' => const HomeShell(),
            'licences' =>
              ResourceListPage(kind: kinds['licenses']!, pushed: true),
            'detail' =>
              ResourceDetailPage(kind: kinds['licenses']!, resource: license),
            'share' => ShareLicensePage(license: license),
            _ => ResourceListPage(kind: kinds['products']!, pushed: true),
          };
          await tester.pumpWidget(MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: session),
              ChangeNotifierProvider.value(value: store)
            ],
            child: RepaintBoundary(
                key: boundary,
                child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme:
                        AppTheme.build(brightness, fontFamily: 'MarketingUI'),
                    home: home)),
          ));
          // Futures complete on the real event loop; UI/chart animations use fake time.
          for (var i = 0; i < 8; i++) {
            await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 10)));
            await tester.pump(const Duration(milliseconds: 250));
          }
          expect(tester.takeException(), isNull,
              reason: '${device['id']} $scene $appearance');
          await tester.runAsync(() async {
            final render = boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
            final img = await render.toImage(pixelRatio: scale);
            final png = await img.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
                '${plan['output']}/${device['id']}/$appearance/$scene.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(png!.buffer.asUint8List());
            img.dispose();
          });
        }
      }
    }
  }, skip: planPath == null, timeout: const Timeout(Duration(minutes: 5)));
}
