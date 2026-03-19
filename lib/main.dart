import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/subscription_service.dart';
import 'appwrite_client.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(const ProviderScope(child: FocusChatApp()));
}
