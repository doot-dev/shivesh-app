import 'package:flutter/material.dart';

/// Central palette extracted from the Shivesh login visual.
///
/// The five brand colours below are FIXED — the rest of the file derives from
/// them, so a redesign changes depth and motion without shifting the brand.
class AppColors {
  const AppColors._();

  // ─── Brand (do not change) ──────────────────────────────────────────────
  static const Color primary = Color(0xFF1F3E96);
  static const Color primaryDark = Color(0xFF142D6E);
  static const Color secondary = Color(0xFFFFB547);
  static const Color accent = Color(0xFF5BC17D);

  static const Color background = Color(0xFFE8EEFF);
  static const Color surface = Color(0xFFF6F8FF);
  static const Color card = Color(0xFFF4F6FF);

  static const Color textPrimary = Color(0xFF0F1F41);
  static const Color textMuted = Color(0xFF7B86AA);

  static const Color border = Color(0xFFD2DBF4);

  static const Color gradientStart = Color(0xFFE1EBFF);
  static const Color gradientEnd = Color(0xFFFFFFFF);

  // ─── Derived tones ──────────────────────────────────────────────────────
  /// A lighter primary used for gradient tails and highlights.
  static const Color primaryLight = Color(0xFF3557C4);

  /// Very low-emphasis surface for skeletons and inactive chips.
  static const Color shimmerBase = Color(0xFFE4EAFA);
  static const Color shimmerHighlight = Color(0xFFF4F7FF);

  // ─── Semantic status colours ────────────────────────────────────────────
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color successFg = Color(0xFF15803D);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color warningFg = Color(0xFF92400E);
  static const Color infoBg = Color(0xFFDBEAFE);
  static const Color infoFg = Color(0xFF1E40AF);
  static const Color dangerBg = Color(0xFFFEE2E2);
  static const Color dangerFg = Color(0xFFB91C1C);

  // ─── Gradients ──────────────────────────────────────────────────────────
  /// The signature header gradient — used on the home header and profile hero.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  static const LinearGradient pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [gradientStart, gradientEnd],
  );
}

/// Shared elevation, radius and motion tokens.
///
/// Centralising these is what makes the app feel like one product: every card
/// uses the same corner radius and the same shadow, every transition the same
/// curve and duration.
class AppStyles {
  const AppStyles._();

  // Radii
  static const double radiusSm = 12;
  static const double radiusMd = 18;
  static const double radiusLg = 24;
  static const double radiusXl = 32;

  // Motion — one curve and a short/medium/long duration for the whole app.
  static const Curve curve = Curves.easeOutCubic;
  static const Curve curveEmphasised = Curves.easeOutBack;
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 550);

  /// Soft, brand-tinted card shadow. A blue-tinted shadow reads as "designed";
  /// a grey/black one reads as default Material.
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.06),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get raisedShadow => [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.14),
      blurRadius: 28,
      offset: const Offset(0, 12),
    ),
  ];
}
