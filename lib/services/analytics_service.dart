import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

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

  /// Sets user properties like subscription status
  Future<void> setUserSubscriptionStatus({required bool isSubscribed}) async {
    if (!_isInitialized) await initialize();
    try {
      await _analytics?.setUserProperty(
        name: 'subscription_status',
        value: isSubscribed ? 'pro' : 'free',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Analytics setUserProperty error: $e');
    }
  }

  /// Log when user views the subscription paywall modal
  Future<void> logPaywallImpression({String? source}) async {
    if (!_isInitialized) await initialize();
    try {
      await _analytics?.logEvent(
        name: 'paywall_impression',
        parameters: {
          'source': source ?? 'ai_feature_prompt',
        },
      );
      if (kDebugMode) debugPrint('Analytics Event: paywall_impression');
    } catch (e) {
      if (kDebugMode) debugPrint('Analytics logPaywallImpression error: $e');
    }
  }

  /// Log when user cancels/dismisses paywall
  Future<void> logPaywallCancelled() async {
    if (!_isInitialized) await initialize();
    try {
      await _analytics?.logEvent(name: 'paywall_cancelled');
      if (kDebugMode) debugPrint('Analytics Event: paywall_cancelled');
    } catch (e) {
      if (kDebugMode) debugPrint('Analytics logPaywallCancelled error: $e');
    }
  }

  /// Core conversion tracker: Log subscription purchase for Google Ads & TikTok Ads
  Future<void> logSubscriptionPurchase(Package package) async {
    if (!_isInitialized) await initialize();
    try {
      final product = package.storeProduct;
      final price = product.price;
      final currency = product.currencyCode;
      final packageId = package.identifier;
      final productId = product.identifier;
      final title = product.title;
      final packageType = package.packageType.name;

      // 1. Standard E-commerce / Revenue Purchase event (Google Ads & GA4 auto-conversion)
      await _analytics?.logPurchase(
        currency: currency,
        value: price,
        transactionId: 'rc_${productId}_${DateTime.now().millisecondsSinceEpoch}',
        items: [
          AnalyticsEventItem(
            itemId: packageId,
            itemName: title,
            itemCategory: 'subscription',
            price: price,
            quantity: 1,
          ),
        ],
      );

      // 2. Standard Subscribe event (recognized by Google Ads & TikTok Ads conversion goals)
      await _analytics?.logEvent(
        name: 'subscribe',
        parameters: {
          'currency': currency,
          'value': price,
          'product_id': productId,
          'package_id': packageId,
          'plan_type': packageType,
        },
      );

      // 3. Custom conversion event for campaign ROAS calculation
      await _analytics?.logEvent(
        name: 'subscription_completed',
        parameters: {
          'currency': currency,
          'value': price,
          'package_id': packageId,
          'plan_type': packageType,
          'price_string': product.priceString,
        },
      );

      // Update user subscription state in analytics
      await setUserSubscriptionStatus(isSubscribed: true);

      if (kDebugMode) {
        debugPrint(
          'Analytics Subscription Logged: price=$price $currency package=$packageId',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Analytics logSubscriptionPurchase error: $e');
    }
  }

  /// Log AI usage event
  Future<void> logAiUsage({required String feature}) async {
    if (!_isInitialized) await initialize();
    try {
      await _analytics?.logEvent(
        name: 'ai_usage',
        parameters: {'feature': feature},
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Analytics logAiUsage error: $e');
    }
  }
}
