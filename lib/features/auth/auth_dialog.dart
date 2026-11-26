import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_gradients.dart';
import '../../core/auth/auth_state.dart';
import '../../core/auth/supabase_auth_service.dart';
import '../../shared/widgets/muxis_button.dart';

class AuthDialog extends ConsumerStatefulWidget {
  const AuthDialog({super.key});

  @override
  ConsumerState<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends ConsumerState<AuthDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _loginEmailCtrl = TextEditingController();
  final TextEditingController _loginPassCtrl = TextEditingController();

  final TextEditingController _regNameCtrl = TextEditingController();
  final TextEditingController _regEmailCtrl = TextEditingController();
  final TextEditingController _regPassCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailCtrl.dispose();
    _loginPassCtrl.dispose();
    _regNameCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPassCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authServiceProvider);
    final authService = ref.read(authServiceProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? MuxisColors.obsidian : MuxisColors.whiteSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark
              ? MuxisColors.subtleBorderDark
              : MuxisColors.subtleBorderLight,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with Muxis Monogram Mark
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          gradient: MuxisGradients.prismaticPrimary,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.cloud_sync_rounded,
                            color: Colors.black,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'MUXIS CLOUD',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                          color: MuxisColors.accent(isDark),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Tabs (Sign In / Register)
              TabBar(
                controller: _tabController,
                indicatorColor: MuxisColors.accent(isDark),
                labelColor: isDark
                    ? Colors.white
                    : MuxisColors.textPrimaryLight,
                unselectedLabelColor: MuxisColors.textMuted(isDark),
                tabs: const [
                  Tab(text: 'Sign In'),
                  Tab(text: 'Create Account'),
                ],
              ),
              const SizedBox(height: 18),

              // Error display if any
              if (authState.errorMessage != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: MuxisColors.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: MuxisColors.error.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: MuxisColors.error,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          authState.errorMessage!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: MuxisColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // --- TAB 1: SIGN IN ---
                    _buildSignInTab(authService, authState, isDark),

                    // --- TAB 2: REGISTER ---
                    _buildRegisterTab(authService, authState, isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignInTab(
    SupabaseAuthService authService,
    AuthState authState,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(
          _loginEmailCtrl,
          'Email Address',
          Icons.email_outlined,
          false,
          isDark,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _loginPassCtrl,
          'Password',
          Icons.lock_outline_rounded,
          true,
          isDark,
        ),
        const SizedBox(height: 18),

        MuxisButton(
          label: 'Sign In to Muxis Cloud',
          variant: MuxisButtonVariant.primary,
          isLoading: authState.isLoading,
          onPressed: () async {
            final ok = await authService.signInWithEmail(
              email: _loginEmailCtrl.text,
              password: _loginPassCtrl.text,
            );
            if (ok && mounted) Navigator.of(context).pop();
          },
        ),

        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {
                if (_loginEmailCtrl.text.isNotEmpty) {
                  authService.sendPasswordReset(_loginEmailCtrl.text);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Password reset instructions sent if email exists.',
                      ),
                    ),
                  );
                }
              },
              child: Text(
                'Forgot Password?',
                style: TextStyle(
                  fontSize: 12,
                  color: MuxisColors.textMuted(isDark),
                ),
              ),
            ),
          ],
        ),

        const Spacer(),
        // OAuth Buttons
        Row(
          children: [
            Expanded(
              child: MuxisButton(
                label: 'Google',
                icon: const Icon(Icons.g_mobiledata_rounded, size: 22),
                variant: MuxisButtonVariant.secondary,
                height: 38,
                onPressed: () => authService.signInWithGoogle(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MuxisButton(
                label: 'Apple',
                icon: const Icon(Icons.apple_rounded, size: 18),
                variant: MuxisButtonVariant.secondary,
                height: 38,
                onPressed: () => authService.signInWithApple(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRegisterTab(
    SupabaseAuthService authService,
    AuthState authState,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(
          _regNameCtrl,
          'Display Name',
          Icons.person_outline_rounded,
          false,
          isDark,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _regEmailCtrl,
          'Email Address',
          Icons.email_outlined,
          false,
          isDark,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _regPassCtrl,
          'Password (min. 8 characters)',
          Icons.lock_outline_rounded,
          true,
          isDark,
        ),
        const SizedBox(height: 18),

        MuxisButton(
          label: 'Create Free Account',
          variant: MuxisButtonVariant.primary,
          isLoading: authState.isLoading,
          onPressed: () async {
            final ok = await authService.signUpWithEmail(
              email: _regEmailCtrl.text,
              password: _regPassCtrl.text,
              displayName: _regNameCtrl.text,
            );
            if (ok && mounted) Navigator.of(context).pop();
          },
        ),

        const SizedBox(height: 12),
        Text(
          'By signing up, your playlists and preferences will sync securely across your devices. Your local music library files are never uploaded.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: MuxisColors.textMuted(isDark),
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String hint,
    IconData icon,
    bool obscure,
    bool isDark,
  ) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: TextStyle(
        fontSize: 13,
        color: isDark ? Colors.white : MuxisColors.textPrimaryLight,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 12,
          color: MuxisColors.textMuted(isDark),
        ),
        prefixIcon: Icon(icon, size: 18, color: MuxisColors.accent(isDark)),
        filled: true,
        fillColor: isDark
            ? MuxisColors.deepSpace
            : MuxisColors.secondarySurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark
                ? MuxisColors.subtleBorderDark
                : MuxisColors.subtleBorderLight,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark
                ? MuxisColors.subtleBorderDark
                : MuxisColors.subtleBorderLight,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: MuxisColors.accent(isDark)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        isDense: true,
      ),
    );
  }
}
