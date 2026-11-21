import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../config/app_config.dart';
import 'auth_state.dart';

final authServiceProvider =
    StateNotifierProvider<SupabaseAuthService, AuthState>((ref) {
      return SupabaseAuthService();
    });

class SupabaseAuthService extends StateNotifier<AuthState> {
  SupabaseClient? _client;
  StreamSubscription<AuthState>? _sub;

  SupabaseAuthService() : super(const AuthState()) {
    init();
  }

  Future<void> init() async {
    if (!AppConfig.isConfigured) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isCloudAvailable: false,
      );
      return;
    }

    try {
      _client = Supabase.instance.client;
      final session = _client!.auth.currentSession;
      if (session != null) {
        _mapUser(session.user);
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          isCloudAvailable: true,
        );
      }

      _client!.auth.onAuthStateChange.listen((data) {
        final session = data.session;
        if (session != null) {
          _mapUser(session.user);
        } else {
          state = state.copyWith(
            status: AuthStatus.unauthenticated,
            user: null,
            isCloudAvailable: true,
          );
        }
      });
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isCloudAvailable: false,
      );
    }
  }

  void _mapUser(User user) {
    final meta = user.userMetadata ?? {};
    final muxisUser = MuxisUser(
      id: user.id,
      email: user.email ?? '',
      displayName:
          meta['display_name'] as String? ??
          user.email?.split('@')[0] ??
          'Muxis Listener',
      avatarUrl: meta['avatar_url'] as String?,
      subscriptionTier: meta['subscription_tier'] as String? ?? 'free',
    );
    state = state.copyWith(
      status: AuthStatus.authenticated,
      user: muxisUser,
      isCloudAvailable: true,
    );
  }

  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (_client == null) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Supabase cloud is not configured yet. Run in local offline mode or configure .env.',
      );
      return false;
    }

    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    try {
      final res = await _client!.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'display_name': displayName.trim()},
      );

      if (res.user != null) {
        _mapUser(res.user!);
        return true;
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Registration pending email confirmation. Please check your inbox.',
        );
        return false;
      }
    } on AuthException catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Connection error during registration: $e',
      );
      return false;
    }
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (_client == null) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage:
            'Supabase cloud is not configured. Running in local mode.',
      );
      return false;
    }

    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    try {
      final res = await _client!.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      if (res.user != null) {
        _mapUser(res.user!);
        return true;
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Invalid login credentials.',
        );
        return false;
      }
    } on AuthException catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Network error: $e',
      );
      return false;
    }
  }

  Future<void> signInWithGoogle() async {
    if (_client == null) return;
    try {
      await _client!.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'muxis://auth-callback',
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'Google Sign-In failed: $e');
    }
  }

  Future<void> signInWithApple() async {
    if (_client == null) return;
    try {
      await _client!.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: 'muxis://auth-callback',
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'Apple Sign-In failed: $e');
    }
  }

  Future<void> signOut() async {
    if (_client != null) {
      try {
        await _client!.auth.signOut();
      } catch (_) {}
    }
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      user: null,
      errorMessage: null,
    );
  }

  Future<bool> sendPasswordReset(String email) async {
    if (_client == null) return false;
    try {
      await _client!.auth.resetPasswordForEmail(email.trim());
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Password reset request failed: $e');
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    if (_client == null || state.user == null) return false;
    try {
      // 1. Primary: execute Postgres SECURITY DEFINER RPC
      try {
        await _client!.rpc('delete_user_account');
      } catch (_) {
        // 2. Secondary fallback: invoke Supabase Edge Function
        await _client!.functions.invoke('delete-account');
      }
      await signOut();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Account deletion failed: $e');
      return false;
    }
  }
}
