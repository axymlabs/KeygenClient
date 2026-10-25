import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keygen_app/brand.dart';
import 'package:keygen_app/state/session.dart';
import 'package:keygen_app/ui/about_page.dart';
import 'package:keygen_app/ui/connect_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, null);
  });

  test('insecure legacy tokens are removed when Keychain is unavailable',
      () async {
    SharedPreferences.setMockInitialValues({
      'serverUrl': 'https://licensing.invalid',
      'token': 'legacy-secret',
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, (_) async {
      throw PlatformException(code: 'keychain-unavailable');
    });
    final session = Session();
    await session.restore();
    expect(session.state, AuthState.signedOut);
    expect((await SharedPreferences.getInstance()).getString('token'), isNull);
    expect(session.client, isNull);
  });

  test('forget connection deletes token and remembered identity', () async {
    SharedPreferences.setMockInitialValues({
      'serverUrl': 'https://licensing.invalid',
      'account': 'account',
      'email': 'admin@licensing.invalid',
      'token': 'legacy-secret',
      'templates': '[]',
    });
    var deleted = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, (call) async {
      if (call.method == 'delete') deleted = true;
      return null;
    });
    final session = Session();
    await session.signOut(forgetConnection: true);
    final prefs = await SharedPreferences.getInstance();
    expect(deleted, isTrue);
    for (final key in ['token', 'serverUrl', 'account', 'email']) {
      expect(prefs.containsKey(key), isFalse);
    }
    expect(prefs.containsKey('templates'), isTrue);
    expect(session.state, AuthState.signedOut);
    expect(session.serverUrl, isEmpty);
  });

  test('failed token removal is reported instead of claiming sign-out',
      () async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, (_) async {
      throw PlatformException(code: 'keychain-unavailable');
    });
    final session = Session()..state = AuthState.signedIn;
    await expectLater(session.signOut(), throwsException);
    expect(session.state, AuthState.signedIn);
  });

  test(
      'leaving sample mode does not require Keychain or remember a fake server',
      () async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, (_) async {
      throw PlatformException(code: 'keychain-unavailable');
    });
    final session = Session();
    await session.startDemo();
    await session.signOut();
    expect(session.state, AuthState.signedOut);
    expect(session.serverUrl, isEmpty);
  });

  testWidgets(
      'displayed version follows the installed package, including build overrides',
      (tester) async {
    PackageInfo.setMockInitialValues(
        appName: AppBrand.name,
        packageName: 'test.client',
        version: '2.3.4',
        buildNumber: '57',
        buildSignature: '');
    await tester
        .pumpWidget(const MaterialApp(home: Scaffold(body: AppVersion())));
    await tester.pumpAndSettle();
    expect(find.text('Keygen Client · 2.3.4 (57)'), findsOneWidget);
  });

  testWidgets(
      'connection and privacy remain usable on small screens with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => Session(),
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data:
              MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const ConnectScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('About & privacy'));
    await tester.tap(find.text('About & privacy'));
    await tester.pumpAndSettle();
    expect(find.byType(AboutPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
