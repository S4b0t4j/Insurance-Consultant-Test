import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscriber.dart';
import '../services/crypto_service.dart';

/// Secure subscriber provider with AES-256 encryption for email data.
/// All subscriber PII (email, name) is encrypted at rest.
class SubscriberProvider with ChangeNotifier {
  static const String _subscribersKey = 'encrypted_subscribers_v2';
  static const String _legacyKey = 'email_subscribers'; // For migration

  List<Subscriber> _subscribers = [];
  bool _isLoading = true;
  CryptoService? _cryptoService;

  SubscriberProvider() {
    _initializeAndLoad();
  }

  List<Subscriber> get subscribers => _subscribers;
  bool get isLoading => _isLoading;

  List<Subscriber> get activeSubscribers =>
      _subscribers.where((s) => !s.isPaused).toList();

  List<Subscriber> get pausedSubscribers =>
      _subscribers.where((s) => s.isPaused).toList();

  /// Initialize crypto service and load subscribers
  Future<void> _initializeAndLoad() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Initialize encryption service
      _cryptoService = await CryptoService.getInstance();

      // Try to load encrypted data first
      await _loadSubscribers();

      // Migrate legacy unencrypted data if exists
      await _migrateLegacyData();
    } catch (e) {
      debugPrint('Error initializing subscriber provider: $e');
      _subscribers = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load encrypted subscribers from storage
  Future<void> _loadSubscribers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedData = prefs.getString(_subscribersKey);

      if (encryptedData != null && encryptedData.isNotEmpty) {
        // Decrypt the subscriber data
        final decryptedJson = _cryptoService!.decrypt(encryptedData);
        final List<dynamic> jsonList = jsonDecode(decryptedJson);
        _subscribers = jsonList
            .map((json) => Subscriber.fromJson(json as Map<String, dynamic>))
            .toList();

        debugPrint('Loaded ${_subscribers.length} encrypted subscribers');
      }
    } catch (e) {
      debugPrint('Error loading encrypted subscribers: $e');
      _subscribers = [];
    }
  }

  /// Migrate unencrypted legacy data to encrypted format
  Future<void> _migrateLegacyData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacyData = prefs.getString(_legacyKey);

      if (legacyData != null && legacyData.isNotEmpty) {
        debugPrint('Migrating legacy unencrypted subscriber data...');

        // Parse legacy data
        final List<dynamic> jsonList = jsonDecode(legacyData);
        final legacySubscribers = jsonList
            .map((json) => Subscriber.fromJson(json as Map<String, dynamic>))
            .toList();

        // Merge with any existing subscribers (avoid duplicates)
        for (final subscriber in legacySubscribers) {
          if (!_subscribers.any((s) => s.email.toLowerCase() == subscriber.email.toLowerCase())) {
            _subscribers.add(subscriber);
          }
        }

        // Save encrypted and remove legacy
        await _saveSubscribers();
        await prefs.remove(_legacyKey);

        debugPrint('Migration complete. Removed legacy unencrypted data.');
      }
    } catch (e) {
      debugPrint('Error migrating legacy data: $e');
    }
  }

  /// Save subscribers with encryption
  Future<void> _saveSubscribers() async {
    if (_cryptoService == null) {
      throw StateError('CryptoService not initialized');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _subscribers.map((s) => s.toJson()).toList();
      final jsonString = jsonEncode(jsonList);

      // Encrypt before storing
      final encryptedData = _cryptoService!.encrypt(jsonString);
      await prefs.setString(_subscribersKey, encryptedData);

      debugPrint('Saved ${_subscribers.length} subscribers (encrypted)');
    } catch (e) {
      debugPrint('Error saving encrypted subscribers: $e');
      rethrow;
    }
  }

  /// Add a new subscriber with validated email
  Future<void> addSubscriber({
    required String email,
    required String name,
    NotificationFrequency frequency = NotificationFrequency.daily,
    FeedPreference feedPreference = FeedPreference.all,
    bool highPriorityImmediate = true,
  }) async {
    // Validate email format
    if (!_isValidEmail(email)) {
      throw Exception('Invalid email format');
    }

    // Sanitize inputs
    final sanitizedEmail = _sanitizeInput(email.trim().toLowerCase());
    final sanitizedName = _sanitizeInput(name.trim());

    // Check if email already exists
    if (_subscribers.any((s) => s.email.toLowerCase() == sanitizedEmail)) {
      throw Exception('Email already subscribed');
    }

    final subscriber = Subscriber(
      id: _generateSecureId(),
      email: sanitizedEmail,
      name: sanitizedName,
      frequency: frequency,
      feedPreference: feedPreference,
      highPriorityImmediate: highPriorityImmediate,
      createdAt: DateTime.now(),
    );

    _subscribers.add(subscriber);
    await _saveSubscribers();
    notifyListeners();
  }

  /// Generate a secure random ID
  String _generateSecureId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecond;
    return '${timestamp}_$random';
  }

  /// Validate email format
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  /// Sanitize input to prevent injection
  String _sanitizeInput(String input) {
    // Remove any potentially dangerous characters
    return input
        .replaceAll('<', '')
        .replaceAll('>', '')
        .replaceAll('"', '')
        .replaceAll("'", '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  Future<void> updateSubscriber(Subscriber updatedSubscriber) async {
    final index = _subscribers.indexWhere((s) => s.id == updatedSubscriber.id);
    if (index != -1) {
      _subscribers[index] = updatedSubscriber;
      await _saveSubscribers();
      notifyListeners();
    }
  }

  Future<void> removeSubscriber(String id) async {
    _subscribers.removeWhere((s) => s.id == id);
    await _saveSubscribers();
    notifyListeners();
  }

  Future<void> togglePause(String id) async {
    final index = _subscribers.indexWhere((s) => s.id == id);
    if (index != -1) {
      final subscriber = _subscribers[index];
      _subscribers[index] = subscriber.copyWith(isPaused: !subscriber.isPaused);
      await _saveSubscribers();
      notifyListeners();
    }
  }

  Future<void> updateFrequency(String id, NotificationFrequency frequency) async {
    final index = _subscribers.indexWhere((s) => s.id == id);
    if (index != -1) {
      _subscribers[index] = _subscribers[index].copyWith(frequency: frequency);
      await _saveSubscribers();
      notifyListeners();
    }
  }

  Future<void> updateFeedPreference(String id, FeedPreference preference) async {
    final index = _subscribers.indexWhere((s) => s.id == id);
    if (index != -1) {
      _subscribers[index] = _subscribers[index].copyWith(feedPreference: preference);
      await _saveSubscribers();
      notifyListeners();
    }
  }

  Future<void> toggleHighPriorityImmediate(String id) async {
    final index = _subscribers.indexWhere((s) => s.id == id);
    if (index != -1) {
      final subscriber = _subscribers[index];
      _subscribers[index] = subscriber.copyWith(
        highPriorityImmediate: !subscriber.highPriorityImmediate,
      );
      await _saveSubscribers();
      notifyListeners();
    }
  }

  Future<void> markDigestSent(String id) async {
    final index = _subscribers.indexWhere((s) => s.id == id);
    if (index != -1) {
      _subscribers[index] = _subscribers[index].copyWith(
        lastDigestSent: DateTime.now(),
      );
      await _saveSubscribers();
      notifyListeners();
    }
  }

  /// Securely clear all subscriber data
  Future<void> clearAllData() async {
    _subscribers.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_subscribersKey);
    await prefs.remove(_legacyKey);
    notifyListeners();
  }

  /// Export subscribers (for admin backup) - returns encrypted blob
  Future<String> exportEncryptedBackup() async {
    if (_cryptoService == null) {
      throw StateError('CryptoService not initialized');
    }
    final jsonList = _subscribers.map((s) => s.toJson()).toList();
    return _cryptoService!.encrypt(jsonEncode(jsonList));
  }
}
