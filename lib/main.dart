import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/auth_service.dart';
import 'utils/chat_privacy_preferences.dart';
import 'services/notification_service.dart';
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
  try {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top],
    );
  } catch (e) {
    debugPrint('SystemUiMode notice: $e');
  }

  // Ping Appwrite server to verify setup
  try {
    final pingResponse = await appwriteClient.ping();
    debugPrint('Appwrite Ping Successful: $pingResponse');
  } catch (e) {
    debugPrint('Appwrite Ping Error: $e');
  }

  // Load cached user info if session exists
  try {
    await AuthService().loadCurrentUser();
  } catch (e) {
    debugPrint('AuthService loadCurrentUser error: $e');
  }

  try {
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('NotificationService initialization error: $e');
  }

  try {
    await ChatPrivacyPreferences.syncAppLockListenable();
  } catch (e) {
    debugPrint('ChatPrivacyPreferences sync error: $e');
  }

  runApp(const ProviderScope(child: FocusChatApp()));
}
