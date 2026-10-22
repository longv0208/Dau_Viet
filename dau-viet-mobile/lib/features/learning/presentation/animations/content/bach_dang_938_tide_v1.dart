import '../historical_animation_definition.dart';
import '../scenes/river_scene.dart';

/// ANIM-01 — Scene "Trận Bạch Đằng 938": cơ chế bãi cọc ngầm + thủy
/// triều. Nội dung lịch sử tham chiếu bài viết của Bảo tàng Lịch sử
/// Quốc gia "Ngô Quyền và chiến thắng Bạch Đằng năm 938" (hỗ trợ khung
/// sự kiện rộng — KHÔNG khẳng định mực nước, bố trí cọc, vị trí hay
/// thời điểm cụ thể). Sơ đồ minh họa chiến thuật, không theo tỉ lệ.
final HistoricalAnimationDefinition bachDang938TideV1 =
    HistoricalAnimationDefinition(
      key: 'bach_dang_938_tide_v1',
      title: 'Trận Bạch Đằng năm 938',
      learningObjective:
          'Hiểu mối liên hệ giữa bãi cọc được chuẩn bị trước, thủy triều '
          'và thời điểm phản công trong chiến thắng Bạch Đằng.',
      disclaimer:
          'Sơ đồ minh họa chiến thuật, không theo tỉ lệ và không phải '
          'phục dựng chính xác trận đánh.',
      sourceReference:
          'Bảo tàng Lịch sử Quốc gia — "Ngô Quyền và chiến thắng Bạch Đằng '
          'năm 938" (baotanglichsuquocgia.vn).',
      hasWaterControl: true,
      transitionDuration: const Duration(milliseconds: 1100),
      createPainter: RiverScenePainter.new,
      steps: const [
        HistoricalAnimationStep(
          label: 'Chuẩn bị',
          narration:
              'Trước trận đánh, quân ta đã đóng sẵn một bãi cọc gỗ ngầm '
              'dưới lòng sông. Sơ đồ chỉ vẽ cọc mang tính minh họa — '
              'sử liệu không ghi bố trí chính xác từng cọc.',
          hint: 'Quan sát vị trí các cọc nhô lên từ đáy sông.',
          target: RiverSceneState(
            waterLevel: 0.30,
            boatProgress: 0.0,
            boatsObstructed: false,
          ),
        ),
        HistoricalAnimationStep(
          label: 'Nước dâng',
          narration:
              'Khi thủy triều dâng, mặt nước cao dần và che khuất đỉnh '
              'cọc. Từ trên thuyền nhìn xuống, khó nhận ra chướng ngại '
              'vật đang ẩn phía dưới.',
          hint: 'Kéo thanh mực nước để tự thấy cọc bị che đi.',
          target: RiverSceneState(
            waterLevel: 0.90,
            boatProgress: 0.0,
            boatsObstructed: false,
          ),
        ),
        HistoricalAnimationStep(
          label: 'Thuyền địch vào sông',
          narration:
              'Lợi dụng lúc nước lớn, thuyền địch tiến vào khu vực bãi cọc '
              'mà không gặp trở ngại. Sơ đồ chỉ mô tả hướng di chuyển — '
              'không khẳng định đội hình hay số lượng thuyền thật.',
          hint: 'Mực nước cao → cọc vẫn chìm, thuyền đi qua được.',
          target: RiverSceneState(
            waterLevel: 0.90,
            boatProgress: 0.85,
            boatsObstructed: false,
          ),
        ),
        HistoricalAnimationStep(
          label: 'Nước rút',
          narration:
              'Khi triều rút, mực nước hạ dần và những đỉnh cọc lộ ra. '
              'Đường đi của thuyền bỗng trở nên nguy hiểm.',
          hint: 'Thử kéo mực nước xuống thấp để thấy cọc lộ rõ.',
          target: RiverSceneState(
            waterLevel: 0.28,
            boatProgress: 0.85,
            boatsObstructed: false,
          ),
        ),
        HistoricalAnimationStep(
          label: 'Thuyền mắc cọc',
          narration:
              'Thuyền địch vướng vào bãi cọc, khó di chuyển — đây chỉ là '
              'khoảnh khắc then chốt của cơ mưu: quân phòng thủ đã chọn '
              'đúng thời điểm triều hạ để đánh úp, chứ không phải chỉ '
              'nhờ triều tự nhiên quyết định trận thắng.',
          hint: 'Cọc lộ + thuyền đã vào sâu → không thể quay đầu dễ dàng.',
          target: RiverSceneState(
            waterLevel: 0.28,
            boatProgress: 0.85,
            boatsObstructed: true,
          ),
        ),
        HistoricalAnimationStep(
          label: 'Chiến thuật',
          narration:
              'Chiến thắng đến từ sự kết hợp: bãi cọc chuẩn bị trước + '
              'tính toán nhịp thủy triều + dụ thuyền địch vào đúng lúc '
              'nước lớn + phản công phối hợp khi triều rút. Cơ chế vật '
              'lý chỉ là một phần của mưu lược.',
          hint:
              'Có thể tua lại các bước hoặc tự kéo mực nước để kiểm '
              'chứng lại cơ chế.',
          target: RiverSceneState(
            waterLevel: 0.28,
            boatProgress: 0.85,
            boatsObstructed: true,
          ),
        ),
      ],
      prediction: const AnimationPrediction(
        question:
            'Khi nước triều rút xuống, điều gì thay đổi đối với thuyền '
            'tiến vào khu vực bãi cọc?',
        options: [
          'Các cọc vẫn chìm sâu và không ảnh hưởng đến đường đi.',
          'Các cọc dần lộ ra, khiến thuyền khó di chuyển.',
        ],
        explainedOptionIndex: 1,
        explanation:
            'Khi mực nước hạ, đỉnh cọc nhô lên khỏi mặt sông. Thuyền đã '
            'tiến vào vùng bãi cọc lúc nước lớn sẽ vướng phải chướng '
            'ngại vật này — chính là cơ chế khiến đội hình địch bị khống '
            'chế để phản công.',
        retryHint:
            'Thử kéo mực nước xuống thấp rồi quan sát: phần cọc nào '
            'còn chìm, phần nào đã lộ? Thuyền nổi trên mặt nước sẽ '
            'chạm vào đâu?',
        revealSceneEffect: RiverSceneState(
          waterLevel: 0.22,
          boatProgress: 0.85,
          boatsObstructed: true,
          highlightStakes: true,
        ),
      ),
    );
