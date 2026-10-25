import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

abstract final class AppBrand {
  static const name = 'Keygen Client';
  static const tagline = 'Your licences. In hand.';
  static const privacyUrl = String.fromEnvironment('PRIVACY_POLICY_URL',
      defaultValue: 'https://axym.dev/apps#keygen-client-privacy');
  static const supportUrl = String.fromEnvironment('SUPPORT_URL',
      defaultValue: 'https://axym.dev/apps#keygen-client-support');
  static final Future<PackageInfo> packageInfo = PackageInfo.fromPlatform();
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.23),
        child: Image.asset('assets/brand/keygen-mark.png',
            width: size, height: size, excludeFromSemantics: true),
      );
}

class AppVersion extends StatelessWidget {
  const AppVersion({super.key});

  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
        future: AppBrand.packageInfo,
        builder: (context, snapshot) {
          final info = snapshot.data;
          return Text(
            info == null
                ? AppBrand.name
                : '${AppBrand.name} · ${info.version} (${info.buildNumber})',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          );
        },
      );
}
