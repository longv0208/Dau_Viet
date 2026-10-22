import '../../../core/api/api_error.dart';
import '../../../core/api/api_exception.dart';
import 'collection_dto.dart';
import 'collection_repository.dart';

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
}
