import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/dau_viet_colors.dart';
import '../theme/dau_viet_typography.dart';

/// Điểm giải phẫu / chú thích cấu tạo mô hình lịch sử (tham chiếu https://Historydauviet.id.vn).
class ArtifactModelCallout {
  final int index;
  final String title;
  final String badge;
  final String detail;

  const ArtifactModelCallout({
    required this.index,
    required this.title,
    required this.badge,
    required this.detail,
  });
}

/// Phân loại mô hình 2.5D để vẽ đúng hiện vật/công trình/huy hiệu lịch sử.
enum HeritageModelKind {
  dongSonDrum,
  bachDangStakes,
  lienChauCrossbow,
  coLoaCitadel,
  hoCitadelGate,
  mySonTower,
  hoiAnAncientHouse,
  ngoQuyenWarship,
  imperialScroll,
  bachDangWatchtower,
  haiBaTrungBadge,
  dienBienPhuBadge,
  bachDangBadge,
  thangLongBadge,
  lyThaiToStatue,
  flagpole,
  communalHall,
  villageGate,
  khueVanCac,
  penTower,
  banyanTree,
  peachTree,
  bambooGrove,
  lotusPond,
  coveredBridge,
  ancientWell,
  lanternPost,
  thatchedHouse,
  historicalPerson,
  historicalLocation,
}

/// Nhận diện loại mô hình từ `code`, `renderKey`, `canonicalCode` hoặc `title`.
HeritageModelKind resolveHeritageModelKind({
  String? code,
  String? renderKey,
  String? title,
  String? category,
}) {
  final combined =
      '${code ?? ''} ${renderKey ?? ''} ${title ?? ''} ${category ?? ''}'
          .toLowerCase();

  if (combined.contains('trong_dong') ||
      combined.contains('trong-dong') ||
      combined.contains('trống đồng') ||
      combined.contains('ngọc lũ')) {
    return HeritageModelKind.dongSonDrum;
  }
  if (combined.contains('coc_bach_dang') ||
      combined.contains('coc-go-bach-dang') ||
      combined.contains('cọc ngầm') ||
      combined.contains('cọc gỗ') ||
      combined.contains('bãi cọc') ||
      combined.contains('stakes')) {
    return HeritageModelKind.bachDangStakes;
  }
  if (combined.contains('no_lien_chau') ||
      combined.contains('no-lien-chau') ||
      combined.contains('nỏ thần') ||
      combined.contains('nỏ liên châu') ||
      combined.contains('mũi tên đồng')) {
    return HeritageModelKind.lienChauCrossbow;
  }
  if (combined.contains('co_loa') ||
      combined.contains('co-loa') ||
      combined.contains('cổ loa')) {
    return HeritageModelKind.coLoaCitadel;
  }
  if (combined.contains('thanh_nha_ho') ||
      combined.contains('thành nhà hồ') ||
      combined.contains('tây đô')) {
    return HeritageModelKind.hoCitadelGate;
  }
  if (combined.contains('chua_my_son') ||
      combined.contains('mỹ sơn') ||
      combined.contains('my_son')) {
    return HeritageModelKind.mySonTower;
  }
  if (combined.contains('pho_hoi_an') ||
      combined.contains('hội an') ||
      combined.contains('hoi_an')) {
    if (combined.contains('den_long') || combined.contains('đèn lồng')) {
      return HeritageModelKind.lanternPost;
    }
    return HeritageModelKind.hoiAnAncientHouse;
  }
  if (combined.contains('thuyen_chien') ||
      combined.contains('chien-thuyen') ||
      combined.contains('thuyen_rong') ||
      combined.contains('chiến thuyền') ||
      combined.contains('thuyền rồng') ||
      combined.contains('thuyền')) {
    return HeritageModelKind.ngoQuyenWarship;
  }
  if (combined.contains('chieu_doi_do') ||
      combined.contains('chieu-doi-do') ||
      combined.contains('nam-quoc-son-ha') ||
      combined.contains('chiếu dời đô') ||
      combined.contains('thiên đô chiếu') ||
      combined.contains('nam quốc sơn hà') ||
      combined.contains('cổ thư')) {
    return HeritageModelKind.imperialScroll;
  }
  if (combined.contains('choi_canh') ||
      combined.contains('chòi canh') ||
      combined.contains('tower')) {
    return HeritageModelKind.bachDangWatchtower;
  }
  if (combined.contains('huy_hieu_hai_ba_trung') ||
      combined.contains('badge.hai_ba_trung') ||
      (combined.contains('huy hiệu') && combined.contains('hai bà trưng'))) {
    return HeritageModelKind.haiBaTrungBadge;
  }
  if (combined.contains('huy_hieu_dien_bien') ||
      combined.contains('badge.dien_bien') ||
      (combined.contains('huy hiệu') && combined.contains('điện biên'))) {
    return HeritageModelKind.dienBienPhuBadge;
  }
  if (combined.contains('huy_hieu_bach_dang') ||
      combined.contains('badge.bach_dang') ||
      (combined.contains('huy hiệu') && combined.contains('bạch đằng'))) {
    return HeritageModelKind.bachDangBadge;
  }
  if (combined.contains('huy_hieu_thang_long') ||
      combined.contains('badge.thang_long') ||
      combined.contains('huy_hieu') ||
      combined.contains('commemorative_badge')) {
    return HeritageModelKind.thangLongBadge;
  }
  if (combined.contains('tuong_ly_thai_to') || combined.contains('tượng')) {
    return HeritageModelKind.lyThaiToStatue;
  }
  if (combined.contains('cot_co') || combined.contains('cột cờ')) {
    return HeritageModelKind.flagpole;
  }
  if (combined.contains('khue_van') || combined.contains('khuê văn')) {
    return HeritageModelKind.khueVanCac;
  }
  if (combined.contains('thap_but') || combined.contains('tháp bút')) {
    return HeritageModelKind.penTower;
  }
  if (combined.contains('dinh_lang') || combined.contains('đình làng')) {
    return HeritageModelKind.communalHall;
  }
  if (combined.contains('cong_lang') || combined.contains('cổng làng')) {
    return HeritageModelKind.villageGate;
  }
  if (combined.contains('cay_dao') || combined.contains('cây đào')) {
    return HeritageModelKind.peachTree;
  }
  if (combined.contains('cay_da') || combined.contains('cây đa')) {
    return HeritageModelKind.banyanTree;
  }
  if (combined.contains('bui_tre') || combined.contains('bụi tre')) {
    return HeritageModelKind.bambooGrove;
  }
  if (combined.contains('ho_sen') || combined.contains('hồ sen')) {
    return HeritageModelKind.lotusPond;
  }
  if (combined.contains('cau_kieu') || combined.contains('cầu kiều')) {
    return HeritageModelKind.coveredBridge;
  }
  if (combined.contains('gieng_co') || combined.contains('giếng cổ')) {
    return HeritageModelKind.ancientWell;
  }
  if (combined.contains('den_long') || combined.contains('đèn lồng')) {
    return HeritageModelKind.lanternPost;
  }
  if (combined.contains('nha_tranh') || combined.contains('nhà tranh')) {
    return HeritageModelKind.thatchedHouse;
  }
  if (combined.contains('person') || combined.contains('character')) {
    return HeritageModelKind.historicalPerson;
  }
  if (combined.contains('location')) {
    return HeritageModelKind.historicalLocation;
  }
  return HeritageModelKind.dongSonDrum;
}

/// Danh sách điểm giải phẫu chi tiết cho từng mô hình (tham chiếu https://Historydauviet.id.vn).
List<ArtifactModelCallout> calloutsForHeritageModel(HeritageModelKind kind) {
  switch (kind) {
    case HeritageModelKind.bachDangStakes:
      return const [
        ArtifactModelCallout(
          index: 1,
          title: 'Đầu cọc vạt nhọn bọc sắt',
          badge: 'Vũ khí xuyên phá',
          detail:
              'Cọc gỗ được đẽo vát chéo thật sắc bén, bịt đầu bằng mũi sắt nhọn hoắt. Khi thuyền chiến Nam Hán lao tới hoặc bị nước rút hạ xuống, mũi sắt này sẽ xé toạc đáy ván thuyền làm nước tràn vào dữ dội.',
        ),
        ArtifactModelCallout(
          index: 2,
          title: 'Thân cọc cắm xiên 45° - 60°',
          badge: 'Góc nghiêng hiểm ác',
          detail:
              'Tất cả các cọc gỗ đều được đóng xiên xuôi theo chiều nước chảy ra biển. Khi thuyền địch rút lui theo con nước, thân cọc đóng vai trò như những chiếc nêm chĩa thẳng vào mũi và lườn thuyền.',
        ),
        ArtifactModelCallout(
          index: 3,
          title: 'Gỗ Lim & Táu ngâm ngập bùn',
          badge: 'Độ bền vĩnh cửu',
          detail:
              'Quân dân Ngô Quyền đã đốn hạ hàng nghìn cây gỗ lim, táu từ rừng thượng nguồn đưa về. Đây là loại thiết mộc nặng, cắm sâu 1.5 - 2m xuống lòng sông chịu được lực va đập hàng chục tấn.',
        ),
      ];
    case HeritageModelKind.dongSonDrum:
      return const [
        ArtifactModelCallout(
          index: 1,
          title: 'Ngôi sao 12 cánh giữa mặt trống',
          badge: 'Biểu tượng Mặt Trời',
          detail:
              'Trung tâm mặt trống đúc nổi ngôi sao 12 cánh tượng trưng cho mặt trời và 12 tháng nông lịch của cư dân trồng lúa nước lưu vực sông Hồng.',
        ),
        ArtifactModelCallout(
          index: 2,
          title: 'Vòng chim Lạc & Hoa văn kỷ hà',
          badge: 'Nghệ thuật Đông Sơn',
          detail:
              'Các vành đồng tâm khắc họa 18 chim Lạc sải cánh bay ngược chiều kim đồng hồ cùng cảnh giã gạo, nhà sàn mái cong và lễ hội đánh trống.',
        ),
        ArtifactModelCallout(
          index: 3,
          title: 'Tang trống phình & Quai kép bện thừng',
          badge: 'Kỹ thuật đúc khuôn sáp',
          detail:
              'Thân trống chia 3 phần (tang, lưng, chân) cân đối hoàn hảo, tạo buồng cộng hưởng âm thanh trầm hùng vang xa hàng dặm.',
        ),
      ];
    case HeritageModelKind.lienChauCrossbow:
      return const [
        ArtifactModelCallout(
          index: 1,
          title: 'Lẫy nỏ đồng Cổ Loa (Quách cơ)',
          badge: 'Cơ khí chính xác',
          detail:
              'Bộ phận lẫy nỏ đúc bằng đồng thau gồm hộp quách, thước ngắm, lẫy cò và chốt giữ dây chịu được lực căng cực lớn.',
        ),
        ArtifactModelCallout(
          index: 2,
          title: 'Cánh cung ghép & Rãnh bắn chùm tên',
          badge: 'Hỏa lực Liên Châu',
          detail:
              'Thiết kế cho phép phóng đồng loạt nhiều mũi tên đồng trong một lần bóp cò, tạo màn tên dày đặc trấn giữ thành Cổ Loa.',
        ),
        ArtifactModelCallout(
          index: 3,
          title: 'Mũi tên đồng 3 cạnh Cầu Vực',
          badge: 'Di chỉ khảo cổ 1959',
          detail:
              'Đầu mũi tên có 3 cạnh sắc bén và trụ đuôi dài giúp bay thẳng, xuyên thủng giáp trụ; hàng vạn mũi tên đã được tìm thấy tại Cổ Loa.',
        ),
      ];
    case HeritageModelKind.coLoaCitadel:
      return const [
        ArtifactModelCallout(
          index: 1,
          title: 'Ba vòng lũy đất xoắn ốc (Loa Thành)',
          badge: 'Kiến trúc quân sự cổ đại',
          detail:
              'Thành Ngoại, Thành Trung và Thành Nội uốn lượn theo địa hình đồi gò tự nhiên, tạo mê cung phòng thủ liên hoàn.',
        ),
        ArtifactModelCallout(
          index: 2,
          title: 'Hào nước nối sông Hoàng Giang',
          badge: 'Thủy bộ phối hợp',
          detail:
              'Hệ thống hào nước rộng bao quanh chân thành nối thông với Đầm Cả và sông Hoàng Giang để thuyền chiến cơ động.',
        ),
        ArtifactModelCallout(
          index: 3,
          title: 'Ụ hỏa lực & Cửa thành kiểm soát',
          badge: 'Phòng tuyến kiên cố',
          detail:
              'Các ụ đất cao bố trí xạ thủ nỏ Liên Châu khống chế mọi lối vào từ cửa sông và đường bộ.',
        ),
      ];
    case HeritageModelKind.hoCitadelGate:
      return const [
        ArtifactModelCallout(
          index: 1,
          title: 'Ba cổng vòm cuốn đá ghép khóa vòm',
          badge: 'Kỹ thuật vòm nêm',
          detail:
              'Các khối đá hình múi bưởi nặng hàng chục tấn được đẽo vát và ghép khít tự khóa chặt vào nhau mà không dùng bất kỳ chất kết dính nào.',
        ),
        ArtifactModelCallout(
          index: 2,
          title: 'Tường thành đá xanh nguyên khối',
          badge: 'Di sản UNESCO 2011',
          detail:
              'Những phiến đá xanh dài tới 6m được khai thác từ núi đá An Tôn và lắp ghép chính xác bền vững hơn 600 năm.',
        ),
      ];
    case HeritageModelKind.mySonTower:
      return const [
        ArtifactModelCallout(
          index: 1,
          title: 'Thân tháp gạch nung mài khít',
          badge: 'Bí quyết kiến trúc Chăm',
          detail:
              'Gạch đất nung đỏ hồng được mài phẳng và kết dính bằng dầu rái thực vật tạo nên khối kiến trúc liền mạch không thấy mạch vữa.',
        ),
        ArtifactModelCallout(
          index: 2,
          title: 'Mái tháp 3 tầng thu nhỏ dần',
          badge: 'Biểu tượng núi thiêng Meru',
          detail:
              'Tầng mái thu hẹp dần lên đỉnh với các tháp góc thu nhỏ và phù điêu đá sa thạch chạm khắc tinh xảo.',
        ),
      ];
    case HeritageModelKind.ngoQuyenWarship:
      return const [
        ArtifactModelCallout(
          index: 1,
          title: 'Mũi thuyền chạm Đầu Rồng & Cờ Đại Việt',
          badge: 'Soái hạm tiên phong',
          detail:
              'Đầu thuyền chạm rồng uy nghiêm cùng đại kỳ đỏ thắm dẫn đầu đội thuyền nhẹ khiêu chiến và tổng phản công.',
        ),
        ArtifactModelCallout(
          index: 2,
          title: 'Buồm nan tre & Hệ thống chèo cơ động',
          badge: 'Linh hoạt trên sông',
          detail:
              'Thân thuyền thon gọn mớm nước nông, dễ dàng vượt qua trên bãi cọc lúc triều lên và luồn lách giữa các rạch sú vẹt.',
        ),
      ];
    default:
      return const [
        ArtifactModelCallout(
          index: 1,
          title: 'Chế tác theo nguyên mẫu tư liệu lịch sử',
          badge: 'Mô hình giáo dục Dấu Việt',
          detail:
              'Mô hình 2.5D được tái dựng trực quan từ nguồn sử liệu và hiện vật bảo tàng nhằm giúp người học quan sát cấu trúc và ý nghĩa lịch sử.',
        ),
      ];
  }
}

/// Widget hiển thị mô hình 2.5D / tranh di sản cho mọi vật phẩm Bộ Sưu Tập,
/// Túi Đồ Sĩ Tử và Đảo Di Sản.
class HeritageArtifactModelView extends StatelessWidget {
  final String? code;
  final String? renderKey;
  final String? title;
  final String? category;
  final double size;
  final bool showPedestal;
  final bool interactiveInspector;
  final String? description;
  final String? sourceNote;

  const HeritageArtifactModelView({
    super.key,
    this.code,
    this.renderKey,
    this.title,
    this.category,
    this.size = 72,
    this.showPedestal = true,
    this.interactiveInspector = false,
    this.description,
    this.sourceNote,
  });

  @override
  Widget build(BuildContext context) {
    final kind = resolveHeritageModelKind(
      code: code,
      renderKey: renderKey,
      title: title,
      category: category,
    );

    final art = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HeritageArtifact25DPainter(
          kind: kind,
          showPedestal: showPedestal,
        ),
      ),
    );

    if (!interactiveInspector) {
      return art;
    }

    return GestureDetector(
      onTap: () => showHeritageModelInspectorDialog(
        context,
        kind: kind,
        title: title ?? 'Mô hình Di sản Dấu Việt',
        description: description,
        sourceNote: sourceNote,
      ),
      child: art,
    );
  }
}

/// Mở hộp thoại xoay/khám phá cấu tạo mô hình 2.5D (tham chiếu https://Historydauviet.id.vn).
Future<void> showHeritageModelInspectorDialog(
  BuildContext context, {
  required HeritageModelKind kind,
  required String title,
  String? description,
  String? sourceNote,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _HeritageModelInspectorDialog(
      kind: kind,
      title: title,
      description: description,
      sourceNote: sourceNote,
    ),
  );
}

class _HeritageModelInspectorDialog extends StatefulWidget {
  final HeritageModelKind kind;
  final String title;
  final String? description;
  final String? sourceNote;

  const _HeritageModelInspectorDialog({
    required this.kind,
    required this.title,
    this.description,
    this.sourceNote,
  });

  @override
  State<_HeritageModelInspectorDialog> createState() =>
      _HeritageModelInspectorDialogState();
}

class _HeritageModelInspectorDialogState
    extends State<_HeritageModelInspectorDialog> {
  int _selectedCalloutIdx = 0;
  double _zoom = 1.0;

  @override
  Widget build(BuildContext context) {
    final callouts = calloutsForHeritageModel(widget.kind);
    final activeCallout =
        callouts[_selectedCalloutIdx.clamp(0, callouts.length - 1)];

    return Dialog(
      backgroundColor: DauVietColors.paperCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: DauVietColors.imperialGold, width: 1.8),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: DauVietColors.cinnabarRed,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'MÔ HÌNH DI SẢN 2.5D',
                      style: DauVietTypography.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: DauVietColors.inkText,
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Text(
                widget.title,
                style: DauVietTypography.headlineMedium.copyWith(
                  fontSize: 18,
                  color: DauVietColors.inkHeading,
                ),
              ),
              const SizedBox(height: 12),

              // Sân khấu trưng bày mô hình 2.5D có thu phóng
              Container(
                height: 210,
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    center: Alignment(0, -0.15),
                    radius: 0.85,
                    colors: [
                      Color(0xFFFFF8E8),
                      DauVietColors.paperCardHi,
                      Color(0xFFE5D2B0),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: DauVietColors.imperialGold,
                    width: 1.4,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.scale(
                      scale: _zoom,
                      child: CustomPaint(
                        size: const Size(176, 176),
                        painter: _HeritageArtifact25DPainter(
                          kind: widget.kind,
                          showPedestal: true,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: DauVietColors.paperCard.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: DauVietColors.outlineVariant,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_rounded, size: 16),
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Thu nhỏ',
                              onPressed: () => setState(
                                () => _zoom = (_zoom - 0.15).clamp(0.85, 1.45),
                              ),
                            ),
                            Text(
                              '${(_zoom * 100).round()}%',
                              style: DauVietTypography.labelSmall.copyWith(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_rounded, size: 16),
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Phóng to',
                              onPressed: () => setState(
                                () => _zoom = (_zoom + 0.15).clamp(0.85, 1.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (widget.description != null &&
                  widget.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  widget.description!,
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.inkText,
                    height: 1.45,
                  ),
                ),
              ],

              const SizedBox(height: 14),
              Text(
                'KHÁM PHÁ CẤU TẠO & CHI TIẾT LỊCH SỬ',
                style: DauVietTypography.labelSmall.copyWith(
                  color: DauVietColors.cinnabarRed,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),

              // Các nút chọn điểm giải phẫu (1, 2, 3...)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int i = 0; i < callouts.length; i++)
                    ChoiceChip(
                      label: Text('${callouts[i].index}. ${callouts[i].title}'),
                      selected: _selectedCalloutIdx == i,
                      selectedColor: DauVietColors.heritageGreen,
                      backgroundColor: DauVietColors.paperBackground,
                      labelStyle: DauVietTypography.labelSmall.copyWith(
                        color: _selectedCalloutIdx == i
                            ? Colors.white
                            : DauVietColors.inkText,
                        fontWeight: FontWeight.w700,
                      ),
                      onSelected: (_) =>
                          setState(() => _selectedCalloutIdx = i),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Khung chi tiết của điểm giải phẫu đang chọn
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DauVietColors.paperBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: DauVietColors.imperialGold.withValues(alpha: 0.7),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: DauVietColors.imperialGoldLight,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: DauVietColors.imperialGold,
                            ),
                          ),
                          child: Text(
                            activeCallout.badge,
                            style: DauVietTypography.labelSmall.copyWith(
                              fontSize: 10,
                              color: DauVietColors.woodBrown,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            activeCallout.title,
                            style: DauVietTypography.labelMedium.copyWith(
                              fontWeight: FontWeight.w800,
                              color: DauVietColors.inkHeading,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      activeCallout.detail,
                      style: DauVietTypography.bodySmall.copyWith(
                        color: DauVietColors.inkSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),

              if (widget.sourceNote != null &&
                  widget.sourceNote!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  widget.sourceNote!,
                  style: DauVietTypography.bodySmall.copyWith(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: DauVietColors.inkMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Painter vẽ chi tiết 2.5D Isometric cho từng mô hình di sản, phiên bản số và huy hiệu.
class _HeritageArtifact25DPainter extends CustomPainter {
  final HeritageModelKind kind;
  final bool showPedestal;

  const _HeritageArtifact25DPainter({
    required this.kind,
    required this.showPedestal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    if (showPedestal) {
      _paintPedestal(canvas, w, h);
    }

    switch (kind) {
      case HeritageModelKind.dongSonDrum:
        _paintDongSonDrum(canvas, w, h);
      case HeritageModelKind.bachDangStakes:
        _paintBachDangStakes(canvas, w, h);
      case HeritageModelKind.lienChauCrossbow:
        _paintLienChauCrossbow(canvas, w, h);
      case HeritageModelKind.coLoaCitadel:
        _paintCoLoaCitadel(canvas, w, h);
      case HeritageModelKind.hoCitadelGate:
        _paintHoCitadelGate(canvas, w, h);
      case HeritageModelKind.mySonTower:
        _paintMySonTower(canvas, w, h);
      case HeritageModelKind.hoiAnAncientHouse:
        _paintHoiAnHouse(canvas, w, h);
      case HeritageModelKind.ngoQuyenWarship:
        _paintWarship(canvas, w, h);
      case HeritageModelKind.imperialScroll:
        _paintImperialScroll(canvas, w, h);
      case HeritageModelKind.bachDangWatchtower:
        _paintWatchtower(canvas, w, h);
      case HeritageModelKind.haiBaTrungBadge:
        _paintCommemorativeBadge(
          canvas,
          w,
          h,
          primary: const Color(0xFFB93430),
          accent: const Color(0xFFE0AE45),
          emblem: 'HBT',
        );
      case HeritageModelKind.dienBienPhuBadge:
        _paintCommemorativeBadge(
          canvas,
          w,
          h,
          primary: const Color(0xFFC62828),
          accent: const Color(0xFFFFD54F),
          emblem: '1954',
        );
      case HeritageModelKind.bachDangBadge:
        _paintCommemorativeBadge(
          canvas,
          w,
          h,
          primary: const Color(0xFF1B6B93),
          accent: const Color(0xFFE0AE45),
          emblem: '938',
        );
      case HeritageModelKind.thangLongBadge:
        _paintCommemorativeBadge(
          canvas,
          w,
          h,
          primary: const Color(0xFF1E4D3B),
          accent: const Color(0xFFE0AE45),
          emblem: '1010',
        );
      case HeritageModelKind.lyThaiToStatue:
        _paintStatue(canvas, w, h);
      case HeritageModelKind.flagpole:
        _paintFlagpole(canvas, w, h);
      default:
        _paintDongSonDrum(canvas, w, h);
    }
  }

  void _paintPedestal(Canvas canvas, double w, double h) {
    final shadowPaint = Paint()
      ..color = const Color(0x2830251F)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.86),
        width: w * 0.72,
        height: h * 0.16,
      ),
      shadowPaint,
    );

    // Đế gỗ lim bát giác 2.5D
    final baseTop = Path()
      ..moveTo(w * 0.5, h * 0.74)
      ..lineTo(w * 0.82, h * 0.83)
      ..lineTo(w * 0.5, h * 0.91)
      ..lineTo(w * 0.18, h * 0.83)
      ..close();
    final baseSide = Path()
      ..moveTo(w * 0.18, h * 0.83)
      ..lineTo(w * 0.5, h * 0.91)
      ..lineTo(w * 0.82, h * 0.83)
      ..lineTo(w * 0.82, h * 0.88)
      ..lineTo(w * 0.5, h * 0.96)
      ..lineTo(w * 0.18, h * 0.88)
      ..close();

    canvas.drawPath(
      baseSide,
      Paint()..color = const Color(0xFF523222),
    );
    canvas.drawPath(
      baseTop,
      Paint()..color = const Color(0xFF7A4B32),
    );
    canvas.drawPath(
      baseTop,
      Paint()
        ..color = const Color(0xFFE0AE45).withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  /// 1. Mô hình Trống đồng Đông Sơn 2.5D (Ngọc Lũ)
  void _paintDongSonDrum(Canvas canvas, double w, double h) {
    final bronzeDark = Paint()..color = const Color(0xFF7B5826);
    final bronzeMid = Paint()..color = const Color(0xFFB38338);
    final bronzeGold = Paint()..color = const Color(0xFFE5B85B);
    final patina = Paint()
      ..color = const Color(0xFF2B6E57).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    // Chân trống loe + Lưng trống trụ + Tang trống phình
    final body = Path()
      ..moveTo(w * 0.26, h * 0.34)
      ..quadraticBezierTo(w * 0.20, h * 0.46, w * 0.28, h * 0.58)
      ..lineTo(w * 0.23, h * 0.78)
      ..quadraticBezierTo(w * 0.50, h * 0.86, w * 0.77, h * 0.78)
      ..lineTo(w * 0.72, h * 0.58)
      ..quadraticBezierTo(w * 0.80, h * 0.46, w * 0.74, h * 0.34)
      ..close();
    canvas.drawPath(body, bronzeMid);

    // Đổ bóng khối trụ bên phải
    final rightShade = Path()
      ..moveTo(w * 0.50, h * 0.34)
      ..lineTo(w * 0.74, h * 0.34)
      ..quadraticBezierTo(w * 0.80, h * 0.46, w * 0.72, h * 0.58)
      ..lineTo(w * 0.77, h * 0.78)
      ..quadraticBezierTo(w * 0.64, h * 0.83, w * 0.50, h * 0.82)
      ..close();
    canvas.drawPath(rightShade, bronzeDark);

    // Đai hoa văn ngang thân trống
    for (final yFactor in const [0.47, 0.58, 0.68]) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(w * 0.5, h * yFactor),
          width: w * 0.48,
          height: h * 0.10,
        ),
        0,
        math.pi,
        false,
        Paint()
          ..color = const Color(0xFFFFDEA7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }

    // Quai trống đôi hai bên
    final handlePaint = Paint()
      ..color = const Color(0xFFD9A441)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawArc(
      Rect.fromLTWH(w * 0.18, h * 0.44, w * 0.10, h * 0.15),
      math.pi * 0.5,
      math.pi,
      false,
      handlePaint,
    );
    canvas.drawArc(
      Rect.fromLTWH(w * 0.72, h * 0.44, w * 0.10, h * 0.15),
      -math.pi * 0.5,
      math.pi,
      false,
      handlePaint,
    );

    // Mặt trống elip nghiêng 2.5D phía trên
    final tympanumRect = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.34),
      width: w * 0.50,
      height: h * 0.22,
    );
    canvas.drawOval(tympanumRect, bronzeGold);
    canvas.drawOval(
      tympanumRect,
      Paint()
        ..color = const Color(0xFF5D4019)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.drawOval(tympanumRect.deflate(w * 0.05), patina);
    canvas.drawOval(tympanumRect.deflate(w * 0.10), patina);

    // Ngôi sao 12 cánh ở tâm mặt trống
    final cx = w * 0.5;
    final cy = h * 0.34;
    final star = Path();
    const rays = 10;
    for (int i = 0; i < rays * 2; i++) {
      final a = (i * math.pi) / rays;
      final rx = i.isEven ? w * 0.09 : w * 0.035;
      final ry = i.isEven ? h * 0.042 : h * 0.016;
      final px = cx + rx * math.cos(a);
      final py = cy + ry * math.sin(a);
      if (i == 0) {
        star.moveTo(px, py);
      } else {
        star.lineTo(px, py);
      }
    }
    star.close();
    canvas.drawPath(star, Paint()..color = const Color(0xFF85211F));
  }

  /// 2. Mô hình Trận địa cọc ngầm Bạch Đằng (theo chuẩn SVG Historydauviet.id.vn)
  void _paintBachDangStakes(Canvas canvas, double w, double h) {
    // Đáy bùn sông
    final riverbed = Path()
      ..moveTo(w * 0.16, h * 0.76)
      ..lineTo(w * 0.62, h * 0.62)
      ..lineTo(w * 0.88, h * 0.76)
      ..lineTo(w * 0.42, h * 0.90)
      ..close();
    canvas.drawPath(riverbed, Paint()..color = const Color(0xFF8C7248));

    // 4 cọc gỗ lim cắm xiên 45°-60° bịt đầu sắt nhọn
    const stakes = [
      (0.28, 0.28),
      (0.47, 0.20),
      (0.65, 0.30),
      (0.46, 0.40),
    ];
    for (final (sx, sy) in stakes) {
      canvas.save();
      canvas.translate(w * sx, h * sy);
      canvas.rotate(-0.22);

      // Thân cọc gỗ lim
      final trunk = Path()
        ..moveTo(0, h * 0.10)
        ..lineTo(w * 0.085, h * 0.08)
        ..lineTo(w * 0.085, h * 0.44)
        ..lineTo(0, h * 0.46)
        ..close();
      canvas.drawPath(trunk, Paint()..color = const Color(0xFF7D5231));

      // Vân gỗ sáng
      canvas.drawLine(
        Offset(w * 0.028, h * 0.13),
        Offset(w * 0.028, h * 0.41),
        Paint()
          ..color = const Color(0xFFD1A26A)
          ..strokeWidth = 1.6,
      );

      // Đầu cọc vạt nhọn bọc sắt
      final ironTip = Path()
        ..moveTo(0, h * 0.10)
        ..lineTo(w * 0.055, 0)
        ..lineTo(w * 0.085, h * 0.08)
        ..close();
      canvas.drawPath(ironTip, Paint()..color = const Color(0xFF546E7A));
      canvas.drawLine(
        Offset(w * 0.055, 0),
        Offset(w * 0.04, h * 0.09),
        Paint()
          ..color = const Color(0xFFCFD8DC)
          ..strokeWidth = 1.3,
      );
      canvas.restore();
    }

    // Sóng nước thủy triều sông Bạch Đằng
    final wavePaint = Paint()
      ..color = const Color(0xFF388EB4).withValues(alpha: 0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final w1 = Path()
      ..moveTo(w * 0.16, h * 0.66)
      ..quadraticBezierTo(w * 0.34, h * 0.60, w * 0.50, h * 0.66)
      ..quadraticBezierTo(w * 0.68, h * 0.72, w * 0.84, h * 0.64);
    final w2 = Path()
      ..moveTo(w * 0.22, h * 0.74)
      ..quadraticBezierTo(w * 0.45, h * 0.68, w * 0.78, h * 0.74);
    canvas.drawPath(w1, wavePaint);
    canvas.drawPath(w2, wavePaint);
  }

  /// 3. Mô hình Nỏ thần Liên Châu & Mũi tên đồng Cổ Loa
  void _paintLienChauCrossbow(Canvas canvas, double w, double h) {
    final woodPaint = Paint()
      ..color = const Color(0xFF6D4226)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    final bronzePaint = Paint()
      ..color = const Color(0xFFD9A441)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    // Cánh cung uốn cong
    final bow = Path()
      ..moveTo(w * 0.20, h * 0.46)
      ..quadraticBezierTo(w * 0.50, h * 0.16, w * 0.80, h * 0.46);
    canvas.drawPath(bow, woodPaint);
    canvas.drawPath(bow, bronzePaint);

    // Dây cung căng
    canvas.drawLine(
      Offset(w * 0.20, h * 0.46),
      Offset(w * 0.50, h * 0.62),
      Paint()
        ..color = const Color(0xFFEAD7B7)
        ..strokeWidth = 1.6,
    );
    canvas.drawLine(
      Offset(w * 0.80, h * 0.46),
      Offset(w * 0.50, h * 0.62),
      Paint()
        ..color = const Color(0xFFEAD7B7)
        ..strokeWidth = 1.6,
    );

    // Thân nỏ & Lẫy đồng Cổ Loa (Quách cơ)
    canvas.drawLine(
      Offset(w * 0.50, h * 0.24),
      Offset(w * 0.50, h * 0.76),
      woodPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.50, h * 0.58),
          width: w * 0.16,
          height: h * 0.14,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFB38338),
    );

    // Chùm 3 mũi tên đồng 3 cạnh bắn Liên Châu
    for (final dx in const [-0.14, 0.0, 0.14]) {
      final tipX = w * (0.50 + dx);
      final tipY = h * (dx == 0.0 ? 0.14 : 0.19);
      canvas.drawLine(
        Offset(w * (0.50 + dx * 0.35), h * 0.54),
        Offset(tipX, tipY),
        Paint()
          ..color = const Color(0xFFE0AE45)
          ..strokeWidth = 2.0,
      );
      final head = Path()
        ..moveTo(tipX, tipY - h * 0.04)
        ..lineTo(tipX - w * 0.035, tipY + h * 0.03)
        ..lineTo(tipX + w * 0.035, tipY + h * 0.03)
        ..close();
      canvas.drawPath(head, Paint()..color = const Color(0xFFFFDEA7));
    }
  }

  /// 4. Mô hình Thành Cổ Loa (3 vòng xoắn ốc)
  void _paintCoLoaCitadel(Canvas canvas, double w, double h) {
    final moatPaint = Paint()
      ..color = const Color(0xFF388EB4).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    final wallPaint = Paint()
      ..color = const Color(0xFFA97932)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    // 3 vòng hào + thành xoắn ốc đồng tâm nghiêng 2.5D
    for (final f in const [0.68, 0.48, 0.28]) {
      final rect = Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.50),
        width: w * f,
        height: h * (f * 0.65),
      );
      canvas.drawOval(rect.inflate(2.5), moatPaint);
      canvas.drawArc(rect, 0.15, math.pi * 1.75, false, wallPaint);
    }

    // Điện trung tâm Thành Nội
    final roof = Path()
      ..moveTo(w * 0.38, h * 0.48)
      ..lineTo(w * 0.50, h * 0.34)
      ..lineTo(w * 0.62, h * 0.48)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFFB93430));
  }

  /// 5. Mô hình Thành nhà Hồ (Cổng đá xanh 3 vòm cuốn)
  void _paintHoCitadelGate(Canvas canvas, double w, double h) {
    final stoneMain = Paint()..color = const Color(0xFF6E7F80);
    final stoneLight = Paint()..color = const Color(0xFF90A4AE);
    final archDark = Paint()..color = const Color(0xFF263238);

    // Khối tường thành đá xanh
    final wall = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.16, h * 0.36, w * 0.68, h * 0.40),
      const Radius.circular(4),
    );
    canvas.drawRRect(wall, stoneMain);
    canvas.drawRect(
      Rect.fromLTWH(w * 0.16, h * 0.36, w * 0.68, h * 0.07),
      stoneLight,
    );

    // 3 cổng vòm cuốn đá ghép
    for (final (cx, archW, archH) in const [
      (0.30, 0.13, 0.18),
      (0.50, 0.17, 0.24),
      (0.70, 0.13, 0.18),
    ]) {
      final left = w * (cx - archW / 2);
      final top = h * (0.76 - archH);
      final p = Path()
        ..moveTo(left, h * 0.76)
        ..lineTo(left, top + h * 0.06)
        ..arcToPoint(
          Offset(left + w * archW, top + h * 0.06),
          radius: Radius.circular(w * archW * 0.5),
        )
        ..lineTo(left + w * archW, h * 0.76)
        ..close();
      canvas.drawPath(p, archDark);
    }
  }

  /// 6. Mô hình Tháp Chăm Mỹ Sơn
  void _paintMySonTower(Canvas canvas, double w, double h) {
    final brick = Paint()..color = const Color(0xFFB84A27);
    final brickDark = Paint()..color = const Color(0xFF8C3216);
    final gold = Paint()..color = const Color(0xFFE0AE45);

    // 3 tầng tháp thu nhỏ dần lên đỉnh
    canvas.drawRect(
      Rect.fromLTWH(w * 0.28, h * 0.46, w * 0.44, h * 0.32),
      brick,
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.33, h * 0.33, w * 0.34, h * 0.14),
      brickDark,
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.39, h * 0.22, w * 0.22, h * 0.12),
      brick,
    );
    // Búp sen vàng đỉnh tháp
    final spire = Path()
      ..moveTo(w * 0.45, h * 0.22)
      ..lineTo(w * 0.50, h * 0.11)
      ..lineTo(w * 0.55, h * 0.22)
      ..close();
    canvas.drawPath(spire, gold);
    // Cửa vòm Kalan
    canvas.drawRect(
      Rect.fromLTWH(w * 0.44, h * 0.56, w * 0.12, h * 0.22),
      Paint()..color = const Color(0xFF3E1C10),
    );
  }

  /// 7. Mô hình Phố cổ Hội An (Nhà cổ tường vàng + đèn lồng)
  void _paintHoiAnHouse(Canvas canvas, double w, double h) {
    // Tường vàng Hội An
    canvas.drawRect(
      Rect.fromLTWH(w * 0.22, h * 0.44, w * 0.56, h * 0.32),
      Paint()..color = const Color(0xFFE8B94F),
    );
    // Mái ngói âm dương nâu trầm
    final roof = Path()
      ..moveTo(w * 0.15, h * 0.46)
      ..lineTo(w * 0.50, h * 0.24)
      ..lineTo(w * 0.85, h * 0.46)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFF5D3A24));
    // Cửa gỗ & 2 đèn lồng đỏ
    canvas.drawRect(
      Rect.fromLTWH(w * 0.42, h * 0.54, w * 0.16, h * 0.22),
      Paint()..color = const Color(0xFF4E2F1D),
    );
    for (final lx in const [0.30, 0.70]) {
      canvas.drawCircle(
        Offset(w * lx, h * 0.52),
        w * 0.045,
        Paint()..color = const Color(0xFFC62828),
      );
    }
  }

  /// 8. Mô hình Chiến thuyền Ngô Quyền (theo chuẩn SVG Historydauviet.id.vn)
  void _paintWarship(Canvas canvas, double w, double h) {
    // Thân thuyền rồng
    final hull = Path()
      ..moveTo(w * 0.14, h * 0.62)
      ..quadraticBezierTo(w * 0.50, h * 0.74, w * 0.88, h * 0.56)
      ..lineTo(w * 0.76, h * 0.76)
      ..quadraticBezierTo(w * 0.46, h * 0.88, w * 0.24, h * 0.74)
      ..close();
    canvas.drawPath(hull, Paint()..color = const Color(0xFF805234));
    // Viền mạn thuyền vàng đồng
    final rim = Path()
      ..moveTo(w * 0.14, h * 0.62)
      ..quadraticBezierTo(w * 0.50, h * 0.72, w * 0.88, h * 0.56);
    canvas.drawPath(
      rim,
      Paint()
        ..color = const Color(0xFFD6AC71)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2,
    );
    // Cột buồm & 2 cánh buồm
    canvas.drawLine(
      Offset(w * 0.49, h * 0.64),
      Offset(w * 0.49, h * 0.16),
      Paint()
        ..color = const Color(0xFF5D3A24)
        ..strokeWidth = 3.0,
    );
    final sailLeft = Path()
      ..moveTo(w * 0.46, h * 0.20)
      ..lineTo(w * 0.22, h * 0.54)
      ..lineTo(w * 0.46, h * 0.52)
      ..close();
    final sailRight = Path()
      ..moveTo(w * 0.52, h * 0.19)
      ..quadraticBezierTo(w * 0.76, h * 0.34, w * 0.78, h * 0.52)
      ..lineTo(w * 0.52, h * 0.55)
      ..close();
    canvas.drawPath(sailLeft, Paint()..color = const Color(0xFFF8E6BB));
    canvas.drawPath(sailRight, Paint()..color = const Color(0xFFB65137));
  }

  /// 9. Mô hình Cuộn Chiếu dời đô / Cổ thư
  void _paintImperialScroll(Canvas canvas, double w, double h) {
    // Tờ chiếu lụa vàng
    final paper = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.24, h * 0.22, w * 0.52, h * 0.52),
      const Radius.circular(6),
    );
    canvas.drawRRect(paper, Paint()..color = const Color(0xFFF9E8C2));
    canvas.drawRRect(
      paper,
      Paint()
        ..color = const Color(0xFFB93430)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
    // Hai trục cuốn đầu ngọc
    for (final y in const [0.22, 0.74]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(w * 0.50, h * y),
            width: w * 0.64,
            height: h * 0.06,
          ),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xFF613B28),
      );
    }
    // Ấn triện chu sa đỏ ở góc
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(w * 0.62, h * 0.58),
        width: w * 0.13,
        height: w * 0.13,
      ),
      Paint()..color = const Color(0xFFB93430),
    );
  }

  /// 10. Mô hình Chòi canh Bạch Đằng (theo chuẩn SVG Historydauviet.id.vn)
  void _paintWatchtower(Canvas canvas, double w, double h) {
    final beam = Paint()
      ..color = const Color(0xFF805234)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.30, h * 0.78), Offset(w * 0.34, h * 0.38), beam);
    canvas.drawLine(Offset(w * 0.70, h * 0.78), Offset(w * 0.66, h * 0.38), beam);
    canvas.drawLine(Offset(w * 0.32, h * 0.70), Offset(w * 0.67, h * 0.45), beam);
    canvas.drawLine(Offset(w * 0.33, h * 0.45), Offset(w * 0.68, h * 0.70), beam);

    // Sàn vọng gác & Mái chòi
    final deck = Path()
      ..moveTo(w * 0.24, h * 0.44)
      ..lineTo(w * 0.50, h * 0.34)
      ..lineTo(w * 0.76, h * 0.44)
      ..lineTo(w * 0.50, h * 0.54)
      ..close();
    canvas.drawPath(deck, Paint()..color = const Color(0xFFBF8C55));

    final roof = Path()
      ..moveTo(w * 0.18, h * 0.30)
      ..lineTo(w * 0.50, h * 0.12)
      ..lineTo(w * 0.82, h * 0.30)
      ..lineTo(w * 0.50, h * 0.40)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFFB25F39));
  }

  /// 11. Huy hiệu kỷ niệm mạ vàng & sơn mài
  void _paintCommemorativeBadge(
    Canvas canvas,
    double w,
    double h, {
    required Color primary,
    required Color accent,
    required String emblem,
  }) {
    // Dải lụa treo huy hiệu
    final ribbon = Path()
      ..moveTo(w * 0.38, h * 0.56)
      ..lineTo(w * 0.32, h * 0.84)
      ..lineTo(w * 0.43, h * 0.77)
      ..lineTo(w * 0.50, h * 0.85)
      ..lineTo(w * 0.57, h * 0.77)
      ..lineTo(w * 0.68, h * 0.84)
      ..lineTo(w * 0.62, h * 0.56)
      ..close();
    canvas.drawPath(ribbon, Paint()..color = primary);

    // Mặt huy chương tròn viền răng cưa vàng
    final center = Offset(w * 0.50, h * 0.42);
    canvas.drawCircle(center, w * 0.27, Paint()..color = accent);
    canvas.drawCircle(center, w * 0.22, Paint()..color = primary);
    canvas.drawCircle(
      center,
      w * 0.19,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Ngôi sao vàng ở giữa huy chương
    final star = Path();
    for (int i = 0; i < 10; i++) {
      final a = -math.pi / 2 + (i * math.pi / 5);
      final r = i.isEven ? w * 0.12 : w * 0.05;
      final pt = Offset(center.dx + r * math.cos(a), center.dy + r * math.sin(a));
      if (i == 0) {
        star.moveTo(pt.dx, pt.dy);
      } else {
        star.lineTo(pt.dx, pt.dy);
      }
    }
    star.close();
    canvas.drawPath(star, Paint()..color = const Color(0xFFFFF59D));
  }

  void _paintStatue(Canvas canvas, double w, double h) {
    canvas.drawRect(
      Rect.fromLTWH(w * 0.36, h * 0.58, w * 0.28, h * 0.22),
      Paint()..color = const Color(0xFF8D6E63),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.41, h * 0.26, w * 0.18, h * 0.32),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFFD4AF37),
    );
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.20),
      w * 0.07,
      Paint()..color = const Color(0xFFD4AF37),
    );
  }

  void _paintFlagpole(Canvas canvas, double w, double h) {
    canvas.drawLine(
      Offset(w * 0.45, h * 0.78),
      Offset(w * 0.45, h * 0.14),
      Paint()
        ..color = const Color(0xFF6D4C41)
        ..strokeWidth = 3.5,
    );
    final flag = Path()
      ..moveTo(w * 0.47, h * 0.16)
      ..quadraticBezierTo(w * 0.66, h * 0.10, w * 0.84, h * 0.20)
      ..lineTo(w * 0.76, h * 0.32)
      ..lineTo(w * 0.84, h * 0.42)
      ..quadraticBezierTo(w * 0.66, h * 0.34, w * 0.47, h * 0.42)
      ..close();
    canvas.drawPath(flag, Paint()..color = const Color(0xFFB93430));
  }

  @override
  bool shouldRepaint(covariant _HeritageArtifact25DPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.showPedestal != showPedestal;
}
