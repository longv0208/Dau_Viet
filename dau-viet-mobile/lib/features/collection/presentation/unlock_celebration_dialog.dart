import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../learning/presentation/renderers/learning_asset_image.dart';
import '../data/dossier_providers.dart';
import '../../rewards/data/reward_dtos.dart';

/// Popup "ĐẠT ĐƯỢC" kiểu game (GAME-04/05) — hiện giữa màn khi attempt
/// complete vừa mở khóa vật phẩm và/hoặc hồ sơ lịch sử. Mỗi entry là một
/// card: icon/asset lớn + tên + loại + mô tả + ngày mở khóa; bấm "TUYỆT VỜI"
/// hoặc chạm nền mờ để qua entry kế tiếp. Không tự đóng — phải có thao tác
/// của learner để không mất thông tin.
///
/// Được gọi MỘT LẦN từ LessonResultScreen khi mount (post-frame) và chỉ khi
/// có ít nhất một entry — không re-show khi deep-link/reload (server-side
/// newlyUnlockedDossiers chỉ trả trên request complete đầu tiên; item
/// itemsUnlocked vẫn có nhưng learner vào qua /result trực tiếp xem như
/// đã biết, không popup lại).
class UnlockCelebrationDialog extends ConsumerStatefulWidget {
  final List<InventoryItemDto> items;

  /// Dossier ids mới mở — resolve title/detail qua dossierDetailProvider.
  final List<String> dossierIds;

  const UnlockCelebrationDialog({
    super.key,
    required this.items,
    required this.dossierIds,
  });

  /// Hiện popup tuần tự cho mọi entry trong [items] + [dossierIds]. Đợi
  /// learner đóng từng cái (hoặc chạm nền). Trả Future hoàn thành khi hết
  /// hàng — caller không cần await.
  static Future<void> show(
    BuildContext context, {
    required List<InventoryItemDto> items,
    required List<String> dossierIds,
  }) async {
    // Item trước, dossier sau — vật phẩm gần gameplay hơn.
    for (final item in items) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.62),
        builder: (_) => UnlockCelebrationDialog._singleItem(item),
      );
    }
    for (final dossierId in dossierIds) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.62),
        builder: (_) => UnlockCelebrationDialog._singleDossier(dossierId),
      );
    }
  }

  // Constructor nội bộ: wrap một entry vào dialog state để giữ API show()
  // gọn — _singleItem/_singleDossier sinh widget dialog hoàn chỉnh.
  factory UnlockCelebrationDialog._singleItem(InventoryItemDto item) =>
      UnlockCelebrationDialog(items: [item], dossierIds: const []);

  factory UnlockCelebrationDialog._singleDossier(String dossierId) =>
      UnlockCelebrationDialog(items: const [], dossierIds: [dossierId]);

  @override
  ConsumerState<UnlockCelebrationDialog> createState() =>
      _UnlockCelebrationDialogState();
}

class _UnlockCelebrationDialogState
    extends ConsumerState<UnlockCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    HapticFeedback.lightImpact();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final Widget content = widget.items.isNotEmpty
        ? _ItemCard(item: widget.items.first)
        : _DossierCard(dossierId: widget.dossierIds.first);

    final Widget animated = reduceMotion
        ? content
        : FadeTransition(
            opacity: _fade,
            child: ScaleTransition(scale: _scale, child: content),
          );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: animated,
    );
  }
}

/// Khung card trung tâm — giấy dó, viền vàng đôi, bóng đổ, header "ĐẠT ĐƯỢC".
class _CardShell extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final String? description;
  final String? footerNote;

  const _CardShell({
    required this.leading,
    required this.title,
    this.subtitle,
    this.description,
    this.footerNote,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DauVietColors.parchmentSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DauVietColors.imperialGold, width: 1.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Viền trong mỏng — "double frame" phong cách giấy khen.
          Container(
            margin: const EdgeInsets.all(6),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: DauVietColors.imperialGold.withValues(alpha: 0.45),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _Header(),
                const SizedBox(height: 14),
                leading,
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: DauVietTypography.headlineSmall.copyWith(
                    color: DauVietColors.inkText,
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: DauVietTypography.labelSmall.copyWith(
                      color: DauVietColors.cinnabarRed,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
                if (description != null && description!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    description!,
                    textAlign: TextAlign.center,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: DauVietTypography.bodySmall.copyWith(
                      color: DauVietColors.inkMuted,
                      height: 1.45,
                    ),
                  ),
                ],
                if (footerNote != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    footerNote!,
                    textAlign: TextAlign.center,
                    style: DauVietTypography.bodySmall.copyWith(
                      color: DauVietColors.inkLight,
                      fontSize: 10.5,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: DauVietColors.cinnabarRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'TUYỆT VỜI',
                      style: DauVietTypography.labelMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.auto_awesome_rounded,
          size: 16,
          color: DauVietColors.imperialGold,
        ),
        const SizedBox(width: 6),
        Text(
          'ĐẠT ĐƯỢC',
          style: DauVietTypography.labelSmall.copyWith(
            color: DauVietColors.imperialGold,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(width: 6),
        const Icon(
          Icons.auto_awesome_rounded,
          size: 16,
          color: DauVietColors.imperialGold,
        ),
      ],
    );
  }
}

/// Card vật phẩm (InventoryItemDto) — icon category + asset nếu có.
class _ItemCard extends StatelessWidget {
  final InventoryItemDto item;
  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      leading: _ItemBadge(item: item),
      title: item.name,
      subtitle: _rarityLabel(item.rarity),
      description: item.description,
      footerNote: _dateNote(item.acquiredAt, 'Mở khóa lúc'),
    );
  }
}

class _ItemBadge extends StatelessWidget {
  final InventoryItemDto item;
  const _ItemBadge({required this.item});

  @override
  Widget build(BuildContext context) {
    final Widget inner = item.assetId != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LearningAssetImage(
              assetId: item.assetId!,
              height: 96,
              fit: BoxFit.cover,
              tappable: false,
            ),
          )
        : Icon(_categoryIcon(item), size: 44, color: Colors.white);
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: DauVietColors.cinnabarRed,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DauVietColors.imperialGold, width: 2),
        boxShadow: [
          BoxShadow(
            color: DauVietColors.cinnabarRed.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(child: inner),
    );
  }

  static IconData _categoryIcon(InventoryItemDto item) {
    final cat = item.category.toUpperCase();
    final type = item.itemType.toUpperCase();
    if (type.contains('TITLE') || cat.contains('DANH')) {
      return Icons.workspace_premium_rounded;
    }
    if (type.contains('TOOL') || cat.contains('DỤNG')) {
      return Icons.handyman_rounded;
    }
    if (cat.contains('HỒ SƠ') || cat.contains('SƯU')) {
      return Icons.menu_book_rounded;
    }
    return Icons.card_giftcard_rounded;
  }
}

/// Card hồ sơ lịch sử — fetch detail qua dossierDetailProvider; khi lỗi/
/// đang tải vẫn hiện khung với title chung (không chặn flow).
class _DossierCard extends ConsumerWidget {
  final String dossierId;
  const _DossierCard({required this.dossierId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dossierDetailProvider(dossierId));
    return async.when(
      loading: () => const _CardShell(
        leading: _DossierBadge(assetId: null, type: null),
        title: 'Hồ sơ lịch sử',
        subtitle: 'ĐANG TẢI...',
        footerNote: null,
      ),
      error: (_, _) => const _CardShell(
        leading: _DossierBadge(assetId: null, type: null),
        title: 'Hồ sơ lịch sử',
        subtitle: 'ĐÃ MỞ KHÓA',
        footerNote: null,
      ),
      data: (d) => _CardShell(
        leading: _DossierBadge(assetId: d.assetId, type: d.dossierType),
        title: d.title.isNotEmpty ? d.title : 'Hồ sơ lịch sử',
        subtitle: _dossierTypeLabel(d.dossierType),
        description: d.summary ?? d.description,
        footerNote: _dateNote(d.grantedAt, 'Mở khóa lúc'),
      ),
    );
  }
}

class _DossierBadge extends StatelessWidget {
  final String? assetId;
  final String? type;
  const _DossierBadge({required this.assetId, required this.type});

  @override
  Widget build(BuildContext context) {
    final Widget inner = assetId != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LearningAssetImage(
              assetId: assetId!,
              height: 96,
              fit: BoxFit.cover,
              tappable: false,
            ),
          )
        : Icon(_typeIcon(type), size: 44, color: Colors.white);
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: DauVietColors.imperialGold,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DauVietColors.woodBrown, width: 2),
        boxShadow: [
          BoxShadow(
            color: DauVietColors.imperialGold.withValues(alpha: 0.45),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(child: inner),
    );
  }

  static IconData _typeIcon(String? t) => switch (t) {
    'PERSON' => Icons.person_rounded,
    'LOCATION' => Icons.place_rounded,
    'ARTIFACT' => Icons.diamond_rounded,
    _ => Icons.menu_book_rounded,
  };
}

String _dossierTypeLabel(String? t) => switch (t) {
  'PERSON' => 'NHÂN VẬT',
  'LOCATION' => 'ĐỊA ĐIỂM',
  'ARTIFACT' => 'HIỆN VẬT',
  _ => 'HỒ SƠ LỊCH SỬ',
};

String _rarityLabel(String rarity) => switch (rarity.toUpperCase()) {
  'COMMON' => 'VẬT PHẨM',
  'UNCOMMON' => 'VẬT PHẨM KHÁ HIẾM',
  'RARE' => 'VẬT PHẨM HIẾM',
  'EPIC' => 'VẬT PHẨM QUÝ',
  'LEGENDARY' => 'VẬT PHẨM HUYỀN THOẠI',
  _ => 'VẬT PHẨM',
};

/// "Mở khóa lúc dd/mm/yyyy" — parse ISO → local, sai format → bỏ note.
String? _dateNote(String? iso, String label) {
  if (iso == null || iso.isEmpty) return null;
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return null;
  final dd = dt.day.toString().padLeft(2, '0');
  final mm = dt.month.toString().padLeft(2, '0');
  return '$label $dd/$mm/${dt.year}';
}
