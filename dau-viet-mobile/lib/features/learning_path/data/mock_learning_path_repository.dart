import '../../../core/api/api_error.dart';
import '../../../core/api/api_exception.dart';
import 'learning_path_dto.dart';
import 'learning_path_repository.dart';

/// Repository demo cho `USE_MOCK=true` (Issue #21 / AC-2):
/// - Có đúng 3 Đại thời kỳ (`ERA`): Cổ – Trung đại, Cận đại, Hiện đại.
/// - Có 6 Thời kỳ (`PERIOD`) phân bổ dưới 3 `ERA`.
/// - Đầy đủ 6 trạng thái `LearnerPathStatus`:
///   `COMPLETED`, `MASTERED`, `IN_PROGRESS`, `AVAILABLE`, `LOCKED`, `NOT_READY`.
/// - Hỗ trợ `touchPeriod(periodCode)` cập nhật `lastPeriodCode` và con trỏ `current`.
class MockLearningPathRepository extends LearningPathRepository {
  String _lastPeriodCode = 'EARLY_INDEPENDENCE';

  static const String eraAncientMedievalId =
      'd7e20000-0000-4000-8000-000000000001';
  static const String eraEarlyModernId = 'd7e20000-0000-4000-8000-000000000002';
  static const String eraModernId = 'd7e20000-0000-4000-8000-000000000003';

  static const String periodFoundingId = 'd7e21000-0000-4000-8000-000000000001';
  static const String periodNorthernDominationId =
      'd7e21000-0000-4000-8000-000000000002';
  static const String periodEarlyIndependenceId =
      'd7e21000-0000-4000-8000-000000000003';
  static const String periodLyDynastyId =
      'd7e21000-0000-4000-8000-000000000004';
  static const String periodPatrioticMovementsId =
      'd7e21000-0000-4000-8000-000000000005';
  static const String periodAntiFrenchId =
      'd7e21000-0000-4000-8000-000000000006';

  static final List<LearningPathChapterDto> _chapters = [
    // =========================================================================
    // 3 ROOT ERAs
    // =========================================================================
    const LearningPathChapterDto(
      chapterId: eraAncientMedievalId,
      parentId: null,
      nodeType: PathNodeType.era,
      code: 'ERA_ANCIENT_MEDIEVAL',
      title: 'Thời kỳ Cổ – Trung đại',
      description:
          'Từ bình minh dựng nước Văn Lang – Âu Lạc, qua hơn một thiên niên kỷ đấu tranh chống Bắc thuộc đến kỷ nguyên độc lập tự chủ của các vương triều phong kiến.',
      startYear: -700,
      endYear: 1858,
      periodLabel: 'Khoảng thế kỷ VII TCN – năm 1858',
      sortOrder: 1,
      themeKey: 'FOUNDING_ERA',
      events: [],
    ),
    const LearningPathChapterDto(
      chapterId: eraEarlyModernId,
      parentId: null,
      nodeType: PathNodeType.era,
      code: 'ERA_EARLY_MODERN',
      title: 'Thời kỳ Cận đại',
      description:
          'Các phong trào yêu nước chống thực dân và hành trình tìm đường cứu nước từ cuối thế kỷ XIX đến năm 1945.',
      startYear: 1858,
      endYear: 1945,
      periodLabel: 'Năm 1858 – năm 1945',
      sortOrder: 2,
      themeKey: 'NORTHERN_DOMINATION',
      events: [],
    ),
    const LearningPathChapterDto(
      chapterId: eraModernId,
      parentId: null,
      nodeType: PathNodeType.era,
      code: 'ERA_MODERN',
      title: 'Thời kỳ Hiện đại',
      description:
          'Cuộc trường kỳ kháng chiến bảo vệ nền độc lập dân tộc và thống nhất đất nước trong thế kỷ XX.',
      startYear: 1945,
      endYear: 1975,
      periodLabel: 'Năm 1945 – năm 1975',
      sortOrder: 3,
      themeKey: 'ANTI_FRENCH_RESISTANCE',
      events: [],
    ),

    // =========================================================================
    // PERIODS UNDER ERA 1 (Cổ – Trung đại)
    // =========================================================================
    const LearningPathChapterDto(
      chapterId: periodFoundingId,
      parentId: eraAncientMedievalId,
      nodeType: PathNodeType.period,
      code: 'FOUNDING_ERA',
      title: 'Buổi đầu dựng nước',
      description:
          'Thời đại Hùng Vương mở nước, văn hóa Đông Sơn và nền văn minh sông Hồng.',
      startYear: -700,
      endYear: -179,
      periodLabel: 'Khoảng thế kỷ VII TCN – năm 179 TCN',
      sortOrder: 1,
      themeKey: 'FOUNDING_ERA',
      events: [
        LearningPathEventNodeDto(
          eventNodeId: 'd7e30000-0000-4000-8000-000000000001',
          eventId: '00000000-0000-0000-0000-000000000005',
          slug: 'hung-vuong-van-lang',
          title: 'Thời Đại Hùng Vương - Dựng Nước Văn Lang',
          startYear: -700,
          endYear: -258,
          datePrecision: EventDatePrecision.century,
          yearLabel: 'Khoảng thế kỷ VII TCN',
          period: 'Khoảng thế kỷ VII TCN',
          coverAssetKey: 'events/hung-vuong/hero.jpg',
          sortOrder: 1,
          participationType: ParticipationType.required,
          status: LearnerPathStatus.completed,
          contentStatus: PathContentStatus.playable,
          lessons: [
            LearningPathLessonNodeDto(
              lessonNodeId: 'd7e40000-0000-4000-8000-000000000001',
              lessonId: 'demo-lesson-hung-vuong-1',
              title: 'Văn minh lúa nước & Trống đồng Đông Sơn',
              sortOrder: 1,
              status: LearnerPathStatus.completed,
            ),
          ],
        ),
      ],
    ),
    const LearningPathChapterDto(
      chapterId: periodNorthernDominationId,
      parentId: eraAncientMedievalId,
      nodeType: PathNodeType.period,
      code: 'NORTHERN_DOMINATION',
      title: 'Bắc thuộc và đấu tranh giành độc lập',
      description:
          'Hơn một thiên niên kỷ kiên cường bảo tồn văn hóa và bền bỉ đấu tranh chống ách đô hộ phương Bắc.',
      startYear: -179,
      endYear: 938,
      periodLabel: 'Năm 179 TCN – năm 938',
      sortOrder: 2,
      themeKey: 'NORTHERN_DOMINATION',
      events: [
        LearningPathEventNodeDto(
          eventNodeId: 'd7e30000-0000-4000-8000-000000000002',
          eventId: '00000000-0000-0000-0000-000000000002',
          slug: 'hai-ba-trung-40',
          title: 'Khởi Nghĩa Hai Bà Trưng',
          startYear: 40,
          endYear: 43,
          datePrecision: EventDatePrecision.exact,
          yearLabel: 'Năm 40',
          period: 'Năm 40 – 43 SCN',
          coverAssetKey: 'events/hai-ba-trung/hero.jpg',
          sortOrder: 1,
          participationType: ParticipationType.required,
          status: LearnerPathStatus.mastered,
          contentStatus: PathContentStatus.playable,
          lessons: [
            LearningPathLessonNodeDto(
              lessonNodeId: 'd7e40000-0000-4000-8000-000000000002',
              lessonId: 'demo-lesson-hai-ba-trung-1',
              title: 'Lời thề Hát Môn & 65 thành Lĩnh Ngoại',
              sortOrder: 1,
              status: LearnerPathStatus.mastered,
            ),
          ],
        ),
      ],
    ),
    const LearningPathChapterDto(
      chapterId: periodEarlyIndependenceId,
      parentId: eraAncientMedievalId,
      nodeType: PathNodeType.period,
      code: 'EARLY_INDEPENDENCE',
      title: 'Buổi đầu độc lập tự chủ',
      description:
          'Thời kỳ phục hưng đất nước sau chiến thắng Bạch Đằng, đặt nền móng thể chế quốc gia độc lập.',
      startYear: 938,
      endYear: 1009,
      periodLabel: 'Năm 938 – năm 1009',
      sortOrder: 3,
      themeKey: 'EARLY_INDEPENDENCE',
      events: [
        LearningPathEventNodeDto(
          eventNodeId: 'd7e30000-0000-4000-8000-000000000003',
          eventId: '00000000-0000-0000-0000-000000000001',
          slug: 'bach-dang-938',
          title: 'Đại Chiến Bạch Đằng 938',
          startYear: 938,
          endYear: 938,
          datePrecision: EventDatePrecision.exact,
          yearLabel: 'Năm 938',
          period: 'Mùa Đông 938 SCN',
          coverAssetKey: 'events/bach-dang-938/hero.jpg',
          sortOrder: 1,
          participationType: ParticipationType.required,
          status: LearnerPathStatus.available,
          contentStatus: PathContentStatus.playable,
          lessons: [
            LearningPathLessonNodeDto(
              lessonNodeId: 'd7e40000-0000-4000-8000-000000000003',
              lessonId: 'demo-lesson-bach-dang-intro',
              title: 'Bối cảnh sông Bạch Đằng & Quân Nam Hán',
              sortOrder: 1,
              status: LearnerPathStatus.completed,
            ),
            LearningPathLessonNodeDto(
              lessonNodeId: 'd7e40000-0000-4000-8000-000000000004',
              lessonId: 'demo-lesson-bach-dang',
              title: 'Bí mật chiến thắng Bạch Đằng (Demo)',
              sortOrder: 2,
              status: LearnerPathStatus.inProgress,
            ),
            LearningPathLessonNodeDto(
              lessonNodeId: 'd7e40000-0000-4000-8000-000000000005',
              lessonId: 'demo-lesson-bach-dang-cer',
              title: 'Lập luận CER: Thủy triều & Bãi cọc gỗ lim',
              sortOrder: 3,
              status: LearnerPathStatus.locked,
            ),
          ],
        ),
      ],
    ),
    const LearningPathChapterDto(
      chapterId: periodLyDynastyId,
      parentId: eraAncientMedievalId,
      nodeType: PathNodeType.period,
      code: 'LY_DYNASTY',
      title: 'Thời nhà Lý',
      description:
          'Triều đại rực rỡ với quyết định dời đô về Thăng Long và chiến công bảo vệ giang sơn trên sông Như Nguyệt.',
      startYear: 1009,
      endYear: 1225,
      periodLabel: 'Năm 1009 – năm 1225',
      sortOrder: 4,
      themeKey: 'LY_DYNASTY',
      events: [
        LearningPathEventNodeDto(
          eventNodeId: 'd7e30000-0000-4000-8000-000000000004',
          eventId: '00000000-0000-0000-0000-000000000003',
          slug: 'ly-thai-to-1010',
          title: 'Lý Thái Tổ Dời Đô Về Thăng Long',
          startYear: 1010,
          endYear: 1010,
          datePrecision: EventDatePrecision.exact,
          yearLabel: 'Năm 1010',
          period: 'Mùa Thu 1010 SCN',
          coverAssetKey: 'events/thang-long-1010/hero.jpg',
          sortOrder: 1,
          participationType: ParticipationType.required,
          status: LearnerPathStatus.available,
          contentStatus: PathContentStatus.playable,
          lessons: [
            LearningPathLessonNodeDto(
              lessonNodeId: 'd7e40000-0000-4000-8000-000000000006',
              lessonId: 'demo-lesson-thang-long-1',
              title: 'Vì sao Lý Công Uẩn chọn thành Đại La?',
              sortOrder: 1,
              status: LearnerPathStatus.available,
            ),
            LearningPathLessonNodeDto(
              lessonNodeId: 'd7e40000-0000-4000-8000-000000000007',
              lessonId: 'demo-lesson-thang-long-2',
              title: 'Dấu tích Hoàng thành Thăng Long',
              sortOrder: 2,
              status: LearnerPathStatus.locked,
            ),
          ],
        ),
        LearningPathEventNodeDto(
          eventNodeId: 'd7e30000-0000-4000-8000-000000000005',
          eventId: '00000000-0000-0000-0000-000000000004',
          slug: 'chien-thang-nhu-nguyet-1077',
          title: 'Chiến Thắng Như Nguyệt 1077',
          startYear: 1077,
          endYear: 1077,
          datePrecision: EventDatePrecision.exact,
          yearLabel: 'Năm 1077',
          period: 'Mùa Xuân 1077 SCN',
          coverAssetKey: 'events/nhu-nguyet-1077/hero.jpg',
          sortOrder: 2,
          participationType: ParticipationType.required,
          status: LearnerPathStatus.locked,
          contentStatus: PathContentStatus.playable,
          lessons: [
            LearningPathLessonNodeDto(
              lessonNodeId: 'd7e40000-0000-4000-8000-000000000008',
              lessonId: 'demo-lesson-nhu-nguyet-1',
              title: 'Chiến tuyến sông Cầu & Nam Quốc Sơn Hà',
              sortOrder: 1,
              status: LearnerPathStatus.locked,
            ),
          ],
        ),
      ],
    ),

    // =========================================================================
    // PERIODS UNDER ERA 2 (Cận đại)
    // =========================================================================
    const LearningPathChapterDto(
      chapterId: periodPatrioticMovementsId,
      parentId: eraEarlyModernId,
      nodeType: PathNodeType.period,
      code: 'PATRIOTIC_MOVEMENTS',
      title: 'Phong trào yêu nước đầu thế kỷ XX',
      description:
          'Các cuộc khởi nghĩa Cần Vương, Yên Thế và phong trào Đông Du, Duy Tân đầu thế kỷ XX.',
      startYear: 1858,
      endYear: 1945,
      periodLabel: 'Năm 1858 – năm 1945',
      sortOrder: 1,
      themeKey: 'NORTHERN_DOMINATION',
      events: [
        LearningPathEventNodeDto(
          eventNodeId: 'd7e30000-0000-4000-8000-000000000006',
          eventId: '00000000-0000-0000-0000-000000000007',
          slug: 'phong-trao-can-vuong-1885',
          title: 'Phong Trào Cần Vương & Khởi Nghĩa Hương Khê',
          startYear: 1885,
          endYear: 1896,
          datePrecision: EventDatePrecision.period,
          yearLabel: 'Năm 1885',
          period: 'Năm 1885 – 1896',
          coverAssetKey: 'events/can-vuong-1885/hero.jpg',
          sortOrder: 1,
          participationType: ParticipationType.explorationOnly,
          status: LearnerPathStatus.notReady,
          contentStatus: PathContentStatus.noPublishedLesson,
          lessons: [],
        ),
      ],
    ),

    // =========================================================================
    // PERIODS UNDER ERA 3 (Hiện đại)
    // =========================================================================
    const LearningPathChapterDto(
      chapterId: periodAntiFrenchId,
      parentId: eraModernId,
      nodeType: PathNodeType.period,
      code: 'ANTI_FRENCH_RESISTANCE',
      title: 'Kháng chiến chống thực dân Pháp',
      description:
          'Cuộc trường kỳ kháng chiến toàn dân, toàn diện kết thúc bằng chiến thắng Điện Biên Phủ lừng lẫy địa cầu.',
      startYear: 1945,
      endYear: 1954,
      periodLabel: 'Năm 1945 – năm 1954',
      sortOrder: 1,
      themeKey: 'ANTI_FRENCH_RESISTANCE',
      events: [
        LearningPathEventNodeDto(
          eventNodeId: 'd7e30000-0000-4000-8000-000000000007',
          eventId: '00000000-0000-0000-0000-000000000006',
          slug: 'chien-dich-dien-bien-phu-1954',
          title: 'Chiến Dịch Điện Biên Phủ 1954',
          startYear: 1954,
          endYear: 1954,
          datePrecision: EventDatePrecision.exact,
          yearLabel: 'Năm 1954',
          period: 'Năm 1954',
          coverAssetKey: 'events/dien-bien-phu-1954/hero.jpg',
          sortOrder: 1,
          participationType: ParticipationType.required,
          status: LearnerPathStatus.available,
          contentStatus: PathContentStatus.playable,
          lessons: [
            LearningPathLessonNodeDto(
              lessonNodeId: 'd7e40000-0000-4000-8000-000000000009',
              lessonId: 'demo-lesson-dien-bien-phu-1',
              title: 'Quyết định lịch sử: Đánh chắc, tiến chắc',
              sortOrder: 1,
              status: LearnerPathStatus.available,
            ),
          ],
        ),
      ],
    ),
  ];

  static const List<PeriodProgressDto> _periodProgress = [
    PeriodProgressDto(
      chapterId: periodFoundingId,
      code: 'FOUNDING_ERA',
      title: 'Buổi đầu dựng nước',
      completedEvents: 1,
      requiredEvents: 1,
      completedLessons: 1,
      requiredLessons: 1,
      percent: 100,
    ),
    PeriodProgressDto(
      chapterId: periodNorthernDominationId,
      code: 'NORTHERN_DOMINATION',
      title: 'Bắc thuộc và đấu tranh giành độc lập',
      completedEvents: 1,
      requiredEvents: 1,
      completedLessons: 1,
      requiredLessons: 1,
      percent: 100,
    ),
    PeriodProgressDto(
      chapterId: periodEarlyIndependenceId,
      code: 'EARLY_INDEPENDENCE',
      title: 'Buổi đầu độc lập tự chủ',
      completedEvents: 0,
      requiredEvents: 1,
      completedLessons: 1,
      requiredLessons: 3,
      percent: 0,
    ),
    PeriodProgressDto(
      chapterId: periodLyDynastyId,
      code: 'LY_DYNASTY',
      title: 'Thời nhà Lý',
      completedEvents: 0,
      requiredEvents: 2,
      completedLessons: 0,
      requiredLessons: 3,
      percent: 0,
    ),
    PeriodProgressDto(
      chapterId: periodPatrioticMovementsId,
      code: 'PATRIOTIC_MOVEMENTS',
      title: 'Phong trào yêu nước đầu thế kỷ XX',
      completedEvents: 0,
      requiredEvents: 0,
      completedLessons: 0,
      requiredLessons: 0,
      percent: 0,
    ),
    PeriodProgressDto(
      chapterId: periodAntiFrenchId,
      code: 'ANTI_FRENCH_RESISTANCE',
      title: 'Kháng chiến chống thực dân Pháp',
      completedEvents: 0,
      requiredEvents: 1,
      completedLessons: 0,
      requiredLessons: 1,
      percent: 0,
    ),
  ];

  static const Map<String, LearningPathCurrentDto> _currentByPeriod = {
    'EARLY_INDEPENDENCE': LearningPathCurrentDto(
      chapterId: periodEarlyIndependenceId,
      eventNodeId: 'd7e30000-0000-4000-8000-000000000003',
      lessonId: 'demo-lesson-bach-dang',
    ),
    'LY_DYNASTY': LearningPathCurrentDto(
      chapterId: periodLyDynastyId,
      eventNodeId: 'd7e30000-0000-4000-8000-000000000004',
      lessonId: 'demo-lesson-thang-long-1',
    ),
    'ANTI_FRENCH_RESISTANCE': LearningPathCurrentDto(
      chapterId: periodAntiFrenchId,
      eventNodeId: 'd7e30000-0000-4000-8000-000000000007',
      lessonId: 'demo-lesson-dien-bien-phu-1',
    ),
  };

  LearningPathDto _buildSnapshot() {
    final activeCurrent =
        _currentByPeriod[_lastPeriodCode] ??
        _currentByPeriod['EARLY_INDEPENDENCE'];
    return LearningPathDto(
      pathCode: defaultLearningPathCode,
      pathVersion: 2,
      title: 'Hành trình Lịch sử Việt Nam',
      description:
          'Lộ trình lịch sử Việt Nam phân cấp Đại thời kỳ (ERA) và Thời kỳ (PERIOD), mở khóa tuần tự theo từng thời kỳ',
      enrolled: true,
      summary: const LearningPathSummaryDto(
        completedEvents: 2,
        totalRequiredEvents: 6,
        completedLessons: 3,
        totalRequiredLessons: 9,
      ),
      current: activeCurrent,
      chapters: _chapters,
      periodProgress: _periodProgress,
      currentByPeriod: _currentByPeriod,
      lastPeriodCode: _lastPeriodCode,
    );
  }

  @override
  Future<LearningPathDto> getMyLearningPath() async {
    return _buildSnapshot();
  }

  @override
  Future<TouchPeriodResponseDto> touchPeriod(String periodCode) async {
    final code = periodCode.trim();
    LearningPathChapterDto? target;
    for (final ch in _chapters) {
      if (ch.isPeriod && ch.code == code) {
        target = ch;
        break;
      }
    }
    if (target == null) {
      throw ApiException(
        ApiError(
          code: 'RESOURCE_NOT_FOUND',
          message: 'Không tìm thấy thời kỳ: $code',
        ),
        statusCode: 404,
      );
    }
    _lastPeriodCode = target.code;
    return TouchPeriodResponseDto(
      periodCode: target.code,
      chapterId: target.chapterId,
      touchedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<LearningPathDto> getPublishedLearningPath({
    String code = defaultLearningPathCode,
  }) async {
    if (code.trim().isNotEmpty && code.trim() != defaultLearningPathCode) {
      throw ApiException(
        ApiError(
          code: 'RESOURCE_NOT_FOUND',
          message: 'Không tìm thấy lộ trình: $code',
        ),
        statusCode: 404,
      );
    }
    return _buildSnapshot();
  }
}
