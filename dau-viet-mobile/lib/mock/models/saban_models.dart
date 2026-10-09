/// Các giai đoạn chu kỳ thủy triều trên Sa Bàn Chiến Thuật Bạch Đằng (M-06)
enum TidePhase {
  risingTide,   // Giờ Tỵ: Triều dâng cao ngập cọc - Nhử địch
  peakTide,     // Giờ Ngọ: Đỉnh triều & Bắt đầu rút xiết - Phản công
  ebbingTide,   // Giờ Mùi: Triều rút cạn lộ bãi cọc - Toàn thắng
}

/// Chốt điểm chiến thuật trên Sa Bàn
class SabanMarkerModel {
  final String id;
  final String title;
  final String description;
  final double xPercent; // Tọa độ tương đối 0.0 -> 1.0
  final double yPercent; // Tọa độ tương đối 0.0 -> 1.0
  final String markerType; // 'stake_field' | 'ambush' | 'enemy' | 'command'

  const SabanMarkerModel({
    required this.id,
    required this.title,
    required this.description,
    required this.xPercent,
    required this.yPercent,
    required this.markerType,
  });
}

/// Dữ liệu từng nhịp thời gian của trận đánh
class SabanPhaseModel {
  final TidePhase phase;
  final String timeLabel;       // e.g. "Giờ Tỵ (09:00 - 11:00)"
  final String tideStatus;      // e.g. "Thủy triều dâng cao ngập bãi cọc"
  final String tacticalAction;  // e.g. "Kế sách: Thuyền nhẹ khiêu chiến & Giả rút"
  final String description;
  final double waterLevelPercent; // Mực nước: 0.3 (cạn) -> 0.9 (cao)
  final List<SabanMarkerModel> activeMarkers;

  const SabanPhaseModel({
    required this.phase,
    required this.timeLabel,
    required this.tideStatus,
    required this.tacticalAction,
    required this.description,
    required this.waterLevelPercent,
    required this.activeMarkers,
  });
}
