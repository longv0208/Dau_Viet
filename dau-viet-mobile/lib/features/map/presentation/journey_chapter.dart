import '../data/map_location_dto.dart';

/// Một "chặng hành trình" — nhóm các địa điểm thuộc cùng sự kiện
/// (`primaryEventId`). Thứ tự chapter theo lần xuất hiện đầu của eventId
/// trong danh sách server trả về; thứ tự location trong chapter giữ nguyên
/// input order. Không suy diễn niên đại hay thứ tự lịch sử.
class JourneyChapter {
  final int index;
  final String eventId;
  final String title;
  final List<MapLocationDto> locations;

  const JourneyChapter({
    required this.index,
    required this.eventId,
    required this.title,
    required this.locations,
  });

  int get total => locations.length;
}

/// Nhóm [locations] thành chapters theo `primaryEventId`, giữ input order.
/// `primaryEventTitle` null/rỗng → `'Chặng N'` (không bịa tên sự kiện).
List<JourneyChapter> groupChapters(List<MapLocationDto> locations) {
  final order = <String>[];
  final byEvent = <String, List<MapLocationDto>>{};
  final titleOf = <String, String>{};
  for (final l in locations) {
    final key = l.primaryEventId ?? 'standalone_${l.id}';
    if (!byEvent.containsKey(key)) {
      order.add(key);
      byEvent[key] = [];
    }
    byEvent[key]!.add(l);
    final t = l.primaryEventTitle;
    if (t != null && t.trim().isNotEmpty && !titleOf.containsKey(key)) {
      titleOf[key] = t;
    }
  }
  return [
    for (int i = 0; i < order.length; i++)
      JourneyChapter(
        index: i,
        eventId: order[i],
        title: titleOf[order[i]] ?? 'Chặng ${i + 1}',
        locations: byEvent[order[i]]!,
      ),
  ];
}
