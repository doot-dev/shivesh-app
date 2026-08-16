import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/animations.dart';
import '../../providers/auth_providers.dart';

class OtpPage extends ConsumerStatefulWidget {
  const OtpPage({super.key});

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

/// Length of the OTP the backend expects. Kept in one place so the pin field
/// and the submit guard can never disagree.
const _otpLength = 4;

/// How long the user must wait before asking for another code.
const _resendCooldown = 30;

class _OtpPageState extends ConsumerState<OtpPage>
    with SingleTickerProviderStateMixin {
  final _pinController = TextEditingController();
  final _focusNode = FocusNode();

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..forward();

  Timer? _cooldownTimer;
  int _secondsLeft = _resendCooldown;

  @override
  void initState() {
    super.initState();
    _startCooldown();
    // Focus the pin field so the keyboard is ready without an extra tap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _secondsLeft = _resendCooldown);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _pinController.dispose();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// The OTP is a fixed 4-digit code checked by the backend — this only guards
  /// against submitting a half-typed pin.
  Future<void> _handleSubmit() async {
    final otp = _pinController.text;
    if (otp.length != _otpLength) {
      _focusNode.requestFocus();
      _snack('Please enter the 4-digit code.');
      return;
    }

    final identifier = ref.read(authProvider).phone;
    if (identifier == null) {
      context.go('/login');
      return;
    }

    final success = await ref
        .read(authProvider.notifier)
        .verifyOtp(identifier, otp);
    if (success && mounted) {
      context.go('/home');
    } else if (mounted) {
      // Clear the wrong code so the user can retype immediately.
      _pinController.clear();
      _focusNode.requestFocus();
    }
  }

  Future<void> _handleResend() async {
    if (_secondsLeft > 0) return;
    final identifier = ref.read(authProvider).phone;
    if (identifier == null) return;
    _pinController.clear();
    final success = await ref.read(authProvider.notifier).sendOtp(identifier);
    if (success && mounted) {
      _startCooldown();
      _snack('A new code has been sent.');
    }
  }

  void _snack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.dangerFg : AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyles.radiusSm),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  PinTheme _pinTheme({Color? border, Color? fill}) {
    return PinTheme(
      width: 58,
      height: 64,
      textStyle: Theme.of(context).textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      decoration: BoxDecoration(
        color: fill ?? Colors.white,
        borderRadius: BorderRadius.circular(AppStyles.radiusMd),
        border: Border.all(color: border ?? AppColors.border, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.error != null && prev?.error != next.error) {
        _snack(next.error!, isError: true);
      }
    });

    // `phone` may hold a clientId code rather than a number, since login accepts
    // either — only mask and prefix it when it really is a 10-digit mobile.
    final identifier = authState.phone ?? '';
    final isMobile = RegExp(r'^\d{10}$').hasMatch(identifier);
    final subtitle = isMobile
        ? '+91 ${identifier.substring(0, 2)}XXXXXX${identifier.substring(8)}'
        : identifier;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.brandGradient),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => context.go('/login'),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Center(
                    child: FadeSlideIn(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.14),
                            ),
                            child: const Icon(
                              Icons.sms_outlined,
                              size: 34,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Verify it\'s you',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 7,
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
                          24,
                          32,
                          24,
                          MediaQuery.of(context).viewInsets.bottom + 28,
                        ),
                        child: Column(
                          children: [
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
                            Text(
                              'Enter the 4-digit code',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              identifier.isNotEmpty
                                  ? 'Sent to $subtitle'
                                  : 'Enter the code you received',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 30),
                            Pinput(
                              length: _otpLength,
                              controller: _pinController,
                              focusNode: _focusNode,
                              defaultPinTheme: _pinTheme(),
                              focusedPinTheme: _pinTheme(
                                border: AppColors.primary,
                                fill: AppColors.primary.withValues(
                                  alpha: 0.04,
                                ),
                              ),
                              submittedPinTheme: _pinTheme(
                                border: AppColors.primary,
                                fill: AppColors.primary.withValues(
                                  alpha: 0.06,
                                ),
                              ),
                              separatorBuilder: (_) =>
                                  const SizedBox(width: 12),
                              showCursor: true,
                              enabled: !authState.isLoading,
                              keyboardType: TextInputType.number,
                              onCompleted: (_) => _handleSubmit(),
                            ),
                            const SizedBox(height: 30),
                            _VerifyButton(
                              isLoading: authState.isLoading,
                              onPressed: _handleSubmit,
                            ),
                            const SizedBox(height: 14),
                            _ResendRow(
                              secondsLeft: _secondsLeft,
                              enabled:
                                  !authState.isLoading && _secondsLeft == 0,
                              onResend: _handleResend,
                            ),
                          ],
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

class _VerifyButton extends StatelessWidget {
  const _VerifyButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: isLoading ? null : onPressed,
      child: Container(
        width: double.infinity,
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
              : Text(
                  'Verify & continue',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Resend control with a visible countdown, so the button never looks broken
/// while it is on cooldown.
class _ResendRow extends StatelessWidget {
  const _ResendRow({
    required this.secondsLeft,
    required this.enabled,
    required this.onResend,
  });

  final int secondsLeft;
  final bool enabled;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Didn\'t get the code?',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: enabled ? onResend : null,
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            secondsLeft > 0 ? 'Resend in ${secondsLeft}s' : 'Resend',
            style: theme.textTheme.bodySmall?.copyWith(
              color: enabled ? AppColors.primary : AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
