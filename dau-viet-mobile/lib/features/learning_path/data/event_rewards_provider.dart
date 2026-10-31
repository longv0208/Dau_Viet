import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../map/data/map_location_dto.dart';
import '../../map/data/map_providers.dart';
import '../../rewards/data/reward_dtos.dart';
import '../../rewards/data/reward_providers.dart';
import '../presentation/widgets/historical_event_card.dart';
import 'learning_path_dto.dart';

Duration? _noRetry(int retryCount, Object error) => null;

/// Gói phần thưởng Địa điểm di sản (`MapLocationDto`) và Vật phẩm sưu tầm
/// (`CatalogItemDto`) gắn với một sự kiện lịch sử (`eventId`), được tổng hợp
/// trực tiếp từ `mapLocationsProvider` và `inventoryCatalogProvider`.
class EventRewardsBundle {
  final String eventId;
  final List<MapLocationDto> locations;
  final List<CatalogItemDto> items;

  const EventRewardsBundle({
    required this.eventId,
    this.locations = const [],
    this.items = const [],
  });

  static const EventRewardsBundle empty = EventRewardsBundle(eventId: '');

  bool get hasRewards => locations.isNotEmpty || items.isNotEmpty;

  /// Chuyển đổi sang `EventRewardPreview` để hiển thị trên Bottom Sheet / Rương quà.
  /// Trả về `null` nếu sự kiện không có phần thưởng nào từ API.
  EventRewardPreview? toPreview(LearningPathEventNodeDto event) {
    if (!hasRewards) return null;
    final bool anyLessonDone =
        event.status.isDone || event.lessons.any((l) => l.status.isDone);
    final bool allLessonsDone = event.status.isDone ||
        (event.lessons.isNotEmpty &&
            event.lessons.every((l) => l.status.isDone));

    final MapLocationDto? loc = locations.firstOrNull;
    final CatalogItemDto? item = items.firstOrNull;

    return EventRewardPreview(
      locationId: loc?.id,
      locationTitle: loc?.title ?? '',
      locationUnlockHint:
          loc?.unlockModeLabelVi ?? 'Mở khóa khi hoàn thành bài học trong chặng',
      isLocationUnlocked: (loc?.isUnlocked ?? false) || anyLessonDone,
      itemTitle: item?.name ?? '',
      itemDescription:
          item?.description ??
          'Nhận tự động khi hoàn thành toàn bộ bài học của chặng',
      isItemUnlocked:
          (item?.owned ?? false) ||
          (item?.requirement?.satisfied ?? false) ||
          allLessonsDone,
    );
  }
}

/// Kiểm tra đệ quy xem `ItemRequirementDto` (hoặc các nhánh con trong `conditions`)
/// có gắn với `targetEventId` hay không.
bool requirementMatchesEventId(
  ItemRequirementDto? requirement,
  String targetEventId,
) {
  if (requirement == null) return false;
  final norm = targetEventId.trim().toLowerCase();
  if (norm.isEmpty) return false;

  if (requirement.eventId != null &&
      requirement.eventId!.trim().toLowerCase() == norm) {
    return true;
  }
  for (final cond in requirement.conditions) {
    if (requirementMatchesEventId(cond, norm)) {
      return true;
    }
  }
  return false;
}

/// Kiểm tra xem `MapLocationDto` có liên kết với `targetEventId` qua `eventId`,
/// `eventIds`, hoặc `events` hay không.
bool locationMatchesEventId(MapLocationDto location, String targetEventId) {
  final norm = targetEventId.trim().toLowerCase();
  if (norm.isEmpty) return false;

  if (location.eventId.trim().toLowerCase() == norm) return true;
  for (final id in location.eventIds) {
    if (id.trim().toLowerCase() == norm) return true;
  }
  for (final evt in location.events) {
    if (evt.eventId.trim().toLowerCase() == norm) return true;
  }
  return false;
}

/// Provider lấy phần thưởng thực tế của một `eventId` từ `inventoryCatalogProvider`
/// và `mapLocationsProvider`. Khi API lỗi hoặc không có phần thưởng cho `eventId`,
/// trả về `EventRewardsBundle.empty` (`hasRewards == false`) để ẩn mốc rương
/// mà không làm gián đoạn màn Hành trình.
final eventRewardsProvider =
    FutureProvider.autoDispose.family<EventRewardsBundle, String>(
      retry: _noRetry,
      (ref, eventId) async {
        final norm = eventId.trim().toLowerCase();
        if (norm.isEmpty) return EventRewardsBundle.empty;

        final asyncCatalog = ref.watch(inventoryCatalogProvider);
        final asyncLocations = ref.watch(mapLocationsProvider);

        List<CatalogItemDto> catalog = const [];
        if (asyncCatalog.hasValue) {
          catalog = asyncCatalog.value ?? const [];
        } else if (asyncCatalog.isLoading) {
          try {
            catalog = await ref.read(inventoryCatalogProvider.future);
          } catch (_) {
            catalog = const [];
          }
        }

        List<MapLocationDto> locations = const [];
        if (asyncLocations.hasValue) {
          locations = asyncLocations.value ?? const [];
        } else if (asyncLocations.isLoading) {
          try {
            locations = await ref.read(mapLocationsProvider.future);
          } catch (_) {
            locations = const [];
          }
        }

        final matchedItems = catalog
            .where((item) => requirementMatchesEventId(item.requirement, norm))
            .toList(growable: false);
        final matchedLocations = locations
            .where((loc) => locationMatchesEventId(loc, norm))
            .toList(growable: false);

        return EventRewardsBundle(
          eventId: eventId,
          locations: matchedLocations,
          items: matchedItems,
        );
      },
    );

/// Quản lý trạng thái "Đã xem rương" lưu cục bộ bằng `shared_preferences`
/// (không gửi lên server).
final seenRewardChestsProvider =
    NotifierProvider<SeenRewardChestsController, Set<String>>(
      SeenRewardChestsController.new,
    );

class SeenRewardChestsController extends Notifier<Set<String>> {
  static const String _prefsKey = 'dauviet_seen_event_reward_chests_v1';
  bool _loaded = false;

  @override
  Set<String> build() {
    if (!_loaded) {
      _loaded = true;
      _loadFromPrefs();
    }
    return const <String>{};
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsKey) ?? const <String>[];
      if (list.isNotEmpty) {
        state = {...state, ...list.map((e) => e.trim().toLowerCase())};
      }
    } catch (_) {
      // Bỏ qua nếu SharedPreferences chưa khởi tạo trong môi trường test tối giản.
    }
  }

  bool isSeen(String eventId) =>
      state.contains(eventId.trim().toLowerCase());

  Future<void> markSeen(String eventId) async {
    final norm = eventId.trim().toLowerCase();
    if (norm.isEmpty || state.contains(norm)) return;
    final next = <String>{...state, norm};
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, next.toList(growable: false));
    } catch (_) {
      // Không chặn luồng mở rương nếu lưu bộ nhớ cục bộ thất bại.
    }
  }
}
