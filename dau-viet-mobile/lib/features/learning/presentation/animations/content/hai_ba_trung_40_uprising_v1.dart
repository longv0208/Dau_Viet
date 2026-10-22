import 'package:flutter/material.dart';

import '../historical_animation_definition.dart';
import '../scenes/historical_map_scene.dart';

/// ANIM-02 — Scene "Khởi nghĩa Hai Bà Trưng năm 40": bản đồ schematic
/// vùng Hát Môn – Mê Linh – Luy Lâu. Nội dung tham chiếu bài viết của
/// Bảo tàng Lịch sử Quốc gia "Cuộc khởi nghĩa Hai Bà Trưng (năm 40–43
/// sau Công nguyên)". Tuyến nối là SƠ ĐỒ minh họa quan hệ các địa điểm,
/// không khẳng định đường hành quân hay tọa độ thật.
final haiBaTrung40UprisingV1 = HistoricalAnimationDefinition(
  key: 'hai_ba_trung_40_uprising_v1',
  title: 'Khởi nghĩa Hai Bà Trưng năm 40',
  learningObjective:
      'Nhận biết các địa điểm then chốt của cuộc khởi nghĩa năm 40 và '
      'hiểu vai trò của Luy Lâu như trung tâm cai trị của nhà Hán.',
  disclaimer:
      'Bản đồ minh họa schematic, không theo tỉ lệ, không phải bản đồ '
      'địa lý hay phục dựng chính xác đường đi.',
  sourceReference:
      'Bảo tàng Lịch sử Quốc gia — "Cuộc khởi nghĩa Hai Bà Trưng '
      '(năm 40–43 sau Công nguyên)" (baotanglichsuquocgia.vn).',
  hasLocationExplorer: true,
  transitionDuration: const Duration(milliseconds: 1100),
  createPainter: () => MapScenePainter(
    locations: const [
      MapLocation(
        id: 'hat_mon',
        name: 'Hát Môn',
        position: Offset(0.30, 0.62),
        description:
            'Khu vực sông Hát / Hát Môn — nơi cuộc khởi nghĩa bắt đầu '
            'năm 40 theo truyền thống lịch sử được ghi nhận rộng rãi.',
        contextLabel: 'Nơi phát khởi',
      ),
      MapLocation(
        id: 'me_linh',
        name: 'Mê Linh',
        position: Offset(0.48, 0.42),
        description:
            'Vùng Mê Linh — quê hương và nơi quy tụ lực lượng, người dân '
            'các vùng lân cận hưởng ứng cuộc khởi nghĩa.',
        contextLabel: 'Nơi quy tụ',
      ),
      MapLocation(
        id: 'luy_lau',
        name: 'Luy Lâu',
        position: Offset(0.72, 0.34),
        description:
            'Luy Lâu — trung tâm hành chính của nhà Đông Hán ở Giao Chỉ, '
            'đại diện cho bộ máy cai trị mà cuộc khởi nghĩa hướng tới.',
        contextLabel: 'Trung tâm Hán',
      ),
    ],
    routes: const [
      MapRoute(
        id: 'gather',
        fromId: 'hat_mon',
        toId: 'me_linh',
        via: [Offset(0.40, 0.55)],
        explanation:
            'Từ điểm phát khởi, lực lượng và người dân quy tụ về Mê '
            'Linh — sơ đồ minh họa, không phải đường đi cụ thể.',
      ),
      MapRoute(
        id: 'advance',
        fromId: 'me_linh',
        toId: 'luy_lau',
        via: [Offset(0.60, 0.40)],
        explanation:
            'Cuộc khởi nghĩa hướng về Luy Lâu, trung tâm cai trị của '
            'nhà Hán — tuyến chỉ mang tính minh họa hướng phát triển.',
      ),
    ],
  ),
  steps: const [
    HistoricalAnimationStep(
      label: 'Bối cảnh',
      narration:
          'Đầu thế kỷ I sau Công nguyên, vùng đồng bằng Bắc Bộ chịu sự '
          'cai trị của nhà Đông Hán. Sơ đồ chỉ gợi ý một số địa điểm '
          'tiêu biểu — không phải bản đồ hành chính của thời kỳ đó.',
      hint: 'Quan sát sơ đồ khu vực rồi tiếp tục.',
      target: MapSceneState(markerVisibility: {}),
    ),
    HistoricalAnimationStep(
      label: 'Khởi nghĩa bùng lên',
      narration:
          'Năm 40, cuộc khởi nghĩa do Hai Bà Trưng khởi xướng bắt đầu ở '
          'khu vực sông Hát / Hát Môn. Sử liệu không ghi lại vị trí '
          'chính xác từng điểm — đây chỉ là minh họa vùng.',
      hint: 'Địa điểm sáng lên là nơi khởi nghĩa bắt đầu.',
      target: MapSceneState(
        markerVisibility: {'hat_mon': 1},
        focusedId: 'hat_mon',
      ),
    ),
    HistoricalAnimationStep(
      label: 'Quy tụ lực lượng',
      narration:
          'Từ điểm phát khởi, lực lượng và người dân các nơi quy tụ về '
          'Mê Linh — quê hương của Hai Bà Trưng. Tuyến nối trên sơ đồ '
          'là minh họa sự lan rộng, không khẳng định đường đi thật.',
      hint: 'Tuyến nét đứt chỉ mang tính sơ đồ hóa quan hệ giữa hai vùng.',
      target: MapSceneState(
        markerVisibility: {'hat_mon': 1, 'me_linh': 1},
        routeProgress: {'gather': 1},
        focusedId: 'me_linh',
      ),
    ),
    HistoricalAnimationStep(
      label: 'Hướng về Luy Lâu',
      narration:
          'Cuộc khởi nghĩa lan rộng và hướng tới Luy Lâu — trung tâm '
          'hành chính của nhà Đông Hán ở Giao Chỉ, nơi đặt bộ máy cai '
          'trị của Tô Định.',
      hint: 'Vì sao Luy Lâu lại là điểm quan trọng?',
      target: MapSceneState(
        markerVisibility: {'hat_mon': 1, 'me_linh': 1, 'luy_lau': 1},
        routeProgress: {'gather': 1, 'advance': 1},
        highlighted: {'luy_lau'},
        focusedId: 'luy_lau',
      ),
    ),
    HistoricalAnimationStep(
      label: 'Khám phá bản đồ',
      narration:
          'Chạm vào từng địa điểm để đọc ý nghĩa lịch sử của nó. Mỗi '
          'địa điểm là một mảnh của bức tranh khởi nghĩa: nơi phát khởi, '
          'nơi quy tụ và mục tiêu chính trị.',
      hint: 'Thử chạm vào Hát Môn, Mê Linh và Luy Lâu.',
      target: MapSceneState(
        markerVisibility: {'hat_mon': 1, 'me_linh': 1, 'luy_lau': 1},
        routeProgress: {'gather': 1, 'advance': 1},
      ),
    ),
    HistoricalAnimationStep(
      label: 'Ý nghĩa',
      narration:
          'Cuộc khởi nghĩa năm 40 thể hiện tinh thần độc lập mạnh mẽ và '
          'trực tiếp thách thức bộ máy cai trị của nhà Hán tại Luy Lâu. '
          'Tuy nhiên, đây mới là giai đoạn đầu — cuộc đấu tranh còn '
          'kéo dài và chưa mang lại độc lập lâu dài ngay lúc đó.',
      hint: 'Có thể tua lại các bước hoặc chạm địa điểm để xem lại.',
      target: MapSceneState(
        markerVisibility: {'hat_mon': 1, 'me_linh': 1, 'luy_lau': 1},
        routeProgress: {'gather': 1, 'advance': 1},
        highlighted: {'luy_lau'},
      ),
    ),
  ],
  prediction: const AnimationPrediction(
    question:
        'Tại sao Luy Lâu là một địa điểm quan trọng trong diễn biến '
        'khởi nghĩa?',
    options: [
      'Vì đây là nơi cuộc khởi nghĩa bắt đầu năm 40.',
      'Vì đây là trung tâm hành chính của nhà Hán ở Giao Chỉ, đại diện '
          'cho bộ máy cai trị mà cuộc khởi nghĩa hướng tới.',
    ],
    explainedOptionIndex: 1,
    explanation:
        'Luy Lâu là trung tâm hành chính của nhà Đông Hán tại Giao Chỉ. '
        'Việc cuộc khởi nghĩa hướng về Luy Lâu cho thấy sức lan tỏa của '
        'phong trào và thách thức trực tiếp đến bộ máy cai trị — chứ '
        'không chỉ là một cuộc nổi dậy cục bộ.',
    retryHint:
        'Nhìn lại sơ đồ: Hát Môn mới là nơi phát khởi. Luy Lâu đóng vai '
        'trò khác trong thể chế cai trị — thử suy nghĩ về vai trò đó.',
    revealSceneEffect: MapSceneState(
      markerVisibility: {'hat_mon': 1, 'me_linh': 1, 'luy_lau': 1},
      routeProgress: {'gather': 1, 'advance': 1},
      highlighted: {'luy_lau'},
      focusedId: 'luy_lau',
    ),
  ),
);
