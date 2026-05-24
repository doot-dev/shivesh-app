import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final AnimationController _blobController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  late final AnimationController _entranceController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final Animation<double> _scaleAnimation =
      Tween<double>(begin: 0.92, end: 1).animate(
        CurvedAnimation(parent: _entranceController, curve: Curves.easeOutBack),
      );

  late final Animation<double> _opacityAnimation =
      Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _entranceController,
          curve: Curves.easeOutCubic,
        ),
      );

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 3), _goToLogin);
  }

  void _goToLogin() {
    if (!mounted) return;
    context.go('/login');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _blobController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.gradientStart, AppColors.gradientEnd],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              left: -60,
              child: _AnimatedBlob(controller: _blobController),
            ),
            Positioned(
              bottom: -100,
              right: -40,
              child: _AnimatedBlob(controller: _blobController, inverted: true),
            ),
            Center(
              child: FadeTransition(
                opacity: _opacityAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/logo/logo.png', height: 140),
                      const SizedBox(height: 20),
                      Text(
                        'SHIVESH',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 4,
                            ),
                      ),
                      Text(
                        'Group of Companies',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedBlob extends StatelessWidget {
  const _AnimatedBlob({required this.controller, this.inverted = false});

  final AnimationController controller;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final scale = 0.8 + (controller.value * 0.2);
        return Transform.rotate(
          angle: inverted ? -controller.value * 0.2 : controller.value * 0.2,
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(200),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: inverted
                ? [AppColors.primaryDark.withValues(alpha: 0.12), Colors.white]
                : [Colors.white, AppColors.primary.withValues(alpha: 0.12)],
          ),
        ),
      ),
    );
  }
}
