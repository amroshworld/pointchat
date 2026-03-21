import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── High-Contrast Black & White Palette ──────────────────────────────

  // Dark Theme Colors
  static const Color darkBg = Color(
    0xFF000000,
  ); // True dark bg or slightly off black like 0F0F0F
  static const Color darkSurface = Color(0xFF121212);
  static const Color darkSurface2 = Color(0xFF222222);
  static const Color darkBorder = Color(0xFF333333);
  static const Color darkMuted = Color(0xFF888888);
  static const Color darkTextPri = Color(0xFFFFFFFF);
  static const Color darkTextSec = Color(0xFFAAAAAA);

  // Light Theme Colors
  static const Color lightBg = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF5F5F5);
  static const Color lightSurface2 = Color(0xFFEBEBEB);
  static const Color lightBorder = Color(0xFFE0E0E0);
  static const Color lightMuted = Color(0xFF757575);
  static const Color lightTextPri = Color(0xFF000000);
  static const Color lightTextSec = Color(0xFF424242);

  // Accent & Semantic
  static const Color primaryAccent = Color(
    0xFFFFFFFF,
  ); // White in dark, Black in light (handled via theme)
  static const Color success = Color(0xFF4CAF50); // Deep green
  static const Color error = Color(0xFFF44336); // Deep red
  static const Color warning = Color(0xFFFF9800); // Orange/Yellow
  static const Color focusBlue = Color(0xFF2196F3); // Standard link/focus blue

  // Legacy aliases (used by widgets - keeping for backwards compatibility but mapping to solid colors)
  // We'll define these based on dark theme as fallback for places that don't use Theme.of(context)
  static const Color bg = darkBg;
  static const Color surface = darkSurface;
  static const Color surface2 = darkSurface2;
  static const Color border = darkBorder;
  static const Color muted = darkMuted;
  static const Color textPri = darkTextPri;
  static const Color textSec = darkTextSec;
  static const Color purple = Color(
    0xFF2196F3,
  ); // Fallback mapping, should avoid usage
  static const Color purpleLt = Color(0xFF64B5F6); // Fallback mapping
  static const Color purpleDim = Color(0xFF0D47A1); // Fallback mapping
  static const Color purpleGlow = Colors.transparent; // Removed glow

  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color accent = darkTextPri; // Replaces 'purple' in old theme
  static const Color onlineDot = success;
  static const Color offlineDot = darkMuted;
  static const Color sentMessageColor = darkSurface2;
  static const Color receivedMessageColor = darkSurface2;
  static const Color green = Color(0xFF4CAF50);
  static const Color red = error;
  static const Color yellow = warning;
  static const Color focusBlueGlow = Colors.transparent;

  // ── Typography helpers ─────────────────────────────────────────────
  static TextStyle _font({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  /// Stream list titles (Arabic, emoji, etc.): Inter first, then system Arabic-capable fonts.
  static TextStyle chatConversationTitleStyle(
    BuildContext context, {
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w600,
    double letterSpacing = -0.2,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: isLight ? Colors.black : Colors.white,
    ).copyWith(
      fontFamilyFallback: const [
        'Segoe UI',
        'Roboto',
        'Noto Sans Arabic',
        'Noto Naskh Arabic',
        'Arial Unicode MS',
      ],
    );
  }

  // ── Theme ──────────────────────────────────────────────────────────

  static ThemeData get lightTheme {
    return _buildTheme(
      brightness: Brightness.light,
      bgColor: lightBg,
      surfaceColor: lightSurface,
      surface2Color: lightSurface2,
      borderColor: lightBorder,
      primaryTextColor: lightTextPri,
      secondaryTextColor: lightTextSec,
      mutedColor: lightMuted,
      accentColor: black, // Black accent for light theme
    );
  }

  static ThemeData get darkTheme {
    return _buildTheme(
      brightness: Brightness.dark,
      bgColor: darkBg,
      surfaceColor: darkSurface,
      surface2Color: darkSurface2,
      borderColor: darkBorder,
      primaryTextColor: darkTextPri,
      secondaryTextColor: darkTextSec,
      mutedColor: darkMuted,
      accentColor: white, // White accent for dark theme
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color bgColor,
    required Color surfaceColor,
    required Color surface2Color,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color mutedColor,
    required Color accentColor,
  }) {
    final isDark = brightness == Brightness.dark;
    final invertedAccentColor = isDark
        ? black
        : white; // Text color on top of accent

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bgColor,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: accentColor,
        onPrimary: invertedAccentColor,
        secondary: mutedColor,
        onSecondary: invertedAccentColor,
        error: error,
        onError: white,
        surface: surfaceColor,
        onSurface: primaryTextColor,
        primaryContainer: surface2Color,
        onPrimaryContainer: primaryTextColor,
        surfaceContainerHighest: surface2Color,
        onSurfaceVariant: secondaryTextColor,
        outline: borderColor,
        tertiaryContainer: isDark
            ? const Color(0xFF0D1C0D)
            : const Color(0xFFE8F5E9),
        onTertiaryContainer: success,
      ),

      textTheme: TextTheme(
        displayLarge: _font(
          size: 36,
          weight: FontWeight.w800,
          letterSpacing: -1.0,
          color: primaryTextColor,
        ),
        displayMedium: _font(
          size: 30,
          weight: FontWeight.w700,
          letterSpacing: -0.8,
          color: primaryTextColor,
        ),
        displaySmall: _font(
          size: 24,
          weight: FontWeight.w700,
          letterSpacing: -0.5,
          color: primaryTextColor,
        ),
        headlineLarge: _font(
          size: 22,
          weight: FontWeight.w700,
          letterSpacing: -0.5,
          color: primaryTextColor,
        ),
        headlineMedium: _font(
          size: 18,
          weight: FontWeight.w600,
          color: primaryTextColor,
        ),
        titleLarge: _font(
          size: 16,
          weight: FontWeight.w600,
          color: primaryTextColor,
        ),
        titleMedium: _font(
          size: 15,
          weight: FontWeight.w500,
          color: primaryTextColor,
        ),
        titleSmall: _font(
          size: 13,
          weight: FontWeight.w500,
          color: primaryTextColor,
        ),
        bodyLarge: _font(size: 15, height: 1.5, color: primaryTextColor),
        bodyMedium: _font(size: 14, height: 1.5, color: primaryTextColor),
        bodySmall: _font(size: 12, height: 1.4, color: secondaryTextColor),
        labelLarge: _font(
          size: 14,
          weight: FontWeight.w600,
          letterSpacing: 0,
          color: primaryTextColor,
        ),
        labelMedium: _font(
          size: 12,
          weight: FontWeight.w600,
          letterSpacing: 0,
          color: primaryTextColor,
        ),
        labelSmall: _font(
          size: 11,
          weight: FontWeight.w500,
          letterSpacing: 0,
          color: secondaryTextColor,
        ),
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: bgColor,
        foregroundColor: primaryTextColor,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: _font(
          color: primaryTextColor,
          size: 18,
          weight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: primaryTextColor),
      ),

      // Navigation bar
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 60,
        backgroundColor: bgColor,
        indicatorColor: surface2Color,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primaryTextColor, size: 24);
          }
          return IconThemeData(color: mutedColor, size: 24);
        }),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // Cards
      cardTheme: CardThemeData(
        elevation: 0,
        color: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero, // sharper corners for modern look
          side: BorderSide(color: borderColor, width: 1),
        ),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: accentColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: const BorderSide(color: error, width: 1),
        ),
        hintStyle: _font(color: mutedColor, weight: FontWeight.w400, size: 14),
        labelStyle: _font(color: secondaryTextColor, size: 12),
        prefixIconColor: mutedColor,
        suffixIconColor: mutedColor,
      ),

      // List tile
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        tileColor: Colors.transparent,
        iconColor: primaryTextColor,
        textColor: primaryTextColor,
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: invertedAccentColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle: _font(size: 14, weight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryTextColor,
          side: BorderSide(color: borderColor, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle: _font(size: 14, weight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryTextColor,
          textStyle: _font(size: 14, weight: FontWeight.w600),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: surface2Color,
          foregroundColor: primaryTextColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(color: borderColor),
          ),
          textStyle: _font(size: 13, weight: FontWeight.w500),
        ),
      ),

      // FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        highlightElevation: 0,
        backgroundColor: accentColor,
        foregroundColor: invertedAccentColor,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),

      // Icon
      iconTheme: IconThemeData(color: primaryTextColor, size: 20),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: surface2Color,
        labelStyle: _font(size: 12, color: primaryTextColor),
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: bgColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: borderColor),
        ),
      ),

      // Snack bar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceColor,
        contentTextStyle: _font(color: primaryTextColor, size: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: borderColor),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Progress indicator
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accentColor,
        linearTrackColor: surface2Color,
      ),

      // Drawer
      drawerTheme: DrawerThemeData(
        backgroundColor: bgColor,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),

      // Bottom Sheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: bgColor,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),

      // Page transitions
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }
}
