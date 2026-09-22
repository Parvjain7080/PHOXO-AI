import 'dart:ui';
import 'package:flutter/material.dart';

/// A frosted-glass panel: blurred backdrop + translucent fill + hairline
/// border. This is the one visual signature reused everywhere (chat
/// bubbles, the input bar, model picker) so the app reads as one system.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
    this.blurSigma = 18,
    this.accentColor,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blurSigma;

  /// Optional accent used for a subtle top-edge gradient + border tint —
  /// pass Theme.of(context).colorScheme.primary or .secondary to signal
  /// "this bubble/panel belongs to X state" without adding a new color.
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseFill = isDark
        ? Colors.white.withValues(alpha: 0.045)
        : Colors.white.withValues(alpha: 0.55);
    final borderColor = accentColor?.withValues(alpha: 0.35) ??
        (isDark
            ? Colors.white.withValues(alpha: 0.12)
            : const Color(0xFFD8DCE3));

    return Container(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: baseFill,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderColor, width: 1),
            gradient: accentColor == null
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accentColor!.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                  ),
          ),
          child: child,
        ),
      ),
    );
  }
}