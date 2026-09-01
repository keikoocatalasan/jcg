import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jcg_fitness/app/app_colors.dart';

export 'package:jcg_fitness/app/app_colors.dart';

@Deprecated('Use AppSemanticColors from app_colors.dart')
class LegacyAppColors {
  LegacyAppColors._();

  // ── Background ──────────────────────────────────────────────
  static const Color bgPrimary = Color(0xFF08090A);
  static const Color bgSecondary = Color(0xFF0D0F10);
  static const Color bgTertiary = Color(0xFF131516);
  static const Color bgElevated = Color(0xE0161819); // #161819 at 88 %
  static const Color bgGlass = Color(0x09FFFFFF); // rgba(255,255,255,0.035)
  static const Color bgGlassStrong = Color(0xD1141617); // #141617 at 82 %
  static const Color bgOverlay = Color(0xAD000000); // rgba(0,0,0,0.68)

  // ── Yellow accent ───────────────────────────────────────────
  static const Color accentPrimary = Color(0xFFFFD400);
  static const Color accentHover = Color(0xFFFFE14A);
  static const Color accentActive = Color(0xFFE6BE00);
  static const Color accentSoft = Color(0x1FFFD400); // 12 %
  static const Color accentMuted = Color(0x14FFD400); // 8 %
  static const Color accentBorder = Color(0x47FFD400); // 28 %
  static const Color accentBorderStrong = Color(0x8CFFD400); // 55 %
  static const Color accentGlow = Color(0x24FFD400); // 14 %

  // ── Text ────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF7F7F5);
  static const Color textSecondary = Color(0xFFB8B8B2);
  static const Color textMuted = Color(0xFF85857F);
  static const Color textDisabled = Color(0xFF5D5F5C);
  static const Color textOnAccent = Color(0xFF08090A);
  static const Color textLink = Color(0xFFFFD400);

  // ── Borders ─────────────────────────────────────────────────
  static const Color borderDefault = Color(0x1AFFFFFF); // 10 %
  static const Color borderSubtle = Color(0x0FFFFFFF); // 6 %
  static const Color borderAccent = Color(0x47FFD400); // 28 %
  static const Color borderFocus = Color(0xCCFFD400); // 80 %

  // ── Semantic ────────────────────────────────────────────────
  static const Color success = Color(0xFFB9F56A);
  static const Color warning = Color(0xFFFFD400);
  static const Color error = Color(0xFFFF6B6B);
  static const Color info = Color(0xFFD7D7D2);

  // ── Legacy compatibility (used by existing screens) ─────────
  static const Color primary = accentPrimary;
  static const Color primaryLight = accentHover;
  static const Color primaryDark = accentActive;
  static const Color secondary = Color(0xFF2A2C2E);
  static const Color secondaryLight = Color(0xFF3A3C3E);
  static const Color secondaryDark = Color(0xFF1A1C1E);
  static const Color surface = bgPrimary;
  static const Color surfaceAlt = bgTertiary;
  static const Color background = bgPrimary;
  static const Color divider = borderDefault;
  static const Color border = borderDefault;
  static const Color borderStrong = Color(0x33FFFFFF);

  // ── Macro / chart colours ───────────────────────────────────
  static const Color calorieColor = accentPrimary;
  static const Color proteinColor = Color(0xFFF7F7F5);
  static const Color carbsColor = Color(0xFFB8B8B2);
  static const Color fatColor = Color(0xFF85857F);
  static const Color budgetColor = accentPrimary;
}

class AppTheme {
  AppTheme._();

  static TextStyle _monoStyle(TextStyle base) {
    return GoogleFonts.jetBrainsMono(
      fontSize: base.fontSize,
      fontWeight: base.fontWeight,
      letterSpacing: base.letterSpacing,
      height: base.height,
      color: base.color,
      decoration: base.decoration,
    );
  }

  static TextTheme _monoTextTheme(TextTheme base) {
    return TextTheme(
      displayLarge: _monoStyle(base.displayLarge ?? const TextStyle()),
      displayMedium: _monoStyle(base.displayMedium ?? const TextStyle()),
      displaySmall: _monoStyle(base.displaySmall ?? const TextStyle()),
      headlineLarge: _monoStyle(base.headlineLarge ?? const TextStyle()),
      headlineMedium: _monoStyle(base.headlineMedium ?? const TextStyle()),
      headlineSmall: _monoStyle(base.headlineSmall ?? const TextStyle()),
      titleLarge: _monoStyle(base.titleLarge ?? const TextStyle()),
      titleMedium: _monoStyle(base.titleMedium ?? const TextStyle()),
      titleSmall: _monoStyle(base.titleSmall ?? const TextStyle()),
      bodyLarge: _monoStyle(base.bodyLarge ?? const TextStyle()),
      bodyMedium: _monoStyle(base.bodyMedium ?? const TextStyle()),
      bodySmall: _monoStyle(base.bodySmall ?? const TextStyle()),
      labelLarge: _monoStyle(base.labelLarge ?? const TextStyle()),
      labelMedium: _monoStyle(base.labelMedium ?? const TextStyle()),
      labelSmall: _monoStyle(base.labelSmall ?? const TextStyle()),
    );
  }

  static ThemeData get light {
    const colors = AppSemanticColors.light;
    final base = ThemeData.light(useMaterial3: true);
    final monoText = _monoTextTheme(base.textTheme).apply(
      bodyColor: colors.textPrimary,
      displayColor: colors.textPrimary,
    );

    return base.copyWith(
      brightness: Brightness.light,
      extensions: const [colors],
      colorScheme: const ColorScheme.light(
        primary: AppPalette.cyan500,
        onPrimary: AppSupportingColors.ink,
        secondary: AppPalette.teal900,
        onSecondary: AppPalette.white,
        surface: AppPalette.white,
        onSurface: AppPalette.teal900,
        error: AppSupportingColors.errorLight,
        onError: AppPalette.white,
        surfaceContainerHighest: AppPalette.cyan100,
      ),
      scaffoldBackgroundColor: colors.background,
      textTheme: monoText,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colors.surfaceGlassStrong,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.jetBrainsMono(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceGlass,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: colors.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colors.border, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          disabledBackgroundColor: colors.backgroundAlt,
          disabledForegroundColor: colors.textDisabled,
          minimumSize: const Size(double.infinity, 48),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.jetBrainsMono(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.borderStrong),
          minimumSize: const Size(double.infinity, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colors.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceGlassStrong,
        labelStyle: TextStyle(color: colors.textSecondary),
        hintStyle: TextStyle(color: colors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colors.accentSoft,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: colors.textPrimary, fontSize: 11),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? colors.textPrimary
                  : colors.textSecondary,
            )),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: colors.border),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
      ),
      dividerTheme: DividerThemeData(color: colors.border, thickness: 1),
      listTileTheme: ListTileThemeData(
        iconColor: colors.textSecondary,
        textColor: colors.textPrimary,
        selectedTileColor: colors.accentSoft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final monoText = _monoTextTheme(base.textTheme);

    return base.copyWith(
      brightness: Brightness.dark,
      extensions: const [AppSemanticColors.dark],
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accentPrimary,
        onPrimary: AppColors.textOnAccent,
        secondary: AppColors.secondary,
        onSecondary: AppColors.textPrimary,
        surface: AppColors.bgPrimary,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
        onError: AppSupportingColors.ink,
        surfaceContainerHighest: AppColors.bgTertiary,
      ),
      scaffoldBackgroundColor: AppColors.bgPrimary,
      textTheme: monoText,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.bgGlassStrong,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.jetBrainsMono(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgGlass,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.borderDefault, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentPrimary,
          foregroundColor: AppColors.textOnAccent,
          disabledBackgroundColor: AppColors.bgTertiary,
          disabledForegroundColor: AppColors.textDisabled,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
          textStyle: GoogleFonts.jetBrainsMono(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.borderDefault, width: 1),
          disabledForegroundColor: AppColors.textDisabled,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.jetBrainsMono(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentPrimary,
          textStyle: GoogleFonts.jetBrainsMono(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgTertiary,
        labelStyle: GoogleFonts.jetBrainsMono(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
        hintStyle: GoogleFonts.jetBrainsMono(
          fontSize: 13,
          color: AppColors.textMuted,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.borderFocus, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.bgGlassStrong,
        foregroundColor: AppColors.accentPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderAccent, width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.accentSoft,
        height: 70,
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(
              color: AppColors.accentPrimary,
              size: 22,
            );
          }
          return const IconThemeData(
            color: AppColors.textMuted,
            size: 22,
          );
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderDefault,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.bgElevated,
        contentTextStyle: GoogleFonts.jetBrainsMono(
          fontSize: 13,
          color: AppColors.textPrimary,
        ),
        closeIconColor: AppColors.textSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.borderDefault, width: 1),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.bgElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.bgTertiary,
        labelStyle: GoogleFonts.jetBrainsMono(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        side: const BorderSide(color: AppColors.borderDefault),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.bgElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.borderDefault, width: 1),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.accentPrimary,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.accentPrimary,
        labelStyle: GoogleFonts.jetBrainsMono(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.jetBrainsMono(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.accentPrimary;
          }
          return AppColors.borderDefault;
        }),
        checkColor: WidgetStateProperty.all(AppColors.textOnAccent),
        side: const BorderSide(color: AppColors.borderDefault, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.accentPrimary;
          }
          return AppColors.textMuted;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.accentPrimary;
          }
          return AppColors.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.accentSoft;
          }
          return AppColors.bgTertiary;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.accentPrimary,
        inactiveTrackColor: AppColors.bgTertiary,
        thumbColor: AppColors.accentPrimary,
        overlayColor: AppColors.accentSoft,
        valueIndicatorColor: AppColors.accentPrimary,
        valueIndicatorTextStyle: GoogleFonts.jetBrainsMono(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textOnAccent,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accentPrimary,
        linearTrackColor: AppColors.bgTertiary,
        circularTrackColor: AppColors.bgTertiary,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderDefault, width: 1),
        ),
        textStyle: GoogleFonts.jetBrainsMono(
          fontSize: 12,
          color: AppColors.textPrimary,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.bgElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.borderDefault, width: 1),
        ),
        textStyle: GoogleFonts.jetBrainsMono(
          fontSize: 13,
          color: AppColors.textPrimary,
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.bgTertiary,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.borderDefault),
          ),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.bgElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.borderDefault, width: 1),
        ),
        todayForegroundColor: WidgetStateProperty.all(AppColors.accentPrimary),
        todayBackgroundColor: WidgetStateProperty.all(AppColors.accentSoft),
        dayForegroundColor: WidgetStateProperty.all(AppColors.textPrimary),
        dayBackgroundColor: WidgetStateProperty.all(Colors.transparent),
        rangeSelectionBackgroundColor: AppColors.accentSoft,
        headerBackgroundColor: AppColors.bgGlassStrong,
        headerForegroundColor: AppColors.textPrimary,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        tileColor: Colors.transparent,
        selectedTileColor: AppColors.accentSoft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bgGlassStrong,
        selectedItemColor: AppColors.accentPrimary,
        unselectedItemColor: AppColors.textMuted,
      ),
    );
  }
}
