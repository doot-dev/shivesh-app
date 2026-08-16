import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Fade + rise entrance for list items and sections.
///
/// Pass [index] when building a list and each row animates slightly after the
/// one above it — the staggered effect that makes a list feel alive rather
/// than snapping in. The delay is capped so a long list never feels slow.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 24,
    this.duration = AppStyles.medium,
    this.staggerStep = const Duration(milliseconds: 55),
    this.maxStagger = const Duration(milliseconds: 400),
  });

  final Widget child;
  final int index;
  final double offset;
  final Duration duration;
  final Duration staggerStep;
  final Duration maxStagger;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: AppStyles.curve,
  );

  @override
  void initState() {
    super.initState();
    final delayMs = (widget.staggerStep.inMilliseconds * widget.index).clamp(
      0,
      widget.maxStagger.inMilliseconds,
    );
    Future.delayed(Duration(milliseconds: delayMs), () {
      // The row can scroll out of the tree before its delay elapses.
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fade,
      builder: (context, child) => Opacity(
        opacity: _fade.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - _fade.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Press feedback: the card dips slightly while held.
///
/// Material's ink splash is invisible on our light cards, so scale gives the
/// tap a physical response instead.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // opaque, NOT the deferToChild default: children whose surface comes from
      // a BoxDecoration (the circular send button) do not reliably answer hit
      // tests, so taps inside the visible shape were being dropped entirely.
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: AppStyles.fast,
        curve: AppStyles.curve,
        child: widget.child,
      ),
    );
  }
}

/// A sweeping highlight used by the skeleton loaders.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            // Sweep from off-screen left to off-screen right.
            final dx = bounds.width * (_controller.value * 2 - 1);
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                AppColors.shimmerBase,
                AppColors.shimmerHighlight,
                AppColors.shimmerBase,
              ],
              stops: const [0.35, 0.5, 0.65],
            ).createShader(
              Rect.fromLTWH(dx, 0, bounds.width, bounds.height),
            );
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A single grey block inside a skeleton.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.shimmerBase,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
