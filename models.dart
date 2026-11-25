import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'totp.dart';

/// The kinds of records the vault understands.
///
/// Declaration order feeds the per-type lookup tables in [ItemTypeX]; adding
/// or reordering values must be done together with those tables. Serialized
/// entries use the enum name, so existing names cannot change either.
enum ItemType { login, card, bank, identity, note, document }

/// Description of one editable value shown on an item's detail screen.
class FieldDef {
  final String key;
  final String label;
  final IconData icon;
  final bool secret;
  final bool multiline;
  final bool required;
  final String hint;
  final TextInputType keyboard;

  const FieldDef(
    this.key,
    this.label,
    this.icon, {
    this.secret = false,
    this.multiline = false,
    this.required = false,
    this.hint = '',
    this.keyboard = TextInputType.text,
  });
}

/// Presentation metadata and field schema for every [ItemType].
extension ItemTypeX on ItemType {
  String get label => switch (this) {
        ItemType.login => 'Login',
        ItemType.card => 'Card',
        ItemType.bank => 'Bank account',
        ItemType.identity => 'Identity',
        ItemType.note => 'Secure note',
        ItemType.document => 'Document',
      };

  String get plural => switch (this) {
        ItemType.login => 'Logins',
        ItemType.card => 'Cards',
        ItemType.bank => 'Banks',
        ItemType.identity => 'IDs',
        ItemType.note => 'Notes',
        ItemType.document => 'Docs',
      };

  String get blurb => switch (this) {
        ItemType.login => 'Websites & apps',
        ItemType.card => 'Credit & debit cards',
        ItemType.bank => 'Account details',
        ItemType.identity => 'Passport, Aadhaar, license',
        ItemType.note => 'Private text',
        ItemType.document => 'Photos of legal papers',
      };

  String get nameHint => switch (this) {
        ItemType.login => 'e.g. Google',
        ItemType.card => 'e.g. HDFC Credit Card',
        ItemType.bank => 'e.g. SBI Savings',
        ItemType.identity => 'e.g. Passport',
        ItemType.note => 'e.g. Wi-Fi & door codes',
        ItemType.document => 'e.g. Property papers',
      };

  String get copyLabel => switch (this) {
        ItemType.login => 'Copy password',
        ItemType.card => 'Copy card number',
        ItemType.bank => 'Copy account number',
        ItemType.identity => 'Copy ID number',
        ItemType.note => 'Copy note',
        ItemType.document => 'View photos',
      };

  IconData get icon => switch (this) {
        ItemType.login => Icons.key_rounded,
        ItemType.card => Icons.credit_card_rounded,
        ItemType.bank => Icons.account_balance_rounded,
        ItemType.identity => Icons.badge_rounded,
        ItemType.note => Icons.sticky_note_2_rounded,
        ItemType.document => Icons.description_rounded,
      };

  Color get tint => switch (this) {
        ItemType.login => const Color(0xFF60A5FA),
        ItemType.card => const Color(0xFFFBBF24),
        ItemType.bank => const Color(0xFF4ADE80),
        ItemType.identity => const Color(0xFF2DD4BF),
        ItemType.note => const Color(0xFFFF8A65),
        ItemType.document => const Color(0xFFC084FC),
      };

  bool get supportsImages =>
      this == ItemType.document || this == ItemType.identity;

  bool get hasNotes => this != ItemType.note && this != ItemType.document;

  String? get primaryKey => switch (this) {
        ItemType.login => 'password',
        ItemType.card => 'number',
        ItemType.bank => 'account',
        ItemType.identity => 'idnum',
        ItemType.note => 'text',
        ItemType.document => null,
      };

  List<FieldDef> get fields => switch (this) {
        ItemType.login => const [
            FieldDef(
              'username',
              'Username or email',
              Icons.person_outline_rounded,
              keyboard: TextInputType.emailAddress,
              hint: 'you@email.com',
            ),
            FieldDef(
              'password',
              'Password',
              Icons.lock_outline_rounded,
              secret: true,
              required: true,
            ),
            FieldDef(
              'url',
              'Website or app',
              Icons.link_rounded,
              keyboard: TextInputType.url,
              hint: 'instagram.com',
            ),
            FieldDef(
              'totp',
              '2FA secret (TOTP)',
              Icons.qr_code_rounded,
              secret: true,
              hint: 'JBSWY3DPEHPK3PXP',
            ),
          ],
        ItemType.card => const [
            FieldDef('holder', 'Cardholder name', Icons.person_outline_rounded),
            FieldDef(
              'number',
              'Card number',
              Icons.credit_card_rounded,
              secret: true,
              required: true,
              keyboard: TextInputType.number,
              hint: '1234 5678 9012 3456',
            ),
            FieldDef(
              'expiry',
              'Expiry',
              Icons.event_rounded,
              keyboard: TextInputType.number,
              hint: 'MM/YY',
            ),
            FieldDef(
              'cvv',
              'CVV',
              Icons.password_rounded,
              secret: true,
              keyboard: TextInputType.number,
            ),
            FieldDef(
              'pin',
              'Card PIN',
              Icons.pin_outlined,
              secret: true,
              keyboard: TextInputType.number,
            ),
          ],
        ItemType.bank => const [
            FieldDef('holder', 'Account holder', Icons.person_outline_rounded),
            FieldDef(
              'account',
              'Account number',
              Icons.account_balance_wallet_outlined,
              secret: true,
              required: true,
              keyboard: TextInputType.number,
            ),
            FieldDef('ifsc', 'IFSC / Routing / SWIFT', Icons.tag_rounded),
            FieldDef(
              'kind',
              'Account type',
              Icons.category_outlined,
              hint: 'Savings, Current...',
            ),
            FieldDef('customer', 'Customer ID', Icons.badge_outlined),
            FieldDef(
              'netpass',
              'Online banking password',
              Icons.lock_outline_rounded,
              secret: true,
            ),
          ],
        ItemType.identity => const [
            FieldDef('fullname', 'Full name', Icons.person_outline_rounded),
            FieldDef(
              'dob',
              'Date of birth',
              Icons.cake_outlined,
              keyboard: TextInputType.datetime,
              hint: 'DD/MM/YYYY',
            ),
            FieldDef(
              'idnum',
              'ID number',
              Icons.fingerprint_rounded,
              secret: true,
              required: true,
            ),
            FieldDef(
              'phone',
              'Phone',
              Icons.phone_outlined,
              keyboard: TextInputType.phone,
            ),
            FieldDef(
              'email',
              'Email',
              Icons.alternate_email_rounded,
              keyboard: TextInputType.emailAddress,
            ),
            FieldDef(
              'address',
              'Address',
              Icons.home_outlined,
              multiline: true,
            ),
          ],
        ItemType.note => const [
            FieldDef(
              'text',
              'Note',
              Icons.notes_rounded,
              multiline: true,
              required: true,
            ),
          ],
        ItemType.document => const [
            FieldDef(
              'description',
              'Description',
              Icons.notes_rounded,
              multiline: true,
            ),
          ],
      };
}

/// A single vault record. The flavour of the record is [type]; its values
/// live in the [data] map keyed by the keys in [ItemTypeX.fields].
class Entry {
  final String id;
  ItemType type;
  String name;
  Map<String, String> data;
  String notes;
  bool favorite;
  int updated;
  List<String> images;
  List<String> tags;
  Map<String, String> custom;

  Entry({
    required this.id,
    required this.type,
    required this.name,
    Map<String, String>? data,
    this.notes = '',
    this.favorite = false,
    int? updated,
    List<String>? images,
    List<String>? tags,
    Map<String, String>? custom,
  })  : data = data ?? {},
        updated = updated ?? DateTime.now().millisecondsSinceEpoch,
        images = images ?? [],
        tags = tags ?? [],
        custom = custom ?? {};

  String f(String key) => data[key] ?? '';

  String get username => f('username');
  String get password => f('password');
  String get url => f('url');

  int get strength => passwordStrength(password);

  String get totpSecret => f('totp');
  bool get hasTotp => Totp.isValid(totpSecret);
  String get totpCode => hasTotp ? Totp.code(totpSecret) : '';
  int get totpRemaining => Totp.remaining();
  double get totpProgress => Totp.progress();

  /// Host / package this login belongs to, normalised for matching.
  String get domain => normalizeDomain(
        url.isNotEmpty ? url : (type == ItemType.login ? name : ''),
      );

  /// Everything searchable, including hidden extras. Lower-case once.
  String get searchText => [
        name,
        subtitle,
        notes,
        ...data.values,
        ...custom.keys,
        ...custom.values,
        ...tags,
      ].join(' ').toLowerCase();

  /// The value copied by the primary action on the detail screen.
  String get primaryValue {
    final key = type.primaryKey;
    if (key == null) return '';
    final value = f(key);
    return type == ItemType.card ? value.replaceAll(' ', '') : value;
  }

  /// Compact one-line description used in list tiles.
  String get subtitle {
    switch (type) {
      case ItemType.login:
        return url.isNotEmpty ? url : username;

      case ItemType.card:
        {
          final digits = f('number').replaceAll(' ', '');
          final last =
              digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
          return [
            if (last.isNotEmpty) '•••• $last',
            if (f('expiry').isNotEmpty) 'exp ${f('expiry')}',
          ].join('  ·  ');
        }

      case ItemType.bank:
        {
          final account = f('account');
          final last = account.length >= 4
              ? account.substring(account.length - 4)
              : account;
          return [
            if (last.isNotEmpty) 'A/c •••• $last',
            if (f('holder').isNotEmpty) f('holder'),
          ].join('  ·  ');
        }

      case ItemType.identity:
        return f('fullname');

      case ItemType.note:
        return f('text').split('\n').first;

      case ItemType.document:
        {
          final count = images.length;
          return count == 0
              ? 'No photos yet'
              : '$count photo${count == 1 ? '' : 's'}';
        }
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'name': name,
        'data': data,
        'notes': notes,
        'favorite': favorite,
        'updated': updated,
        'images': images,
        'tags': tags,
        'custom': custom,
      };

  factory Entry.fromJson(Map<String, dynamic> j) {
    final typeName = j['type'] as String?;
    final type = ItemType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => ItemType.login,
    );

    Map<String, String> data;
    final stored = j['data'];
    if (stored is Map) {
      data = stored.map((k, v) => MapEntry('$k', '$v'));
    } else {
      // v1 kept login fields directly on the record instead of in `data`.
      data = {
        'username': j['username'] as String? ?? '',
        'password': j['password'] as String? ?? '',
        'url': j['url'] as String? ?? '',
      };
    }

    return Entry(
      id: j['id'] as String,
      type: type,
      name: j['name'] as String? ?? '',
      data: data,
      notes: j['notes'] as String? ?? '',
      favorite: j['favorite'] as bool? ?? false,
      updated: j['updated'] as int?,
      images: (j['images'] as List?)?.map((e) => '$e').toList(),
      tags: (j['tags'] as List?)
              ?.map((e) => '$e'.trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          <String>[],
      custom: (j['custom'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ??
          <String, String>{},
    );
  }
}

// ---------------------------------------------------------------- ids

String newId() => DateTime.now().microsecondsSinceEpoch.toString();

// ------------------------------------------------------------ passwords

/// A tiny offline blocklist of passwords attackers try first.
const kCommonPasswords = <String>{
  'password',
  'password1',
  'password123',
  '123456',
  '12345678',
  '123456789',
  '1234567890',
  'qwerty',
  'qwerty123',
  'abc123',
  'admin',
  'admin123',
  'letmein',
  'welcome',
  'welcome1',
  'login',
  'iloveyou',
  'monkey',
  'dragon',
  'sunshine',
  'princess',
  'football',
  'baseball',
  'trustno1',
  'passw0rd',
  'p@ssw0rd',
  'password!',
  'test123',
  'user123',
  'default',
  'secret',
};

/// Rough Shannon entropy in bits, useful for UI hints (not a proof of safety).
double passwordEntropy(String p) {
  if (p.isEmpty) return 0;

  var pool = 0;
  if (RegExp(r'[a-z]').hasMatch(p)) pool += 26;
  if (RegExp(r'[A-Z]').hasMatch(p)) pool += 26;
  if (RegExp(r'\d').hasMatch(p)) pool += 10;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) pool += 32;
  if (pool == 0) pool = 26;

  final repeats = RegExp(r'(.)\1{2,}').allMatches(p).length;
  final sequences = RegExp(
    r'(0123|1234|2345|3456|4567|5678|6789|abcd|qwer)',
    caseSensitive: false,
  ).allMatches(p).length;

  return p.length * (math.log(pool) / math.ln2) -
      repeats * 4.0 -
      sequences * 3.0;
}

bool isCommonPassword(String p) =>
    kCommonPasswords.contains(p.toLowerCase().replaceAll(RegExp(r'\s'), ''));

/// 0 (very weak) .. 4 (strong). Common passwords are never above 1.
int passwordStrength(String p) {
  if (p.isEmpty) return 0;
  if (isCommonPassword(p) || p.length < 6) return 0;
  final entropy = passwordEntropy(p);
  if (entropy < 28) return 1;
  if (entropy < 50) return 2;
  if (entropy < 72) return 3;
  return 4;
}

const kStrengthLabels = ['Very weak', 'Weak', 'Okay', 'Good', 'Strong'];

/// Human-readable, deliberately conservative estimate.
String crackTimeLabel(String p) {
  if (p.isEmpty) return 'instantly';
  if (isCommonPassword(p)) return 'instantly (common password)';

  final bits = passwordEntropy(p);
  final seconds = math.pow(2, bits) / 2e10; // 20 billion guesses / second
  if (seconds < 1) return 'instantly';
  if (seconds < 60) return '${seconds.round()} seconds';
  if (seconds < 3600) return '${(seconds / 60).round()} minutes';
  if (seconds < 86400) return '${(seconds / 3600).round()} hours';
  if (seconds < 31536000) return '${(seconds / 86400).round()} days';
  final years = seconds / 31536000;
  if (years < 1000) return '${years.round()} years';
  return 'centuries';
}

String generatePassword({
  int length = 16,
  bool upper = true,
  bool digits = true,
  bool symbols = true,
  bool avoidAmbiguous = false,
  bool requireEach = true,
}) {
  var lowerPool = 'abcdefghijkmnopqrstuvwxyz';
  var upperPool = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  var digitPool = '23456789';
  var symbolPool = r'!@#$%^&*-_+=?';
  if (avoidAmbiguous) {
    lowerPool = lowerPool.replaceAll(RegExp(r'[lI1O0]'), '');
    upperPool = upperPool.replaceAll(RegExp(r'[ILO]'), '');
    digitPool = '23456789';
    symbolPool = symbolPool.replaceAll(RegExp(r'[|`~;:,\.]'), '');
  }

  final pools = <String>[
    lowerPool,
    if (upper) upperPool,
    if (digits) digitPool,
    if (symbols) symbolPool,
  ];
  final random = math.Random.secure();
  final alphabet = pools.join();

  length = math.max(length, requireEach ? pools.length : 1);
  final chars = <String>[
    if (requireEach)
      for (final pool in pools) pool[random.nextInt(pool.length)],
  ];
  while (chars.length < length) {
    chars.add(alphabet[random.nextInt(alphabet.length)]);
  }
  chars.shuffle(random);
  return chars.join();
}

const _wordList = <String>[
  'amber',
  'anchor',
  'atlas',
  'aurora',
  'badger',
  'banner',
  'bison',
  'bloom',
  'brave',
  'bridge',
  'canyon',
  'cedar',
  'comet',
  'coral',
  'cosmos',
  'crater',
  'crystal',
  'dawn',
  'delta',
  'ember',
  'falcon',
  'feather',
  'fjord',
  'flare',
  'forest',
  'frost',
  'galaxy',
  'glacier',
  'harbor',
  'hazel',
  'honey',
  'horizon',
  'indigo',
  'juniper',
  'lagoon',
  'lantern',
  'lunar',
  'maple',
  'meadow',
  'meteor',
  'mint',
  'nebula',
  'nimble',
  'noble',
  'ocean',
  'olive',
  'onyx',
  'opal',
  'orbit',
  'pebble',
  'pepper',
  'pixel',
  'prairie',
  'quartz',
  'raven',
  'reef',
  'river',
  'rocket',
  'sable',
  'shadow',
  'silver',
  'solar',
  'sonic',
  'sparrow',
  'summit',
  'sunset',
  'thistle',
  'tiger',
  'topaz',
  'torch',
  'velvet',
  'vertex',
  'violet',
  'walnut',
  'willow',
  'zephyr',
  'zircon',
];

/// Memorable but strong: e.g. "lagoon-quartz-rocket-ember".
String generatePassphrase({
  int words = 4,
  String separator = '-',
  bool capitalize = false,
  bool addNumber = true,
}) {
  final random = math.Random.secure();
  final picked = <String>[
    for (var i = 0; i < words; i++) _wordList[random.nextInt(_wordList.length)],
  ];

  if (capitalize) {
    for (var i = 0; i < picked.length; i++) {
      picked[i] = picked[i][0].toUpperCase() + picked[i].substring(1);
    }
  }

  // 0–99, deliberately not zero-padded.
  if (addNumber) picked.add(random.nextInt(90 + 10).toString());
  return picked.join(separator);
}

/// Turn "https://www.Google.com/path?x=1" into "google.com".
/// Also accepts package names and bare domains.
String normalizeDomain(String raw) {
  var s = raw.trim().toLowerCase();
  if (s.isEmpty) return '';

  s = s.split(RegExp(r'\s')).first;
  s = s.replaceFirst(RegExp(r'^[a-z][a-z0-9+.-]*://'), '');
  s = s.replaceFirst(RegExp(r'^\*\.'), '');
  s = s.split(RegExp(r'[/?#]')).first;

  final at = s.lastIndexOf('@');
  if (at >= 0) s = s.substring(at + 1);

  s = s.split(':').first;
  s = s.replaceFirst(RegExp(r'^www\.'), '');
  while (s.endsWith('.')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

String ago(int ms) {
  final difference =
      DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
  if (difference.inMinutes < 1) return 'just now';
  if (difference.inHours < 1) return '${difference.inMinutes}m ago';
  if (difference.inDays < 1) return '${difference.inHours}h ago';
  if (difference.inDays < 30) return '${difference.inDays}d ago';
  return '${(difference.inDays / 30).floor()}mo ago';
}

// --------------------------------------------------------- card helpers

String cardBrand(String number) {
  final n = number.replaceAll(' ', '');
  if (n.startsWith('4')) return 'VISA';
  if (RegExp(r'^(5[1-5]|2[2-7])').hasMatch(n)) return 'MASTERCARD';
  if (RegExp(r'^3[47]').hasMatch(n)) return 'AMEX';
  if (RegExp(r'^(508|60|65|81|82)').hasMatch(n)) return 'RUPAY';
  return 'CARD';
}

String maskedCard(String number, bool reveal) {
  final digits = number.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '•••• •••• •••• ••••';

  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && i % 4 == 0) buffer.write(' ');
    buffer.write(reveal || i >= digits.length - 4 ? digits[i] : '•');
  }
  return buffer.toString();
}

class CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 19) digits = digits.substring(0, 19);

    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 4) digits = digits.substring(0, 4);
    final text = digits.length > 2
        ? '${digits.substring(0, 2)}/${digits.substring(2)}'
        : digits;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

// ---------------------------------------------- unsaved work ("draft")

/// A snapshot of an in-progress editor, including pending image changes.
class Draft {
  final String type;
  final String? entryId;
  final String name;
  final Map<String, String> data;
  final String notes;
  final List<String> images;
  final List<String> added;
  final List<String> removed;
  final List<String> tags;
  final Map<String, String> custom;
  final int ts;

  Draft({
    required this.type,
    this.entryId,
    required this.name,
    required this.data,
    required this.notes,
    required this.images,
    required this.added,
    required this.removed,
    List<String>? tags,
    Map<String, String>? custom,
    int? ts,
  })  : tags = tags ?? <String>[],
        custom = custom ?? <String, String>{},
        ts = ts ?? DateTime.now().millisecondsSinceEpoch;

  ItemType get itemType => ItemType.values.firstWhere(
        (t) => t.name == type,
        orElse: () => ItemType.login,
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'entryId': entryId,
        'name': name,
        'data': data,
        'notes': notes,
        'images': images,
        'added': added,
        'removed': removed,
        'tags': tags,
        'custom': custom,
        'ts': ts,
      };

  factory Draft.fromJson(Map<String, dynamic> j) {
    List<String> strings(String key) =>
        (j[key] as List?)?.map((e) => '$e').toList() ?? <String>[];

    return Draft(
      type: j['type'] as String? ?? 'login',
      entryId: j['entryId'] as String?,
      name: j['name'] as String? ?? '',
      data: (j['data'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ??
          <String, String>{},
      notes: j['notes'] as String? ?? '',
      images: strings('images'),
      added: strings('added'),
      removed: strings('removed'),
      tags: strings('tags'),
      custom: (j['custom'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ??
          <String, String>{},
      ts: j['ts'] as int?,
    );
  }
}
