import 'package:flutter/material.dart';
import 'tactile_3d_button.dart';

enum DongSonButtonVariant {
  primaryCinnabar,   // Đỏ chu sa (Hành động chính)
  secondaryParchment,// Nền giấy dó viền gỗ (Hành động phụ)
  imperialGold,      // Vàng ngự xưởng (Ăn mừng / Phần thưởng)
}

/// Nút bấm hoa văn di sản Dấu Việt v2.0
/// Đã được nâng cấp với công nghệ xúc giác 3D lò xo (Tactile Spring Physics) chuẩn Duolingo
class DongSonButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final DongSonButtonVariant variant;
  final bool isLoading;
  final double? width;
  final double height;

  const DongSonButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = DongSonButtonVariant.primaryCinnabar,
    this.isLoading = false,
    this.width,
    this.height = 50.0,
  });

  @override
  Widget build(BuildContext context) {
    Tactile3DVariant tVariant;
    switch (variant) {
      case DongSonButtonVariant.primaryCinnabar:
        tVariant = Tactile3DVariant.primaryCinnabar;
        break;
      case DongSonButtonVariant.secondaryParchment:
        tVariant = Tactile3DVariant.secondaryParchment;
        break;
      case DongSonButtonVariant.imperialGold:
        tVariant = Tactile3DVariant.imperialGold;
        break;
    }

    return Tactile3DButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      variant: tVariant,
      isLoading: isLoading,
      width: width,
      height: height,
    );
  }
}
