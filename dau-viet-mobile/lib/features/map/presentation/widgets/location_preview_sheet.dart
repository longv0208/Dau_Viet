import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../../core/widgets/dong_son_button.dart';
import '../../../learning/presentation/renderers/learning_asset_image.dart';
import '../../data/map_location_dto.dart';
import 'heritage_map_marker.dart';

class LocationPreviewSheet extends StatelessWidget {
  final MapLocationDto location;
  final VoidCallback onOpenProfile;
  final VoidCallback? onOpenLesson;
  final VoidCallback? onOpenEvent;

  const LocationPreviewSheet({
    super.key,
    required this.location,
    required this.onOpenProfile,
    this.onOpenLesson,
    this.onOpenEvent,
  });

  @override
  Widget build(BuildContext context) {
    final lesson = location.actionableLesson;
    final canOpenLesson = lesson != null && lesson.accessible;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
      child: SafeArea(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFFBF6EA),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFDEC8A4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8C4A2),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: location.coverAssetId == null
                            ? ColoredBox(
                                color: const Color(0xFF1A5642),
                                child: Icon(
                                  heritageKindIcon(location.kind),
                                  color: Colors.white,
                                ),
                              )
                            : LearningAssetImage(
                                assetId: location.coverAssetId!,
                                fit: BoxFit.cover,
                                tappable: false,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            location.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: DauVietTypography.headlineSmall.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${location.kindLabelVi} · ${location.unlockState.labelVi}',
                            style: DauVietTypography.labelSmall.copyWith(
                              color: DauVietColors.heritageGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (location.primaryEventTitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              location.primaryEventTitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DauVietTypography.bodySmall.copyWith(
                                color: DauVietColors.inkMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if ((location.shortSummary ?? location.description) != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    (location.shortSummary ?? location.description)!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: DauVietTypography.bodySmall.copyWith(height: 1.4),
                  ),
                ],
                const SizedBox(height: 14),
                DongSonButton(
                  label: 'XEM HỒ SƠ',
                  height: 44,
                  onPressed: onOpenProfile,
                ),
                if (onOpenEvent != null || canOpenLesson) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (onOpenEvent != null)
                        Expanded(
                          child: DongSonButton(
                            label: 'XEM SỰ KIỆN',
                            variant: DongSonButtonVariant.secondaryParchment,
                            height: 42,
                            onPressed: onOpenEvent,
                          ),
                        ),
                      if (onOpenEvent != null && canOpenLesson)
                        const SizedBox(width: 8),
                      if (canOpenLesson)
                        Expanded(
                          child: DongSonButton(
                            label: location.unlockState == MapUnlockState.locked
                                ? 'HỌC ĐỂ MỞ'
                                : 'ÔN BÀI HỌC',
                            height: 42,
                            onPressed: onOpenLesson,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
