import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscriber.dart';

class SubscriberProvider with ChangeNotifier {
  static const String _subscribersKey = 'email_subscribers';

  List<Subscriber> _subscribers = [];
  bool _isLoading = true;

  SubscriberProvider() {
    _loadSubscribers();
  }

  List<Subscriber> get subscribers => _subscribers;
  bool get isLoading => _isLoading;

  List<Subscriber> get activeSubscribers =>
      _subscribers.where((s) => !s.isPaused).toList();

  List<Subscriber> get pausedSubscribers =>
      _subscribers.where((s) => s.isPaused).toList();

  Future<void> _loadSubscribers() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_subscribersKey);
      if (data != null) {
        final List<dynamic> jsonList = jsonDecode(data);
        _subscribers = jsonList
            .map((json) => Subscriber.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading subscribers: $e');
      _subscribers = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _saveSubscribers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _subscribers.map((s) => s.toJson()).toList();
      await prefs.setString(_subscribersKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving subscribers: $e');
    }
  }

  Future<void> addSubscriber({
    required String email,
    required String name,
    NotificationFrequency frequency = NotificationFrequency.daily,
    FeedPreference feedPreference = FeedPreference.all,
    bool highPriorityImmediate = true,
  }) async {
    // Check if email already exists
    if (_subscribers.any((s) => s.email.toLowerCase() == email.toLowerCase())) {
      throw Exception('Email already subscribed');
    }

    final subscriber = Subscriber(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      email: email,
      name: name,
      frequency: frequency,
      feedPreference: feedPreference,
      highPriorityImmediate: highPriorityImmediate,
      createdAt: DateTime.now(),
    );

    _subscribers.add(subscriber);
    await _saveSubscribers();
    notifyListeners();
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
}
