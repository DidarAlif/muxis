import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  final TextEditingController _resetKeyCtrl = TextEditingController();
  final TextEditingController _resetPassCtrl = TextEditingController();

  final TextEditingController _googleIdCtrl = TextEditingController();
  final TextEditingController _googleSecretCtrl = TextEditingController();

  bool _hideLoginPass = true;
  bool _hideRegPass = true;
  bool _showRecoveryReset = false;
  bool _showGoogleKeySetup = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailCtrl.dispose();
    _loginPassCtrl.dispose();
    _regNameCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPassCtrl.dispose();
    _resetKeyCtrl.dispose();
    _resetPassCtrl.dispose();
    _googleIdCtrl.dispose();
    _googleSecretCtrl.dispose();
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
        if (next.recoveryKey != null && prev?.user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Signed in! Backup Recovery Key: ${next.recoveryKey} (saved inside Account)',
              ),
              duration: const Duration(seconds: 6),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        Navigator.of(context).pop();
      }
    });

    return Dialog(
      backgroundColor: MuxisColors.surface(isDark),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 40,
        vertical: isMobile ? 20 : 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: MuxisColors.border(isDark)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 640),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 18 : 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with Muxis Brand Mark
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
              const SizedBox(height: 10),

              TabBar(
                controller: _tabController,
                indicatorColor: MuxisColors.accent(isDark),
                labelColor: MuxisColors.textPrimary(isDark),
                unselectedLabelColor: MuxisColors.textMuted(isDark),
                tabs: const [
                  Tab(text: 'Sign In'),
                  Tab(text: 'Create Account'),
                ],
              ),
              const SizedBox(height: 12),

              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                              color: MuxisColors.accent(isDark)
                                  .withOpacity(0.45),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.cloud_sync_rounded,
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
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.35,
                                    color: isDark
                                        ? const Color(0xFFFCA5A5)
                                        : const Color(0xFFB91C1C),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (_tabController.index == 0)
                        _buildSignInTab(authService, authState, isDark)
                      else
                        _buildRegisterTab(authService, authState, isDark),
                    ],
                  ),
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
          keyboardType: TextInputType.emailAddress,
        ),
        if (!_showRecoveryReset) ...[
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
            label: 'Sign In to MUXIS Cloud',
            variant: MuxisButtonVariant.primary,
            isLoading: authState.isLoading,
            onPressed: () => authService.signInWithEmail(
              email: _loginEmailCtrl.text,
              password: _loginPassCtrl.text,
            ),
          ),
        ] else ...[
          const SizedBox(height: 12),
          _buildTextField(
            _resetKeyCtrl,
            'Backup Recovery Key (MUXIS-XXXX-XXXX-XXXX)',
            Icons.vpn_key_outlined,
            false,
            isDark,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            _resetPassCtrl,
            'New Password (min. 6 characters)',
            Icons.lock_reset_rounded,
            _hideLoginPass,
            isDark,
            onToggleObscure: () =>
                setState(() => _hideLoginPass = !_hideLoginPass),
          ),
          const SizedBox(height: 14),
          MuxisButton(
            label: 'Reset Password & Sign In',
            variant: MuxisButtonVariant.primary,
            isLoading: authState.isLoading,
            onPressed: () => authService.resetPasswordWithRecoveryKey(
              email: _loginEmailCtrl.text,
              recoveryKey: _resetKeyCtrl.text,
              newPassword: _resetPassCtrl.text,
            ),
          ),
        ],

        const SizedBox(height: 6),
        Center(
          child: TextButton(
            onPressed: () {
              authService.clearMessages();
              setState(() => _showRecoveryReset = !_showRecoveryReset);
            },
            child: Text(
              _showRecoveryReset
                  ? 'Back to Password Sign In'
                  : 'Forgot Password? Use Recovery Key',
              style: TextStyle(fontSize: 12, color: MuxisColors.accent(isDark)),
            ),
          ),
        ),

        const SizedBox(height: 10),
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
          keyboardType: TextInputType.emailAddress,
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
          label: 'Create Free Account (Instant)',
          variant: MuxisButtonVariant.primary,
          isLoading: authState.isLoading,
          onPressed: () => authService.signUpWithEmail(
            email: _regEmailCtrl.text,
            password: _regPassCtrl.text,
            displayName: _regNameCtrl.text,
          ),
        ),

        const SizedBox(height: 8),
        Text(
          'Instant activation — no broken verification emails required. Playlists & favorites sync cleanly while local audio files stay on-device.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            color: MuxisColors.textMuted(isDark),
            height: 1.35,
          ),
        ),

        const SizedBox(height: 12),
        _buildOAuthSection(authService, authState, isDark),
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
                'OR GOOGLE OAUTH',
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
        if (authState.isGoogleSignInReady)
          MuxisButton(
            label: 'Continue with Google',
            icon: const Icon(Icons.g_mobiledata_rounded, size: 22),
            variant: MuxisButtonVariant.secondary,
            height: 38,
            isLoading: authState.isLoading,
            onPressed: () => authService.signInWithGoogle(),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MuxisColors.secondaryBg(isDark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MuxisColors.border(isDark)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Use your Gmail + Password above for instant zero-verification signup/login across Mobile & Desktop.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: MuxisColors.textSecondary(isDark),
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => setState(
                    () => _showGoogleKeySetup = !_showGoogleKeySetup,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      _showGoogleKeySetup
                          ? 'Hide Google OAuth Setup'
                          : 'Have a Google OAuth Client ID? Tap to Enable',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: MuxisColors.accent(isDark),
                      ),
                    ),
                  ),
                ),
                if (_showGoogleKeySetup) ...[
                  const SizedBox(height: 8),
                  _buildTextField(
                    _googleIdCtrl,
                    'Google OAuth Client ID',
                    Icons.vpn_key_outlined,
                    false,
                    isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    _googleSecretCtrl,
                    'Google Client Secret (Optional)',
                    Icons.lock_outline_rounded,
                    true,
                    isDark,
                  ),
                  const SizedBox(height: 8),
                  MuxisButton(
                    label: 'Save & Enable Google Sign-In',
                    variant: MuxisButtonVariant.secondary,
                    height: 34,
                    onPressed: () {
                      final id = _googleIdCtrl.text.trim();
                      if (id.isEmpty) return;
                      authService.saveCustomGoogleClient(
                        id,
                        _googleSecretCtrl.text,
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                        const ClipboardData(
                          text: 'http://localhost:8888/callback',
                        ),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Copied redirect URI: http://localhost:8888/callback',
                          ),
                        ),
                      );
                    },
                    child: Text(
                      'Desktop redirect URI: http://localhost:8888/callback (tap to copy)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: MuxisColors.textMuted(isDark),
                      ),
                    ),
                  ),
                ],
              ],
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
    bool isDark, {
    TextInputType keyboardType = TextInputType.text,
    VoidCallback? onToggleObscure,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: 13.5, color: MuxisColors.textPrimary(isDark)),
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
        fillColor: MuxisColors.secondaryBg(isDark),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: MuxisColors.border(isDark)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: MuxisColors.border(isDark)),
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
