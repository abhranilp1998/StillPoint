import 'dart:convert';

import 'package:crypto/crypto.dart';

class SecurityService {
  static String hashPin(String pin) {
    return sha256.convert(utf8.encode('stillpoint:$pin')).toString();
  }

  static bool isPinFormat(String pin) {
    return RegExp(r'^\d{4,8}$').hasMatch(pin);
  }
}
