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
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _authService.signInWithEmailAndPassword(email, password);
      ref.invalidate(authStateProvider);
      state = state.copyWith(isLoading: false);
      return true;
    } on AppwriteException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message ?? e.toString(),
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> registerWithEmailAndPassword(
    String email,
    String password,
    String displayName,
  ) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _authService.registerWithEmailAndPassword(
        email,
        password,
        displayName,
      );
      ref.invalidate(authStateProvider);
      state = state.copyWith(isLoading: false);
      return true;
    } on AppwriteException catch (e) {
      final errorMessage = 'Appwrite Error: ${e.message} (Code: ${e.code}, Type: ${e.type})';
      print(errorMessage);
      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );
      return false;
    } catch (e) {
      final errorMessage = 'General Error: ${e.toString()}';
      print(errorMessage);
      state = state.copyWith(isLoading: false, error: errorMessage);
      return false;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      await _authService.signOut();
      ref.invalidate(authStateProvider);
    } catch (e) {
      state = state.copyWith(error: e.toString());
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
