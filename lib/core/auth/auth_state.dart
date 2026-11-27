class MuxisUser {
  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final String subscriptionTier;
  final String authProvider;

  const MuxisUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.subscriptionTier = 'free',
    this.authProvider = 'email',
  });

  factory MuxisUser.fromJson(Map<String, dynamic> json) {
    final email = (json['email'] as String?) ?? '';
    final rawName =
        (json['display_name'] as String?) ??
        (json['full_name'] as String?) ??
        (json['name'] as String?);
    final displayName = (rawName != null && rawName.trim().isNotEmpty)
        ? rawName.trim()
        : (email.contains('@') ? email.split('@').first : 'Muxis Listener');

    return MuxisUser(
      id: (json['id'] as String?) ?? '',
      email: email,
      displayName: displayName,
      avatarUrl: json['avatar_url'] as String?,
      subscriptionTier: (json['subscription_tier'] as String?) ?? 'free',
      authProvider: (json['auth_provider'] as String?) ?? 'email',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'display_name': displayName,
    'avatar_url': avatarUrl,
    'subscription_tier': subscriptionTier,
    'auth_provider': authProvider,
  };

  MuxisUser copyWith({
    String? id,
    String? email,
    String? displayName,
    String? avatarUrl,
    String? subscriptionTier,
    String? authProvider,
  }) {
    return MuxisUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      authProvider: authProvider ?? this.authProvider,
    );
  }
}

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final MuxisUser? user;
  final String? accessToken;
  final String? recoveryKey;
  final String? errorMessage;
  final String? infoMessage;
  final bool isCloudAvailable;
  final bool needsEmailConfirmation;
  final String? pendingConfirmationEmail;
  final bool isGoogleOAuthEnabled;
  final bool isAppleOAuthEnabled;
  final bool hasCustomGoogleClient;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.accessToken,
    this.recoveryKey,
    this.errorMessage,
    this.infoMessage,
    this.isCloudAvailable = false,
    this.needsEmailConfirmation = false,
    this.pendingConfirmationEmail,
    this.isGoogleOAuthEnabled = false,
    this.isAppleOAuthEnabled = false,
    this.hasCustomGoogleClient = false,
  });

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;
  bool get isLoading => status == AuthStatus.loading;
  bool get isGoogleSignInReady => isGoogleOAuthEnabled || hasCustomGoogleClient;

  AuthState copyWith({
    AuthStatus? status,
    MuxisUser? user,
    bool clearUser = false,
    String? accessToken,
    bool clearAccessToken = false,
    String? recoveryKey,
    bool clearRecoveryKey = false,
    String? errorMessage,
    String? infoMessage,
    bool? isCloudAvailable,
    bool? needsEmailConfirmation,
    String? pendingConfirmationEmail,
    bool? isGoogleOAuthEnabled,
    bool? isAppleOAuthEnabled,
    bool? hasCustomGoogleClient,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      accessToken: clearAccessToken ? null : (accessToken ?? this.accessToken),
      recoveryKey: clearRecoveryKey ? null : (recoveryKey ?? this.recoveryKey),
      errorMessage: errorMessage,
      infoMessage: infoMessage,
      isCloudAvailable: isCloudAvailable ?? this.isCloudAvailable,
      needsEmailConfirmation:
          needsEmailConfirmation ?? this.needsEmailConfirmation,
      pendingConfirmationEmail:
          pendingConfirmationEmail ?? this.pendingConfirmationEmail,
      isGoogleOAuthEnabled: isGoogleOAuthEnabled ?? this.isGoogleOAuthEnabled,
      isAppleOAuthEnabled: isAppleOAuthEnabled ?? this.isAppleOAuthEnabled,
      hasCustomGoogleClient:
          hasCustomGoogleClient ?? this.hasCustomGoogleClient,
    );
  }
}
