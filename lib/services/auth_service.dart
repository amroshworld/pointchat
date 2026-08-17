import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import '../appwrite_client.dart';
import '../models/user_model.dart';
import '../utils/chat_privacy_preferences.dart';
import 'notification_service.dart';

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

  // Sign in with email/password using a pre-created Appwrite account.
  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      throw AppwriteException('Email and password are required.');
    }

    try {
      await _account.deleteSession(sessionId: 'current');
    } catch (_) {}

    await _account.createEmailPasswordSession(
      email: normalizedEmail,
      password: password,
    );

    final user = await _account.get();
    await _saveUserToDatabase(user);
    _cacheCurrentUser(user);
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
  }

  Future<void> _signInWithGoogleMobile() async {
    final callbackUrl = Uri.parse(_oauthCallbackUrl);
    final failureUrl = callbackUrl.replace(queryParameters: {'error': 'oauth'});
    final authUri = Uri.parse(
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
      await _saveUserToDatabase(user);
  
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

  /// Ensures the current authenticated user has a row in Tables DB.
  Future<void> ensureCurrentUserRow() async {
    final user = await _account.get();
    _cacheCurrentUser(user);
    await _saveUserToDatabase(user);
  }

  // Save user data to Appwrite database
  Future<void> _saveUserToDatabase(models.User user) async {
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
        try {
          await _databases.createRow(
            databaseId: AppwriteConstants.databaseId,
            tableId: AppwriteConstants.usersCollection,
            rowId: user.$id,
            data: newUser.toMap(),
          );
        } on AppwriteException catch (ce) {
          if (ce.code == 409 || (ce.type != null && ce.type!.contains('duplicate'))) {
            try {
              final oldRows = await _databases.listRows(
                databaseId: AppwriteConstants.databaseId,
                tableId: AppwriteConstants.usersCollection,
                queries: [Query.equal('email', user.email)],
              );
              for (var oldRow in oldRows.rows) {
                await _databases.deleteRow(
                  databaseId: AppwriteConstants.databaseId,
                  tableId: AppwriteConstants.usersCollection,
                  rowId: oldRow.$id,
                );
              }
              await _databases.createRow(
                databaseId: AppwriteConstants.databaseId,
                tableId: AppwriteConstants.usersCollection,
                rowId: user.$id,
                data: newUser.toMap(),
              );
            } catch (_) {
              throw AppwriteException('This email is linked to an orphaned account. Please contact support.', 409, 'user_already_exists');
            }
          } else {
            rethrow;
          }
        }
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
    } on AppwriteException catch (e) {
      // If row was deleted/missing (e.g. after account deletion + fresh login),
      // recreate it and retry once so heartbeat/settings recover automatically.
      if (e.code == 404 || e.type == 'row_not_found') {
        try {
          await ensureCurrentUserRow();
          await _databases.updateRow(
            databaseId: AppwriteConstants.databaseId,
            tableId: AppwriteConstants.usersCollection,
            rowId: cachedUserId,
            data: {
              'isOnline': isOnline,
              'lastSeen': DateTime.now().toUtc().toIso8601String(),
            },
          );
          return;
        } catch (retryError) {
          debugPrint('Error recovering missing user row: $retryError');
        }
      }
      debugPrint('Error setting online status: $e');
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
    await ChatPrivacyPreferences.clearAll();
    await NotificationService.instance.unbind();
  }

  // Delete currently signed-in account (production path used by Settings).
  Future<void> deleteCurrentAccount({required String confirmText}) async {
    const requiredPhrase = 'DELETE MY ACCOUNT';
    final normalizedPhrase = confirmText.trim();
    if (normalizedPhrase != requiredPhrase) {
      throw AppwriteException('Please type exactly: $requiredPhrase');
    }

    if (cachedUserId.isEmpty) {
      final current = await _account.get();
      _cacheCurrentUser(current);
    }

    try {
      await _databases.deleteRow(
        databaseId: AppwriteConstants.databaseId,
        tableId: AppwriteConstants.usersCollection,
        rowId: cachedUserId,
      );
    } catch (e) {
      debugPrint('Warning: Failed to delete user row: $e');
    }

    try {
      await setUserOnlineStatus(false);
    } catch (_) {}

    late final models.Execution execution;
    try {
      execution = await appwriteFunctions
          .createExecution(
            functionId: 'account_deletion',
            body: jsonEncode({'confirmText': normalizedPhrase}),
            method: ExecutionMethod.pOST,
            xasync: false,
            headers: {'content-type': 'application/json'},
          )
          .timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw AppwriteException(
        'Deletion request timed out. Please try again in a moment.',
      );
    }

    if (execution.status == ExecutionStatus.failed ||
        execution.responseStatusCode < 200 ||
        execution.responseStatusCode >= 300) {
      var message =
          'Could not delete your account right now. Please try again.';
      final body = execution.responseBody;
      if (body.isNotEmpty) {
        try {
          final data = jsonDecode(body);
          if (data is Map<String, dynamic>) {
            message = (data['error'] ?? data['message'] ?? message).toString();
          }
        } catch (_) {}
      }
      throw AppwriteException(message);
    }

    final responseBody = execution.responseBody.trim();
    if (responseBody.isNotEmpty) {
      try {
        final data = jsonDecode(responseBody);
        if (data is Map<String, dynamic> && data['success'] == false) {
          final message = (data['error'] ?? data['message'] ??
                  'Could not delete your account right now. Please try again.')
              .toString();
          throw AppwriteException(message);
        }
      } catch (e) {
        if (e is AppwriteException) {
          rethrow;
        }
        throw AppwriteException(
          'Deletion service returned an unexpected response. Please try again.',
        );
      }
    }

    try {
      await _account.deleteSession(sessionId: 'current');
    } catch (_) {}

    cachedUserId = '';
    cachedUserName = '';
    cachedUserPhotoUrl = '';
    cachedUserEmail = '';
    await ChatPrivacyPreferences.clearAll();
    await NotificationService.instance.unbind();
  }
}
