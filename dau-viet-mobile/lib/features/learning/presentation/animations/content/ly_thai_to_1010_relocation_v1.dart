import 'package:flutter/material.dart';

import '../historical_animation_definition.dart';
import '../scenes/historical_map_scene.dart';

/// ANIM-02 — Scene "Lý Thái Tổ dời đô năm 1010": từ Hoa Lư về Đại La
/// (kinh đô mới mang tên Thăng Long). Nội dung tham chiếu các bài viết
/// của Bảo tàng Lịch sử Quốc gia "Thăng Long thời nhà Lý (1009–1225)"
/// và "Hà Nội — địa linh nhân kiệt". Tuyến nối là sơ đồ khái niệm, không
/// khẳng định đường thủy hay hành trình cụ thể.
final lyThaiTo1010RelocationV1 = HistoricalAnimationDefinition(
  key: 'ly_thai_to_1010_relocation_v1',
  title: 'Lý Thái Tổ dời đô năm 1010',
  learningObjective:
      'Hiểu vì sao Lý Thái Tổ chọn Đại La làm kinh đô mới và ý nghĩa '
      'lâu dài của quyết định dời đô năm 1010.',
  disclaimer:
      'Bản đồ minh họa schematic, không theo tỉ lệ, không phải bản đồ '
      'địa lý hay đường đi thực tế của triều đình.',
  sourceReference:
      'Bảo tàng Lịch sử Quốc gia — "Thăng Long thời nhà Lý (1009–1225)" '
      'và "Hà Nội — địa linh nhân kiệt" (baotanglichsuquocgia.vn).',
  hasLocationExplorer: true,
  transitionDuration: const Duration(milliseconds: 1100),
  createPainter: () => MapScenePainter(
    locations: const [
      MapLocation(
        id: 'hoa_lu',
        name: 'Hoa Lư',
        position: Offset(0.28, 0.70),
        description:
            'Hoa Lư — kinh đô của các triều Đinh và Tiền Lê, kinh đô cũ '
            'trước khi triều Lý quyết định dời đô năm 1010.',
        contextLabel: 'Kinh đô cũ',
      ),
      MapLocation(
        id: 'dai_la',
        name: 'Đại La — Thăng Long',
        position: Offset(0.62, 0.40),
        description:
            'Thành Đại La — nơi Lý Thái Tổ chọn làm kinh đô mới năm '
            '1010, sau đổi tên thành Thăng Long. Đại La và Thăng Long '
            'là CÙNG một địa điểm, không phải hai thành khác nhau.',
        contextLabel: 'Kinh đô mới',
      ),
    ],
    routes: const [
      MapRoute(
        id: 'relocation',
        fromId: 'hoa_lu',
        toId: 'dai_la',
        via: [Offset(0.45, 0.58)],
        explanation:
            'Dời kinh đô từ Hoa Lư về Đại La — tuyến minh họa khái '
            'niệm, không phải đường đi hay đường thủy thật.',
      ),
    ],
  ),
  steps: const [
    HistoricalAnimationStep(
      label: 'Hoa Lư — kinh đô cũ',
      narration:
          'Hoa Lư từng là kinh đô của các triều Đinh và Tiền Lê — '
          'trung tâm chính trị trước khi nhà Lý lên ngôi. Địa thế núi '
          'non hiểm trở phù hợp phòng thủ nhưng hạn chế cho phát triển '
          'lâu dài.',
      hint: 'Địa điểm sáng lên là kinh đô cũ.',
      target: MapSceneState(
        markerVisibility: {'hoa_lu': 1},
        focusedId: 'hoa_lu',
      ),
    ),
    HistoricalAnimationStep(
      label: 'Cân nhắc dời đô',
      narration:
          'Sau khi lên ngôi, Lý Thái Tổ và triều thần cân nhắc vị trí '
          'kinh đô. Theo tư liệu truyền thống, việc chọn địa điểm mới '
          'gắn với cân nhắc về địa thế và hướng phát triển lâu dài của '
          'đất nước — sử liệu không ghi đầy đủ mọi lý do cụ thể.',
      hint: 'Vì sao một kinh đô mới lại được cân nhắc?',
      target: MapSceneState(markerVisibility: {'hoa_lu': 1}),
    ),
    HistoricalAnimationStep(
      label: 'Đại La được chọn',
      narration:
          'Năm 1010, Lý Thái Tổ chọn vùng thành Đại La làm kinh đô mới. '
          'Vị trí trung tâm vùng đồng bằng, thuận lợi giao thông và '
          'phát triển — theo cách hiểu được ghi nhận trong tư liệu.',
      hint: 'Địa điểm mới xuất hiện là kinh đô được chọn.',
      target: MapSceneState(
        markerVisibility: {'hoa_lu': 1, 'dai_la': 1},
        focusedId: 'dai_la',
      ),
    ),
    HistoricalAnimationStep(
      label: 'Dời đô năm 1010',
      narration:
          'Quyết định dời đô từ Hoa Lư về Đại La được thực hiện năm '
          '1010. Tuyến nối trên sơ đồ chỉ minh họa quan hệ giữa hai '
          'địa điểm — không phải đường đi hay hành trình cụ thể của '
          'triều đình.',
      hint: 'Tuyến đứt nét là sơ đồ khái niệm, không phải đường thật.',
      target: MapSceneState(
        markerVisibility: {'hoa_lu': 1, 'dai_la': 1},
        routeProgress: {'relocation': 1},
        focusedId: 'dai_la',
      ),
    ),
    HistoricalAnimationStep(
      label: 'Thăng Long',
      narration:
          'Kinh đô mới ở Đại La được đặt tên Thăng Long — "rồng bay '
          'lên". Quyết định năm 1010 đặt nền móng cho một trung tâm '
          'chính trị lâu dài, gắn với Hà Nội ngày nay.',
      hint: 'Chạm vào từng địa điểm để đọc vai trò của nó.',
      target: MapSceneState(
        markerVisibility: {'hoa_lu': 1, 'dai_la': 1},
        routeProgress: {'relocation': 1},
        highlighted: {'dai_la'},
      ),
    ),
  ],
  prediction: const AnimationPrediction(
    question: 'Địa điểm nào được Lý Thái Tổ lựa chọn làm kinh đô mới?',
    options: [
      'Hoa Lư — kinh đô cũ được giữ nguyên.',
      'Đại La — sau này mang tên Thăng Long.',
    ],
    explainedOptionIndex: 1,
    explanation:
        'Năm 1010, Lý Thái Tổ chọn thành Đại La làm kinh đô mới và đổi '
        'tên thành Thăng Long. Đại La và Thăng Long là cùng một địa '
        'điểm — quyết định này gắn với cân nhắc địa thế trung tâm và '
        'tầm phát triển lâu dài.',
    retryHint:
        'Hoa Lư là kinh đô CŨ. Hãy xem lại sơ đồ: địa điểm nào vừa '
        'xuất hiện ở bước "Đại La được chọn"?',
    revealSceneEffect: MapSceneState(
      markerVisibility: {'hoa_lu': 1, 'dai_la': 1},
      routeProgress: {'relocation': 1},
      highlighted: {'dai_la'},
      focusedId: 'dai_la',
    ),
    // Checkpoint ở bước "Dời đô năm 1010" (index 3) — sau khi Đại La đã
    // xuất hiện: dự đoán điểm được chọn trước kết luận Thăng Long.
    stepIndex: 3,
  ),
);
