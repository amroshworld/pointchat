import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import '../services/auth_service.dart';
import '../appwrite_client.dart';

// Declare first so we can invalidate it
final authStateProvider = StreamProvider<models.User?>((ref) {
  final controller = StreamController<models.User?>();

  void checkAuth() {
    appwriteAccount
        .get()
        .then((user) {
          if (!controller.isClosed) controller.add(user);
        })
        .catchError((_) {
          if (!controller.isClosed) controller.add(null);
        });
  }

  // Check initial auth state
  checkAuth();

  // Subscribe to account events via realtime
  final sub = appwriteRealtime.subscribe(['account']);
  sub.stream.listen((_) => checkAuth());

  ref.onDispose(() {
    sub.close();
    controller.close();
  });

  return controller.stream;
});

// ── Auth State ──
class AuthState {
  final bool isLoading;
  final String? error;

  const AuthState({this.isLoading = false, this.error});

  AuthState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ── Auth Notifier (Riverpod v3 Notifier) ──
class AuthNotifier extends Notifier<AuthState> {
  late final AuthService _authService;

  String _friendlyAuthError(Object error) {
    if (error is AppwriteException) {
      final type = (error.type ?? '').toLowerCase();
      final message = (error.message ?? '').toLowerCase();

      if (type.contains('user_invalid_credentials') ||
          message.contains('invalid credentials')) {
        return 'Incorrect email or password.';
      }
      if (type.contains('user_already_exists') ||
          message.contains('already exists')) {
        return 'This email is already in use. Please sign in instead.';
      }
      if (type.contains('user_password') || message.contains('password')) {
        return 'Password must be at least 8 characters.';
      }
      if (type.contains('user_email') || message.contains('email')) {
        return 'Please enter a valid email address.';
      }
      if (type.contains('general_rate_limit_exceeded') ||
          message.contains('too many requests')) {
        return 'Too many attempts. Please wait a moment and try again.';
      }
      if (type.contains('user_blocked')) {
        return 'This account is currently restricted. Please contact support.';
      }
      return 'We could not complete authentication right now. Please try again.';
    }

    return 'Something went wrong. Please try again.';
  }

  @override
  AuthState build() {
    _authService = AuthService();
    return const AuthState();
  }

  Future<models.User?> getCurrentUser() => _authService.getCurrentUser();

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _authService.signInWithGoogle();
      ref.invalidate(authStateProvider);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendlyAuthError(e));
      return false;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      await _authService.signOut();
      ref.invalidate(authStateProvider);
    } catch (e) {
      state = state.copyWith(
        error: 'Sign out could not be completed. Please try again.',
      );
    }
    state = state.copyWith(isLoading: false);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// ── Riverpod Providers ──
final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
