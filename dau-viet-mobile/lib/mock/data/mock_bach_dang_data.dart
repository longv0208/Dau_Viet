import '../models/lesson_models.dart';

/// Dữ liệu mẫu hoàn chỉnh cho Sự kiện Đại Chiến Bạch Đằng 938
/// Phục vụ chế độ Demo kiểm thử giao diện Mobile trước khi cắm Backend
class MockBachDangData {
  MockBachDangData._();

  static const HistoricalEventModel event = HistoricalEventModel(
    id: 'evt_bach_dang_938',
    title: 'Đại Chiến Bạch Đằng 938',
    era: 'Thời Tiền Ngô',
    year: 938,
    heroBannerUrl: 'assets/images/dv_EVT_ngoquyen_bachdang_hero_v01.jpg',
    summary:
        'Trận thủy chiến kinh điển chấm dứt hơn 1000 năm Bắc thuộc, mở ra kỷ nguyên độc lập tự chủ lâu dài cho dân tộc Việt Nam dưới sự lãnh đạo tài tình của Tiền Ngô Vương Ngô Quyền.',
    lessonIds: ['les_bach_dang_ep2'],
  );

  static const EvidenceRefModel evidenceYenGiang = EvidenceRefModel(
    id: 'evi_yen_giang',
    title: 'Di chỉ Bãi cọc Yên Giang (Quảng Ninh)',
    category: 'Khảo cổ thực địa',
    citation:
        'Cọc gỗ lim đường kính 20-30cm, cắm nghiêng 15-45 độ xuôi theo dòng triều, đầu vát nhọn bịt sắt.',
    reliabilityRating: 5.0,
    dating: 'Niên đại C-14 Thế kỷ X',
  );

  static const EvidenceRefModel evidenceToanThu = EvidenceRefModel(
    id: 'evi_toan_thu',
    title: 'Đại Việt Sử Ký Toàn Thư (Bản Kỷ Quyển 1)',
    category: 'Thư tịch cổ',
    citation:
        'Quyền nghe tin Hoằng Tháo sắp đến, bảo các tướng tá rằng: Hoằng Tháo là đứa trẻ khờ dại... Nếu ta sai người vót nhọn cọc lớn bịt sắt cắm ngầm trước ở cửa biển...',
    reliabilityRating: 5.0,
    dating: 'Khắc in năm 1479',
  );

  static const HeritageArtifactModel
  artifactThuyenChien = HeritageArtifactModel(
    id: 'art_thuyen_chien_938',
    name: 'Mô hình Chiến thuyền Bạch Đằng',
    era: 'Thế kỷ X (Thời Ngô)',
    rarity: 'Bảo vật Quốc gia',
    description:
        'Thuyền chiến thân hẹp đáy nông, cơ động linh hoạt, lợi dụng con nước cạn để nhử hạm đội thuyền lớn của giặc Nam Hán lọt trọn vào bãi cọc.',
    excavationLocation: 'Vùng cửa sông Bạch Đằng, Quảng Ninh - Hải Phòng',
    historicalSignificance:
        'Minh chứng cho đỉnh cao nghệ thuật thủy chiến "dĩ đoản chế trường" lấy nhỏ đánh lớn của ông cha ta.',
  );

  static final LessonModel lessonEpisode2 = LessonModel(
    id: 'les_bach_dang_ep2',
    eventId: 'evt_bach_dang_938',
    title: 'Kế Sách Cọc Ngầm & Sa Bàn Thủy Triều',
    episodeNumber: 2,
    historicalQuestion:
        'Ngô Quyền đã phối hợp địa hình hiểm yếu và quy luật thủy triều như thế nào để đè bẹp đạo quân Nam Hán?',
    objectives: [
      'Giải mã lý do vì sao cọc gỗ lim phải được đóng bí mật trước khi giặc đến.',
      'Sắp xếp chính xác 4 bước ngoặt chiến thuật theo chu kỳ con nước triều.',
      'Vận dụng mô hình CER đối sánh giữa thư tịch cổ và hiện vật khảo cổ học.',
    ],
    energyCost: 20,
    historyPointsReward: 150,
    xpReward: 50,
    stages: [
      // Giai đoạn 1: Bối cảnh & Thăm dò
      StageModel(
        id: 'stage_1',
        stageNumber: 1,
        title: 'Giai đoạn 1: Bối Cảnh Lịch Sử',
        subtitle: 'Khai thác tư liệu thư tịch cổ Hán Nôm',
        activities: [
          ActivityModel(
            id: 'act_1_1',
            type: ActivityType.contextReader,
            title: 'Khảo cứu Quân mưu Ngô Quyền',
            prompt:
                'Đọc kỹ trích đoạn Đại Việt Sử Ký Toàn Thư để thấu hiểu kế sách phục kích hiểm yếu của chủ tướng.',
            config: {
              'citation':
                  'Nếu ta sai người vót nhọn cọc lớn bịt sắt cắm ngầm trước ở cửa biển, thuyền giặc nhân khi nước triều lên tiến vào bên trong bãi cọc, sau đó ta dễ bề chế ngự, không kế gì hơn kế ấy.',
              'glossary': {
                'Hoằng Tháo':
                    'Con trai vua Nam Hán Lưu Cung, được phong làm Giao Châu vương thống lĩnh thủy quân xâm lược nước ta.',
                'Bịt sắt':
                    'Đầu cọc gỗ lim được gia cố kim loại để tăng sức công phá đáy thuyền giặc.',
              },
            },
            evidenceRefs: [evidenceToanThu],
          ),
          ActivityModel(
            id: 'act_1_2',
            type: ActivityType.multipleChoice,
            title: 'Trắc nghiệm: Mục đích việc đóng cọc',
            prompt:
                'Tại sao việc đóng cọc gỗ ngầm phải được thực hiện từ tháng 10 năm 938?',
            config: {
              'options': [
                {
                  'id': 'opt_a',
                  'text':
                      'Để chuẩn bị bí mật khi giặc chưa tới và con nước triều đang rút cạn lộ bãi.',
                  'isCorrect': true,
                },
                {
                  'id': 'opt_b',
                  'text':
                      'Để ngăn chặn thuyền buôn dân sự không đi vào cửa biển.',
                  'isCorrect': false,
                },
                {
                  'id': 'opt_c',
                  'text':
                      'Được đóng trong lúc hai bên đang giao chiến trực diện.',
                  'isCorrect': false,
                },
              ],
              'explanation':
                  'Đóng cọc cần thời gian đốn gỗ lim và cắm ngầm lúc triều rút để bảo đảm tính bí mật quân sự tuyệt đối.',
            },
            evidenceRefs: [evidenceToanThu],
          ),
        ],
      ),

      // Giai đoạn 2: Tác chiến sa bàn & Sắp xếp niên đại
      StageModel(
        id: 'stage_2',
        stageNumber: 2,
        title: 'Giai đoạn 2: Tác Chiến Sa Bàn',
        subtitle: 'Sắp xếp diễn biến & Ghép nối dữ kiện',
        activities: [
          ActivityModel(
            id: 'act_2_1',
            type: ActivityType.dragOrder,
            title: 'Sắp xếp diễn biến chiến thuật Bạch Đằng 938',
            prompt:
                'Hãy kéo thả 4 bước ngoặt lịch sử dưới đây theo đúng thứ tự thời gian của trận chiến:',
            config: {
              'items': [
                {
                  'id': 'step_1',
                  'text':
                      'Ngô Quyền họp bàn kế sách, quân ta bí mật cắm cọc gỗ lim bịt sắt dưới lòng sông lúc triều rút.',
                },
                {
                  'id': 'step_2',
                  'text':
                      'Đạo quân thủy Nam Hán vượt biển tiến vào cửa sông Bạch Đằng.',
                },
                {
                  'id': 'step_3',
                  'text':
                      'Thuyền nhẹ quân ta ra khiêu chiến rồi giả thua rút chạy, nhử địch vượt qua bãi cọc lúc triều dâng.',
                },
                {
                  'id': 'step_4',
                  'text':
                      'Nước triều rút xiết, cọc nhô lên chọc thủng đáy thuyền giặc, quân ta tổng phản công đại thắng.',
                },
              ],
            },
            evidenceRefs: [evidenceToanThu, evidenceYenGiang],
          ),
        ],
      ),

      // Giai đoạn 3: Kiểm chứng & Lập luận CER
      StageModel(
        id: 'stage_3',
        stageNumber: 3,
        title: 'Giai đoạn 3: Luận Điểm Khoa Học',
        subtitle: 'Phương pháp lập luận Claim - Evidence - Reasoning',
        activities: [
          ActivityModel(
            id: 'act_3_1',
            type: ActivityType.cerConclusion,
            title: 'Lập luận CER: Tính Xác Thực Bãi Cọc',
            prompt:
                'Hãy chọn Bằng chứng khảo cổ phù hợp nhất để chứng minh Luận điểm của bạn:',
            config: {
              'claim':
                  'Ngô Quyền đã thực sự bố trí bãi cọc gỗ lim vát nhọn dưới lòng sông Bạch Đằng.',
              'evidenceOptions': [
                {
                  'id': 'evi_1',
                  'text':
                      'Di chỉ khảo cổ Bãi cọc Yên Giang (Quảng Ninh) với cọc gỗ lim niên đại C-14 thế kỷ X.',
                  'isStrong': true,
                },
                {
                  'id': 'evi_2',
                  'text':
                      'Truyền thuyết dân gian về vị tướng đánh cá vùng cửa biển.',
                  'isStrong': false,
                },
              ],
              'reasoning':
                  'Hiện vật khảo cổ học thực địa niên đại thế kỷ X hoàn toàn trùng khớp với ghi chép trong Đại Việt Sử Ký Toàn Thư, khẳng định kế sách cọc ngầm là sự thật lịch sử được chứng minh bằng khoa học.',
            },
            evidenceRefs: [evidenceYenGiang],
          ),
        ],
      ),
    ],
  );
}
