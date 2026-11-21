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
  final bool isCloudAvailable;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
    this.isCloudAvailable = false,
  });

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;
  bool get isLoading => status == AuthStatus.loading;

  AuthState copyWith({
    AuthStatus? status,
    MuxisUser? user,
    String? errorMessage,
    bool? isCloudAvailable,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
      isCloudAvailable: isCloudAvailable ?? this.isCloudAvailable,
    );
  }
}
