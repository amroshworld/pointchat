import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Discord-inspired color palette ──────────────────────────────
  static const Color bg = Color(0xFF313338); // Discord primary chat bg
  static const Color surface = Color(0xFF2B2D31); // Discord sidebar/surface bg
  static const Color surface2 = Color(0xFF1E1F22); // Discord dark surface
  static const Color border = Colors.transparent; // remove edges/contrast
  static const Color muted = Color(0xFF80848E); // secondary text / muted
  static const Color mutedHover = Color(0xFF949BA4);
  static const Color textPri = Color(0xFFF2F3F5); // primary text
  static const Color textSec = Color(0xFFB5BAC1); // secondary text

  // Blurple accent
  static const Color purple = Color(0xFF5865F2); // Blurple
  static const Color purpleLt = Color(0xFF7983F5); // lighter blurple
  static const Color purpleDim = Color(0xFF4752C4); // dim blurple
  static const Color purpleGlow = Color(
    0x335865F2,
  ); // removed neon, subtle tint

  // Semantic
  static const Color green = Color(0xFF23A559); // online / success
  static const Color red = Color(0xFFDA373C); // error
  static const Color yellow = Color(0xFFF0B232); // warning / star
  static const Color focusBlue = Color(0xFF00A8FC);
  static const Color focusBlueGlow = Color(0x2200A8FC);

  // Legacy aliases used by widgets
  static const Color black = bg;
  static const Color white = textPri;
  static const Color accent = purple;
  static const Color onlineDot = green;
  static const Color offlineDot = muted;
  static const Color sentMessageColor = surface2;
  static const Color receivedMessageColor = surface2;

  // ── Typography helpers ─────────────────────────────────────────────
  static TextStyle _font({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color color = textPri,
    double? height,
    double? letterSpacing,
  }) => GoogleFonts.outfit(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  // ── Theme ──────────────────────────────────────────────────────────
  static ThemeData get lightTheme => darkTheme;

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: purple,
        onPrimary: textPri,
        secondary: purpleLt,
        onSecondary: textPri,
        surface: surface,
        onSurface: textPri,
        error: red,
        onError: textPri,
        primaryContainer: purpleDim,
        onPrimaryContainer: textPri,
        tertiaryContainer: Color(0xFF1A2A1A),
        onTertiaryContainer: green,
        surfaceContainerHighest: surface2,
        onSurfaceVariant: textSec,
      ),

      textTheme: TextTheme(
        displayLarge: _font(
          size: 36,
          weight: FontWeight.w800,
          letterSpacing: -1.5,
        ),
        displayMedium: _font(
          size: 30,
          weight: FontWeight.w700,
          letterSpacing: -1,
        ),
        displaySmall: _font(
          size: 24,
          weight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineLarge: _font(
          size: 22,
          weight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: _font(size: 18, weight: FontWeight.w600),
        titleLarge: _font(size: 16, weight: FontWeight.w600),
        titleMedium: _font(size: 15, weight: FontWeight.w500),
        titleSmall: _font(size: 13, weight: FontWeight.w500),
        bodyLarge: _font(size: 15, height: 1.5),
        bodyMedium: _font(size: 14, height: 1.5),
        bodySmall: _font(size: 12, color: textSec, height: 1.4),
        labelLarge: _font(
          size: 14,
          weight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        labelMedium: _font(
          size: 12,
          weight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        labelSmall: _font(
          size: 11,
          weight: FontWeight.w500,
          color: textSec,
          letterSpacing: 0.5,
        ),
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: bg,
        foregroundColor: textPri,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.outfit(
          color: textPri,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: textSec),
      ),

      // Navigation bar
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 60,
        backgroundColor: bg,
        indicatorColor: purpleDim,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: purpleLt, size: 22);
          }
          return const IconThemeData(color: muted, size: 22);
        }),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // Cards
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: border, width: 1),
        ),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: purple, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: red, width: 1),
        ),
        hintStyle: GoogleFonts.outfit(
          color: muted,
          fontWeight: FontWeight.w400,
          fontSize: 14,
        ),
        labelStyle: GoogleFonts.outfit(color: textSec, fontSize: 12),
        prefixIconColor: muted,
        suffixIconColor: muted,
      ),

      // List tile
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        tileColor: Colors.transparent,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: purple,
          foregroundColor: textPri,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPri,
          side: const BorderSide(color: border, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: purple,
          textStyle: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: surface2,
          foregroundColor: textPri,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: border),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // FAB
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 0,
        highlightElevation: 0,
        backgroundColor: purple,
        foregroundColor: textPri,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),

      // Icon
      iconTheme: const IconThemeData(color: textSec, size: 20),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: surface2,
        labelStyle: GoogleFonts.outfit(fontSize: 12, color: textPri),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border),
        ),
      ),

      // Snack bar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface2,
        contentTextStyle: GoogleFonts.outfit(color: textPri, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),

      // Progress indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: purple,
        linearTrackColor: Colors.transparent,
      ),

      // Drawer
      drawerTheme: const DrawerThemeData(backgroundColor: bg, elevation: 0),

      // Page transitions
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
