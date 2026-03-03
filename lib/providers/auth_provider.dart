import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

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

  User? get currentUser => _authService.currentUser;
  Stream<User?> get authStateChanges => _authService.authStateChanges;

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _authService.signInWithGoogle();
      state = state.copyWith(isLoading: false);
      return result != null;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _authService.signInWithEmailAndPassword(
        email,
        password,
      );
      state = state.copyWith(isLoading: false);
      return result != null;
    } catch (e) {
      if (e is FirebaseAuthException) {
        state = state.copyWith(
          isLoading: false,
          error: e.message ?? e.toString(),
        );
      } else {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
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
      final result = await _authService.registerWithEmailAndPassword(
        email,
        password,
        displayName,
      );
      state = state.copyWith(isLoading: false);
      return result != null;
    } catch (e) {
      if (e is FirebaseAuthException) {
        state = state.copyWith(
          isLoading: false,
          error: e.message ?? e.toString(),
        );
      } else {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
      return false;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      await _authService.signOut();
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

/// Stream of Firebase auth state changes
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});
