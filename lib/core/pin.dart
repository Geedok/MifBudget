import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Longueur du code de verrouillage.
const pinLength = 4;

/// Sel aléatoire pour le code de verrouillage.
String newPinSalt() {
  final random = Random.secure();
  return base64Url.encode(List.generate(16, (_) => random.nextInt(256)));
}

/// Empreinte du code : SHA-256 de sel + code (le code n'est jamais gardé).
String hashPin(String pin, String salt) =>
    sha256.convert(utf8.encode('$salt:$pin')).toString();
