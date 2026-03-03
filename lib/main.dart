import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Google Sign-In (v7 API)
  await GoogleSignIn.instance.initialize(
    clientId: kIsWeb
        ? '661146478033-e4g1a52u146r2da58dk41rpl55div591.apps.googleusercontent.com'
        : null,
  );

  runApp(const ProviderScope(child: FocusChatApp()));
}
