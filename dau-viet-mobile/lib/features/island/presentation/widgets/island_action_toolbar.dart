import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_typography.dart';

/// Cụm nút thao tác bên phải: Lưu / Thu hồi / Xoay / Xóa / Bản đồ.
class IslandActionToolbar extends StatelessWidget {
  final bool showManageActions;
  final bool hasSelectedPlacement;
  final VoidCallback onSave;
  final VoidCallback onRecall;
  final VoidCallback onRotate;
  final VoidCallback onDelete;
  final VoidCallback onMap;

  const IslandActionToolbar({
    super.key,
    required this.showManageActions,
    required this.hasSelectedPlacement,
    required this.onSave,
    required this.onRecall,
    required this.onRotate,
    required this.onDelete,
    required this.onMap,
  });

  @override
  Widget build(BuildContext context) {
    if (!showManageActions) {
      return _ToolButton(
        icon: Icons.map_rounded,
        label: 'Bản đồ',
        accent: const Color(0xFF1A5642),
        onTap: onMap,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToolButton(
          icon: Icons.save_outlined,
          label: 'Lưu',
          accent: const Color(0xFF1A5642),
          onTap: onSave,
        ),
        const SizedBox(height: 8),
        _ToolButton(
          icon: Icons.unarchive_outlined,
          label: 'Thu hồi',
          enabled: hasSelectedPlacement,
          onTap: onRecall,
        ),
        const SizedBox(height: 8),
        _ToolButton(
          icon: Icons.rotate_right_rounded,
          label: 'Xoay',
          onTap: onRotate,
        ),
        const SizedBox(height: 8),
        _ToolButton(
          icon: Icons.delete_outline_rounded,
          label: 'Xóa',
          accent: const Color(0xFFB93430),
          enabled: hasSelectedPlacement,
          onTap: onDelete,
        ),
        const SizedBox(height: 8),
        _ToolButton(
          icon: Icons.map_rounded,
          label: 'Bản đồ',
          accent: const Color(0xFF1A5642),
          onTap: onMap,
        ),
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? accent;
  final bool enabled;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? (accent ?? const Color(0xFF4A3728))
        : const Color(0xFFB5A38F);
    return Opacity(
      opacity: enabled ? 1 : 0.46,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: const Color(0xF8FBF3E4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: enabled ? const Color(0xFFDEC8A4) : const Color(0xFFE8D8BE),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: enabled ? 0.12 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: DauVietTypography.bodySmall.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: enabled
                      ? const Color(0xFF3A2618)
                      : const Color(0xFF9A8874),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
