import 'package:flutter/material.dart';

import '../api/keygen_client.dart';
import '../ui/util.dart';

enum FieldType {
  text,
  multiline,
  password,
  integer,
  boolean,
  choice,
  durationDays,
  dateTime,
  metadata,
  relation,
}

class FieldSpec {
  const FieldSpec(
    this.key,
    this.label,
    this.type, {
    this.required = false,
    this.choices = const [],
    this.helper,
    this.createOnly = false,
    this.relationPath,
  });

  /// Attribute name, or relationship name for [FieldType.relation].
  final String key;
  final String label;
  final FieldType type;
  final bool required;
  final List<String> choices;
  final String? helper;
  final bool createOnly;

  /// For relations: the API path of the related kind (e.g. "policies").
  final String? relationPath;
}

class ActionSpec {
  const ActionSpec(this.label, this.action, this.icon,
      {this.visible, this.confirm = false});
  final String label;
  final String action;
  final IconData icon;
  final bool Function(Resource)? visible;
  final bool confirm;
}

class RelatedSpec {
  const RelatedSpec(this.label, this.suffix, this.kindPath);
  final String label;

  /// Sub-path under the resource, e.g. "machines".
  final String suffix;
  final String kindPath;
}

class ResourceKind {
  const ResourceKind({
    required this.path,
    required this.singular,
    required this.plural,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.fields = const [],
    this.actions = const [],
    this.related = const [],
    this.canCreate = true,
    this.deleteLabel = 'Delete',
  });

  final String path;
  final String singular;
  final String plural;
  final IconData icon;
  final String Function(Resource) title;
  final String Function(Resource) subtitle;
  final List<FieldSpec> fields;
  final List<ActionSpec> actions;
  final List<RelatedSpec> related;
  final bool canCreate;
  final String deleteLabel;
}

String _short(String s, [int n = 24]) =>
    s.length > n ? '${s.substring(0, n)}…' : s;

const _meta = FieldSpec('metadata', 'Metadata', FieldType.metadata,
    helper:
        'Your own key/value data attached to this record, e.g. customer_id or plan.');

final Map<String, ResourceKind> kinds = {
  'licenses': ResourceKind(
    path: 'licenses',
    singular: 'Licence',
    plural: 'Licences',
    icon: Icons.vpn_key_outlined,
    deleteLabel: 'Revoke',
    title: (r) => r.str('name') ?? _short(r.str('key') ?? r.id),
    subtitle: (r) {
      final exp = r.date('expiry');
      final key = r.str('key') ?? '';
      final tail = key.length > 4 ? '…${key.substring(key.length - 4)}' : key;
      return [
        tail,
        exp == null ? 'No expiry' : relativeDays(exp),
      ].where((e) => e.isNotEmpty).join(' · ');
    },
    fields: const [
      FieldSpec('name', 'Name', FieldType.text,
          helper: 'A label for you, such as the customer or order. Optional.'),
      FieldSpec('policy', 'Policy', FieldType.relation,
          required: true,
          createOnly: true,
          relationPath: 'policies',
          helper:
              'Sets the rules: duration, machine limits and expiry behaviour. Cannot be changed later.'),
      FieldSpec('user', 'Owner (optional)', FieldType.relation,
          createOnly: true,
          relationPath: 'users',
          helper: 'The user this licence belongs to.'),
      FieldSpec('expiry', 'Expiry', FieldType.dateTime,
          helper:
              'When the licence stops working. Leave empty to follow the policy duration.'),
      FieldSpec('maxMachines', 'Max machines override', FieldType.integer,
          helper: 'Overrides the policy limit for this licence only.'),
      _meta,
    ],
    actions: [
      ActionSpec('Suspend', 'suspend', Icons.pause_circle_outline,
          confirm: true,
          visible: (r) =>
              r.str('status') != 'SUSPENDED' && r.boolVal('suspended') != true),
      ActionSpec('Reinstate', 'reinstate', Icons.play_circle_outline,
          visible: (r) =>
              r.str('status') == 'SUSPENDED' || r.boolVal('suspended') == true),
      const ActionSpec('Renew', 'renew', Icons.autorenew),
      const ActionSpec('Check in', 'check-in', Icons.check_circle_outline),
    ],
    related: const [RelatedSpec('Machines', 'machines', 'machines')],
  ),
  'policies': ResourceKind(
    path: 'policies',
    singular: 'Policy',
    plural: 'Policies',
    icon: Icons.policy_outlined,
    title: (r) => r.str('name') ?? r.id,
    subtitle: (r) {
      final secs = r.intVal('duration');
      return [
        secs == null ? 'Perpetual' : '${(secs / 86400).round()} days',
        if (r.boolVal('floating') == true) 'Floating',
        if (r.intVal('maxMachines') != null)
          '${r.intVal('maxMachines')} machines',
      ].join(' · ');
    },
    fields: const [
      FieldSpec('name', 'Name', FieldType.text,
          required: true,
          helper: 'Shown in lists, e.g. "Pro yearly" or "Trial 14 days".'),
      FieldSpec('product', 'Product', FieldType.relation,
          required: true,
          createOnly: true,
          relationPath: 'products',
          helper:
              'The product licences from this policy unlock. Cannot be changed later.'),
      FieldSpec('duration', 'Duration (days)', FieldType.durationDays,
          helper: 'Leave empty for a perpetual licence'),
      FieldSpec('maxMachines', 'Max machines', FieldType.integer,
          helper:
              'How many devices can activate one licence. Empty means unlimited.'),
      FieldSpec('maxUses', 'Max uses', FieldType.integer,
          helper:
              'Cap on how many times a licence can be used, such as launches or exports.'),
      FieldSpec('floating', 'Floating machines', FieldType.boolean,
          helper:
              'Devices can be swapped freely up to the limit, instead of being locked in.'),
      FieldSpec('strict', 'Strict', FieldType.boolean,
          helper:
              'Licence is only valid while activated machines stay within the limit.'),
      FieldSpec('protected', 'Protected', FieldType.boolean,
          helper: 'Licences must be created by an admin, not by end users.'),
      FieldSpec('expirationStrategy', 'When expired', FieldType.choice,
          helper: 'What happens to a licence once it expires.',
          choices: [
            'RESTRICT_ACCESS',
            'REVOKE_ACCESS',
            'MAINTAIN_ACCESS',
            'ALLOW_ACCESS',
          ]),
      FieldSpec('authenticationStrategy', 'Authentication', FieldType.choice,
          choices: ['TOKEN', 'LICENSE', 'SESSION', 'MIXED', 'NONE'],
          helper: 'How clients prove who they are when calling the API.'),
      FieldSpec('scheme', 'Signing scheme', FieldType.choice,
          createOnly: true,
          choices: [
            'ED25519_SIGN',
            'RSA_2048_PKCS1_SIGN_V2',
            'RSA_2048_PKCS1_PSS_SIGN_V2',
            'RSA_2048_JWT_RS256',
          ],
          helper: 'Needed for signed licence files'),
      _meta,
    ],
    related: const [RelatedSpec('Licences', 'licenses', 'licenses')],
  ),
  'products': ResourceKind(
    path: 'products',
    singular: 'Product',
    plural: 'Products',
    icon: Icons.inventory_2_outlined,
    title: (r) => r.str('name') ?? r.id,
    subtitle: (r) => r.str('url') ?? r.str('distributionStrategy') ?? '',
    fields: const [
      FieldSpec('name', 'Name', FieldType.text,
          required: true, helper: 'The name of your app or service.'),
      FieldSpec('url', 'URL', FieldType.text,
          helper: 'Where the product lives, such as its website. Optional.'),
      FieldSpec('distributionStrategy', 'Distribution', FieldType.choice,
          choices: ['LICENSED', 'OPEN', 'CLOSED'],
          helper:
              'Who can download releases: licensed users only, anyone, or nobody.'),
      _meta,
    ],
    related: const [RelatedSpec('Policies', 'policies', 'policies')],
  ),
  'machines': ResourceKind(
    path: 'machines',
    singular: 'Machine',
    plural: 'Machines',
    icon: Icons.computer_outlined,
    canCreate: false,
    deleteLabel: 'Deactivate',
    title: (r) =>
        r.str('name') ??
        r.str('hostname') ??
        _short(r.str('fingerprint') ?? r.id),
    subtitle: (r) =>
        [r.str('platform'), r.str('ip')].whereType<String>().join(' · '),
    fields: const [
      FieldSpec('name', 'Name', FieldType.text,
          helper: 'A friendly name for this device.'),
      FieldSpec('hostname', 'Hostname', FieldType.text,
          helper: 'The network name of the device.'),
      FieldSpec('ip', 'IP address', FieldType.text,
          helper: 'Last known IP address of the device.'),
      _meta,
    ],
  ),
  'users': ResourceKind(
    path: 'users',
    singular: 'User',
    plural: 'Users',
    icon: Icons.person_outline,
    title: (r) {
      final n =
          [r.str('firstName'), r.str('lastName')].whereType<String>().join(' ');
      return n.isEmpty ? (r.str('email') ?? r.id) : n;
    },
    subtitle: (r) => r.str('email') ?? '',
    fields: const [
      FieldSpec('email', 'Email', FieldType.text,
          required: true, helper: 'Used to identify and contact this user.'),
      FieldSpec('firstName', 'First name', FieldType.text, helper: 'Optional.'),
      FieldSpec('lastName', 'Last name', FieldType.text, helper: 'Optional.'),
      FieldSpec('password', 'Password', FieldType.password,
          createOnly: true,
          helper: 'Only needed if this user will sign in themselves.'),
      _meta,
    ],
    actions: [
      ActionSpec('Ban', 'ban', Icons.block,
          confirm: true, visible: (r) => r.str('status') != 'BANNED'),
      ActionSpec('Unban', 'unban', Icons.lock_open,
          visible: (r) => r.str('status') == 'BANNED'),
    ],
    related: const [RelatedSpec('Licences', 'licenses', 'licenses')],
  ),
};
