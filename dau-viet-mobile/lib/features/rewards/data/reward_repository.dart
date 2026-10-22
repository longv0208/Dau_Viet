import 'reward_dtos.dart';

/// Hợp đồng nguồn dữ liệu thưởng + vật phẩm — presentation chỉ phụ thuộc
/// interface; provider chọn Api (real) hay Mock (demo) theo USE_MOCK.
/// Read-only: không có phương thức ghi/claim — thưởng do server cấp.
abstract class RewardRepository {
  /// Tổng EXP + Điểm Lịch sử + số bài đã hoàn thành + số vật phẩm sở hữu.
  Future<RewardSummaryDto> summary();

  /// Lịch sử bút toán thưởng phân trang, mới nhất trước.
  Future<RewardTransactionPageDto> transactions({int page = 0, int size = 20});

  /// Vật phẩm đã sở hữu, mới nhất trước.
  Future<List<InventoryItemDto>> inventory();

  /// Catalog đầy đủ kèm owned + requirement + progress.
  Future<List<CatalogItemDto>> catalog();
}
