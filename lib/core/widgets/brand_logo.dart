import 'package:flutter/material.dart';

/// How the Shivesh logo is drawn.
enum BrandLogoVariant {
  /// The full lockup: lotus mark above the "SHIVESH / Group of Companies"
  /// wordmark. Only legible on a LIGHT background — the wordmark is dark teal.
  lockup,

  /// The lotus mark alone. Use on the dark brand gradient, where the lockup's
  /// wordmark all but disappears.
  mark,
}

/// The Shivesh logo, always in its real brand colours — never tinted.
///
/// Rendered exactly like the splash screen: the artwork sits directly on the
/// background with no white chip or box behind it.
///
/// Two things this widget exists to prevent, both of which were live bugs:
///
///  * `Image.asset(..., color: Colors.white)` — the artwork is genuinely
///    multicoloured (orange, green, teal), so a `color:` filter collapses it
///    into a flat silhouette and throws the brand away.
///  * The full lockup on the dark header — measured, 25% of its pixels fall
///    below 1.6:1 contrast against `#1F3E96`, because the bottom third of the
///    artwork is a dark-teal wordmark. Hence [BrandLogoVariant.mark], which
///    crops to the colourful lotus and stays legible without a chip.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.height = 40,
    this.variant = BrandLogoVariant.lockup,
  });

  /// Height of the logo artwork.
  final double height;

  /// Which cut of the logo to draw. Use [BrandLogoVariant.mark] on dark
  /// surfaces and wherever the wordmark is already set in text beside it.
  final BrandLogoVariant variant;

  /// Convenience for the dark brand header/gradient.
  const BrandLogo.onDark({Key? key, double height = 40})
    : this(key: key, height: height, variant: BrandLogoVariant.mark);

  @override
  Widget build(BuildContext context) {
    // No `color:` filter and no chip — this is the whole point of the widget.
    return Image.asset(
      switch (variant) {
        BrandLogoVariant.lockup => 'assets/logo/logo.png',
        BrandLogoVariant.mark => 'assets/logo/logo_mark.png',
      },
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}
