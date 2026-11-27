class MuxisUser {
  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final String subscriptionTier;

  const MuxisUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.subscriptionTier = 'free',
  });

  MuxisUser copyWith({
    String? id,
    String? email,
    String? displayName,
    String? avatarUrl,
    String? subscriptionTier,
  }) {
    return MuxisUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
    );
  }
}

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final MuxisUser? user;
  final String? errorMessage;
  final String? infoMessage;
  final bool isCloudAvailable;
  final bool needsEmailConfirmation;
  final String? pendingConfirmationEmail;
  final bool isGoogleOAuthEnabled;
  final bool isAppleOAuthEnabled;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
    this.infoMessage,
    this.isCloudAvailable = false,
    this.needsEmailConfirmation = false,
    this.pendingConfirmationEmail,
    this.isGoogleOAuthEnabled = false,
    this.isAppleOAuthEnabled = false,
  });

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;
  bool get isLoading => status == AuthStatus.loading;

  AuthState copyWith({
    AuthStatus? status,
    MuxisUser? user,
    bool clearUser = false,
    String? errorMessage,
    String? infoMessage,
    bool? isCloudAvailable,
    bool? needsEmailConfirmation,
    String? pendingConfirmationEmail,
    bool? isGoogleOAuthEnabled,
    bool? isAppleOAuthEnabled,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      errorMessage: errorMessage,
      infoMessage: infoMessage,
      isCloudAvailable: isCloudAvailable ?? this.isCloudAvailable,
      needsEmailConfirmation:
          needsEmailConfirmation ?? this.needsEmailConfirmation,
      pendingConfirmationEmail:
          pendingConfirmationEmail ?? this.pendingConfirmationEmail,
      isGoogleOAuthEnabled: isGoogleOAuthEnabled ?? this.isGoogleOAuthEnabled,
      isAppleOAuthEnabled: isAppleOAuthEnabled ?? this.isAppleOAuthEnabled,
    );
  }
}
