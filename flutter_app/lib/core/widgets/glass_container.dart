import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:jcg_fitness/app/app_colors.dart';

/// Surface hierarchy controls the amount of blur and opacity used by glass.
enum GlassSurfaceLevel { card, panel, chrome, overlay, modal }

/// A bounded glass surface with a static, repaint-isolated path for scrollable
/// content and a live [BackdropFilter] path for stationary chrome and overlays.
///
/// Keep [liveBlur] false inside ListView/GridView items. The assertion prevents
/// card and panel levels from accidentally enabling an expensive live blur.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.level = GlassSurfaceLevel.card,
    this.liveBlur = false,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.blurSigma,
    this.fillOpacity,
    this.borderOpacity = 0.25,
    this.clipBehavior = Clip.antiAlias,
  })  : assert(
            fillOpacity == null || (fillOpacity >= 0.15 && fillOpacity <= 0.4)),
        assert(borderOpacity >= 0.2 && borderOpacity <= 0.3),
        assert(!liveBlur ||
            level == GlassSurfaceLevel.chrome ||
            level == GlassSurfaceLevel.overlay ||
            level == GlassSurfaceLevel.modal);

  final Widget child;
  final GlassSurfaceLevel level;
  final bool liveBlur;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final double? blurSigma;
  final double? fillOpacity;
  final double borderOpacity;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final spec = _GlassSpec.forLevel(level);
    final sigma = blurSigma ?? spec.blurSigma;
    final opacity = fillOpacity ?? spec.fillOpacity;
    assert(sigma >= spec.minimumBlur && sigma <= spec.maximumBlur);

    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.colors;
    final fill = (dark ? AppPalette.cyan100 : AppPalette.white)
        .withValues(alpha: opacity);
    final border = (dark ? AppPalette.cyan100 : AppPalette.white)
        .withValues(alpha: borderOpacity);

    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: borderRadius,
        border: Border.all(color: border, width: 1),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: dark ? 0.22 : 0.14),
            blurRadius: level == GlassSurfaceLevel.modal ? 24 : 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: child,
      ),
    );

    Widget surface;
    if (liveBlur) {
      surface = ClipRRect(
        borderRadius: borderRadius,
        clipBehavior: clipBehavior,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: decorated,
        ),
      );
    } else {
      // Static glass is intentionally isolated from parent scroll repaints.
      surface = RepaintBoundary(
        child: ClipRRect(
          borderRadius: borderRadius,
          clipBehavior: clipBehavior,
          child: decorated,
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      margin: margin,
      child: surface,
    );
  }
}

/// Static glass card intended for lists, grids, and dashboard panels.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.level = GlassSurfaceLevel.card,
  }) : assert(level == GlassSurfaceLevel.card ||
            level == GlassSurfaceLevel.panel);

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius borderRadius;
  final GlassSurfaceLevel level;

  @override
  Widget build(BuildContext context) => GlassContainer(
        level: level,
        liveBlur: false,
        padding: padding,
        margin: margin,
        borderRadius: borderRadius,
        child: child,
      );
}

/// Palette-backed static background layering behind glass surfaces.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [
                  AppPalette.teal900,
                  AppSupportingColors.darkSurface,
                  AppPalette.teal900,
                ]
              : const [
                  AppPalette.cyan50,
                  AppPalette.white,
                  AppPalette.cyan100,
                ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.topRight,
                child: FractionallySizedBox(
                  widthFactor: 0.65,
                  heightFactor: 0.32,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          AppPalette.cyan500.withValues(alpha: 0.14),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _GlassSpec {
  const _GlassSpec({
    required this.blurSigma,
    required this.fillOpacity,
    required this.minimumBlur,
    required this.maximumBlur,
  });

  final double blurSigma;
  final double fillOpacity;
  final double minimumBlur;
  final double maximumBlur;

  static _GlassSpec forLevel(GlassSurfaceLevel level) => switch (level) {
        GlassSurfaceLevel.card => const _GlassSpec(
            blurSigma: 12,
            fillOpacity: 0.20,
            minimumBlur: 10,
            maximumBlur: 20,
          ),
        GlassSurfaceLevel.panel => const _GlassSpec(
            blurSigma: 18,
            fillOpacity: 0.28,
            minimumBlur: 10,
            maximumBlur: 20,
          ),
        GlassSurfaceLevel.chrome => const _GlassSpec(
            blurSigma: 8,
            fillOpacity: 0.22,
            minimumBlur: 5,
            maximumBlur: 10,
          ),
        GlassSurfaceLevel.overlay => const _GlassSpec(
            blurSigma: 24,
            fillOpacity: 0.32,
            minimumBlur: 20,
            maximumBlur: 30,
          ),
        GlassSurfaceLevel.modal => const _GlassSpec(
            blurSigma: 28,
            fillOpacity: 0.35,
            minimumBlur: 20,
            maximumBlur: 30,
          ),
      };
}
