import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/parchment_card.dart';
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

  @override
  Widget build(BuildContext context) {
    final locked = dossier.preview;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ParchmentCard(
        padding: const EdgeInsets.all(12),
        onTap: () => context.push('/collection/dossiers/${dossier.dossierId}'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 72,
                height: 72,
                child: dossier.assetId != null
                    ? LearningAssetImage(
                        assetId: dossier.assetId!,
                        altText: dossier.title,
                        height: 72,
                        fit: BoxFit.cover,
                        tappable: false,
                      )
                    : Container(
                        color: locked
                            ? DauVietColors.parchmentHigh
                            : DauVietColors.parchmentContainer,
                        child: Icon(
                          locked
                              ? Icons.lock_outline_rounded
                              : _typeIcon(dossier.dossierType),
                          size: 30,
                          color: locked
                              ? DauVietColors.inkMuted
                              : DauVietColors.cinnabarRed,
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
                        const Icon(
                          Icons.lock_rounded,
                          size: 13,
                          color: DauVietColors.inkMuted,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    dossier.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DauVietTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: locked
                          ? DauVietColors.inkMuted
                          : DauVietColors.inkText,
                    ),
                  ),
                  if (dossier.summary != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      dossier.summary!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DauVietTypography.bodySmall.copyWith(
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
                        color: DauVietColors.inkMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: DauVietColors.inkMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeBadge(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: DauVietColors.cinnabarRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: DauVietColors.cinnabarRed.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        _typeLabel(type).toUpperCase(),
        style: DauVietTypography.labelSmall.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: DauVietColors.cinnabarRed,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
