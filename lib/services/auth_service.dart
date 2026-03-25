import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import '../appwrite_client.dart';
import '../models/user_model.dart';
import 'notification_service.dart';
import 'subscription_service.dart';

class AuthService {
  final Account _account = appwriteAccount;
  final TablesDB _databases = appwriteTablesDB;

  String get _oauthCallbackScheme =>
      'appwrite-callback-${AppwriteConstants.projectId}';

  String get _oauthCallbackUrl => '$_oauthCallbackScheme://auth';

  // Get current user (async)
  Future<models.User?> getCurrentUser() async {
    try {
      return await _account.get();
    } catch (_) {
      return null;
    }
  }

  // Sign in with Google (requires Google OAuth provider in Appwrite console)
  Future<void> signInWithGoogle() async {
    try {
      await _account.deleteSession(sessionId: 'current');
    } catch (_) {}

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      await _signInWithGoogleMobile();
      return;
    }

    await _account.createOAuth2Session(
      provider: OAuthProvider.google,
      success: kIsWeb ? null : _oauthCallbackUrl,
      failure: kIsWeb ? null : _oauthCallbackUrl,
    );

    final user = await _waitForOAuthSessionUser();
    await _saveUserToDatabase(user);
    _cacheCurrentUser(user);
    await SubscriptionService.instance.logIn(user.$id);
  }

  Future<void> _signInWithGoogleMobile() async {
    final callbackUrl = Uri.parse(_oauthCallbackUrl);
    final failureUrl = callbackUrl.replace(queryParameters: {'error': 'oauth'});
    final authUri =
        Uri.parse(
          '${AppwriteConstants.endpoint}/account/tokens/oauth2/google',
        ).replace(
          queryParameters: {
            'project': AppwriteConstants.projectId,
            'success': callbackUrl.toString(),
            'failure': failureUrl.toString(),
          },
        );

    final result = await FlutterWebAuth2.authenticate(
      url: authUri.toString(),
      callbackUrlScheme: _oauthCallbackScheme,
    );

    final callback = Uri.parse(result);
    if ((callback.queryParameters['error'] ?? '').isNotEmpty) {
      throw AppwriteException('Google sign-in was cancelled or failed.');
    }

    final userId = callback.queryParameters['userId'];
    final secret = callback.queryParameters['secret'];
    if (userId == null || userId.isEmpty || secret == null || secret.isEmpty) {
      throw AppwriteException(
        'Google sign-in did not return a valid Appwrite session token.',
      );
    }

    await _account.createSession(userId: userId, secret: secret);

    final user = await _account.get();
    await _saveUserToDatabase(user);
    _cacheCurrentUser(user);
    await SubscriptionService.instance.logIn(user.$id);
  }

  Future<models.User> _waitForOAuthSessionUser() async {
    AppwriteException? lastException;
    for (var attempt = 0; attempt < 12; attempt++) {
      try {
        return await _account.get();
      } on AppwriteException catch (e) {
        lastException = e;
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    throw lastException ??
        AppwriteException('Google sign-in failed to create a session.');
  }

  // Cache the current user info in globals
  void _cacheCurrentUser(models.User user) {
    cachedUserId = user.$id;
    cachedUserName = user.name.isNotEmpty ? user.name : 'User';
    cachedUserEmail = user.email;
  }

  // Load cached user info (call on app start when session exists)
  Future<void> loadCurrentUser() async {
    try {
      final user = await _account.get();
      _cacheCurrentUser(user);
      await SubscriptionService.instance.logIn(user.$id);

      // Also load photoUrl from database
      try {
        final doc = await _databases.getRow(
          databaseId: AppwriteConstants.databaseId,
          tableId: AppwriteConstants.usersCollection,
          rowId: user.$id,
        );
        cachedUserPhotoUrl = doc.data['photoUrl'] ?? '';
      } catch (_) {}
    } catch (_) {}
  }

  // Save user data to Appwrite database
  Future<void> _saveUserToDatabase(
    models.User user) async {
    final displayName = user.name.isNotEmpty ? user.name : 'User';

    try {
      await _databases.getRow(
        databaseId: AppwriteConstants.databaseId,
        tableId: AppwriteConstants.usersCollection,
        rowId: user.$id,
      );

      // Existing user - update online status
      await _databases.updateRow(
        databaseId: AppwriteConstants.databaseId,
        tableId: AppwriteConstants.usersCollection,
        rowId: user.$id,
        data: {
          'isOnline': true,
          'lastSeen': DateTime.now().toUtc().toIso8601String(),
          'displayName': displayName,
        },
      );
    } on AppwriteException catch (e) {
      if (e.code == 404) {
        // New user - create document
        final newUser = UserModel(
          uid: user.$id,
          displayName: displayName,
          email: user.email,
          onlineFlag: true,
        );
        await _databases.createRow(
          databaseId: AppwriteConstants.databaseId,
          tableId: AppwriteConstants.usersCollection,
          rowId: user.$id,
          data: newUser.toMap(),
        );
      } else {
        rethrow;
      }
    }
  }

  // Set user online status
  Future<void> setUserOnlineStatus(bool isOnline) async {
    if (cachedUserId.isEmpty) return;
    try {
      await _databases.updateRow(
        databaseId: AppwriteConstants.databaseId,
        tableId: AppwriteConstants.usersCollection,
        rowId: cachedUserId,
        data: {
          'isOnline': isOnline,
          'lastSeen': DateTime.now().toUtc().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('Error setting online status: $e');
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
      await _account.deleteSession(sessionId: 'current');
    } catch (e) {
      debugPrint('Error deleting session during sign out: $e');
    }

    cachedUserId = '';
    cachedUserName = '';
    cachedUserPhotoUrl = '';
    cachedUserEmail = '';
    await SubscriptionService.instance.logOut();
    await NotificationService.instance.unbind();
  }
}
