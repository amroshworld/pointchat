import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  AnalyticsService._internal();
  static final AnalyticsService instance = AnalyticsService._internal();

  FirebaseAnalytics? _analytics;
  bool _isInitialized = false;

  FirebaseAnalytics? get analytics => _analytics;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      _analytics = FirebaseAnalytics.instance;
      _isInitialized = true;
      await _analytics?.setAnalyticsCollectionEnabled(true);
      if (kDebugMode) {
        debugPrint('AnalyticsService initialized successfully.');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AnalyticsService initialization notice: $e');
      }
    }
  }

  /// Sets the user ID for analytics & ad conversion attribution
  Future<void> setUserId(String userId) async {
    if (!_isInitialized) await initialize();
    try {
      await _analytics?.setUserId(id: userId.isEmpty ? null : userId);
    } catch (e) {
      if (kDebugMode) debugPrint('Analytics setUserId error: $e');
    }
  }
}
