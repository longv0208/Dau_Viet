import '../historical_animation_definition.dart';
import '../scenes/river_scene.dart';

/// ANIM-01 + POLISH-BD-01 — Scene "Trận Bạch Đằng 938": cơ chế bãi cọc
/// ngầm + thủy triều + dụ địch + phản công phối hợp. Nội dung lịch sử
/// tham chiếu bài viết của Bảo tàng Lịch sử Quốc gia "Ngô Quyền và
/// chiến thắng Bạch Đằng năm 938" (hỗ trợ khung sự kiện rộng — KHÔNG
/// khẳng định mực nước, bố trí cọc, vị trí, số lượng thuyền hay lộ
/// trình cụ thể). Thuyền dụ địch và hướng phản công là SƠ ĐỒ CHIẾN
/// THUẬT minh họa ý tưởng, không phải phục dựng đường đi.
final HistoricalAnimationDefinition bachDang938TideV1 =
    HistoricalAnimationDefinition(
      key: 'bach_dang_938_tide_v1',
      title: 'Trận Bạch Đằng năm 938',
      learningObjective:
          'Hiểu mối liên hệ giữa bãi cọc được chuẩn bị trước, thủy triều, '
          'việc dụ thuyền địch và thời điểm phản công phối hợp trong '
          'chiến thắng Bạch Đằng.',
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
          label: 'Dụ địch vào bãi',
          narration:
              'Sử liệu ghi nhận quân ta đã lợi dụng lúc nước lớn dụ hoặc '
              'dẫn thuyền địch vào vùng bãi cọc. Trên sơ đồ, thuyền xanh '
              'lục (phòng thủ) đi trước dẫn hướng đoàn địch tiến vào — '
              'đây là chỉ báo sơ đồ chiến thuật, không phải lộ trình cụ '
              'thể được ghi lại.',
          hint:
              'Thuyền dụ địch (buồm xanh lục) và vệt đường dẫn nét đứt '
              'đi trước đoàn địch về phía bãi cọc.',
          target: RiverSceneState(
            waterLevel: 0.90,
            boatProgress: 0.72,
            boatsObstructed: false,
            decoyProgress: 1,
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
            decoyProgress: 1,
          ),
        ),
        HistoricalAnimationStep(
          label: 'Phản công phối hợp',
          narration:
              'Thuyền địch vướng vào bãi cọc, khó di chuyển. Sử liệu ghi '
              'nhận quân ta đã đánh úp, phối hợp phản công đúng lúc triều '
              'hạ. Trên sơ đồ, thuyền phòng thủ (buồm xanh lục) tiến vào '
              'từ phía sau cùng mũi tên phối hợp hướng về bãi — minh họa '
              'hướng tác chiến, không phải đội hình hay vị trí thật.',
          hint:
              'Thuyền địch mắc cọc + thuyền xanh lục tiến vào từ mép '
              'trái + mũi tên phối hợp cùng hướng.',
          target: RiverSceneState(
            waterLevel: 0.28,
            boatProgress: 0.85,
            boatsObstructed: true,
            decoyProgress: 1,
            counterattackProgress: 1,
          ),
        ),
        HistoricalAnimationStep(
          label: 'Tổng kết',
          narration:
              'Chiến thắng đến từ một chuỗi chủ động: chuẩn bị bãi cọc → '
              'tính toán nhịp thủy triều → dụ thuyền địch vào đúng lúc '
              'nước lớn → vật cản khống chế → phản công phối hợp khi '
              'triều rút. Cơ chế vật lý chỉ là một phần của mưu lược — '
              'sơ đồ bên trên tóm tắt lại trình tự đó.',
          hint:
              'Sơ đồ chuỗi 5 giai đoạn: đây là kết luận, không phải '
              'một cảnh hành động mới.',
          target: RiverSceneState(
            waterLevel: 0.28,
            boatProgress: 0.85,
            boatsObstructed: true,
            decoyProgress: 1,
            counterattackProgress: 1,
            showSequenceSummary: true,
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
        // Checkpoint ở bước "Dụ địch vào bãi" (index 2) — ngay trước
        // "Nước rút": dự đoán trước khi xem cọc lộ. Giữ parity hiển thị
        // cũ (khối luôn hiện) nhưng AUTO giờ dừng chờ learner tại đây.
        stepIndex: 2,
      ),
    );
