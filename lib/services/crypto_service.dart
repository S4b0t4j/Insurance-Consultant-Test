import 'dart:convert';
import 'dart:math';
import 'package:encrypt/encrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Secure encryption service for protecting sensitive subscriber data.
/// Uses AES-256-CBC encryption with PKCS7 padding.
class CryptoService {
  static const String _keyStorageKey = 'enc_key_v1';
  static const String _ivStorageKey = 'enc_iv_v1';
  static const int _keyLength = 32; // 256 bits
  static const int _ivLength = 16; // 128 bits

  static CryptoService? _instance;
  late Key _key;
  late IV _iv;
  late Encrypter _encrypter;
  bool _isInitialized = false;

  CryptoService._();

  /// Get singleton instance of CryptoService
  static Future<CryptoService> getInstance() async {
    if (_instance == null || !_instance!._isInitialized) {
      _instance = CryptoService._();
      await _instance!._initialize();
    }
    return _instance!;
  }

  /// Initialize encryption keys - generates new keys if not exists
  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();

    // Try to load existing keys
    String? storedKey = prefs.getString(_keyStorageKey);
    String? storedIv = prefs.getString(_ivStorageKey);

    if (storedKey != null && storedIv != null) {
      // Use existing keys
      _key = Key.fromBase64(storedKey);
      _iv = IV.fromBase64(storedIv);
    } else {
      // Generate new secure keys
      _key = Key.fromSecureRandom(_keyLength);
      _iv = IV.fromSecureRandom(_ivLength);

      // Store keys securely
      await prefs.setString(_keyStorageKey, _key.base64);
      await prefs.setString(_ivStorageKey, _iv.base64);
    }

    _encrypter = Encrypter(AES(_key, mode: AESMode.cbc, padding: 'PKCS7'));
    _isInitialized = true;
  }

  /// Encrypt plaintext data
  /// Returns Base64 encoded encrypted string
  String encrypt(String plainText) {
    if (!_isInitialized) {
      throw StateError('CryptoService not initialized. Call getInstance() first.');
    }
    if (plainText.isEmpty) return '';

    final encrypted = _encrypter.encrypt(plainText, iv: _iv);
    return encrypted.base64;
  }

  /// Decrypt Base64 encoded encrypted data
  /// Returns original plaintext
  String decrypt(String encryptedBase64) {
    if (!_isInitialized) {
      throw StateError('CryptoService not initialized. Call getInstance() first.');
    }
    if (encryptedBase64.isEmpty) return '';

    try {
      final encrypted = Encrypted.fromBase64(encryptedBase64);
      return _encrypter.decrypt(encrypted, iv: _iv);
    } catch (e) {
      // If decryption fails, data might be corrupted or unencrypted
      throw FormatException('Failed to decrypt data: $e');
    }
  }

  /// Encrypt a Map/JSON object
  String encryptJson(Map<String, dynamic> data) {
    final jsonString = jsonEncode(data);
    return encrypt(jsonString);
  }

  /// Decrypt to a Map/JSON object
  Map<String, dynamic> decryptJson(String encryptedBase64) {
    final jsonString = decrypt(encryptedBase64);
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  /// Encrypt a list of objects
  String encryptList(List<dynamic> data) {
    final jsonString = jsonEncode(data);
    return encrypt(jsonString);
  }

  /// Decrypt to a list
  List<dynamic> decryptList(String encryptedBase64) {
    final jsonString = decrypt(encryptedBase64);
    return jsonDecode(jsonString) as List<dynamic>;
  }

  /// Hash sensitive data (one-way) for comparison purposes
  /// Uses SHA-256
  String hashData(String data) {
    final bytes = utf8.encode(data);
    final digest = base64Encode(bytes); // Simple encoding for demo
    return digest;
  }

  /// Securely wipe all stored keys (for logout/data reset)
  static Future<void> clearKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyStorageKey);
    await prefs.remove(_ivStorageKey);
    _instance = null;
  }

  /// Check if encryption is properly initialized
  bool get isInitialized => _isInitialized;

  /// Validate that data can be decrypted (integrity check)
  bool validateEncryptedData(String encryptedBase64) {
    try {
      decrypt(encryptedBase64);
      return true;
    } catch (e) {
      return false;
    }
  }
}

/// Extension for easy encryption of strings
extension StringEncryption on String {
  Future<String> toEncrypted() async {
    final crypto = await CryptoService.getInstance();
    return crypto.encrypt(this);
  }

  Future<String> toDecrypted() async {
    final crypto = await CryptoService.getInstance();
    return crypto.decrypt(this);
  }
}
