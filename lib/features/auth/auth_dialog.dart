import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/theme/muxis_colors.dart';
import '../../app/theme/muxis_gradients.dart';
import '../../app/theme/muxis_typography.dart';
import '../../core/auth/auth_state.dart';
import '../../core/auth/supabase_auth_service.dart';
import '../../core/config/app_config.dart';
import '../../shared/widgets/muxis_button.dart';

/// Official multi-color Google "G" emblem SVG for authentic 1-Click OAuth UX.
const String _googleMarkSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <path fill="#4285F4" d="M23.49 12.27c0-.79-.07-1.54-.19-2.27H12v4.51h6.47c-.29 1.48-1.14 2.73-2.4 3.58v3h3.86c2.26-2.09 3.56-5.17 3.56-8.82z"/>
  <path fill="#34A853" d="M12 24c3.24 0 5.95-1.08 7.93-2.91l-3.86-3c-1.08.72-2.45 1.16-4.07 1.16-3.13 0-5.78-2.11-6.73-4.96H1.29v3.09C3.26 21.3 7.31 24 12 24z"/>
  <path fill="#FBBC05" d="M5.27 14.29c-.25-.72-.38-1.49-.38-2.29s.14-1.57.38-2.29V6.62H1.29C.47 8.24 0 10.06 0 12s.47 3.76 1.29 5.38l3.98-3.09z"/>
  <path fill="#EA4335" d="M12 4.75c1.77 0 3.35.61 4.6 1.8l3.42-3.42C17.95 1.19 15.24 0 12 0 7.31 0 3.26 2.7 1.29 6.62l3.98 3.09c.95-2.85 3.6-4.96 6.73-4.96z"/>
</svg>
''';

class AuthDialog extends ConsumerStatefulWidget {
  const AuthDialog({super.key});

  @override
  ConsumerState<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends ConsumerState<AuthDialog> {
  bool _isSignUpMode = false;
  bool _hideLoginPass = true;
  bool _hideRegPass = true;
  bool _showRecoveryReset = false;
  bool _showGoogleSetupGuide = false;

  final TextEditingController _loginEmailCtrl = TextEditingController();
  final TextEditingController _loginPassCtrl = TextEditingController();

  final TextEditingController _regNameCtrl = TextEditingController();
  final TextEditingController _regEmailCtrl = TextEditingController();
  final TextEditingController _regPassCtrl = TextEditingController();

  final TextEditingController _resetKeyCtrl = TextEditingController();
  final TextEditingController _resetPassCtrl = TextEditingController();

  final TextEditingController _googleIdCtrl = TextEditingController();
  final TextEditingController _googleSecretCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _regPassCtrl.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    if (mounted && _isSignUpMode) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _regPassCtrl.removeListener(_onPasswordChanged);
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
    final viewportSize = MediaQuery.sizeOf(context);
    final viewportWidth = viewportSize.width;
    final viewportHeight = viewportSize.height;
    final isWideShowcase = viewportWidth >= 760 && viewportHeight >= 590;
    final isCompactMobile = viewportWidth < 500;
    final wideModalHeight = (viewportHeight - 48).clamp(540.0, 620.0);
    final accent = MuxisColors.accent(isDark);

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

    final surfaceBg = MuxisColors.surface(isDark);
    final showcaseBg = MuxisColors.secondaryBg(isDark);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompactMobile ? 14 : 28,
        vertical: isCompactMobile ? 16 : 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isWideShowcase ? 820 : 450,
          maxHeight: isWideShowcase ? wideModalHeight : viewportHeight - 32,
        ),
        child: Container(
          height: isWideShowcase ? wideModalHeight : null,
          decoration: BoxDecoration(
            color: surfaceBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: MuxisColors.border(isDark).withValues(alpha: 0.9),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.56 : 0.16),
                blurRadius: 42,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: isWideShowcase
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 332,
                      child: _buildShowcaseColumn(
                        isDark: isDark,
                        accent: accent,
                        showcaseBg: showcaseBg,
                      ),
                    ),
                    Container(width: 1, color: MuxisColors.border(isDark)),
                    Expanded(
                      child: _buildFormPanel(
                        context: context,
                        authState: authState,
                        authService: authService,
                        isDark: isDark,
                        accent: accent,
                        isWideShowcase: true,
                        isCompactMobile: false,
                      ),
                    ),
                  ],
                )
              : _buildFormPanel(
                  context: context,
                  authState: authState,
                  authService: authService,
                  isDark: isDark,
                  accent: accent,
                  isWideShowcase: false,
                  isCompactMobile: isCompactMobile,
                ),
        ),
      ),
    );
  }

  /// Editorial brand & sync value column shown on desktop and tablet screens.
  Widget _buildShowcaseColumn({
    required bool isDark,
    required Color accent,
    required Color showcaseBg,
  }) {
    final textPrimary = MuxisColors.textPrimary(isDark);
    final textSecondary = MuxisColors.textSecondary(isDark);
    final textMuted = MuxisColors.textMuted(isDark);

    return Container(
      decoration: BoxDecoration(
        color: showcaseBg,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: isDark ? 0.12 : 0.10),
            showcaseBg,
            showcaseBg,
          ],
          stops: const [0.0, 0.48, 1.0],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(28, 28, 26, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/brand/app_icon_1024.png',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MUXIS',
                    style: MuxisTypography.sectionHeading(isDark: isDark)
                        .copyWith(fontSize: 18, letterSpacing: 1.0),
                  ),
                  Text(
                    'by A Leaf',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Your music library,\nunified across every screen.',
            style: MuxisTypography.pageTitle(
              isDark: isDark,
            ).copyWith(fontSize: 23, height: 1.22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            'Sign in once to synchronize your playlists, liked songs, and custom audio themes automatically.',
            style: TextStyle(fontSize: 13, height: 1.5, color: textSecondary),
          ),
          const SizedBox(height: 24),
          _ShowcasePoint(
            icon: Icons.sync_rounded,
            title: 'Cloudflare D1 Edge Sync',
            detail: 'Playlists, favorites, and Theme Studio presets travel cleanly across every device.',
            accent: accent,
            isDark: isDark,
          ),
          const SizedBox(height: 14),
          _ShowcasePoint(
            icon: Icons.sd_storage_rounded,
            title: 'Private Local Files',
            detail: 'Lossless FLAC, MP3, and WAV libraries stay offline on your own storage.',
            accent: accent,
            isDark: isDark,
          ),
          const SizedBox(height: 14),
          _ShowcasePoint(
            icon: Icons.vpn_key_rounded,
            title: 'Zero-Delay Recovery',
            detail: 'Instant signup with Backup Recovery Keys — no broken verification emails.',
            accent: accent,
            isDark: isDark,
          ),
          const Spacer(),
          Divider(color: MuxisColors.border(isDark)),
          const SizedBox(height: 10),
          Text(
            'Windows • macOS • Linux • Android • iPhone',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: textPrimary.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormPanel({
    required BuildContext context,
    required AuthState authState,
    required SupabaseAuthService authService,
    required bool isDark,
    required Color accent,
    required bool isWideShowcase,
    required bool isCompactMobile,
  }) {
    final textPrimary = MuxisColors.textPrimary(isDark);
    final textSecondary = MuxisColors.textSecondary(isDark);
    final textMuted = MuxisColors.textMuted(isDark);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            isCompactMobile ? 18 : 26,
            isCompactMobile ? 16 : 22,
            isCompactMobile ? 12 : 18,
            0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isWideShowcase) ...[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/brand/app_icon_1024.png',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _showRecoveryReset
                          ? 'Reset Cloud Password'
                          : (_isSignUpMode
                                ? 'Create MUXIS Account'
                                : 'Welcome back to MUXIS'),
                      style: MuxisTypography.sectionHeading(isDark: isDark)
                          .copyWith(
                            fontSize: isCompactMobile ? 18 : 20,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _showRecoveryReset
                          ? 'Use your Backup Recovery Key to regain instant access.'
                          : (_isSignUpMode
                                ? 'Free cloud sync across desktop & mobile.'
                                : 'Sign in to sync playlists, favorites, and themes.'),
                      style: TextStyle(fontSize: 12.5, color: textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close_rounded, size: 20, color: textMuted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Tactile Segmented Auth Mode Switcher
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isCompactMobile ? 18 : 26),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: MuxisColors.secondaryBg(isDark),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: MuxisColors.border(isDark)),
            ),
            child: Row(
              children: [
                _SegmentTabButton(
                  label: 'Sign In',
                  selected: !_isSignUpMode,
                  isDark: isDark,
                  accent: accent,
                  onTap: () {
                    authService.clearMessages();
                    setState(() {
                      _isSignUpMode = false;
                      _showRecoveryReset = false;
                    });
                  },
                ),
                _SegmentTabButton(
                  label: 'Create Account',
                  selected: _isSignUpMode,
                  isDark: isDark,
                  accent: accent,
                  onTap: () {
                    authService.clearMessages();
                    setState(() {
                      _isSignUpMode = true;
                      _showRecoveryReset = false;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              isCompactMobile ? 18 : 26,
              2,
              isCompactMobile ? 18 : 26,
              isCompactMobile ? 20 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (authState.infoMessage != null)
                  _StatusBanner(
                    message: authState.infoMessage!,
                    icon: Icons.cloud_done_outlined,
                    tint: accent,
                    textColor: textPrimary,
                  ),

                if (authState.errorMessage != null)
                  _StatusBanner(
                    message: authState.errorMessage!,
                    icon: Icons.error_outline_rounded,
                    tint: MuxisColors.error,
                    textColor: isDark
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFF991B1B),
                  ),

                if (!_showRecoveryReset) ...[
                  _buildGoogleHeroButton(
                    authService,
                    authState,
                    isDark,
                    accent,
                  ),
                  if (_showGoogleSetupGuide &&
                      !authState.isGoogleSignInReady) ...[
                    const SizedBox(height: 10),
                    _buildGoogleSetupDrawer(authService, isDark, accent),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Divider(color: MuxisColors.border(isDark)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'or continue with Gmail / Email',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: textMuted,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(color: MuxisColors.border(isDark)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                if (!_isSignUpMode)
                  _buildSignInForm(authService, authState, isDark, accent)
                else
                  _buildSignUpForm(authService, authState, isDark, accent),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleHeroButton(
    SupabaseAuthService authService,
    AuthState authState,
    bool isDark,
    Color accent,
  ) {
    final isReady = authState.isGoogleSignInReady;
    final btnBg = isDark ? const Color(0xFFF8FAFC) : Colors.white;
    final btnText = const Color(0xFF0F172A);
    final btnBorder = isDark
        ? Colors.white.withValues(alpha: 0.22)
        : MuxisColors.border(false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: authState.isLoading
                ? null
                : () {
                    if (isReady) {
                      authService.signInWithGoogle();
                    } else {
                      setState(
                        () => _showGoogleSetupGuide = !_showGoogleSetupGuide,
                      );
                    }
                  },
            child: Ink(
              height: 46,
              decoration: BoxDecoration(
                color: btnBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: btnBorder, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.string(_googleMarkSvg, width: 19, height: 19),
                  const SizedBox(width: 11),
                  Text(
                    isReady
                        ? (_isSignUpMode
                              ? 'Sign up with Google (1-Click)'
                              : 'Continue with Google')
                        : 'Enable 1-Click Google Sign-In',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: btnText,
                      letterSpacing: 0.1,
                    ),
                  ),
                  if (!isReady) ...[
                    const SizedBox(width: 6),
                    Icon(
                      _showGoogleSetupGuide
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.settings_outlined,
                      size: 16,
                      color: const Color(0xFF475569),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (isReady)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Instant Google OAuth active across Desktop & Mobile',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: accent,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGoogleSetupDrawer(
    SupabaseAuthService authService,
    bool isDark,
    Color accent,
  ) {
    final textPrimary = MuxisColors.textPrimary(isDark);
    final textSecondary = MuxisColors.textSecondary(isDark);
    final workerCallback =
        '${AppConfig.cloudflareWorkerUrl}/api/auth/google/callback';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MuxisColors.secondaryBg(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enable 1-Click Google OAuth',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'For all users (Windows, macOS, Linux, Android & iPhone): add GOOGLE_CLIENT_ID & GOOGLE_CLIENT_SECRET to your Cloudflare Worker using the authorized callback URL below:',
            style: TextStyle(fontSize: 11.5, height: 1.4, color: textSecondary),
          ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: () {
              Clipboard.setData(ClipboardData(text: workerCallback));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied Worker Google callback URL!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: MuxisColors.surface(isDark),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: MuxisColors.border(isDark)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      workerCallback,
                      style: MuxisTypography.mono(
                        fontSize: 10.5,
                        color: accent,
                        isDark: isDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.copy_rounded, size: 14, color: textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Or paste your own OAuth Client ID for this Desktop device:',
            style: TextStyle(fontSize: 11, color: textSecondary),
          ),
          const SizedBox(height: 6),
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
            label: 'Save Client ID & Enable',
            variant: MuxisButtonVariant.secondary,
            height: 36,
            onPressed: () {
              final id = _googleIdCtrl.text.trim();
              if (id.isEmpty) return;
              authService.saveCustomGoogleClient(id, _googleSecretCtrl.text);
            },
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () {
              Clipboard.setData(
                const ClipboardData(text: 'http://localhost:8888/callback'),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Copied Desktop redirect URI: http://localhost:8888/callback',
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                'Desktop loopback URI: http://localhost:8888/callback (tap to copy)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInForm(
    SupabaseAuthService authService,
    AuthState authState,
    bool isDark,
    Color accent,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(
          _loginEmailCtrl,
          'Gmail or Email Address',
          Icons.mail_outline_rounded,
          false,
          isDark,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        if (!_showRecoveryReset) ...[
          const SizedBox(height: 12),
          _buildTextField(
            _loginPassCtrl,
            'Password',
            Icons.lock_outline_rounded,
            _hideLoginPass,
            isDark,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => authService.signInWithEmail(
              email: _loginEmailCtrl.text,
              password: _loginPassCtrl.text,
            ),
            onToggleObscure: () =>
                setState(() => _hideLoginPass = !_hideLoginPass),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                authService.clearMessages();
                setState(() => _showRecoveryReset = true);
              },
              child: Text(
                'Forgot password? Use Recovery Key',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _PrimaryGradientActionButton(
            label: 'Sign In to MUXIS Cloud',
            isLoading: authState.isLoading,
            isDark: isDark,
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
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            _resetPassCtrl,
            'New Password (min. 6 characters)',
            Icons.lock_reset_rounded,
            _hideLoginPass,
            isDark,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => authService.resetPasswordWithRecoveryKey(
              email: _loginEmailCtrl.text,
              recoveryKey: _resetKeyCtrl.text,
              newPassword: _resetPassCtrl.text,
            ),
            onToggleObscure: () =>
                setState(() => _hideLoginPass = !_hideLoginPass),
          ),
          const SizedBox(height: 14),
          _PrimaryGradientActionButton(
            label: 'Reset Password & Sign In',
            isLoading: authState.isLoading,
            isDark: isDark,
            onPressed: () => authService.resetPasswordWithRecoveryKey(
              email: _loginEmailCtrl.text,
              recoveryKey: _resetKeyCtrl.text,
              newPassword: _resetPassCtrl.text,
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: () {
                authService.clearMessages();
                setState(() => _showRecoveryReset = false);
              },
              child: Text(
                'Back to Password Sign In',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSignUpForm(
    SupabaseAuthService authService,
    AuthState authState,
    bool isDark,
    Color accent,
  ) {
    final pass = _regPassCtrl.text;
    final passStrength = _computePasswordStrength(pass);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(
          _regNameCtrl,
          'Display Name',
          Icons.person_outline_rounded,
          false,
          isDark,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _regEmailCtrl,
          'Gmail or Email Address',
          Icons.mail_outline_rounded,
          false,
          isDark,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _regPassCtrl,
          'Password (min. 6 characters)',
          Icons.lock_outline_rounded,
          _hideRegPass,
          isDark,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => authService.signUpWithEmail(
            email: _regEmailCtrl.text,
            password: _regPassCtrl.text,
            displayName: _regNameCtrl.text,
          ),
          onToggleObscure: () => setState(() => _hideRegPass = !_hideRegPass),
        ),
        if (pass.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: passStrength.fraction,
                    minHeight: 4,
                    backgroundColor: MuxisColors.border(isDark),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      passStrength.color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                passStrength.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: passStrength.color,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        _PrimaryGradientActionButton(
          label: 'Create Free Cloud Account',
          isLoading: authState.isLoading,
          isDark: isDark,
          onPressed: () => authService.signUpWithEmail(
            email: _regEmailCtrl.text,
            password: _regPassCtrl.text,
            displayName: _regNameCtrl.text,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Instant activation with Backup Recovery Key — your local audio stays strictly offline on your device.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            color: MuxisColors.textMuted(isDark),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  ({double fraction, String label, Color color}) _computePasswordStrength(
    String password,
  ) {
    if (password.length < 6) {
      return (fraction: 0.25, label: 'Too short', color: MuxisColors.error);
    }
    int score = 1;
    if (password.length >= 10) score++;
    if (RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password)) {
      score++;
    }
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;
    return switch (score) {
      1 => (fraction: 0.45, label: 'Fair', color: MuxisColors.warning),
      2 => (fraction: 0.72, label: 'Good', color: MuxisColors.info),
      _ => (fraction: 1.0, label: 'Strong', color: MuxisColors.success),
    };
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String hint,
    IconData icon,
    bool obscure,
    bool isDark, {
    TextInputType keyboardType = TextInputType.text,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
    VoidCallback? onToggleObscure,
  }) {
    final accent = MuxisColors.accent(isDark);
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        color: MuxisColors.textPrimary(isDark),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 12.5,
          color: MuxisColors.textMuted(isDark),
        ),
        prefixIcon: Icon(icon, size: 18, color: accent),
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
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: MuxisColors.border(isDark)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: MuxisColors.border(isDark)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }
}

class _ShowcasePoint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final Color accent;
  final bool isDark;

  const _ShowcasePoint({
    required this.icon,
    required this.title,
    required this.detail,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: isDark ? 0.16 : 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: accent),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MuxisColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.38,
                  color: MuxisColors.textMuted(isDark),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SegmentTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDark;
  final Color accent;
  final VoidCallback onTap;

  const _SegmentTabButton({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? MuxisColors.surface(isDark) : Colors.transparent,
            borderRadius: BorderRadius.circular(9.5),
            border: selected
                ? Border.all(color: accent.withValues(alpha: 0.42))
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.25 : 0.06,
                      ),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? MuxisColors.textPrimary(isDark)
                  : MuxisColors.textMuted(isDark),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color tint;
  final Color textColor;

  const _StatusBanner({
    required this.message,
    required this.icon,
    required this.tint,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: tint.withValues(alpha: 0.42)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tint, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, height: 1.38, color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryGradientActionButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final bool isDark;
  final VoidCallback onPressed;

  const _PrimaryGradientActionButton({
    required this.label,
    required this.isLoading,
    required this.isDark,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final onAccent = MuxisColors.onAccent(isDark);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isLoading ? null : onPressed,
        child: Ink(
          height: 46,
          decoration: BoxDecoration(
            gradient: MuxisGradients.activePrimary(isDark),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: MuxisColors.accent(isDark).withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(onAccent),
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: onAccent,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
