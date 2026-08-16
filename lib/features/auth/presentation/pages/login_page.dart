import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/brand_logo.dart';
import '../../providers/auth_providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _focusNode = FocusNode();

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _phoneController.dispose();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Accepts either a 10-digit mobile number or a clientId code — the backend
  /// resolves both through the same login endpoint.
  String? _validateNumber(String? value) {
    final trimmed = value?.replaceAll(RegExp(r'\s+'), '') ?? '';
    if (trimmed.isEmpty) return 'Please enter your client number';

    final isPhone = RegExp(r'^\d{10}$').hasMatch(trimmed);
    final isClientCode = RegExp(r'^[A-Za-z0-9\-_/]{4,}$').hasMatch(trimmed);

    if (!isPhone && !isClientCode) {
      return 'Enter your 10-digit mobile number or client ID';
    }
    return null;
  }

  /// Step 1 of login — the backend confirms the number belongs to an active
  /// client, then we move to the OTP screen which completes the login.
  Future<void> _handleSubmit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final number = _phoneController.text.trim();
    final success = await ref.read(authProvider.notifier).sendOtp(number);
    if (success && mounted) {
      context.go('/otp');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.error != null && prev?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.dangerFg,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppStyles.radiusSm),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.primary,
      // resizeToAvoidBottomInset keeps the Continue button reachable when the
      // keyboard is up — otherwise it sits underneath the keys.
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Brand gradient behind everything.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.brandGradient),
            ),
          ),
          _FloatingOrb(controller: _controller, top: -90, left: -70, size: 240),
          _FloatingOrb(
            controller: _controller,
            top: 60,
            right: -90,
            size: 190,
            inverted: true,
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Brand block ─────────────────────────────────────────
                Expanded(
                  flex: 4,
                  child: Center(
                    child: FadeSlideIn(
                      offset: 30,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Mark only: "SHIVESH / Group of Companies" is
                          // already set as white text directly below, so the
                          // full lockup would print the wordmark twice.
                          const BrandLogo.onDark(height: 92),
                          const SizedBox(height: 18),
                          Text(
                            'SHIVESH',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Group of Companies',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Login sheet ─────────────────────────────────────────
                Expanded(
                  flex: 6,
                  child: FadeSlideIn(
                    index: 1,
                    offset: 60,
                    duration: AppStyles.slow,
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(38),
                          topRight: Radius.circular(38),
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          28,
                          32,
                          28,
                          MediaQuery.of(context).viewInsets.bottom + 28,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Grab handle — signals a sheet.
                              Center(
                                child: Container(
                                  width: 42,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: AppColors.border,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 26),

                              // Explains an unexpected bounce back to login.
                              if (authState.sessionExpiredMessage != null)
                                _SessionExpiredBanner(
                                  message: authState.sessionExpiredMessage!,
                                  onDismiss: () => ref
                                      .read(authProvider.notifier)
                                      .acknowledgeSessionExpiry(),
                                ),

                              Text(
                                'Welcome back',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Log in with your registered client number to '
                                'track your projects and orders.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textMuted,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 26),

                              Text(
                                'Client number',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _phoneController,
                                focusNode: _focusNode,
                                decoration: InputDecoration(
                                  hintText: 'Mobile number or client ID',
                                  prefixIcon: const Icon(
                                    Icons.badge_outlined,
                                    color: AppColors.textMuted,
                                    size: 20,
                                  ),
                                  suffixIcon: _phoneController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.close_rounded,
                                            size: 18,
                                            color: AppColors.textMuted,
                                          ),
                                          onPressed: () =>
                                              setState(_phoneController.clear),
                                        )
                                      : null,
                                ),
                                keyboardType: TextInputType.text,
                                textInputAction: TextInputAction.done,
                                validator: _validateNumber,
                                enabled: !authState.isLoading,
                                onChanged: (_) => setState(() {}),
                                onFieldSubmitted: (_) => authState.isLoading
                                    ? null
                                    : _handleSubmit(),
                              ),
                              const SizedBox(height: 26),

                              _SubmitButton(
                                isLoading: authState.isLoading,
                                onPressed: _handleSubmit,
                              ),
                              const SizedBox(height: 18),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 14,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'We\'ll send a verification code to confirm '
                                      'it\'s you',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: AppColors.textMuted,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Gradient submit button with an inline loading state.
class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: isLoading ? null : onPressed,
      child: AnimatedContainer(
        duration: AppStyles.medium,
        height: 56,
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(AppStyles.radiusMd),
          boxShadow: isLoading ? null : AppStyles.raisedShadow,
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Shown when the server rejected our token and we logged the user out.
/// Without this, a 401 mid-session looks like the app randomly signed them out.
class _SessionExpiredBanner extends StatelessWidget {
  const _SessionExpiredBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FadeSlideIn(
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: AppColors.warningBg,
          borderRadius: BorderRadius.circular(AppStyles.radiusSm),
          border: Border.all(
            color: AppColors.warningFg.withValues(alpha: 0.20),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: AppColors.warningFg,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.warningFg,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.close_rounded,
                size: 16,
                color: AppColors.warningFg,
              ),
              onPressed: onDismiss,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

/// Slow-drifting translucent circle — adds depth to the brand area.
class _FloatingOrb extends StatelessWidget {
  const _FloatingOrb({
    required this.controller,
    required this.size,
    this.top,
    this.left,
    this.right,
    this.inverted = false,
  });

  final AnimationController controller;
  final double size;
  final double? top;
  final double? left;
  final double? right;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final t = Curves.easeOut.transform(controller.value);
          return Transform.scale(
            scale: 0.7 + (t * 0.3),
            child: Opacity(opacity: t, child: child),
          );
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: inverted ? 0.05 : 0.08),
          ),
        ),
      ),
    );
  }
}
