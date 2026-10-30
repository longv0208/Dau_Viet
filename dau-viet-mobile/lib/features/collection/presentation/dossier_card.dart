import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/tactile_card.dart';
import '../../learning/presentation/renderers/learning_asset_image.dart';
import '../data/dossier_dto.dart';

/// Card một dossier trong list. Locked (preview) = icon khoá + yêu cầu
/// "Hoàn thành sự kiện để mở"; unlocked = metadata đầy đủ.
class DossierCard extends StatelessWidget {
  final DossierSummaryDto dossier;

  const DossierCard({super.key, required this.dossier});

  String _typeLabel(String type) => switch (type) {
    'PERSON' => 'Nhân vật',
    'LOCATION' => 'Địa điểm',
    'ARTIFACT' => 'Hiện vật',
    'CONTEXT' => 'Bối cảnh',
    _ => type,
  };

  IconData _typeIcon(String type) => switch (type) {
    'PERSON' => Icons.person_rounded,
    'LOCATION' => Icons.place_rounded,
    'ARTIFACT' => Icons.diamond_rounded,
    'CONTEXT' => Icons.history_edu_rounded,
    _ => Icons.inventory_2_rounded,
  };

  Color _typeAccentColor(String type) => switch (type) {
    'PERSON' => DauVietColors.heritageGreenLight,
    'LOCATION' => DauVietColors.jadeDark,
    'ARTIFACT' => DauVietColors.imperialGoldDark,
    'CONTEXT' => DauVietColors.cinnabarRed,
    _ => DauVietColors.jadeDark,
  };

  Color _typeBgColor(String type) => switch (type) {
    'PERSON' => DauVietColors.heritageGreenSurface,
    'LOCATION' => const Color(0xFFDCEFED),
    'ARTIFACT' => const Color(0xFFFFF3D6),
    'CONTEXT' => const Color(0xFFFDE3DD),
    _ => const Color(0xFFDCEFED),
  };

  @override
  Widget build(BuildContext context) {
    final locked = dossier.preview;
    final accent = _typeAccentColor(dossier.dossierType);
    final bgTint = _typeBgColor(dossier.dossierType);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TactileCard(
        usePixelShadow: false,
        backgroundColor: const Color(0xFFFAF3E4),
        borderColor: const Color(0xFFE3D2B4),
        borderWidth: 1.1,
        borderRadius: 16,
        padding: const EdgeInsets.all(12),
        onTap: () => context.push('/collection/dossiers/${dossier.dossierId}'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: locked ? const Color(0xFFF3E5CE) : bgTint,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: locked
                      ? const Color(0xFFE3D2B4)
                      : accent.withValues(alpha: 0.30),
                  width: 1.0,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: dossier.assetId != null
                  ? LearningAssetImage(
                      assetId: dossier.assetId!,
                      altText: dossier.title,
                      height: 72,
                      fit: BoxFit.cover,
                      tappable: false,
                    )
                  : Center(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: locked
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.72),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          locked
                              ? Icons.lock_outline_rounded
                              : _typeIcon(dossier.dossierType),
                          size: 24,
                          color: locked ? DauVietColors.inkMuted : accent,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _typeBadge(dossier.dossierType),
                      const SizedBox(width: 6),
                      if (locked)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E5CE),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFE3D2B4),
                              width: 0.9,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.lock_rounded,
                                size: 11,
                                color: DauVietColors.inkMuted,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Chưa mở',
                                style: DauVietTypography.labelSmall.copyWith(
                                  fontSize: 8.5,
                                  color: DauVietColors.inkMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    dossier.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DauVietTypography.labelMedium.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: locked
                          ? DauVietColors.inkMuted
                          : DauVietColors.inkHeading,
                    ),
                  ),
                  if (dossier.summary != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      dossier.summary!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DauVietTypography.bodySmall.copyWith(
                        fontSize: 11.5,
                        color: DauVietColors.inkMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (locked) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Hoàn thành sự kiện để mở hồ sơ',
                      style: DauVietTypography.labelSmall.copyWith(
                        fontSize: 10.5,
                        color: DauVietColors.inkMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: DauVietColors.inkMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeBadge(String type) {
    final accent = _typeAccentColor(type);
    final bg = _typeBgColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: accent.withValues(alpha: 0.42),
          width: 1.0,
        ),
      ),
      child: Text(
        _typeLabel(type).toUpperCase(),
        style: DauVietTypography.labelSmall.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: accent,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
