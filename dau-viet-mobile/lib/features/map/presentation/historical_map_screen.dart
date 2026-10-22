import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/parchment_card.dart';
import '../data/map_location_dto.dart';
import '../data/map_providers.dart';
import 'historical_map_painter.dart';

/// FR-35..38 — Bản đồ lịch sử LƯỢC HOẠ với marker theo trạng thái mở
/// khoá do server tính (AVAILABLE / LOCKED / UNLOCKED). Pan/pinch qua
/// InteractiveViewer; marker nằm TRONG child transform nên tap luôn
/// khớp nền. Chạm marker → sheet chi tiết; CTA tới bài học mở khoá hoặc
/// sự kiện. Trên màn hẹp, danh sách bên dưới luôn truy cập được.
class HistoricalMapScreen extends ConsumerStatefulWidget {
  const HistoricalMapScreen({super.key});

  @override
  ConsumerState<HistoricalMapScreen> createState() =>
      _HistoricalMapScreenState();
}

class _HistoricalMapScreenState extends ConsumerState<HistoricalMapScreen> {
  final TransformationController _transform = TransformationController();
  int? _selectedIndex;

  /// Sau khi hoàn thành bài học và quay lại, refresh trạng thái mở khoá.
  /// (Hoàn thành thật cũng invalidate trong lesson_player, đây là lớp
  /// dự phòng khi quay lại từ bất kỳ điều hướng nào.)
  Future<void> _openLesson(MapLocationDto loc) async {
    final lesson = loc.requiredLesson;
    if (lesson == null || !lesson.accessible) return;
    await context.push('/learning/lesson/${lesson.lessonId}');
    if (mounted) ref.invalidate(mapLocationsProvider);
  }

  Future<void> _openEvent(MapLocationDto loc) async {
    await context.push('/campaign/${loc.eventId}');
    if (mounted) ref.invalidate(mapLocationsProvider);
  }

  void _showDetail(MapLocationDto loc) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _LocationDetailSheet(
        location: loc,
        onOpenLesson: () {
          Navigator.of(ctx).pop();
          _openLesson(loc);
        },
        onOpenEvent: () {
          Navigator.of(ctx).pop();
          _openEvent(loc);
        },
      ),
    );
  }

  void _resetView() {
    _transform.value = Matrix4.identity();
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(mapLocationsProvider);
    return Scaffold(
      backgroundColor: DauVietColors.parchmentSurface,
      appBar: AppBar(
        backgroundColor: DauVietColors.parchmentSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: DauVietColors.inkText),
        title: Text('Bản Đồ Dấu Ấn', style: DauVietTypography.headlineSmall),
        actions: [
          IconButton(
            tooltip: 'Về khung nhìn ban đầu',
            icon: const Icon(Icons.fit_screen_rounded),
            onPressed: _resetView,
          ),
          IconButton(
            tooltip: 'Tải lại bản đồ',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(mapLocationsProvider),
          ),
        ],
      ),
      body: SafeArea(
        child: async.when(
          loading: () =>
              AsyncStateView.loading(message: 'Đang mở tấm bản đồ cổ...'),
          error: (e, _) => AsyncStateView.error(
            error: e,
            onRetry: () => ref.invalidate(mapLocationsProvider),
          ),
          data: (locations) {
            if (locations.isEmpty) {
              return AsyncStateView.empty(
                message:
                    'Chưa có địa điểm nào được mở trên bản đồ. Hoàn thành '
                    'bài học để khám phá thêm dấu ấn lịch sử.',
              );
            }
            return Column(
              children: [
                _buildLegend(),
                Expanded(flex: 5, child: _buildMapCanvas(locations)),
                const Divider(height: 1, color: DauVietColors.outlineVariant),
                Expanded(flex: 4, child: _buildLocationList(locations)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              _LegendDot(
                color: DauVietColors.imperialGold,
                label: 'Đã mở khoá',
              ),
              _LegendDot(color: DauVietColors.natureGreen, label: 'Sẵn sàng'),
              _LegendDot(color: DauVietColors.inkLight, label: 'Chưa mở'),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Bản đồ lược hoạ — vị trí tương đối, không phải bản đồ địa lý',
            style: DauVietTypography.bodySmall.copyWith(
              fontSize: 10,
              color: DauVietColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }

  /// Canvas lớn hơn viewport → pan/zoom trong InteractiveViewer vẫn giữ
  /// mật độ chi tiết; marker + nền cùng nằm trong child transform nên
  /// tap không bao giờ lệch projection.
  Widget _buildMapCanvas(List<MapLocationDto> locations) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        // Canvas rộng gấp 1.6 viewport — fit-to-bounds ban đầu phóng to
        // vùng dữ liệu, còn dư để pan quanh.
        final canvas = Size(viewport.width * 1.6, viewport.height * 1.6);
        final bounds = mapDataBounds(locations);
        final markerOffsets = _spreadOffsets(locations, canvas, bounds);
        return InteractiveViewer(
          transformationController: _transform,
          minScale: 0.5,
          maxScale: 5,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(160),
          child: SizedBox(
            width: canvas.width,
            height: canvas.height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: HistoricalMapPainter(locations: locations),
                  ),
                ),
                for (int i = 0; i < locations.length; i++)
                  _markerAt(locations[i], i, markerOffsets[i]),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Offset trung tâm (x, y) của từng marker — cụm điểm project trùng/
  /// chồng nhau được tách dần để marker luôn bấm được.
  List<Offset> _spreadOffsets(
    List<MapLocationDto> locations,
    Size canvas,
    Rect bounds,
  ) {
    final raw = [for (final l in locations) projectLngLat(l, canvas, bounds)];
    final offsets = List<Offset>.of(raw);
    const minGap = 46.0;
    for (var pass = 0; pass < 4; pass++) {
      var moved = false;
      for (var i = 0; i < offsets.length; i++) {
        for (var j = i + 1; j < offsets.length; j++) {
          var delta = offsets[j] - offsets[i];
          var dist = delta.distance;
          if (dist >= minGap) continue;
          if (dist < 0.5) {
            // Trùng tuyệt đối — đẩy theo hướng cố định khác nhau.
            delta = Offset(0.5 * (j - i), 0.5);
            dist = delta.distance;
          }
          final push = delta / dist * (minGap - dist) / 2;
          offsets[i] -= push;
          offsets[j] += push;
          moved = true;
        }
      }
      if (!moved) break;
    }
    return offsets;
  }

  Widget _markerAt(MapLocationDto loc, int index, Offset position) {
    return Positioned(
      left: position.dx - 24,
      top: position.dy - 34,
      child: _MapMarker(
        location: loc,
        selected: _selectedIndex == index,
        onTap: () {
          setState(() => _selectedIndex = index);
          _showDetail(loc);
        },
      ),
    );
  }

  Widget _buildLocationList(List<MapLocationDto> locations) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: locations.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final loc = locations[i];
        return ParchmentCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          onTap: () => _showDetail(loc),
          child: Row(
            children: [
              _StateBadge(state: loc.unlockState),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loc.title, style: DauVietTypography.labelMedium),
                    Text(
                      _subtitle(loc),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DauVietTypography.bodySmall.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: DauVietColors.inkLight,
              ),
            ],
          ),
        );
      },
    );
  }

  String _subtitle(MapLocationDto loc) {
    switch (loc.unlockState) {
      case MapUnlockState.unlocked:
        return 'Đã mở khoá — nhấn để xem chi tiết';
      case MapUnlockState.available:
        return 'Sẵn sàng khám phá';
      case MapUnlockState.locked:
        final lesson = loc.requiredLesson?.title;
        return lesson == null ? 'Chưa mở khoá' : 'Mở khoá bằng: $lesson';
    }
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: DauVietTypography.bodySmall.copyWith(fontSize: 11)),
      ],
    );
  }
}

class _StateBadge extends StatelessWidget {
  final MapUnlockState state;
  const _StateBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (state) {
      MapUnlockState.unlocked => (
        DauVietColors.imperialGold,
        Icons.lock_open_rounded,
      ),
      MapUnlockState.available => (
        DauVietColors.natureGreen,
        Icons.explore_rounded,
      ),
      MapUnlockState.locked => (DauVietColors.inkLight, Icons.lock_rounded),
    };
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.4),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _MapMarker extends StatelessWidget {
  final MapLocationDto location;
  final bool selected;
  final VoidCallback onTap;

  const _MapMarker({
    required this.location,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (location.unlockState) {
      MapUnlockState.unlocked => (
        DauVietColors.imperialGold,
        Icons.lock_open_rounded,
      ),
      MapUnlockState.available => (
        DauVietColors.natureGreen,
        Icons.place_rounded,
      ),
      MapUnlockState.locked => (DauVietColors.inkLight, Icons.lock_rounded),
    };
    return Semantics(
      button: true,
      label: '${location.title} — ${_stateLabel(location.unlockState)}',
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: selected ? 44 : 38,
              height: selected ? 44 : 38,
              decoration: BoxDecoration(
                color: DauVietColors.parchmentDim,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: selected ? 2.6 : 1.8),
                boxShadow: DauVietColors.heritageShadow,
              ),
              child: Icon(icon, size: selected ? 22 : 18, color: color),
            ),
            const SizedBox(height: 2),
            Container(
              constraints: const BoxConstraints(maxWidth: 110),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: DauVietColors.parchmentDim.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                location.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DauVietTypography.labelSmall.copyWith(fontSize: 9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _stateLabel(MapUnlockState s) => switch (s) {
    MapUnlockState.unlocked => 'đã mở khoá',
    MapUnlockState.available => 'sẵn sàng khám phá',
    MapUnlockState.locked => 'chưa mở khoá',
  };
}

class _LocationDetailSheet extends StatelessWidget {
  final MapLocationDto location;
  final VoidCallback onOpenLesson;
  final VoidCallback onOpenEvent;

  const _LocationDetailSheet({
    required this.location,
    required this.onOpenLesson,
    required this.onOpenEvent,
  });

  @override
  Widget build(BuildContext context) {
    final locked = location.unlockState == MapUnlockState.locked;
    final lesson = location.requiredLesson;
    // CTA bài học chỉ hiện khi có link VÀ lesson vẫn mở được cho learner
    // (server cờ accessible=false khi lesson bị draft/archived sau đó).
    final canOpenLesson = lesson != null && lesson.accessible;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: ParchmentCard(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _StateBadge(state: location.unlockState),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          location.title,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                          style: DauVietTypography.headlineSmall,
                        ),
                      ),
                    ],
                  ),
                  if (location.eventTitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Thuộc sự kiện: ${location.eventTitle}',
                      style: DauVietTypography.bodySmall.copyWith(
                        fontSize: 12,
                        color: DauVietColors.inkMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    location.description ?? 'Địa điểm lịch sử.',
                    style: DauVietTypography.bodySmall.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tọa độ: ${location.latitude.toStringAsFixed(4)}, '
                    '${location.longitude.toStringAsFixed(4)}',
                    style: DauVietTypography.bodySmall.copyWith(
                      fontSize: 11,
                      color: DauVietColors.inkMuted,
                    ),
                  ),
                  if (lesson != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: locked
                            ? DauVietColors.inkLight.withValues(alpha: 0.12)
                            : DauVietColors.imperialGoldLight.withValues(
                                alpha: 0.35,
                              ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            locked
                                ? Icons.lock_rounded
                                : Icons.lock_open_rounded,
                            size: 16,
                            color: locked
                                ? DauVietColors.inkMuted
                                : DauVietColors.woodBrown,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _lessonBlurb(locked, lesson),
                              style: DauVietTypography.bodySmall.copyWith(
                                fontSize: 12,
                                color: DauVietColors.inkText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, c) {
                      final eventBtn = DongSonButton(
                        label: 'XEM SỰ KIỆN',
                        variant: DongSonButtonVariant.secondaryParchment,
                        height: 44,
                        onPressed: onOpenEvent,
                      );
                      if (!canOpenLesson) {
                        return Row(children: [Expanded(child: eventBtn)]);
                      }
                      final lessonBtn = DongSonButton(
                        label: locked ? 'HỌC ĐỂ MỞ' : 'ÔN BÀI HỌC',
                        icon: locked
                            ? Icons.lock_rounded
                            : Icons.play_arrow_rounded,
                        variant: DongSonButtonVariant.primaryCinnabar,
                        height: 44,
                        onPressed: onOpenLesson,
                      );
                      // Màn hẹp → xếp dọc, tránh overflow hai nút dài.
                      if (c.maxWidth < 360) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            lessonBtn,
                            const SizedBox(height: 10),
                            eventBtn,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: eventBtn),
                          const SizedBox(width: 12),
                          Expanded(child: lessonBtn),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _lessonBlurb(bool locked, RequiredLessonRef lesson) {
    if (locked) {
      return lesson.accessible
          ? 'Hoàn thành bài học "${lesson.title}" để mở khoá'
          : 'Địa điểm này yêu cầu bài học "${lesson.title}" — bài học '
                'đang được cập nhật, quay lại sau';
    }
    return 'Đã mở qua bài học "${lesson.title}"';
  }
}
