// ============================================================
// security_helper.dart  —  part of liquid_logistics main library
// Add this as a NEW file at:  lib/src/security_helper.dart
// Then register it in main.dart with:  part 'src/security_helper.dart';
// ------------------------------------------------------------
// Provides:
//   • AppCrypto      — AES-256-GCM encrypt/decrypt for files & strings
//   • SecureStore    — encrypted key/value using flutter_secure_storage
//   • Pii            — masking helpers so logs never leak Aadhaar/phone
// ------------------------------------------------------------
// REQUIRES these packages in pubspec.yaml (see instructions doc):
//   encrypt: ^5.0.3
//   flutter_secure_storage: ^9.2.2
//   crypto: ^3.0.6
// And these imports in main.dart (see instructions doc).
// ============================================================
part of 'package:liquid_logistics/main.dart';

// ────────────────────────────────────────────────────────────
// AES-256-GCM encryption for KYC documents and sensitive text.
// The master key is derived once, stored in the OS keystore via
// SecureStore, and never written to source or Firestore.
// ────────────────────────────────────────────────────────────
class AppCrypto {
  static enc.Key? _cachedKey;

  // Get (or lazily create) the device master key from secure storage.
  static Future<enc.Key> _masterKey() async {
    if (_cachedKey != null) return _cachedKey!;
    var b64 = await SecureStore.read('kyc_master_key');
    if (b64 == null || b64.isEmpty) {
      final fresh = enc.Key.fromSecureRandom(32); // 256-bit
      b64 = fresh.base64;
      await SecureStore.write('kyc_master_key', b64);
    }
    _cachedKey = enc.Key.fromBase64(b64);
    return _cachedKey!;
  }

  // Encrypt raw bytes (e.g. a KYC image/PDF). Returns iv-prefixed bytes.
  static Future<Uint8List> encryptBytes(Uint8List plain) async {
    final key = await _masterKey();
    final iv = enc.IV.fromSecureRandom(12); // GCM standard nonce
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    final encrypted = encrypter.encryptBytes(plain, iv: iv);
    // Prepend the 12-byte IV so we can decrypt later.
    final out = BytesBuilder();
    out.add(iv.bytes);
    out.add(encrypted.bytes);
    return out.toBytes();
  }

  // Decrypt iv-prefixed bytes produced by encryptBytes.
  static Future<Uint8List> decryptBytes(Uint8List blob) async {
    final key = await _masterKey();
    final iv = enc.IV(blob.sublist(0, 12));
    final body = blob.sublist(12);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    final decrypted = encrypter.decryptBytes(enc.Encrypted(body), iv: iv);
    return Uint8List.fromList(decrypted);
  }

  // Encrypt a short string (e.g. Aadhaar number) → base64 blob for Firestore.
  static Future<String> encryptString(String plain) async {
    if (plain.isEmpty) return '';
    final bytes = Uint8List.fromList(utf8.encode(plain));
    final blob = await encryptBytes(bytes);
    return base64Encode(blob);
  }

  // Decrypt a base64 blob back to the original string.
  static Future<String> decryptString(String b64) async {
    if (b64.isEmpty) return '';
    try {
      final blob = base64Decode(b64);
      final bytes = await decryptBytes(Uint8List.fromList(blob));
      return utf8.decode(bytes);
    } catch (_) {
      // If it wasn't encrypted (legacy plaintext), return as-is.
      return b64;
    }
  }
}

// ────────────────────────────────────────────────────────────
// SecureStore — thin wrapper over flutter_secure_storage.
// Use this for the admin PIN hash, session tokens, master key.
// NEVER use SharedPreferences for these.
// ────────────────────────────────────────────────────────────
class SecureStore {
  static const _s = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static Future<void> write(String k, String v) => _s.write(key: k, value: v);
  static Future<String?> read(String k) => _s.read(key: k);
  static Future<void> delete(String k) => _s.delete(key: k);
  static Future<void> wipeAll() => _s.deleteAll();
}

// ────────────────────────────────────────────────────────────
// Pii — masking so debug logs never print full sensitive values.
// Use: debugPrint(Pii.phone(number))  instead of  debugPrint(number)
// ────────────────────────────────────────────────────────────
class Pii {
  static String phone(String p) {
    final d = p.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.length < 4) return '****';
    return '${'*' * (d.length - 4)}${d.substring(d.length - 4)}';
  }

  static String aadhaar(String a) {
    final d = a.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.length < 4) return '********';
    return 'XXXX-XXXX-${d.substring(d.length - 4)}';
  }

  static String generic(String s) =>
      s.length <= 2 ? '**' : '${s[0]}***${s[s.length - 1]}';
}
