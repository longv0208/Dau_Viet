import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dau_viet_colors.dart';
import 'dau_viet_typography.dart';

/// Cấu hình ThemeData cho Dấu Việt Mobile v3.0
/// Đồng bộ với Landing Page: nền giấy dó ấm, chữ mực nho,
/// điểm nhấn đỏ chu sa / vàng ngự xưởng / jade.
class DauVietTheme {
  DauVietTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: GoogleFonts.beVietnamPro().fontFamily,
      scaffoldBackgroundColor: DauVietColors.paperBackground,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: DauVietColors.cinnabarRed,
        onPrimary: Colors.white,
        secondary: DauVietColors.imperialGold,
        onSecondary: DauVietColors.inkText,
        tertiary: DauVietColors.jade,
        onTertiary: Colors.white,
        surface: DauVietColors.paperBackground,
        onSurface: DauVietColors.inkText,
        error: DauVietColors.errorRed,
        onError: Colors.white,
        outline: DauVietColors.outline,
        outlineVariant: DauVietColors.outlineVariant,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: DauVietColors.paperBackground,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: DauVietTypography.headlineMedium,
        iconTheme: const IconThemeData(color: DauVietColors.inkText),
      ),
      cardTheme: CardThemeData(
        color: DauVietColors.paperCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: DauVietColors.outlineVariant,
            width: 1,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DauVietColors.cinnabarRed,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: DauVietTypography.labelLarge.copyWith(color: Colors.white),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DauVietColors.inkText,
          side: const BorderSide(color: DauVietColors.outline, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: DauVietTypography.labelLarge,
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: DauVietTypography.headlineLarge,
        headlineMedium: DauVietTypography.headlineMedium,
        headlineSmall: DauVietTypography.headlineSmall,
        bodyLarge: DauVietTypography.bodyLarge,
        bodyMedium: DauVietTypography.bodyMedium,
        bodySmall: DauVietTypography.bodySmall,
        labelLarge: DauVietTypography.labelLarge,
        labelMedium: DauVietTypography.labelMedium,
        labelSmall: DauVietTypography.labelSmall,
      ),
    );
  }
}
