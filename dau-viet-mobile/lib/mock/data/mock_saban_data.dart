import '../models/saban_models.dart';

/// Dữ liệu mẫu Sa Bàn Thủy Chiến Sông Bạch Đằng 938 (M-06)
class MockSabanData {
  MockSabanData._();

  static const List<SabanPhaseModel> phases = [
    SabanPhaseModel(
      phase: TidePhase.risingTide,
      timeLabel: 'Giờ Tỵ (09:00 - 11:00)',
      tideStatus: 'Thủy triều dâng ngập hoàn toàn bãi cọc',
      tacticalAction: 'Khiêu chiến & Nhử địch vượt qua bãi cọc',
      description: 'Lúc nước triều dâng cuồn cuộn, bãi cọc gỗ lim bị ngập sâu dưới lòng sông. Ngô Quyền sai các toán thuyền nhẹ ra khiêu chiến với hạm đội của Lưu Hoằng Tháo rồi giả vờ thua chạy. Hoằng Tháo trúng kế đắc thắng xua thuyền lớn đuổi theo vào sâu trong sông Bạch Đằng.',
      waterLevelPercent: 0.9,
      activeMarkers: [
        SabanMarkerModel(
          id: 'mk_enemy_1',
          title: 'Hạm đội Nam Hán (Hoằng Tháo)',
          description: 'Hàng trăm chiến thuyền lớn cồng kềnh vượt qua cửa biển tiến sâu vào bẫy mai phục.',
          xPercent: 0.35,
          yPercent: 0.70,
          markerType: 'enemy',
        ),
        SabanMarkerModel(
          id: 'mk_lure_1',
          title: 'Đội thuyền nhẹ ta nhử địch',
          description: 'Thuyền chiến nhỏ cơ động vừa đánh vừa rút, dẫn dụ giặc vượt qua bãi cọc lúc nước ngập.',
          xPercent: 0.45,
          yPercent: 0.45,
          markerType: 'command',
        ),
        SabanMarkerModel(
          id: 'mk_stake_1',
          title: 'Bãi cọc ngầm Yên Giang',
          description: 'Hàng ngàn cọc gỗ lim bịt sắt chìm sâu dưới mặt nước triều dâng, sẵn sàng chờ địch.',
          xPercent: 0.55,
          yPercent: 0.60,
          markerType: 'stake_field',
        ),
      ],
    ),
    SabanPhaseModel(
      phase: TidePhase.peakTide,
      timeLabel: 'Giờ Ngọ (11:00 - 13:00)',
      tideStatus: 'Đỉnh triều chuyển dòng, nước bắt đầu rút xiết',
      tacticalAction: 'Quay đầu đánh quật lại, phục binh ập tới',
      description: 'Khi nước triều bắt đầu rút mạnh xuôi ra biển, Ngô Quyền hạ lệnh tổng phản công. Đội thuyền chủ lực của ta quay mũi đánh rát, đồng thời phục binh hai bên bờ sông từ rừng sú vẹt hò reo xông ra giáp công dữ dội. Quân Nam Hán hoảng loạn quay đầu tháo chạy.',
      waterLevelPercent: 0.55,
      activeMarkers: [
        SabanMarkerModel(
          id: 'mk_ambush_left',
          title: 'Phục binh tả ngạn (Dương Tam Kha)',
          description: 'Thuyền mai phục từ các nhánh sông đổ ra bịt chặt đường rút lui của địch.',
          xPercent: 0.25,
          yPercent: 0.40,
          markerType: 'ambush',
        ),
        SabanMarkerModel(
          id: 'mk_command_ngo',
          title: 'Tiền Ngô Vương phản công',
          description: 'Đội hình chiến thuyền chủ lực quay lại đánh quật quyết liệt.',
          xPercent: 0.50,
          yPercent: 0.35,
          markerType: 'command',
        ),
        SabanMarkerModel(
          id: 'mk_enemy_panicked',
          title: 'Hạm đội địch rối loạn',
          description: 'Quân giặc trở tay không kịp, giẫm đạp lên nhau tìm đường tháo lui ra cửa biển.',
          xPercent: 0.45,
          yPercent: 0.55,
          markerType: 'enemy',
        ),
      ],
    ),
    SabanPhaseModel(
      phase: TidePhase.ebbingTide,
      timeLabel: 'Giờ Mùi (13:00 - 15:00)',
      tideStatus: 'Triều rút cạn, cọc gỗ nhô lên tua tủa',
      tacticalAction: 'Thuyền giặc vỡ đắm, toàn thắng vang dội',
      description: 'Nước triều rút cạn để lộ hàng ngàn cọc gỗ lim bịt sắt nhọn hoắt. Thuyền lớn cồng kềnh của giặc bị dòng nước xiết đẩy dồn vào bãi cọc, đâm thủng đáy, vỡ tan và lật úp. Tướng giặc Lưu Hoằng Tháo bị trúng tên tử trận. Quân ta đại thắng rực rỡ!',
      waterLevelPercent: 0.25,
      activeMarkers: [
        SabanMarkerModel(
          id: 'mk_stake_exposed',
          title: 'Bãi cọc vát nhọn nhô lên',
          description: 'Cọc gỗ lim cắm xuôi dòng triều cắm phập vào lườn thuyền giặc đang tháo chạy.',
          xPercent: 0.52,
          yPercent: 0.62,
          markerType: 'stake_field',
        ),
        SabanMarkerModel(
          id: 'mk_enemy_destroyed',
          title: 'Lưu Hoằng Tháo đền tội',
          description: 'Thuyền soái hạm bị vỡ nát, Hoằng Tháo tử trận, quân Nam Hán thiệt hại quá nửa.',
          xPercent: 0.40,
          yPercent: 0.65,
          markerType: 'enemy',
        ),
        SabanMarkerModel(
          id: 'mk_victory',
          title: 'Đại thắng Sông Bạch Đằng',
          description: 'Khải hoàn ca vang dội cửa biển, chấm dứt 1.000 năm Bắc thuộc.',
          xPercent: 0.65,
          yPercent: 0.30,
          markerType: 'command',
        ),
      ],
    ),
  ];
}
