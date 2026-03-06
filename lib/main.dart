import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/auth_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load cached user info if session exists
  await AuthService().loadCurrentUser();

  runApp(const ProviderScope(child: FocusChatApp()));
}
