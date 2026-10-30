import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../data/map_location_dto.dart';

/// Cuốn Sách Lịch Sử Mở Ra — trình bày hồ sơ địa điểm di sản theo 3
/// phần có cấu trúc (Tóm tắt Sự kiện · Câu chuyện & Diễn biến ·
/// Tư liệu & Dấu tích), nền giấy dó ấm `#F8F0E0`, viền đôi vàng kim
/// `#D5B886`, chữ cái đầu đoạn phóng lớn (Drop-cap) và thanh điều
/// khiển cỡ chữ `A-`/`A+`.
class HistoricalStorybookReader extends StatefulWidget {
  final MapLocationDto location;
  final VoidCallback? onOpenEvent;
  final VoidCallback? onOpenLesson;
  final ValueChanged<String>? onOpenEventById;
  final ValueChanged<String>? onOpenPeriodByCode;
  final ValueChanged<MapLocationUnlockLessonDto>? onOpenLessonItem;

  const HistoricalStorybookReader({
    super.key,
    required this.location,
    this.onOpenEvent,
    this.onOpenLesson,
    this.onOpenEventById,
    this.onOpenPeriodByCode,
    this.onOpenLessonItem,
  });

  @override
  State<HistoricalStorybookReader> createState() =>
      _HistoricalStorybookReaderState();
}

class _HistoricalStorybookReaderState
    extends State<HistoricalStorybookReader> {
  double _fontScale = 1.0;

  MapLocationDto get location => widget.location;

  /// Văn bản chương "Câu chuyện & Diễn biến": ưu tiên `storyNarrative`,
  /// sau đó `primaryEvent.description`. `location.description` được hiển
  /// thị riêng nguyên văn bên trên để giữ tương thích các test tra
  /// `find.text(location.description)`.
  String get _narrativeText {
    if (location.storyNarrative != null &&
        location.storyNarrative!.trim().isNotEmpty) {
      return location.storyNarrative!.trim();
    }
    final primary = _primaryEvent;
    if (primary?.description != null &&
        primary!.description!.trim().isNotEmpty) {
      return primary.description!.trim();
    }
    return '';
  }

  MapLocationLinkedEventDto? get _primaryEvent {
    if (location.events.isEmpty) return null;
    for (final e in location.events) {
      if (e.role.trim().toUpperCase() == 'PRIMARY') return e;
    }
    return location.events.first;
  }

  List<MapLocationMediaDto> get _docMedia =>
      location.videoMedia.where((m) => m.isVideoOrAudioMedia).toList();

  @override
  Widget build(BuildContext context) {
    final double bodySize = 14 * _fontScale;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F0E0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD5B886), width: 3),
      ),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD5B886)),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBookHeader(),
            const SizedBox(height: 10),
            _buildChapterBar(),
            const SizedBox(height: 12),
            _buildPart1Summary(bodySize),
            const SizedBox(height: 12),
            _buildPart2Narrative(bodySize),
            const SizedBox(height: 12),
            _buildPart3Artifacts(bodySize),
          ],
        ),
      ),
    );
  }

  Widget _buildBookHeader() {
    return Row(
      children: [
        const Icon(
          Icons.menu_book_rounded,
          size: 18,
          color: DauVietColors.cinnabarRed,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CUỐN SÁCH LỊCH SỬ',
                style: DauVietTypography.sectionEyebrow.copyWith(
                  fontSize: 10,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                location.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: DauVietTypography.headlineSmall.copyWith(
                  color: DauVietColors.inkHeading,
                ),
              ),
            ],
          ),
        ),
        // A- / A+ controls
        _FontButton(
          label: 'A-',
          onTap: () => setState(() {
            _fontScale = (_fontScale - 0.1).clamp(0.8, 1.4);
          }),
        ),
        const SizedBox(width: 4),
        _FontButton(
          label: 'A+',
          onTap: () => setState(() {
            _fontScale = (_fontScale + 0.1).clamp(0.8, 1.4);
          }),
        ),
      ],
    );
  }

  Widget _buildChapterBar() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: const [
        _ChapterChip(label: 'I. Tóm tắt'),
        _ChapterChip(label: 'II. Câu chuyện'),
        _ChapterChip(label: 'III. Tư liệu & Dấu tích'),
      ],
    );
  }

  // ─── Phần 1 ──────────────────────────────────────────────────────────

  Widget _buildPart1Summary(double bodySize) {
    final primary = _primaryEvent;
    final rows = <_SummaryRow>[];

    final eventTitle =
        location.eventTitle ?? primary?.title ?? 'Sự kiện lịch sử';
    final yearLabel = primary?.yearLabel;
    final periodTitle = primary?.periodTitle;

    rows.add(
      _SummaryRow(
        label: 'Sự kiện & Thời gian',
        value: [
          if (eventTitle.trim().isNotEmpty) eventTitle,
          if (yearLabel != null && yearLabel.trim().isNotEmpty) yearLabel,
          if (periodTitle != null && periodTitle.trim().isNotEmpty)
            periodTitle,
        ].join(' • '),
      ),
    );
    rows.add(
      _SummaryRow(
        label: 'Phân loại địa điểm',
        value: location.kindLabelVi,
      ),
    );
    if (location.keyFigures != null &&
        location.keyFigures!.trim().isNotEmpty) {
      rows.add(
        _SummaryRow(
          label: 'Nhân vật lịch sử',
          value: location.keyFigures!.trim(),
        ),
      );
    }

    final summaryBody = <String>[
      if (location.shortSummary != null &&
          location.shortSummary!.trim().isNotEmpty)
        location.shortSummary!.trim(),
      if (primary?.summary != null && primary!.summary!.trim().isNotEmpty)
        primary.summary!.trim(),
    ].join('\n');

    return _BookSection(
      sectionKey: const Key('storybook-part-summary'),
      heading: 'PHẦN 1 — TÓM TẮT SỰ KIỆN & DI TÍCH',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final row in rows) ...[
            _SummaryLine(label: row.label, value: row.value, size: bodySize),
            const SizedBox(height: 4),
          ],
          if (summaryBody.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              summaryBody,
              style: DauVietTypography.bodyMedium.copyWith(
                fontSize: bodySize,
                height: 1.55,
                color: DauVietColors.inkText,
              ),
            ),
          ],
          if (location.historicalSignificance != null &&
              location.historicalSignificance!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: DauVietColors.imperialGoldLight.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: DauVietColors.imperialGold),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ý NGHĨA CỐT LÕI',
                    style: DauVietTypography.labelSmall.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: DauVietColors.woodBrown,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    location.historicalSignificance!,
                    style: DauVietTypography.bodySmall.copyWith(
                      fontSize: bodySize * 0.94,
                      height: 1.45,
                      color: DauVietColors.inkText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Phần 2 ──────────────────────────────────────────────────────────

  Widget _buildPart2Narrative(double bodySize) {
    final narrative = _narrativeText;
    final rawParagraphs = narrative.isEmpty
        ? <String>[]
        : narrative
              .split(RegExp(r'\n{1,}'))
              .map((p) => p.trim())
              .where((p) => p.isNotEmpty)
              .toList();
    final quotes = _extractQuotes(rawParagraphs);
    final paragraphs = rawParagraphs
        .where((p) => !quotes.contains(p))
        .toList();
    return _BookSection(
      sectionKey: const Key('storybook-part-narrative'),
      heading: 'PHẦN 2 — CÂU CHUYỆN & DIỄN BIẾN',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Keep the full plain `location.description` visible so legacy
          // `find.text(location.description)` lookups keep matching.
          if (location.description != null &&
              location.description!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                location.description!,
                style: DauVietTypography.bodySmall.copyWith(
                  fontSize: bodySize * 0.94,
                  height: 1.5,
                  color: DauVietColors.inkSecondary,
                ),
              ),
            ),
          if (paragraphs.isEmpty)
            Text(
              'Nội dung câu chuyện lịch sử đang được biên soạn.',
              style: DauVietTypography.bodySmall.copyWith(
                fontSize: bodySize * 0.94,
                fontStyle: FontStyle.italic,
                color: DauVietColors.inkMuted,
              ),
            )
          else
            for (int i = 0; i < paragraphs.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _DropCapParagraph(
                text: paragraphs[i],
                fontSize: bodySize,
                dropCap: i == 0,
              ),
            ],
          // Historical quote callout — only rendered when `storyNarrative`
          // carries a quoted line (convention: a paragraph starting with
          // `"` or `“`), keeping an unobtrusive slot for sử liệu quotes.
          for (final quote in quotes) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFBF8F1),
                borderRadius: BorderRadius.circular(8),
                border: const Border(
                  left: BorderSide(color: DauVietColors.imperialGold, width: 3),
                ),
              ),
              child: Text(
                quote,
                style: DauVietTypography.ancientCitation.copyWith(
                  fontSize: bodySize,
                  color: DauVietColors.inkHeading,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<String> _extractQuotes(List<String> paragraphs) {
    final quotes = <String>[];
    for (final p in paragraphs) {
      final t = p.trim();
      if (t.startsWith('“') || t.startsWith('"')) {
        quotes.add(t);
      }
    }
    return quotes.take(1).toList();
  }

  // ─── Phần 3 ──────────────────────────────────────────────────────────

  Widget _buildPart3Artifacts(double bodySize) {
    final events = location.events;
    final lessons = location.unlockLessons;
    final docMedia = _docMedia;
    return _BookSection(
      sectionKey: const Key('storybook-part-artifacts'),
      heading: 'PHẦN 3 — TƯ LIỆU & DẤU TÍCH DI SẢN',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (events.isNotEmpty) ...[
            Text(
              'SỰ KIỆN LỊCH SỬ LIÊN QUAN',
              style: DauVietTypography.labelSmall.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: DauVietColors.cinnabarRed,
              ),
            ),
            const SizedBox(height: 6),
            for (final ev in events)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (widget.onOpenEventById != null &&
                          ev.eventId.trim().isNotEmpty) {
                        widget.onOpenEventById!(ev.eventId.trim());
                      } else {
                        widget.onOpenEvent?.call();
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBF8F1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5DAC6)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.history_edu_rounded,
                            size: 16,
                            color: DauVietColors.cinnabarRed,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ev.yearLabel != null &&
                                      ev.yearLabel!.trim().isNotEmpty
                                  ? '${ev.title} (${ev.yearLabel})'
                                  : ev.title,
                              style: DauVietTypography.bodySmall.copyWith(
                                fontSize: bodySize * 0.94,
                                fontWeight: FontWeight.w600,
                                color: DauVietColors.inkText,
                              ),
                            ),
                          ),
                          if (ev.periodCode != null &&
                              ev.periodCode!.trim().isNotEmpty &&
                              widget.onOpenPeriodByCode != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: InkWell(
                                onTap: () => widget.onOpenPeriodByCode!(
                                  ev.periodCode!.trim(),
                                ),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3ECE0),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    ev.periodTitle ?? ev.periodCode!,
                                    style: DauVietTypography.labelSmall
                                        .copyWith(
                                          fontSize: 9.5,
                                          color: DauVietColors.woodBrown,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: DauVietColors.inkMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
          if (lessons.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'BÀI HỌC MỞ KHÓA (${location.unlockModeLabelVi})',
              style: DauVietTypography.labelSmall.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: DauVietColors.cinnabarRed,
              ),
            ),
            const SizedBox(height: 6),
            for (final ul in lessons)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: ul.accessible
                        ? () {
                            if (widget.onOpenLessonItem != null) {
                              widget.onOpenLessonItem!(ul);
                            } else {
                              widget.onOpenLesson?.call();
                            }
                          }
                        : null,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 3,
                        horizontal: 2,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            ul.completed
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 16,
                            color: ul.completed
                                ? DauVietColors.natureGreen
                                : DauVietColors.inkMuted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ul.title,
                              style: DauVietTypography.bodySmall.copyWith(
                                fontSize: bodySize * 0.94,
                                color: DauVietColors.inkText,
                              ),
                            ),
                          ),
                          if (ul.accessible)
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: DauVietColors.inkMuted,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
          if (docMedia.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'TƯ LIỆU PHIM / ÂM THANH',
              style: DauVietTypography.labelSmall.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: DauVietColors.cinnabarRed,
              ),
            ),
            const SizedBox(height: 6),
            for (final m in docMedia)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      m.mediaType.trim().toUpperCase() == 'AUDIO_GUIDE'
                          ? Icons.headphones_rounded
                          : Icons.play_circle_fill_rounded,
                      size: 16,
                      color: DauVietColors.cinnabarRed,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.title,
                            style: DauVietTypography.bodySmall.copyWith(
                              fontSize: bodySize * 0.94,
                              fontWeight: FontWeight.w600,
                              color: DauVietColors.inkText,
                            ),
                          ),
                          if (m.sourceCitation != null &&
                              m.sourceCitation!.trim().isNotEmpty)
                            Text(
                              'Nguồn: ${m.sourceCitation}',
                              style: DauVietTypography.bodySmall.copyWith(
                                fontSize: bodySize * 0.85,
                                fontStyle: FontStyle.italic,
                                color: DauVietColors.woodBrown,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (events.isEmpty && lessons.isEmpty && docMedia.isEmpty)
            Text(
              'Chưa có tư liệu đính kèm cho địa điểm này.',
              style: DauVietTypography.bodySmall.copyWith(
                fontSize: bodySize * 0.94,
                fontStyle: FontStyle.italic,
                color: DauVietColors.inkMuted,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Nội bộ ────────────────────────────────────────────────────────────

class _SummaryRow {
  final String label;
  final String value;
  const _SummaryRow({required this.label, required this.value});
}

class _SummaryLine extends StatelessWidget {
  final String label;
  final String value;
  final double size;
  const _SummaryLine({
    required this.label,
    required this.value,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: DauVietTypography.bodySmall.copyWith(
          fontSize: size,
          height: 1.45,
          color: DauVietColors.inkText,
        ),
        children: [
          TextSpan(
            text: '• $label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: DauVietColors.woodBrown,
            ),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

class _BookSection extends StatelessWidget {
  final Key sectionKey;
  final String heading;
  final Widget child;
  const _BookSection({
    required this.sectionKey,
    required this.heading,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: sectionKey,
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF4E4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5DAC6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: DauVietTypography.labelMedium.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: DauVietColors.cinnabarRed,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ChapterChip extends StatelessWidget {
  final String label;
  const _ChapterChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFE4CE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8C8B0)),
      ),
      child: Text(
        label,
        style: DauVietTypography.labelSmall.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: DauVietColors.woodBrown,
        ),
      ),
    );
  }
}

class _FontButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _FontButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFEFE4CE),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            label,
            style: DauVietTypography.labelMedium.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: DauVietColors.woodBrown,
            ),
          ),
        ),
      ),
    );
  }
}

class _DropCapParagraph extends StatelessWidget {
  final String text;
  final double fontSize;
  final bool dropCap;
  const _DropCapParagraph({
    required this.text,
    required this.fontSize,
    required this.dropCap,
  });

  @override
  Widget build(BuildContext context) {
    if (!dropCap || text.isEmpty) {
      return Text(
        text,
        style: DauVietTypography.bodyMedium.copyWith(
          fontSize: fontSize,
          height: 1.68,
          color: DauVietColors.inkText,
        ),
      );
    }
    final first = text.substring(0, 1);
    final rest = text.substring(1);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2, right: 6),
          child: Text(
            first,
            style: DauVietTypography.headlineLarge.copyWith(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              height: 1.0,
              color: DauVietColors.cinnabarRed,
            ),
          ),
        ),
        Expanded(
          child: Text(
            rest,
            style: DauVietTypography.bodyMedium.copyWith(
              fontSize: fontSize,
              height: 1.68,
              color: DauVietColors.inkText,
            ),
          ),
        ),
      ],
    );
  }
}
