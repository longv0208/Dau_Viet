import 'collection_dto.dart';
import 'dossier_dto.dart';
import 'event_progress_dto.dart';

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

  /// Các evidence_type learner đã collect trên TOÀN collection — nguồn
  /// filter chips; không phụ thuộc trang đã tải (P2-D).
  Future<List<String>> availableTypes();

  /* ---------- GAME-04 dossier ---------- */

  /// List dossier learner thấy được; `unlocked` null = cả hai.
  Future<DossierPageDto> listDossiers({
    String? type,
    String? eventId,
    bool? unlocked,
    int page = 0,
    int size = 20,
  });

  /// Chi tiết dossier — preview khi locked, full khi unlocked.
  Future<DossierDetailDto> dossierDetail(String dossierId);

  /// Tiến độ event của learner (GAME-04 §10).
  Future<EventProgressDto> eventProgress(String eventId);
}
