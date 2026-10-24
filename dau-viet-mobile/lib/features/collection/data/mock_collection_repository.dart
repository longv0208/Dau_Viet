import '../../../core/api/api_error.dart';
import '../../../core/api/api_exception.dart';
import 'collection_dto.dart';
import 'collection_repository.dart';
import 'dossier_dto.dart';
import 'event_progress_dto.dart';

/// Dữ liệu demo rõ ràng cho `USE_MOCK=true` — bộ sưu tập mẫu Bạch Đằng 938.
/// Không phải fallback: chỉ dùng khi build chạy chế độ demo.
class MockCollectionRepository implements CollectionRepository {
  static const List<CollectionItemDto> _items = [
    CollectionItemDto(
      evidenceId: '00000000-0000-0000-0000-000000000101',
      evidenceType: 'ARTIFACT',
      collectedAt: '2025-10-20T10:30:00Z',
      eventId: '00000000-0000-0000-0000-000000000001',
      eventTitle: 'Bạch Đằng 938',
      lessonId: '00000000-0000-0000-0000-000000000201',
      lessonTitle: 'Cọc ngầm Bạch Đằng',
      evidence: EvidenceSnapshotDto(
        title: 'Bãi cọc gỗ Yên Giang (mẫu demo)',
        description:
            'Di chỉ bãi cọc ngầm niên đại C-14 trùng giai đoạn trận Bạch Đằng '
            '938 — bằng chứng vật lý của trận thủy chiến trên sông.',
        assetId: null,
        source: EvidenceSourceDto(
          title: 'Bảo tàng Lịch sử Quốc gia',
          author: 'Viện Khảo cổ học Việt Nam',
          citation: 'Khai quật Yên Giang 1957–1976 (dữ liệu demo)',
        ),
      ),
    ),
    CollectionItemDto(
      evidenceId: '00000000-0000-0000-0000-000000000102',
      evidenceType: 'DOCUMENT',
      collectedAt: '2025-10-18T08:00:00Z',
      eventId: '00000000-0000-0000-0000-000000000001',
      eventTitle: 'Bạch Đằng 938',
      lessonId: '00000000-0000-0000-0000-000000000201',
      lessonTitle: 'Cọc ngầm Bạch Đằng',
      evidence: EvidenceSnapshotDto(
        title: 'Đại Việt sử ký toàn thư — đoạn Bạch Đằng (mẫu demo)',
        description:
            'Chép lời kể về việc Ngô Quyền dùng thủy triều và cọc ngầm đánh '
            'thắng quân Nam Hán năm 938.',
        source: EvidenceSourceDto(
          title: 'Đại Việt sử ký toàn thư',
          author: 'Ngô Sĩ Liên',
          publishedAt: '1479',
        ),
      ),
    ),
  ];

  @override
  Future<CollectionPageDto> list({
    String? type,
    String? eventId,
    int page = 0,
    int size = 20,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final filtered = _items.where((i) {
      if (type != null && i.evidenceType != type) return false;
      if (eventId != null && i.eventId != eventId) return false;
      return true;
    }).toList();
    final start = page * size;
    final end = (start + size).clamp(0, filtered.length);
    return CollectionPageDto(
      content: start >= filtered.length
          ? const []
          : filtered.sublist(start, end),
      page: page,
      size: size,
      totalElements: filtered.length,
      totalPages: filtered.isEmpty ? 0 : ((filtered.length + size - 1) ~/ size),
    );
  }

  @override
  Future<List<String>> availableTypes() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return _items
        .map((i) => i.evidenceType)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
  }

  @override
  Future<CollectionItemDto> detail(String evidenceId) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    for (final item in _items) {
      if (item.evidenceId == evidenceId) return item;
    }
    throw const ApiException(
      ApiError(
        code: 'COLLECTION_ITEM_NOT_FOUND',
        message: 'Không tìm thấy mục trong bộ sưu tập.',
      ),
      statusCode: 404,
    );
  }

  /* ---------- GAME-04 dossier (demo) ---------- */

  static const _d1 = DossierDetailDto(
    dossierId: 'd7c10000-0000-4000-8000-000000000001',
    canonicalCode: 'ngo-quyen',
    dossierType: 'PERSON',
    title: 'Ngô Quyền',
    summary: 'Thủ lĩnh trận Bạch Đằng 938, mở kỷ nguyên độc lập.',
    description:
        'Ngô Quyền (897–944), người Ái Châu. Năm 938 ông lợi dụng thủy '
        'triều trên sông Bạch Đằng phối hợp bãi cọc ngầm để đánh bại thủy '
        'quân Nam Hán, chấm dứt hơn một nghìn năm Bắc thuộc.',
    source: DossierSourceDto(
      title: 'Đại Việt sử ký toàn thư',
      author: 'Ngô Sĩ Liên',
      citation: 'Ngoại kỷ, quyển 5, kỷ Ngô Quyền',
      reliability: 'HIGH',
    ),
    eventIds: ['00000000-0000-0000-0000-000000000001'],
    unlocked: true,
    grantedAt: '2025-10-24T09:00:00Z',
    unlockEventId: '00000000-0000-0000-0000-000000000001',
    dossierVersion: 1,
    preview: false,
  );
  static const _d2 = DossierDetailDto(
    dossierId: 'd7c10000-0000-4000-8000-000000000005',
    canonicalCode: 'song-bach-dang',
    dossierType: 'LOCATION',
    title: 'Sông Bạch Đằng',
    summary: 'Trận địa thủy chiến quyết định năm 938.',
    description:
        'Cửa sông Bạch Đằng (Quảng Ninh) có chế độ bán nhật triều mạnh — '
        'Ngô Quyền tận dụng nhịp con nước để giấu bãi cọc rồi chặn đánh khi '
        'triều rút.',
    source: DossierSourceDto(
      title: 'Viện Hàn lâm KHXH&NV',
      citation: 'Tư liệu địa hình cửa sông Bạch Đằng',
      reliability: 'MEDIUM',
    ),
    eventIds: ['00000000-0000-0000-0000-000000000001'],
    unlocked: true,
    grantedAt: '2025-10-24T09:00:00Z',
    unlockEventId: '00000000-0000-0000-0000-000000000001',
    dossierVersion: 1,
    preview: false,
  );
  static const _d3 = DossierDetailDto(
    dossierId: 'd7c10000-0000-4000-8000-000000000008',
    canonicalCode: 'coc-go-bach-dang',
    dossierType: 'ARTIFACT',
    title: 'Bãi cọc gỗ Bạch Đằng',
    summary: 'Hiện vật khảo cổ chứng minh trận địa cọc ngầm.',
    description:
        'Các bãi cọc gỗ khai quật tại Yên Giang – Vạn Yên có niên đại phù '
        'hợp giai đoạn trận Bạch Đằng 938, củng cố mô tả sử liệu về trận '
        'thủy chiến.',
    source: DossierSourceDto(
      title: 'Bảo tàng Lịch sử Quốc gia',
      citation: 'Hiện vật bãi cọc Bạch Đằng (khai quật Yên Giang)',
      url: 'https://baotanglichsuquocgia.vn',
      reliability: 'HIGH',
    ),
    eventIds: ['00000000-0000-0000-0000-000000000001'],
    unlocked: false,
    grantedAt: null,
    unlockEventId: null,
    dossierVersion: null,
    preview: true,
  );

  static const List<DossierDetailDto> _dossiers = [_d1, _d2, _d3];

  DossierSummaryDto _summary(DossierDetailDto d) => DossierSummaryDto(
    dossierId: d.dossierId,
    canonicalCode: d.canonicalCode,
    dossierType: d.dossierType,
    title: d.title,
    summary: d.summary,
    assetId: d.assetId,
    eventIds: d.eventIds,
    unlocked: d.unlocked,
    grantedAt: d.grantedAt,
    unlockEventId: d.unlockEventId,
    preview: d.preview,
  );

  @override
  Future<DossierPageDto> listDossiers({
    String? type,
    String? eventId,
    bool? unlocked,
    int page = 0,
    int size = 20,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final filtered = _dossiers
        .where((d) {
          if (type != null && d.dossierType != type) return false;
          if (eventId != null && !d.eventIds.contains(eventId)) return false;
          if (unlocked == true && !d.unlocked) return false;
          if (unlocked == false && d.unlocked) return false;
          return true;
        })
        .map(_summary)
        .toList();
    final start = page * size;
    final end = (start + size).clamp(0, filtered.length);
    return DossierPageDto(
      content: start >= filtered.length
          ? const []
          : filtered.sublist(start, end),
      page: page,
      size: size,
      totalElements: filtered.length,
      totalPages: filtered.isEmpty ? 0 : ((filtered.length + size - 1) ~/ size),
    );
  }

  @override
  Future<DossierDetailDto> dossierDetail(String dossierId) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    for (final d in _dossiers) {
      if (d.dossierId == dossierId) return d;
    }
    throw const ApiException(
      ApiError(code: 'DOSSIER_NOT_FOUND', message: 'Không tìm thấy hồ sơ.'),
      statusCode: 404,
    );
  }

  @override
  Future<EventProgressDto> eventProgress(String eventId) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    // Demo: 1 required lesson, completed → EVENT_COMPLETED.
    return const EventProgressDto(
      eventId: '00000000-0000-0000-0000-000000000001',
      status: 'EVENT_COMPLETED',
      policyVersion: 1,
      requiredLessonsTotal: 1,
      requiredLessonsCompleted: 1,
      eventCompleted: true,
      eventMastered: false,
      masteryThreshold: 70,
      requiredLessons: [
        RequiredLessonProgressDto(
          lessonId: '00000000-0000-0000-0000-000000000201',
          title: 'Cọc ngầm Bạch Đằng',
          completed: true,
          masteryStatus: 'MASTERED',
          bestKnowledgeScore: 85,
        ),
      ],
      unlockedDossiersCount: 2,
    );
  }
}
