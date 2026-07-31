import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/auth_service.dart';
import 'utils/chat_privacy_preferences.dart';
import 'services/notification_service.dart';
import 'services/subscription_service.dart';
import 'services/analytics_service.dart';
import 'appwrite_client.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (safely catch if config file is pending platform setup)
  try {
    await Firebase.initializeApp();
    await AnalyticsService.instance.initialize();
    debugPrint('Firebase & Analytics initialized successfully.');
  } catch (e) {
    debugPrint('Firebase initialization notice: $e');
  }

  // Hide the native Android bottom navigation bar
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.top],
  );

  // Ping Appwrite server to verify setup
  try {
    final pingResponse = await appwriteClient.ping();
    debugPrint('Appwrite Ping Successful: $pingResponse');
  } catch (e) {
    debugPrint('Appwrite Ping Error: $e');
  }

  await SubscriptionService.instance.initialize();

  // Load cached user info if session exists
  await AuthService().loadCurrentUser();
  await NotificationService.instance.initialize();
  await ChatPrivacyPreferences.syncAppLockListenable();

  runApp(const ProviderScope(child: FocusChatApp()));
}
