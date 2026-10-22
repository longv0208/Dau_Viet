import 'collection_dto.dart';

/// Hợp đồng nguồn dữ liệu Bộ sưu tập — presentation chỉ phụ thuộc interface;
/// provider chọn Api (real) hay Mock (demo) theo USE_MOCK. API lỗi KHÔNG tự
/// động đổi sang mock.
abstract class CollectionRepository {
  /// Danh sách phân trang mới nhất trước; filter `type`/`eventId` khi có.
  Future<CollectionPageDto> list({
    String? type,
    String? eventId,
    int page = 0,
    int size = 20,
  });

  /// Chi tiết một mục đã collect — lỗi nếu không thuộc learner hiện tại.
  Future<CollectionItemDto> detail(String evidenceId);
}
