import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dau_viet_colors.dart';

/// Hệ thống Typography Di sản Dấu Việt v2.0
/// Kết hợp Noto Serif (Trang trọng, Sử liệu) & Be Vietnam Pro (Hiện đại, Dễ đọc)
class DauVietTypography {
  DauVietTypography._();

  // Tiêu đề lớn (Noto Serif)
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
    color: DauVietColors.inkText,
  );

  static TextStyle get headlineSmall => GoogleFonts.notoSerif(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.4,
    color: DauVietColors.inkText,
  );

  // Nội dung chính (Be Vietnam Pro)
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
    color: DauVietColors.inkMuted,
  );

  // Nhãn & Điều khiển (Be Vietnam Pro)
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

  // Kiểu đặc thù: Chữ trích dẫn cổ thư
  static TextStyle get ancientCitation => GoogleFonts.notoSerif(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    height: 1.6,
    color: DauVietColors.inkText,
  );
}
