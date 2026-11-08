import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class HashService {
  static Future<String> hashFile(String filePath) async {
    try {
      final file  = File(filePath);
      final bytes = await file.readAsBytes();
      final hash  = sha256.convert(bytes);
      return hash.toString();
    } catch (e) {
      return 'ERROR: $e';
    }
  }

  static String hashString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  static Future<bool> verifyFile(
      String filePath, String expectedHash) async {
    final actualHash = await hashFile(filePath);
    return actualHash == expectedHash;
  }
}