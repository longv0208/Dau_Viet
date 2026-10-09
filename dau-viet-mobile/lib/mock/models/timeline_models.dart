/// Mô hình mốc lịch sử trên Trục Thời Gian (M-04)
class TimelineMilestoneModel {
  final String id;
  final String yearLabel;
  final int yearValue;
  final String title;
  final String subtitle;
  final String description;
  final String era;
  final bool isActive;
  final String? eventId;
  final String? badgeText;

  const TimelineMilestoneModel({
    required this.id,
    required this.yearLabel,
    required this.yearValue,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.era,
    this.isActive = false,
    this.eventId,
    this.badgeText,
  });
}
