import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../appwrite_client.dart';

class RevenueCatConfig {
  static const String entitlementId = 'ai_access';
  static const String androidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
    defaultValue: 'goog_TERmGBEENicfFTgbipVDDIItzWL',
  );
  static const String iosApiKey = String.fromEnvironment(
    'REVENUECAT_IOS_API_KEY',
    defaultValue: 'appl_ADugYdOCqeDqvVufcLTapimDzGx',
  );

  static String? get apiKey {
    if (kIsWeb) {
      return null;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return androidApiKey.isEmpty ? null : androidApiKey;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return iosApiKey.isEmpty ? null : iosApiKey;
    }
    return null;
  }
}

class ReviewerAccessConfig {
  static const bool enabled = bool.fromEnvironment(
    'REVIEWER_FREE_AI_ENABLED',
    defaultValue: true,
  );
  static const String _userIdsCsv = String.fromEnvironment(
    'REVIEWER_FREE_AI_USER_IDS',
    defaultValue: 'reviewer_ai_01',
  );
  static const String _emailsCsv = String.fromEnvironment(
    'REVIEWER_FREE_AI_EMAILS',
    defaultValue: 'reviewer.ai.pointchat@gmail.com',
  );

  static final Set<String> userIds = _parseCsv(_userIdsCsv);
  static final Set<String> emails = _parseCsv(_emailsCsv);

  static Set<String> _parseCsv(String raw) {
    return raw
        .split(',')
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();
  }
}

class SubscriptionState {
  final bool isReady;
  final bool isConfigured;
  final bool isBusy;
  final bool hasAiAccess;
  final String? message;
  final Offering? offering;

  const SubscriptionState({
    required this.isReady,
    required this.isConfigured,
    required this.isBusy,
    required this.hasAiAccess,
    this.message,
    this.offering,
  });

  const SubscriptionState.initial()
      : isReady = false,
        isConfigured = false,
        isBusy = false,
        hasAiAccess = false,
        message = null,
        offering = null;

  SubscriptionState copyWith({
    bool? isReady,
    bool? isConfigured,
    bool? isBusy,
    bool? hasAiAccess,
    String? message,
    bool clearMessage = false,
    Offering? offering,
    bool clearOffering = false,
  }) {
    return SubscriptionState(
      isReady: isReady ?? this.isReady,
      isConfigured: isConfigured ?? this.isConfigured,
      isBusy: isBusy ?? this.isBusy,
      hasAiAccess: hasAiAccess ?? this.hasAiAccess,
      message: clearMessage ? null : (message ?? this.message),
      offering: clearOffering ? null : (offering ?? this.offering),
    );
  }
}

class SubscriptionService {
  SubscriptionService._internal();

  static final SubscriptionService instance = SubscriptionService._internal();

  final ValueNotifier<SubscriptionState> state = ValueNotifier(
    const SubscriptionState.initial(),
  );

  bool _isConfigured = false;
  bool _listenerAttached = false;

  bool get hasAiAccess => state.value.hasAiAccess;
  bool get isReviewerAiAccess => _hasReviewerAiAccess();

  bool _hasReviewerAiAccess() {
    if (!ReviewerAccessConfig.enabled) {
      return false;
    }

    final normalizedUserId = cachedUserId.trim().toLowerCase();
    if (normalizedUserId.isNotEmpty &&
        ReviewerAccessConfig.userIds.contains(normalizedUserId)) {
      return true;
    }

    final normalizedEmail = cachedUserEmail.trim().toLowerCase();
    if (normalizedEmail.isNotEmpty &&
        ReviewerAccessConfig.emails.contains(normalizedEmail)) {
      return true;
    }

    return false;
  }

  String _reviewerAccessMessage() {
    return 'Reviewer AI access is active for this account.';
  }

  Future<void> initialize({String? appUserId}) async {
    final reviewerAccess = _hasReviewerAiAccess();
    final apiKey = RevenueCatConfig.apiKey;
    if (apiKey == null || apiKey.isEmpty) {
      final setupMessage = kIsWeb
          ? 'Purchases are currently available on mobile only.'
          : 'Subscription setup is incomplete. Please try again later.';
      state.value = state.value.copyWith(
        isReady: true,
        isConfigured: false,
        hasAiAccess: reviewerAccess,
        message: reviewerAccess ? _reviewerAccessMessage() : setupMessage,
        clearOffering: true,
      );
      return;
    }

    if (!_isConfigured) {
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }

      final configuration = PurchasesConfiguration(apiKey);
      if (appUserId != null && appUserId.isNotEmpty) {
        configuration.appUserID = appUserId;
      }

      await Purchases.configure(configuration);
      _isConfigured = true;
    } else if (appUserId != null && appUserId.isNotEmpty) {
      await Purchases.logIn(appUserId);
    }

    if (!_listenerAttached) {
      Purchases.addCustomerInfoUpdateListener(_handleCustomerInfo);
      _listenerAttached = true;
    }

    await refresh();
  }

  Future<void> logIn(String userId) async {
    if (userId.isEmpty) {
      return;
    }
    await initialize(appUserId: userId);
  }

  Future<void> logOut() async {
    if (_isConfigured) {
      await Purchases.logOut();
    }

    state.value = state.value.copyWith(
      isReady: true,
      isBusy: false,
      hasAiAccess: false,
      clearMessage: true,
      clearOffering: true,
    );
  }

  Future<void> refresh() async {
    if (!_isConfigured) {
      final reviewerAccess = _hasReviewerAiAccess();
      state.value = state.value.copyWith(
        isReady: true,
        isBusy: false,
        hasAiAccess: reviewerAccess,
        message:
            reviewerAccess ? _reviewerAccessMessage() : state.value.message,
      );
      return;
    }

    state.value = state.value.copyWith(isBusy: true, clearMessage: true);

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final offerings = await Purchases.getOfferings();
      _applyCustomerInfo(customerInfo, offerings.current);
    } on PlatformException {
      final reviewerAccess = _hasReviewerAiAccess();
      state.value = state.value.copyWith(
        isReady: true,
        isBusy: false,
        hasAiAccess: reviewerAccess,
        message: reviewerAccess
            ? _reviewerAccessMessage()
            : 'Subscription status is unavailable right now. Please try again.',
      );
    } catch (_) {
      final reviewerAccess = _hasReviewerAiAccess();
      state.value = state.value.copyWith(
        isReady: true,
        isBusy: false,
        hasAiAccess: reviewerAccess,
        message: reviewerAccess
            ? _reviewerAccessMessage()
            : 'Subscription status is unavailable right now. Please try again.',
      );
    }
  }

  Future<bool> ensureAiAccess() async {
    await initialize(appUserId: cachedUserId.isEmpty ? null : cachedUserId);
    if (_isConfigured) {
      await refresh();
    }
    return hasAiAccess || _hasReviewerAiAccess();
  }

  Future<bool> purchasePackage(Package package) async {
    if (!_isConfigured) {
      return false;
    }

    state.value = state.value.copyWith(isBusy: true, clearMessage: true);

    try {
      final purchaseResult = await Purchases.purchase(
        PurchaseParams.package(package),
      );
      final offerings = await Purchases.getOfferings();
      _applyCustomerInfo(purchaseResult.customerInfo, offerings.current);
      return state.value.hasAiAccess;
    } on PlatformException catch (error) {
      final errorCode = PurchasesErrorHelper.getErrorCode(error);
      final isCancelled =
          errorCode == PurchasesErrorCode.purchaseCancelledError;
      final reviewerAccess = _hasReviewerAiAccess();
      state.value = state.value.copyWith(
        isReady: true,
        isBusy: false,
        hasAiAccess: reviewerAccess,
        message: reviewerAccess
            ? _reviewerAccessMessage()
            : (isCancelled
                ? 'Purchase canceled.'
                : 'Purchase could not be completed. Please try again.'),
      );
      return false;
    } catch (error) {
      final reviewerAccess = _hasReviewerAiAccess();
      state.value = state.value.copyWith(
        isReady: true,
        isBusy: false,
        hasAiAccess: reviewerAccess,
        message: reviewerAccess
            ? _reviewerAccessMessage()
            : 'Purchase could not be completed. Please try again.',
      );
      return false;
    }
  }

  Future<void> restorePurchases() async {
    if (!_isConfigured) {
      return;
    }

    state.value = state.value.copyWith(isBusy: true, clearMessage: true);

    try {
      final customerInfo = await Purchases.restorePurchases();
      final offerings = await Purchases.getOfferings();
      _applyCustomerInfo(customerInfo, offerings.current);
    } on PlatformException {
      final reviewerAccess = _hasReviewerAiAccess();
      state.value = state.value.copyWith(
        isReady: true,
        isBusy: false,
        hasAiAccess: reviewerAccess,
        message: reviewerAccess
            ? _reviewerAccessMessage()
            : 'Restore failed. Please try again.',
      );
    } catch (error) {
      final reviewerAccess = _hasReviewerAiAccess();
      state.value = state.value.copyWith(
        isReady: true,
        isBusy: false,
        hasAiAccess: reviewerAccess,
        message: reviewerAccess
            ? _reviewerAccessMessage()
            : 'Restore failed. Please try again.',
      );
    }
  }

  /// iOS: App Store subscription offer codes. Returns false on other platforms (use Play Console promos on Android).
  Future<bool> presentSubscriptionOfferCodeSheet() async {
    if (kIsWeb || !_isConfigured) {
      return false;
    }
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    try {
      await Purchases.presentCodeRedemptionSheet();
      return true;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  void _handleCustomerInfo(CustomerInfo customerInfo) {
    _applyCustomerInfo(customerInfo, state.value.offering);
  }

  void _applyCustomerInfo(CustomerInfo customerInfo, Offering? offering) {
    final entitlement =
        customerInfo.entitlements.active[RevenueCatConfig.entitlementId];
    final reviewerAccess = _hasReviewerAiAccess();
    state.value = state.value.copyWith(
      isReady: true,
      isConfigured: true,
      isBusy: false,
      hasAiAccess: entitlement?.isActive == true || reviewerAccess,
      offering: offering,
      message: reviewerAccess ? _reviewerAccessMessage() : null,
      clearMessage: !reviewerAccess,
    );
  }
}
