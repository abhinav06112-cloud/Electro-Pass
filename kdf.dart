import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'vault_crypto.dart';

// Cost of deriving a key from a PIN. A short PIN is only a deterrent, so this
// stays quick enough for everyday unlocks.
const int kPinIter = 30000;

// Account password and recovery key guard the encrypted cloud copy, so they
// use a deliberately higher work factor.
const int kAccountIter = 150000;
const int kRecoveryIter = 100000;

/// Entry point run on the isolate by [deriveKey].
///
/// The arguments travel as plain lists/ints through `compute`, hence the
/// casts back to the concrete types used by PBKDF2.
Uint8List _derive(List<dynamic> args) => VaultCrypto.pbkdf2(
      args[0] as List<int>,
      args[1] as List<int>,
      args[2] as int,
    );

/// Derives a 256-bit key on a background isolate to keep the UI responsive.
Future<Uint8List> deriveKey(String secret, Uint8List salt, int iterations) =>
    compute(_derive, <dynamic>[utf8.encode(secret), salt, iterations]);
