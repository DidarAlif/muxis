import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_typography.dart';
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

  bool _hideLoginPass = true;
  bool _hideRegPass = true;

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
    final isMobile = MediaQuery.sizeOf(context).width < 520;

    ref.listen<AuthState>(authServiceProvider, (prev, next) {
      if (!mounted) return;
      if ((prev == null || !prev.isAuthenticated) && next.isAuthenticated) {
        Navigator.of(context).pop();
        return;
      }
      if ((prev?.needsEmailConfirmation != true) &&
          next.needsEmailConfirmation &&
          next.pendingConfirmationEmail != null &&
          _tabController.index == 1) {
        _loginEmailCtrl.text = next.pendingConfirmationEmail!;
        _tabController.animateTo(0);
      }
    });

    return Dialog(
      backgroundColor: isDark ? MuxisColors.obsidian : MuxisColors.whiteSurface,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 40,
        vertical: isMobile ? 20 : 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark
              ? MuxisColors.subtleBorderDark
              : MuxisColors.subtleBorderLight,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 620),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 18 : 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with Muxis Monogram Mark
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/brand/muxis_mark.png',
                        height: 22,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'MUXIS CLOUD',
                        style: MuxisTypography.mono(
                          fontSize: 13.5,
                          letterSpacing: 1.8,
                          color: MuxisColors.accent(isDark),
                          isDark: isDark,
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
              const SizedBox(height: 12),

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
              const SizedBox(height: 16),

              // Info banner (e.g., email confirmation sent)
              if (authState.infoMessage != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: MuxisColors.accent(isDark).withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: MuxisColors.accent(isDark).withOpacity(0.45),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.mark_email_read_outlined,
                        color: MuxisColors.accent(isDark),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          authState.infoMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: MuxisColors.textPrimary(isDark),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Error display if any
              if (authState.errorMessage != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: MuxisColors.error.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: MuxisColors.error.withOpacity(0.45),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: MuxisColors.error,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          authState.errorMessage!,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: Color(0xFFFCA5A5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (authState.needsEmailConfirmation) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: MuxisButton(
                    label: 'Resend Confirmation Email',
                    icon: const Icon(Icons.forward_to_inbox_rounded, size: 17),
                    variant: MuxisButtonVariant.secondary,
                    height: 36,
                    isLoading: authState.isLoading,
                    onPressed: () {
                      final email = _loginEmailCtrl.text.trim().isNotEmpty
                          ? _loginEmailCtrl.text.trim()
                          : _regEmailCtrl.text.trim();
                      authService.resendConfirmationEmail(email);
                    },
                  ),
                ),
              ],

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    SingleChildScrollView(
                      child: _buildSignInTab(authService, authState, isDark),
                    ),
                    SingleChildScrollView(
                      child: _buildRegisterTab(authService, authState, isDark),
                    ),
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
          'Gmail / Email Address',
          Icons.email_outlined,
          false,
          isDark,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _loginPassCtrl,
          'Password',
          Icons.lock_outline_rounded,
          _hideLoginPass,
          isDark,
          onToggleObscure: () =>
              setState(() => _hideLoginPass = !_hideLoginPass),
        ),
        const SizedBox(height: 16),

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

        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () async {
                if (_loginEmailCtrl.text.trim().isEmpty) {
                  authService.clearMessages();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter your Gmail / email address first.'),
                    ),
                  );
                  return;
                }
                await authService.sendPasswordReset(_loginEmailCtrl.text);
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

        const SizedBox(height: 12),
        _buildOAuthSection(authService, authState, isDark),
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
          'Gmail / Email Address',
          Icons.email_outlined,
          false,
          isDark,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _regPassCtrl,
          'Password (min. 6 characters)',
          Icons.lock_outline_rounded,
          _hideRegPass,
          isDark,
          onToggleObscure: () => setState(() => _hideRegPass = !_hideRegPass),
        ),
        const SizedBox(height: 16),

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

        const SizedBox(height: 14),
        _buildOAuthSection(authService, authState, isDark),

        const SizedBox(height: 12),
        Text(
          'Your playlists and preferences sync securely across devices. Local music library files are never uploaded.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            color: MuxisColors.textMuted(isDark),
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildOAuthSection(
    SupabaseAuthService authService,
    AuthState authState,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: MuxisColors.border(isDark))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'OR CONTINUE WITH',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: MuxisColors.textMuted(isDark),
                ),
              ),
            ),
            Expanded(child: Divider(color: MuxisColors.border(isDark))),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: MuxisButton(
                label: 'Google',
                icon: const Icon(Icons.g_mobiledata_rounded, size: 22),
                variant: MuxisButtonVariant.secondary,
                height: 38,
                isLoading: authState.isLoading,
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
                isLoading: authState.isLoading,
                onPressed: () => authService.signInWithApple(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String hint,
    IconData icon,
    bool obscure,
    bool isDark, {
    VoidCallback? onToggleObscure,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: TextStyle(
        fontSize: 13.5,
        color: isDark ? Colors.white : MuxisColors.textPrimaryLight,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 12.5,
          color: MuxisColors.textMuted(isDark),
        ),
        prefixIcon: Icon(icon, size: 18, color: MuxisColors.accent(isDark)),
        suffixIcon: onToggleObscure == null
            ? null
            : IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                  color: MuxisColors.textMuted(isDark),
                ),
                onPressed: onToggleObscure,
              ),
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
