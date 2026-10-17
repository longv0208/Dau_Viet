import 'package:flutter/material.dart';

/// Bảng màu chuẩn Di sản Văn hiến Dấu Việt v2.0
/// Tham chiếu từ ART_DIRECTION.md và UI_COMPONENT_SPEC.md
class DauVietColors {
  DauVietColors._();

  // Tông màu chủ đạo
  static const Color cinnabarRed = Color(0xFFA51F18); // Đỏ chu sa hoàng gia
  static const Color cinnabarRedDark = Color(0xFF751B19); // Đỏ chu sa sẫm
  static const Color imperialGold = Color(0xFFE7B451); // Vàng ngự xưởng
  static const Color imperialGoldLight = Color(0xFFFFDEA7); // Vàng nhạt viền

  // Tông màu nền giấy dó cổ (Parchment)
  static const Color parchmentSurface = Color(
    0xFFFFFBF4,
  ); // Giấy dó sáng (Nền chính)
  static const Color parchmentContainer = Color(
    0xFFFFF1D5,
  ); // Giấy dó ngả vàng (Thẻ bài)
  static const Color parchmentHigh = Color(0xFFF3E5CE); // Giấy dó đậm hơn
  static const Color parchmentDim = Color(0xFFF5ECE0); // Giấy dó tối nhẹ

  // Tông màu chữ mực nho (Ink)
  static const Color inkText = Color(0xFF30251F); // Mực nho đậm (Chữ chính)
  static const Color inkMuted = Color(0xFF685F56); // Mực nho nhạt (Chữ phụ)
  static const Color inkLight = Color(0xFF8C8077); // Mực nho xám

  // Tông màu viền & Gỗ cổ
  static const Color woodBrown = Color(0xFF613B28); // Nâu gỗ lim
  static const Color outline = Color(0xFF8C6747); // Viền đồng cổ
  static const Color outlineVariant = Color(0xFFD4C1A5); // Viền giấy dó mờ

  // Tông màu tự nhiên & Ngữ cảnh
  static const Color natureGreen = Color(
    0xFF64824C,
  ); // Xanh lục ngàn (Thành công, Khảo cổ)
  static const Color riverBlue = Color(
    0xFF388EB4,
  ); // Xanh lam giang (Thủy triều, Sa bàn)
  static const Color errorRed = Color(0xFFB3261E); // Đỏ cảnh báo / Lỗi

  // Hiệu ứng đổ bóng mềm di sản
  static const List<BoxShadow> heritageShadow = [
    BoxShadow(
      color: Color(0x1A613B28),
      offset: Offset(0, 4),
      blurRadius: 12,
      spreadRadius: 0,
    ),
  ];
}
