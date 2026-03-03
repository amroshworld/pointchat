import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with Email and Password
  Future<UserCredential?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Save/update user data in Firestore
        await _saveUserToFirestore(userCredential.user!);
      }

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Register with Email and Password
  Future<UserCredential?> registerWithEmailAndPassword(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Update user display name
        await userCredential.user!.updateDisplayName(displayName);

        // Save user data in Firestore
        await _saveUserToFirestore(
          userCredential.user!,
          explicitDisplayName: displayName,
        );
      }

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Initialize Google Sign In
  Future<void> initGoogleSignIn() async {
    await GoogleSignIn.instance.initialize();
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // On web, use Firebase Auth's native popup which handles GIS internally
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');

        final userCredential = await _auth.signInWithPopup(googleProvider);

        // Save/update user data in Firestore
        if (userCredential.user != null) {
          await _saveUserToFirestore(userCredential.user!);
        }

        return userCredential;
      }

      // On Android/iOS, use the Google Sign-In plugin (v7 API)
      final GoogleSignInAccount googleUser = await GoogleSignIn.instance
          .authenticate();

      // Obtain the id token
      final idToken = googleUser.authentication.idToken;

      // Get access token via authorization client
      final authClient = googleUser.authorizationClient;
      final clientAuth = await authClient.authorizeScopes(['email', 'profile']);

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: clientAuth.accessToken,
        idToken: idToken,
      );

      // Sign in to Firebase
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      // Save/update user data in Firestore
      if (userCredential.user != null) {
        await _saveUserToFirestore(userCredential.user!);
      }

      return userCredential;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null; // User cancelled
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  // Save user data to Firestore
  Future<void> _saveUserToFirestore(
    User user, {
    String? explicitDisplayName,
  }) async {
    final userDoc = _firestore.collection('users').doc(user.uid);
    final docSnapshot = await userDoc.get();

    final displayName = explicitDisplayName ?? user.displayName ?? 'User';

    if (!docSnapshot.exists) {
      // New user - create document
      final newUser = UserModel(
        uid: user.uid,
        displayName: displayName,
        email: user.email ?? '',
        photoUrl: user.photoURL ?? '',
        isOnline: true,
      );
      await userDoc.set(newUser.toMap());
    } else {
      // Existing user - update online status
      await userDoc.update({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'displayName': displayName,
      });
    }
  }

  // Set user online status
  Future<void> setUserOnlineStatus(bool isOnline) async {
    if (currentUser != null) {
      try {
        await _firestore.collection('users').doc(currentUser!.uid).set({
          'isOnline': isOnline,
          'lastSeen': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error setting online status: $e');
      }
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await setUserOnlineStatus(false);
    } catch (e) {
      debugPrint('Error setting online status during sign out: $e');
    }

    try {
      if (!kIsWeb) {
        // GoogleSignIn.instance.signOut() may not be supported on all platforms (e.g. Windows)
        // or may fail if not signed in via Google.
        await GoogleSignIn.instance.signOut();
      }
    } catch (e) {
      debugPrint('Error signing out from Google: $e');
    }

    await _auth.signOut();
  }
}
