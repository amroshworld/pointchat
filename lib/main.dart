import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/auth_service.dart';
import 'appwrite_client.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ping Appwrite server to verify setup
  try {
    final pingResponse = await appwriteClient.ping();
    debugPrint('Appwrite Ping Successful: $pingResponse');
  } catch (e) {
    debugPrint('Appwrite Ping Error: $e');
  }

  // Load cached user info if session exists
  await AuthService().loadCurrentUser();

  runApp(const ProviderScope(child: FocusChatApp()));
}
