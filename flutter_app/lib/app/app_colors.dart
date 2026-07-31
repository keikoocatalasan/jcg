import 'package:flutter/material.dart';

/// The five immutable brand colors supplied for NutriSmart AI / JCG Fitness.
/// Semantic UI code should consume [AppSemanticColors], not these raw values.
abstract final class AppPalette {
  static const white = Color(0xFFFFFFFF);
  static const cyan50 = Color(0xFFE9FBFF);
  static const cyan100 = Color(0xFFBDF1FF);
  static const cyan500 = Color(0xFF3CC7E8);
  static const teal900 = Color(0xFF115166);
}

/// Supporting neutrals are used only where the five-color palette cannot meet
/// WCAG contrast by itself. `ink` is intentionally near-black, not #000000.
/// It produces 7.57:1 on #3CC7E8, while white produces only 1.95:1.
abstract final class AppSupportingColors {
  static const ink = Color(0xFF062A35);
  static const inkMuted = Color(0xFF2B6172);
  static const darkSurface = Color(0xFF0B3F50);
  static const darkElevated = Color(0xFF164F61);
  static const errorLight = Color(0xFF9B2C2C);
  static const errorDark = Color(0xFFFFB4AB);
  static const successLight = Color(0xFF236A4B);
  static const successDark = Color(0xFF8EDDB8);
}

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color background;
  final Color backgroundAlt;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceGlass;
  final Color surfaceGlassStrong;
  final Color primary;
  final Color onPrimary;
  final Color accentSoft;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textDisabled;
  final Color border;
  final Color borderStrong;
  final Color shadow;
  final Color scrim;
  final Color error;
  final Color onError;
  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;
  final Color calorie;
  final Color protein;
  final Color carbs;
  final Color fat;
  final Color budget;

  const AppSemanticColors({
    required this.background,
    required this.backgroundAlt,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceGlass,
    required this.surfaceGlassStrong,
    required this.primary,
    required this.onPrimary,
    required this.accentSoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textDisabled,
    required this.border,
    required this.borderStrong,
    required this.shadow,
    required this.scrim,
    required this.error,
    required this.onError,
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.calorie,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.budget,
  });

  /// WCAG body-text pairings:
  /// - #115166 on #FFFFFF: 8.78:1
  /// - #115166 on #E9FBFF: 8.24:1
  /// - #115166 on #BDF1FF: 7.18:1
  /// - #062A35 on #3CC7E8: 7.57:1
  static const light = AppSemanticColors(
    background: AppPalette.cyan50,
    backgroundAlt: AppPalette.cyan100,
    surface: AppPalette.white,
    surfaceElevated: AppPalette.white,
    surfaceGlass: Color(0x38FFFFFF),
    surfaceGlassStrong: Color(0x54FFFFFF),
    primary: AppPalette.cyan500,
    onPrimary: AppSupportingColors.ink,
    accentSoft: Color(0x293CC7E8),
    textPrimary: AppPalette.teal900,
    textSecondary: AppSupportingColors.inkMuted,
    textMuted: Color(0xCC2B6172),
    textDisabled: Color(0x99315F6D),
    border: Color(0x66BDF1FF),
    borderStrong: Color(0x993CC7E8),
    shadow: Color(0x24115166),
    scrim: Color(0x99062A35),
    error: AppSupportingColors.errorLight,
    onError: AppPalette.white,
    success: AppSupportingColors.successLight,
    onSuccess: AppPalette.white,
    warning: AppPalette.teal900,
    onWarning: AppPalette.white,
    calorie: AppPalette.cyan500,
    protein: AppPalette.teal900,
    carbs: AppSupportingColors.inkMuted,
    fat: Color(0xFF4A7785),
    budget: AppPalette.cyan500,
  );

  /// WCAG body-text pairings:
  /// - #FFFFFF on #115166: 8.78:1
  /// - #BDF1FF on #115166: 7.18:1
  /// - #062A35 on #3CC7E8: 7.57:1
  /// - #062A35 on #FFB4AB: 8.90:1
  static const dark = AppSemanticColors(
    background: AppPalette.teal900,
    backgroundAlt: AppSupportingColors.darkSurface,
    surface: AppPalette.teal900,
    surfaceElevated: AppSupportingColors.darkElevated,
    surfaceGlass: Color(0x26FFFFFF),
    surfaceGlassStrong: Color(0x47BDF1FF),
    primary: AppPalette.cyan500,
    onPrimary: AppSupportingColors.ink,
    accentSoft: Color(0x333CC7E8),
    textPrimary: AppPalette.white,
    textSecondary: AppPalette.cyan100,
    textMuted: Color(0xCCE9FBFF),
    textDisabled: Color(0x99BDF1FF),
    border: Color(0x4DBDF1FF),
    borderStrong: Color(0x733CC7E8),
    shadow: Color(0x52062A35),
    scrim: Color(0xB3062A35),
    error: AppSupportingColors.errorDark,
    onError: AppSupportingColors.ink,
    success: AppSupportingColors.successDark,
    onSuccess: AppSupportingColors.ink,
    warning: AppPalette.cyan100,
    onWarning: AppSupportingColors.ink,
    calorie: AppPalette.cyan500,
    protein: AppPalette.white,
    carbs: AppPalette.cyan100,
    fat: AppPalette.cyan50,
    budget: AppPalette.cyan500,
  );

  @override
  AppSemanticColors copyWith({
    Color? background,
    Color? backgroundAlt,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceGlass,
    Color? surfaceGlassStrong,
    Color? primary,
    Color? onPrimary,
    Color? accentSoft,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textDisabled,
    Color? border,
    Color? borderStrong,
    Color? shadow,
    Color? scrim,
    Color? error,
    Color? onError,
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
    Color? calorie,
    Color? protein,
    Color? carbs,
    Color? fat,
    Color? budget,
  }) {
    return AppSemanticColors(
      background: background ?? this.background,
      backgroundAlt: backgroundAlt ?? this.backgroundAlt,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceGlass: surfaceGlass ?? this.surfaceGlass,
      surfaceGlassStrong: surfaceGlassStrong ?? this.surfaceGlassStrong,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      accentSoft: accentSoft ?? this.accentSoft,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textDisabled: textDisabled ?? this.textDisabled,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      shadow: shadow ?? this.shadow,
      scrim: scrim ?? this.scrim,
      error: error ?? this.error,
      onError: onError ?? this.onError,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      calorie: calorie ?? this.calorie,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      budget: budget ?? this.budget,
    );
  }

  @override
  AppSemanticColors lerp(covariant AppSemanticColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppSemanticColors(
      background: mix(background, other.background),
      backgroundAlt: mix(backgroundAlt, other.backgroundAlt),
      surface: mix(surface, other.surface),
      surfaceElevated: mix(surfaceElevated, other.surfaceElevated),
      surfaceGlass: mix(surfaceGlass, other.surfaceGlass),
      surfaceGlassStrong: mix(surfaceGlassStrong, other.surfaceGlassStrong),
      primary: mix(primary, other.primary),
      onPrimary: mix(onPrimary, other.onPrimary),
      accentSoft: mix(accentSoft, other.accentSoft),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textMuted: mix(textMuted, other.textMuted),
      textDisabled: mix(textDisabled, other.textDisabled),
      border: mix(border, other.border),
      borderStrong: mix(borderStrong, other.borderStrong),
      shadow: mix(shadow, other.shadow),
      scrim: mix(scrim, other.scrim),
      error: mix(error, other.error),
      onError: mix(onError, other.onError),
      success: mix(success, other.success),
      onSuccess: mix(onSuccess, other.onSuccess),
      warning: mix(warning, other.warning),
      onWarning: mix(onWarning, other.onWarning),
      calorie: mix(calorie, other.calorie),
      protein: mix(protein, other.protein),
      carbs: mix(carbs, other.carbs),
      fat: mix(fat, other.fat),
      budget: mix(budget, other.budget),
    );
  }
}

extension AppThemeColors on BuildContext {
  AppSemanticColors get colors =>
      Theme.of(this).extension<AppSemanticColors>() ?? AppSemanticColors.dark;
}

/// Temporary compatibility facade for screens not yet migrated to context
/// tokens. Values map to the dark semantic scheme used by the current app.
abstract final class AppColors {
  static const bgPrimary = AppPalette.teal900;
  static const bgSecondary = AppSupportingColors.darkSurface;
  static const bgTertiary = AppSupportingColors.darkElevated;
  static const bgElevated = Color(0xE6164F61);
  static const bgGlass = Color(0x26FFFFFF);
  static const bgGlassStrong = Color(0x47BDF1FF);
  static const bgOverlay = Color(0xB3062A35);
  static const accentPrimary = AppPalette.cyan500;
  static const accentHover = AppPalette.cyan100;
  static const accentActive = AppPalette.teal900;
  static const accentSoft = Color(0x333CC7E8);
  static const accentMuted = Color(0x1F3CC7E8);
  static const accentBorder = Color(0x733CC7E8);
  static const accentBorderStrong = Color(0xB33CC7E8);
  static const accentGlow = Color(0x3D3CC7E8);
  static const textPrimary = AppPalette.white;
  static const textSecondary = AppPalette.cyan100;
  static const textMuted = Color(0xCCE9FBFF);
  static const textDisabled = Color(0x99BDF1FF);
  static const textOnAccent = AppSupportingColors.ink;
  static const textLink = AppPalette.cyan500;
  static const borderDefault = Color(0x4DBDF1FF);
  static const borderSubtle = Color(0x33BDF1FF);
  static const borderAccent = Color(0x733CC7E8);
  static const borderFocus = AppPalette.cyan500;
  static const success = AppSupportingColors.successDark;
  static const warning = AppPalette.cyan100;
  static const error = AppSupportingColors.errorDark;
  static const info = AppPalette.cyan50;
  static const primary = accentPrimary;
  static const primaryLight = AppPalette.cyan100;
  static const primaryDark = AppPalette.teal900;
  static const secondary = AppSupportingColors.darkElevated;
  static const secondaryLight = AppPalette.cyan100;
  static const secondaryDark = AppSupportingColors.darkSurface;
  static const surface = bgPrimary;
  static const surfaceAlt = bgTertiary;
  static const background = bgPrimary;
  static const divider = borderDefault;
  static const border = borderDefault;
  static const borderStrong = Color(0x80BDF1FF);
  static const calorieColor = accentPrimary;
  static const proteinColor = AppPalette.white;
  static const carbsColor = AppPalette.cyan100;
  static const fatColor = AppPalette.cyan50;
  static const budgetColor = accentPrimary;
}
