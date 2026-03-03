import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Render.com-inspired color palette ──────────────────────────────
  static const Color bg = Color(0xFF0A0A0A); // near-black page bg
  static const Color surface = Color(0xFF111111); // card / tile surface
  static const Color surface2 = Color(0xFF1A1A1A); // elevated surface
  static const Color border = Color(0xFF242424); // subtle border
  static const Color muted = Color(0xFF6B6B6B); // secondary text
  static const Color mutedHover = Color(0xFF888888);
  static const Color textPri = Color(0xFFEAEAEA); // primary text
  static const Color textSec = Color(0xFF9A9A9A); // secondary text

  // Purple accent (Render logo purple spectrum)
  static const Color purple = Color(0xFF7C3AED); // primary purple
  static const Color purpleLt = Color(0xFF9D5CF6); // lighter purple
  static const Color purpleDim = Color(0xFF3D1C7B); // dim purple bg
  static const Color purpleGlow = Color(0x337C3AED); // purple glow tint

  // Semantic
  static const Color green = Color(0xFF22C55E); // online / success
  static const Color red = Color(0xFFEF4444); // error
  static const Color yellow = Color(0xFFEAB308); // warning / star

  // Legacy aliases used by widgets
  static const Color black = bg;
  static const Color white = textPri;
  static const Color accent = purple;
  static const Color onlineDot = green;
  static const Color offlineDot = muted;
  static const Color sentMessageColor = surface2;
  static const Color receivedMessageColor = surface2;

  // ── Typography helpers ─────────────────────────────────────────────
  static TextStyle _inter({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color color = textPri,
    double? height,
    double? letterSpacing,
  }) => GoogleFonts.inter(
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
        displayLarge: _inter(
          size: 36,
          weight: FontWeight.w800,
          letterSpacing: -1.5,
        ),
        displayMedium: _inter(
          size: 30,
          weight: FontWeight.w700,
          letterSpacing: -1,
        ),
        displaySmall: _inter(
          size: 24,
          weight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineLarge: _inter(
          size: 22,
          weight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: _inter(size: 18, weight: FontWeight.w600),
        titleLarge: _inter(size: 16, weight: FontWeight.w600),
        titleMedium: _inter(size: 15, weight: FontWeight.w500),
        titleSmall: _inter(size: 13, weight: FontWeight.w500),
        bodyLarge: _inter(size: 15, height: 1.5),
        bodyMedium: _inter(size: 14, height: 1.5),
        bodySmall: _inter(size: 12, color: textSec, height: 1.4),
        labelLarge: _inter(
          size: 14,
          weight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        labelMedium: _inter(
          size: 12,
          weight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        labelSmall: _inter(
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
        titleTextStyle: GoogleFonts.inter(
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
        hintStyle: GoogleFonts.inter(
          color: muted,
          fontWeight: FontWeight.w400,
          fontSize: 14,
        ),
        labelStyle: GoogleFonts.inter(color: textSec, fontSize: 12),
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
          textStyle: GoogleFonts.inter(
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
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: purple,
          textStyle: GoogleFonts.inter(
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
          textStyle: GoogleFonts.inter(
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
        labelStyle: GoogleFonts.inter(fontSize: 12, color: textPri),
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
        contentTextStyle: GoogleFonts.inter(color: textPri, fontSize: 14),
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
