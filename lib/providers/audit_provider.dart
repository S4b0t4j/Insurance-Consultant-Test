import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/audit_event.dart';
import '../models/user.dart';

/// Persists an advisory audit trail (ring buffer of 500 events) in
/// SharedPreferences. Client-side only — the authoritative access log is the
/// hosting layer (see docs/DEPLOYMENT.md).
class AuditProvider extends ChangeNotifier {
  static const _storageKey = 'audit_log_v1';
  static const int maxEvents = 500;

  final List<AuditEvent> _events = [];
  bool _loaded = false;
  AppUser? _currentUser;

  List<AuditEvent> get events => List.unmodifiable(_events.reversed.toList());

  AuditProvider() {
    _load();
  }

  /// Wired from main.dart so events are stamped with the acting user.
  void updateCurrentUser(AppUser? user) {
    _currentUser = user;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final List list = jsonDecode(raw);
        _events.addAll(list
            .whereType<Map<String, dynamic>>()
            .map(AuditEvent.fromJson));
      } catch (_) {
        // Corrupt log: start fresh rather than blocking the app.
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_events.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> log(AuditAction action,
      {String detail = '', String? userEmail, String? userId}) async {
    if (!_loaded) await _load();
    _events.add(AuditEvent(
      id: 'ae_${DateTime.now().microsecondsSinceEpoch}',
      timestamp: DateTime.now(),
      userId: userId ?? _currentUser?.id ?? 'anonymous',
      userEmail: userEmail ?? _currentUser?.email ?? 'anonymous',
      action: action,
      detail: detail,
    ));
    while (_events.length > maxEvents) {
      _events.removeAt(0);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    _events.clear();
    await _persist();
    notifyListeners();
  }

  String exportJson() =>
      const JsonEncoder.withIndent('  ')
          .convert(_events.map((e) => e.toJson()).toList());
}
