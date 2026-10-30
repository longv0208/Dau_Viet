import 'package:flutter/material.dart';

/// Bảng màu chuẩn Di sản Văn hiến Dấu Việt v3.0 — đồng bộ Landing Page.
/// Nguồn: https://dau-viet-landing.vercel.app/ (CSS bundle đã trích).
/// Tham chiếu bổ sung: docs/ART_DIRECTION.md, docs/UI_COMPONENT_SPEC.md.
///
/// Quy ước dùng:
/// - Nền trang:  [paperBackground]
/// - Nền thẻ:    [paperCard] / [paperCardHi] cho nhấn
/// - Chữ chính:  [inkText]; heading chapter: [inkHeading]; body phụ: [inkSecondary]
/// - Điểm nhấn chính:  [cinnabarRed] (CTA/primary), [imperialGold] (reward), [jade] (clue/accent phụ)
/// - Chapter/badge xanh: [chapterGreen] (đậm) / [heritageGreen] (điểm nhấn secondary)
/// - Cảnh báo: [imperialGold]; Lỗi: [errorRed]; Thành công: [natureGreen]
class DauVietColors {
  DauVietColors._();

  // ─── Giấy dó đa tầng (Paper / Parchment) — align Landing Page ───
  /// Nền scaffold chính (`--background` trên Landing).
  static const Color paperBackground = Color(0xFFF8F0E0);
  /// Nền card/panel (`from-paper-card` trên Landing ≈ #FBF8F1).
  static const Color paperCard = Color(0xFFFBF8F1);
  /// Nền card nâng cao / nhấn (`--dv-paper` trên Landing).
  static const Color paperCardHi = Color(0xFFF3E5CE);
  /// Giấy dó tối nhẹ cho divider/vùng mờ.
  static const Color paperDim = Color(0xFFEFE3CC);

  // ─── Legacy aliases (giữ tương thích ngược; màn mới nên dùng paper*) ───
  static const Color parchmentSurface = paperBackground;
  static const Color parchmentContainer = paperCard;
  static const Color parchmentHigh = paperCardHi;
  static const Color parchmentDim = paperDim;

  // ─── Mực nho (Ink) ───
  /// Chữ body chính — đậm nhất.
  static const Color inkText = Color(0xFF30251F);
  /// Chữ heading chapter/event (charcoal-gỗ `--foreground-heading`).
  static const Color inkHeading = Color(0xFF3C3026);
  /// Chữ phụ (`--foreground` trên Landing).
  static const Color inkSecondary = Color(0xFF49382F);
  /// Mực nho nhạt (chữ phụ trợ).
  static const Color inkMuted = Color(0xFF685F56);
  /// Mực nho xám nhạt (disabled/placeholder).
  static const Color inkLight = Color(0xFF8C8077);

  // ─── Điểm nhấn chính ───
  /// Đỏ chu sa / lacquer — CTA chính, brand.
  static const Color cinnabarRed = Color(0xFFB93430);
  /// Đỏ chu sa sẫm — pressed/dark state.
  static const Color cinnabarRedDark = Color(0xFF85211F);
  /// Vàng ngự xưởng — reward, vàng đồng viền.
  static const Color imperialGold = Color(0xFFE0AE45);
  /// Vàng đồng đậm (`--dv-gold` trên Landing).
  static const Color imperialGoldDark = Color(0xFFA97932);
  /// Vàng nhạt viền/glow.
  static const Color imperialGoldLight = Color(0xFFFFDEA7);
  /// Jade / xanh ngọc — accent phụ cho clue, badge, link secondary.
  static const Color jade = Color(0xFF247D78);
  /// Jade đậm cho text trên nền sáng.
  static const Color jadeDark = Color(0xFF1A5F5B);

  // ─── Xanh di sản / chapter ───
  /// Xanh rêu di sản — nút phụ, điểm nhấn.
  static const Color heritageGreen = Color(0xFF1E4D3B);
  /// Xanh đậm cho `CHƯƠNG 01…` chapter number/heading.
  static const Color chapterGreen = Color(0xFF283F36);
  /// Xanh rêu đậm — đổ bóng 3D, viền.
  static const Color heritageGreenDark = Color(0xFF123427);
  /// Xanh rêu tươi nhẹ.
  static const Color heritageGreenLight = Color(0xFF2D6A4F);
  /// Nền xanh rêu nhạt cho chip/success tint.
  static const Color heritageGreenSurface = Color(0xFFEBF4EF);

  // ─── Ngữ cảnh ───
  /// Xanh lục ngàn — thành công, khảo cổ.
  static const Color natureGreen = Color(0xFF64824C);
  /// Xanh lam giang — thủy triều, sa bàn.
  static const Color riverBlue = Color(0xFF388EB4);
  /// Đỏ cảnh báo/lỗi.
  static const Color errorRed = Color(0xFFB3261E);

  // ─── Viền & gỗ cổ ───
  /// Nâu gỗ lim.
  static const Color woodBrown = Color(0xFF613B28);
  /// Viền đồng cổ.
  static const Color outline = Color(0xFF8C6747);
  /// Viền giấy dó mờ.
  static const Color outlineVariant = Color(0xFFD4C1A5);
  /// Màu đổ bóng pixel (Landing `--shadow-pixel`: `#402C29`).
  static const Color pixelShadowColor = Color(0xFF402C29);

  // ─── Shadows ───
  /// Đổ bóng mềm di sản — card lớn, hero.
  static const List<BoxShadow> heritageShadow = [
    BoxShadow(
      color: Color(0x1A613B28),
      offset: Offset(0, 4),
      blurRadius: 12,
      spreadRadius: 0,
    ),
  ];

  /// Đổ bóng mềm tinh tế chuẩn Soft Heritage Card (đồng bộ ProfileScreen).
  static const List<BoxShadow> softCardShadow = [
    BoxShadow(
      color: Color(0x0F5D4024),
      offset: Offset(0, 2),
      blurRadius: 6,
      spreadRadius: 0,
    ),
  ];

  /// Pixel-shadow lớn (`shadow-pixel` trên Landing) — button, chip nổi bật.
  static const List<BoxShadow> pixelShadow = [
    BoxShadow(
      color: pixelShadowColor,
      offset: Offset(4, 4),
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];

  /// Pixel-shadow nhỏ (`shadow-pixel-sm`) — badge, tag, eyebrow chip.
  static const List<BoxShadow> pixelShadowSm = [
    BoxShadow(
      color: pixelShadowColor,
      offset: Offset(2, 2),
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];

  /// Pixel-shadow cực lớn (`shadow-pixel-lg`) — hero actions.
  static const List<BoxShadow> pixelShadowLg = [
    BoxShadow(
      color: pixelShadowColor,
      offset: Offset(6, 6),
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];
}
