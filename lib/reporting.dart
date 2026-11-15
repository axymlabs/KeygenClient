import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'firebase_options.dart';

/// Optional reports never contain account IDs, credentials or application records.
/// Native collection is off in Info.plist/AndroidManifest before Dart starts.
class Reporting extends ChangeNotifier {
  Reporting._();
  static final instance = Reporting._();
  bool available = false;
  bool decided = false;
  bool crashes = false;
  bool usage = false;
  SharedPreferences? _preferences;

  Future<void> initialize() async {
    if (kIsWeb ||
        ![TargetPlatform.iOS, TargetPlatform.macOS, TargetPlatform.android]
            .contains(defaultTargetPlatform)) return;
    try {
      _preferences = await SharedPreferences.getInstance();
      decided = _preferences!.getBool('reporting_decided_v1') ?? false;
      crashes = _preferences!.getBool('reporting_crashes_v1') ?? false;
      usage = _preferences!.getBool('reporting_usage_v1') ?? false;
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
      await FirebaseAnalytics.instance.setConsent(
        analyticsStorageConsentGranted: usage && kReleaseMode,
        adStorageConsentGranted: false,
        adUserDataConsentGranted: false,
        adPersonalizationSignalsConsentGranted: false,
      );
      await FirebaseAnalytics.instance
          .setAnalyticsCollectionEnabled(usage && kReleaseMode);
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(crashes && kReleaseMode);
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        record(details.exception, details.stack ?? StackTrace.current,
            fatal: true);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        record(error, stack, fatal: true);
        return false;
      };
      available = true;
    } catch (_) {
      // Reporting must never prevent use of the app, including offline launches.
      debugPrint('Optional reporting is unavailable.');
    }
  }

  void record(Object error, StackTrace stack, {bool fatal = false}) {
    if (!available || !crashes || !kReleaseMode) return;
    // Error strings can contain API tokens, URLs, or user-entered records.
    // Send the error type and code stack only, never the error's message.
    unawaited(FirebaseCrashlytics.instance
        .recordError(
          'Application error (${error.runtimeType})',
          stack,
          fatal: fatal,
        )
        .catchError((Object _) {}));
  }

  Future<void> update({required bool crashes, required bool usage}) async {
    if (!available) return;
    await FirebaseAnalytics.instance.setConsent(
      analyticsStorageConsentGranted: usage && kReleaseMode,
      adStorageConsentGranted: false,
      adUserDataConsentGranted: false,
      adPersonalizationSignalsConsentGranted: false,
    );
    await FirebaseAnalytics.instance
        .setAnalyticsCollectionEnabled(usage && kReleaseMode);
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(crashes && kReleaseMode);
    if (!usage && this.usage)
      await FirebaseAnalytics.instance.resetAnalyticsData();
    if (!crashes) await FirebaseCrashlytics.instance.deleteUnsentReports();
    await _preferences!.setBool('reporting_crashes_v1', crashes);
    await _preferences!.setBool('reporting_usage_v1', usage);
    await _preferences!.setBool('reporting_decided_v1', true);
    this.crashes = crashes;
    this.usage = usage;
    decided = true;
    notifyListeners();
  }
}

class ReportingSettings extends StatelessWidget {
  const ReportingSettings({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Reporting.instance,
        builder: (context, _) {
          final reports = Reporting.instance;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Optional reporting',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                        'Help AXYM Labs improve the app with Google Firebase. Crash reports '
                        'include code traces and device details. Usage reports include app '
                        'interactions and an installation identifier. Your account credentials '
                        'and app records are not included. Both are optional.')),
                SwitchListTile(
                    title: const Text('Crash reports'),
                    value: reports.crashes,
                    onChanged: reports.available
                        ? (value) => _save(context, value, reports.usage)
                        : null),
                SwitchListTile(
                    title: const Text('Usage analytics'),
                    value: reports.usage,
                    onChanged: reports.available
                        ? (value) => _save(context, reports.crashes, value)
                        : null),
                TextButton(
                    onPressed: () => launchUrl(
                        Uri.parse('https://axym.dev/apps#keygen-privacy')),
                    child: const Text('Privacy policy')),
              ]);
        },
      );
  Future<void> _save(BuildContext context, bool crashes, bool usage) async {
    try {
      await Reporting.instance.update(crashes: crashes, usage: usage);
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
            content: Text(
                'Could not save reporting preferences. Please try again.')));
    }
  }
}

/// The choice is made before any optional native or Dart reporting is enabled.
class ReportingConsent extends StatefulWidget {
  const ReportingConsent({super.key, required this.child});
  final Widget child;
  @override
  State<ReportingConsent> createState() => _ReportingConsentState();
}

class _ReportingConsentState extends State<ReportingConsent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final r = Reporting.instance;
      if (mounted && r.available && !r.decided) {
        showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
                  title: const Text('Help improve the app'),
                  content:
                      const SingleChildScrollView(child: ReportingSettings()),
                  actions: [
                    TextButton(
                        onPressed: () async {
                          try {
                            await r.update(crashes: r.crashes, usage: r.usage);
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          } catch (_) {
                            if (ctx.mounted)
                              ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Could not save preferences. Please try again.')));
                          }
                        },
                        child: const Text('Continue'))
                  ],
                ));
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
