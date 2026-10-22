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

/// FR-35..38 — Bản đồ lịch sử với marker theo trạng thái mở khoá do server
/// tính (AVAILABLE / LOCKED / UNLOCKED). Chạm marker → thẻ chi tiết;
/// CTA đưa learner tới bài học mở khoá hoặc sự kiện. Trên máy thật màn
/// hẹp, danh sách bên dưới luôn truy cập được (list fallback).
class HistoricalMapScreen extends ConsumerStatefulWidget {
  const HistoricalMapScreen({super.key});

  @override
  ConsumerState<HistoricalMapScreen> createState() =>
      _HistoricalMapScreenState();
}

class _HistoricalMapScreenState extends ConsumerState<HistoricalMapScreen> {
  int? _selectedIndex;

  /// Sau khi hoàn thành bài học và quay lại, refresh trạng thái mở khoá.
  Future<void> _openLesson(MapLocationDto loc) async {
    final lessonId = loc.requiredLesson?.lessonId;
    if (lessonId == null) return;
    await context.push('/learning/lesson/$lessonId');
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: const [
          _LegendDot(color: DauVietColors.imperialGold, label: 'Đã mở khoá'),
          _LegendDot(color: DauVietColors.natureGreen, label: 'Sẵn sàng'),
          _LegendDot(color: DauVietColors.inkLight, label: 'Chưa mở'),
        ],
      ),
    );
  }

  Widget _buildMapCanvas(List<MapLocationDto> locations) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final painter = HistoricalMapPainter(locations: locations);
        // Project tọa độ thật vào canvas.
        const fallback = Rect.fromLTRB(104.5, 20.0, 107.5, 22.5);
        Rect bounds = fallback;
        if (locations.isNotEmpty) {
          double minLng = locations.first.longitude;
          double maxLng = minLng;
          double minLat = locations.first.latitude;
          double maxLat = minLat;
          for (final l in locations) {
            minLng = l.longitude < minLng ? l.longitude : minLng;
            maxLng = l.longitude > maxLng ? l.longitude : maxLng;
            minLat = l.latitude < minLat ? l.latitude : minLat;
            maxLat = l.latitude > maxLat ? l.latitude : maxLat;
          }
          final spanLng = (maxLng - minLng).clamp(0.6, 180.0);
          final spanLat = (maxLat - minLat).clamp(0.6, 90.0);
          bounds = Rect.fromLTRB(
            minLng - spanLng * 0.15,
            minLat - spanLat * 0.15,
            maxLng + spanLng * 0.15,
            maxLat + spanLat * 0.15,
          );
        }
        return Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: painter)),
            for (int i = 0; i < locations.length; i++)
              _positionedMarker(locations[i], i, size, bounds),
          ],
        );
      },
    );
  }

  Widget _positionedMarker(
    MapLocationDto loc,
    int index,
    Size size,
    Rect bounds,
  ) {
    final dx = ((loc.longitude - bounds.left) / bounds.width).clamp(0.03, 0.97);
    final dy = (1 - (loc.latitude - bounds.top) / bounds.height).clamp(
      0.05,
      0.95,
    );
    return Positioned(
      left: dx * size.width - 20,
      top: dy * size.height - 28,
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ParchmentCard(
        padding: const EdgeInsets.all(20),
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
                    style: DauVietTypography.headlineSmall,
                  ),
                ),
              ],
            ),
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
            if (location.requiredLesson != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: locked
                      ? DauVietColors.inkLight.withValues(alpha: 0.12)
                      : DauVietColors.imperialGoldLight.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                      size: 16,
                      color: locked
                          ? DauVietColors.inkMuted
                          : DauVietColors.woodBrown,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        locked
                            ? 'Hoàn thành bài học '
                                  '"${location.requiredLesson!.title}" để mở khoá'
                            : 'Đã mở qua bài học '
                                  '"${location.requiredLesson!.title}"',
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
            Row(
              children: [
                Expanded(
                  child: DongSonButton(
                    label: 'XEM SỰ KIỆN',
                    variant: DongSonButtonVariant.secondaryParchment,
                    height: 44,
                    onPressed: onOpenEvent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DongSonButton(
                    label: locked ? 'HỌC ĐỂ MỞ' : 'ÔN BÀI HỌC',
                    icon: locked
                        ? Icons.lock_rounded
                        : Icons.play_arrow_rounded,
                    variant: DongSonButtonVariant.primaryCinnabar,
                    height: 44,
                    onPressed: location.requiredLesson == null
                        ? null
                        : onOpenLesson,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
