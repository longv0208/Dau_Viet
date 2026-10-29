import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dau_viet_colors.dart';

/// Hệ thống Typography Di sản Dấu Việt v3.0
/// Kết hợp Noto Serif (Trang trọng, Sử liệu) & Be Vietnam Pro (Hiện đại, Dễ đọc)
/// & Press Start 2P (Pixel accent — số chương/dấu vết theo Landing Page)
class DauVietTypography {
  DauVietTypography._();

  // ─── Tiêu đề (Noto Serif) ───
  static TextStyle get headlineLarge => GoogleFonts.notoSerif(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: DauVietColors.inkText,
    letterSpacing: -0.2,
  );

  static TextStyle get headlineMedium => GoogleFonts.notoSerif(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.35,
    color: DauVietColors.inkHeading,
  );

  static TextStyle get headlineSmall => GoogleFonts.notoSerif(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.4,
    color: DauVietColors.inkText,
  );

  /// Số chương "01", "02"… — pixel-accent như Landing Page.
  /// Fallback về Noto Serif 700 nếu pixel font chưa bundle.
  static TextStyle get chapterNumber => GoogleFonts.pressStart2p(
    fontSize: 28,
    fontWeight: FontWeight.w400,
    height: 1.0,
    color: DauVietColors.chapterGreen,
    letterSpacing: 1.5,
  );

  static TextStyle get chapterNumberSmall => GoogleFonts.pressStart2p(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 1.0,
    color: DauVietColors.chapterGreen,
    letterSpacing: 1.0,
  );

  /// Eyebrow chip — `CHƯƠNG 01 · HÀNH TRÌNH` uppercase mono-bold.
  static TextStyle get sectionEyebrow => GoogleFonts.beVietnamPro(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 1.4,
    color: DauVietColors.cinnabarRed,
  );

  /// Tag dấu vết (Hiện vật / Địa hình / Nhân vật / Cổ thư).
  static TextStyle get clueTag => GoogleFonts.beVietnamPro(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.8,
    color: DauVietColors.jadeDark,
  );

  // ─── Tiêu đề phụ (Be Vietnam Pro) ───
  static TextStyle get titleSmall => GoogleFonts.beVietnamPro(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: DauVietColors.inkText,
  );

  // ─── Nội dung (Be Vietnam Pro) ───
  static TextStyle get bodyLarge => GoogleFonts.beVietnamPro(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: DauVietColors.inkText,
  );

  static TextStyle get bodyMedium => GoogleFonts.beVietnamPro(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: DauVietColors.inkText,
  );

  static TextStyle get bodySmall => GoogleFonts.beVietnamPro(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: DauVietColors.inkSecondary,
  );

  // ─── Nhãn & Điều khiển (Be Vietnam Pro) ───
  static TextStyle get labelLarge => GoogleFonts.beVietnamPro(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    color: DauVietColors.inkText,
  );

  static TextStyle get labelMedium => GoogleFonts.beVietnamPro(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    color: DauVietColors.inkText,
  );

  static TextStyle get labelSmall => GoogleFonts.beVietnamPro(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    color: DauVietColors.inkMuted,
  );

  /// Trích dẫn cổ thư — in nghiêng, có indent trái.
  static TextStyle get ancientCitation => GoogleFonts.notoSerif(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    height: 1.6,
    color: DauVietColors.inkSecondary,
  );
}
