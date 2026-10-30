import 'package:flutter_test/flutter_test.dart';
import 'package:dau_viet_mobile/core/theme/dau_viet_colors.dart';
import 'package:dau_viet_mobile/core/theme/dau_viet_typography.dart';
import 'package:dau_viet_mobile/core/theme/dau_viet_theme.dart';
import 'package:flutter/material.dart';

/// Design System v3.0 — tokens phải khớp bảng quyết định trong
/// plans/261029-issue-40-ui-overhaul/plan.md §2.
void main() {
  group('DauVietColors v3', () {
    test('paper palette khớp Landing Page', () {
      expect(DauVietColors.paperBackground, const Color(0xFFF8F0E0));
      expect(DauVietColors.paperCard, const Color(0xFFFBF8F1));
      expect(DauVietColors.paperCardHi, const Color(0xFFF3E5CE));
      expect(DauVietColors.paperDim, const Color(0xFFEFE3CC));
      // Legacy aliases phải giữ nguyên giá trị mới.
      expect(DauVietColors.parchmentSurface, DauVietColors.paperBackground);
      expect(DauVietColors.parchmentContainer, DauVietColors.paperCard);
      expect(DauVietColors.parchmentHigh, DauVietColors.paperCardHi);
    });

    test('ink palette', () {
      expect(DauVietColors.inkText, const Color(0xFF30251F));
      expect(DauVietColors.inkHeading, const Color(0xFF3C3026));
      expect(DauVietColors.inkSecondary, const Color(0xFF49382F));
      expect(DauVietColors.inkMuted, const Color(0xFF685F56));
      expect(DauVietColors.inkLight, const Color(0xFF8C8077));
    });

    test('accent palette — đỏ chu sa, vàng ngự xưởng, jade', () {
      expect(DauVietColors.cinnabarRed, const Color(0xFFB93430));
      expect(DauVietColors.cinnabarRedDark, const Color(0xFF85211F));
      expect(DauVietColors.imperialGold, const Color(0xFFE0AE45));
      expect(DauVietColors.imperialGoldDark, const Color(0xFFA97932));
      expect(DauVietColors.jade, const Color(0xFF247D78));
      expect(DauVietColors.jadeDark, const Color(0xFF1A5F5B));
    });

    test('chapter & heritage green', () {
      expect(DauVietColors.chapterGreen, const Color(0xFF283F36));
      expect(DauVietColors.heritageGreen, const Color(0xFF1E4D3B));
      expect(DauVietColors.heritageGreenDark, const Color(0xFF123427));
    });

    test('shadows', () {
      expect(DauVietColors.pixelShadow.single.color,
          DauVietColors.pixelShadowColor);
      expect(DauVietColors.pixelShadow.single.offset, const Offset(4, 4));
      expect(DauVietColors.pixelShadowSm.single.offset, const Offset(2, 2));
      expect(DauVietColors.pixelShadowLg.single.offset, const Offset(6, 6));
      expect(DauVietColors.heritageShadow, isNotEmpty);
      expect(DauVietColors.softCardShadow.single.offset, const Offset(0, 2));
      expect(DauVietColors.softCardShadow.single.blurRadius, 6);
    });
  });

  group('DauVietTypography v3', () {
    test('chapter number dùng pixel style', () {
      final s = DauVietTypography.chapterNumber;
      expect(s.fontSize, 28);
      expect(s.color, DauVietColors.chapterGreen);
      // GoogleFonts.pressStart2p được resolve — family phải chứa 'PressStart2P'.
      expect(s.fontFamily?.toLowerCase(), contains('pressstart'));
    });

    test('sectionEyebrow là uppercase mono-bold', () {
      final s = DauVietTypography.sectionEyebrow;
      expect(s.fontWeight, FontWeight.w700);
      expect(s.letterSpacing, greaterThan(1.0));
      expect(s.color, DauVietColors.cinnabarRed);
    });

    test('clueTag dùng jade', () {
      final s = DauVietTypography.clueTag;
      expect(s.color, DauVietColors.jadeDark);
    });
  });

  group('DauVietTheme', () {
    test('scaffold background = paperBackground', () {
      final theme = DauVietTheme.lightTheme;
      expect(theme.scaffoldBackgroundColor, DauVietColors.paperBackground);
      expect(theme.colorScheme.primary, DauVietColors.cinnabarRed);
      expect(theme.colorScheme.secondary, DauVietColors.imperialGold);
      expect(theme.colorScheme.tertiary, DauVietColors.jade);
      expect(theme.cardTheme.color, DauVietColors.paperCard);
    });
  });
}
