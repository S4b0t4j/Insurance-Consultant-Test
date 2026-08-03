import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  static const _usersKey = 'app_users_v1';
  static const _sessionKey = 'app_session_v1';
  static const _onboardingKey = 'app_onboarded_';

  final List<AppUser> _users = [];
  AppUser? _currentUser;
  bool _initialized = false;

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get initialized => _initialized;
  List<AppUser> get users => List.unmodifiable(_users);

  /// Report Studio / Risk Desk gate: default deny, admins implicit.
  bool get canUseReportStudio =>
      _currentUser != null &&
      (_currentUser!.isAdmin || _currentUser!.canUseReportStudio);

  AuthProvider() {
    _bootstrap();
  }

  String _hashPassword(String password) {
    final salt = 'vantage_public_sector_2026';
    final bytes = utf8.encode('$salt:$password');
    return crypto.sha256.convert(bytes).toString();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_usersKey);
    if (raw != null) {
      final List list = jsonDecode(raw);
      _users.addAll(list.map((j) => AppUser.fromJson(j)));
    }

    // Seed default admin if none exist
    if (_users.where((u) => u.isAdmin).isEmpty) {
      _users.add(AppUser(
        id: 'admin-seed',
        email: 'admin@vantage.local',
        displayName: 'VANTAGE Admin',
        passwordHash: _hashPassword('vantage2026'),
        role: UserRole.admin,
        createdAt: DateTime.now(),
      ));
      await _persist();
    }

    final sessionId = prefs.getString(_sessionKey);
    if (sessionId != null) {
      try {
        _currentUser = _users.firstWhere((u) => u.id == sessionId && u.active);
      } catch (_) {
        _currentUser = null;
      }
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _usersKey,
      jsonEncode(_users.map((u) => u.toJson()).toList()),
    );
  }

  Future<bool> login(String email, String password) async {
    final hashed = _hashPassword(password);
    try {
      final user = _users.firstWhere(
        (u) =>
            u.email.toLowerCase() == email.toLowerCase().trim() &&
            u.passwordHash == hashed &&
            u.active,
      );
      _currentUser = user.copyWith(lastLoginAt: DateTime.now());
      // Update record
      final idx = _users.indexWhere((u) => u.id == user.id);
      _users[idx] = _currentUser!;
      await _persist();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, user.id);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    notifyListeners();
  }

  Future<bool> addUser({
    required String email,
    required String displayName,
    required String password,
    UserRole role = UserRole.viewer,
  }) async {
    final clean = email.toLowerCase().trim();
    if (_users.any((u) => u.email.toLowerCase() == clean)) {
      return false;
    }
    _users.add(AppUser(
      id: 'u_${DateTime.now().millisecondsSinceEpoch}',
      email: clean,
      displayName: displayName.trim(),
      passwordHash: _hashPassword(password),
      role: role,
      createdAt: DateTime.now(),
    ));
    await _persist();
    notifyListeners();
    return true;
  }

  Future<void> removeUser(String id) async {
    _users.removeWhere((u) => u.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> toggleActive(String id) async {
    final idx = _users.indexWhere((u) => u.id == id);
    if (idx == -1) return;
    _users[idx] = _users[idx].copyWith(active: !_users[idx].active);
    await _persist();
    notifyListeners();
  }

  /// Returns the new grant state, or null if the user wasn't found.
  Future<bool?> toggleReportStudioAccess(String id) async {
    final idx = _users.indexWhere((u) => u.id == id);
    if (idx == -1) return null;
    final next = !_users[idx].canUseReportStudio;
    _users[idx] = _users[idx].copyWith(canUseReportStudio: next);
    if (_currentUser?.id == id) _currentUser = _users[idx];
    await _persist();
    notifyListeners();
    return next;
  }

  Future<bool> hasSeenOnboarding() async {
    if (_currentUser == null) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_onboardingKey${_currentUser!.id}') ?? false;
  }

  Future<void> markOnboardingComplete() async {
    if (_currentUser == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_onboardingKey${_currentUser!.id}', true);
  }
}
