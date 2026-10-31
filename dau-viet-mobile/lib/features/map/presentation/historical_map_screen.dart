import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/main_bottom_nav.dart';
import '../data/map_location_dto.dart';
import '../data/map_providers.dart';
import '../geo/vietnam_world_map_projection.dart';
import 'location_profile_screen.dart';
import 'widgets/location_preview_sheet.dart';
import 'widgets/vietnam_world_map_view.dart';

/// Giữ enum tương thích chữ ký với `router.dart` (`/map?view=timeline`).
enum ExploreViewMode { timeline, map }

class HistoricalMapScreen extends ConsumerStatefulWidget {
  final ExploreViewMode initialMode;
  final String? initialEventId;
  final String? initialLocationId;

  const HistoricalMapScreen({
    super.key,
    this.initialMode = ExploreViewMode.map,
    this.initialEventId,
    this.initialLocationId,
  });

  @override
  ConsumerState<HistoricalMapScreen> createState() =>
      _HistoricalMapScreenState();
}

class _HistoricalMapScreenState extends ConsumerState<HistoricalMapScreen>
    with TickerProviderStateMixin {
  final TransformationController _camera = TransformationController();
  final GlobalKey _mapKey = GlobalKey();
  AnimationController? _cameraAnim;

  String? _eventId;
  String? _periodCode;
  String? _kind;
  bool _unlockedOnly = false;
  String? _selectedId;
  bool _hasAppliedDeepLink = false;
  bool _hasRedirectedTimeline = false;
  bool _hasFittedVietnam = false;

  @override
  void initState() {
    super.initState();
    _eventId = widget.initialEventId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasRedirectedTimeline &&
        widget.initialMode == ExploreViewMode.timeline) {
      _hasRedirectedTimeline = true;
      final router = GoRouter.maybeOf(context);
      if (router != null && _hasJourneyRoute(router.configuration.routes)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/journey');
        });
      }
    }
  }

  bool _hasJourneyRoute(List<RouteBase> routes) {
    for (final r in routes) {
      if (r is GoRoute && (r.path == '/journey' || r.path == 'journey')) {
        return true;
      }
      if (_hasJourneyRoute(r.routes)) return true;
    }
    return false;
  }

  Size? get _viewport {
    final box = _mapKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.size;
  }

  void _animateCamera(Matrix4 target) {
    _cameraAnim?.dispose();
    final begin = Matrix4.copy(_camera.value);
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    final animation = Matrix4Tween(begin: begin, end: target).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOutCubic),
    );
    controller.addListener(() => _camera.value = animation.value);
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        controller.dispose();
        if (identical(_cameraAnim, controller)) _cameraAnim = null;
      }
    });
    _cameraAnim = controller;
    controller.forward();
  }

  void _fitVietnam() {
    final vp = _viewport;
    if (vp == null) return;
    _animateCamera(VietnamWorldMapProjection.fitVietnam(vp));
  }

  void _fitLocations(Iterable<MapLocationDto> locations) {
    final vp = _viewport;
    if (vp == null) return;
    _animateCamera(VietnamWorldMapProjection.fitLocations(locations, vp));
  }

  void _focusLocation(MapLocationDto location) {
    final vp = _viewport;
    if (vp == null) return;
    _animateCamera(VietnamWorldMapProjection.focusLocation(location, vp));
  }

  void _zoomBy(double factor) {
    final vp = _viewport;
    if (vp == null) return;
    final scale = (_camera.value.getMaxScaleOnAxis() * factor).clamp(0.22, 6.0);
    final center = Offset(vp.width / 2, vp.height / 2);
    final world = VietnamWorldMapProjection.screenToWorld(center, _camera.value);
    _animateCamera(
      VietnamWorldMapProjection.focusWorld(world, viewport: vp, scale: scale),
    );
  }

  Future<void> _openLesson(MapLocationDto loc) async {
    final lesson = loc.actionableLesson;
    if (lesson == null || !lesson.accessible) return;
    await context.push('/learning/lesson/${lesson.lessonId}');
    if (mounted) ref.invalidate(mapLocationsProvider);
  }

  Future<void> _openEvent(MapLocationDto loc) async {
    final targetEventId = loc.primaryEventId;
    if (targetEventId == null || targetEventId.isEmpty) return;
    await context.push('/campaign/$targetEventId');
    if (mounted) ref.invalidate(mapLocationsProvider);
  }

  void _showProfile(MapLocationDto loc) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => LocationProfileSheet(
        initialLocation: loc,
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

  void _showPreview(MapLocationDto loc) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      builder: (ctx) => LocationPreviewSheet(
        location: loc,
        onOpenProfile: () {
          Navigator.of(ctx).pop();
          _showProfile(loc);
        },
        onOpenLesson: loc.actionableLesson?.accessible == true
            ? () {
                Navigator.of(ctx).pop();
                _openLesson(loc);
              }
            : null,
        onOpenEvent: loc.primaryEventId == null
            ? null
            : () {
                Navigator.of(ctx).pop();
                _openEvent(loc);
              },
      ),
    );
  }

  void _selectLocation(MapLocationDto loc) {
    setState(() => _selectedId = loc.id);
    if (loc.hasReliableGeographicCoordinate) {
      _focusLocation(loc);
    }
    _showPreview(loc);
  }

  void _applyDeepLink(List<MapLocationDto> locations) {
    if (_hasAppliedDeepLink) return;
    _hasAppliedDeepLink = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final locationId = widget.initialLocationId;
      if (locationId != null) {
        MapLocationDto? target;
        for (final loc in locations) {
          if (loc.id == locationId) {
            target = loc;
            break;
          }
        }
        if (target != null) {
          setState(() => _selectedId = target!.id);
          if (target.hasReliableGeographicCoordinate) {
            _focusLocation(target);
          } else {
            _fitVietnam();
          }
          _showProfile(target);
          return;
        }
      }
      if (_eventId != null && _eventId!.isNotEmpty) {
        final focused = locations.where((l) => l.matchesEvent(_eventId)).toList();
        if (focused.any((l) => l.hasReliableGeographicCoordinate)) {
          _fitLocations(focused);
          return;
        }
      }
      _fitVietnam();
    });
  }

  List<MapLocationDto> _visible(List<MapLocationDto> raw) {
    return raw.where((l) => l.shouldDisplayOnMap).where((l) {
      if (_eventId != null && _eventId!.isNotEmpty && !l.matchesEvent(_eventId)) {
        return false;
      }
      if (_periodCode != null &&
          _periodCode!.isNotEmpty &&
          !l.matchesPeriod(_periodCode)) {
        return false;
      }
      if (_kind != null &&
          _kind!.isNotEmpty &&
          l.kind.toUpperCase() != _kind!.toUpperCase()) {
        return false;
      }
      if (_unlockedOnly && !l.unlocked) return false;
      return true;
    }).toList();
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }
    context.go('/dashboard');
  }

  @override
  void dispose() {
    _cameraAnim?.dispose();
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(mapLocationsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFD7E4EC),
      appBar: AppBar(
        backgroundColor: DauVietColors.paperCard,
        elevation: 0,
        iconTheme: const IconThemeData(color: DauVietColors.inkText),
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _goBack,
        ),
        title: Text('Bản đồ Di sản', style: DauVietTypography.headlineSmall),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Bộ lọc',
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () => async.whenOrNull(
              data: (raw) => _openFilter(raw),
            ),
          ),
        ],
      ),
      body: async.when(
        loading: () =>
            AsyncStateView.loading(message: 'Đang mở tấm bản đồ cổ...'),
        error: (e, _) => AsyncStateView.error(
          error: e,
          onRetry: () => ref.invalidate(mapLocationsProvider),
        ),
        data: (raw) {
          final allVisible = raw.where((l) => l.shouldDisplayOnMap).toList();
          if (allVisible.isEmpty) {
            return AsyncStateView.empty(
              message:
                  'Chưa có địa điểm nào được mở trên bản đồ. Hoàn thành '
                  'bài học để khám phá thêm dấu ấn lịch sử.',
            );
          }
          final filtered = _visible(raw);
          _applyDeepLink(allVisible);
          if (!_hasFittedVietnam &&
              widget.initialLocationId == null &&
              (widget.initialEventId == null || widget.initialEventId!.isEmpty)) {
            _hasFittedVietnam = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _fitVietnam();
            });
          }
          return Column(
            children: [
              _ContextBar(
                label: _contextLabel(filtered),
                count: filtered.length,
                onPick: () => _openFilter(raw),
              ),
              Expanded(
                child: Stack(
                  key: _mapKey,
                  children: [
                    VietnamWorldMapView(
                      controller: _camera,
                      locations: filtered,
                      selectedId: _selectedId,
                      highlightedIds: {
                        if (_eventId != null && _eventId!.isNotEmpty)
                          for (final loc in filtered)
                            if (loc.matchesEvent(_eventId)) loc.id,
                      },
                      onSelect: _selectLocation,
                      onClusterTap: (cluster) => _fitLocations(cluster.members),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 16,
                      child: _ZoomControls(
                        onZoomIn: () => _zoomBy(1.35),
                        onZoomOut: () => _zoomBy(1 / 1.35),
                        onReset: () {
                          setState(() {
                            _eventId = null;
                            _periodCode = null;
                            _kind = null;
                            _unlockedOnly = false;
                            _selectedId = null;
                          });
                          _fitVietnam();
                        },
                      ),
                    ),
                    Positioned(
                      left: 12,
                      bottom: 16,
                      right: 72,
                      child: Text(
                        VietnamWorldMapProjection.attribution,
                        maxLines: 2,
                        style: DauVietTypography.labelSmall.copyWith(
                          fontSize: 9,
                          color: const Color(0xFF3A4A42),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const MainBottomNav(),
    );
  }

  String _contextLabel(List<MapLocationDto> filtered) {
    if (_eventId != null && _eventId!.isNotEmpty) {
      for (final loc in filtered) {
        for (final ev in loc.events) {
          if (ev.eventId == _eventId && ev.title.trim().isNotEmpty) {
            return ev.title;
          }
        }
        if (loc.eventId == _eventId &&
            loc.eventTitle != null &&
            loc.eventTitle!.trim().isNotEmpty) {
          return loc.eventTitle!;
        }
      }
      return 'Sự kiện đã chọn';
    }
    if (_periodCode != null && _periodCode!.isNotEmpty) {
      for (final loc in filtered) {
        for (final ev in loc.events) {
          if ((ev.periodCode ?? '').toUpperCase() == _periodCode!.toUpperCase()) {
            return ev.periodTitle ?? _periodCode!;
          }
        }
      }
      return _periodCode!;
    }
    return 'Tất cả Việt Nam';
  }

  Future<void> _openFilter(List<MapLocationDto> raw) async {
    final visible = raw.where((l) => l.shouldDisplayOnMap).toList();
    final events = <_FilterOption>[];
    final seenEvents = <String>{};
    final periods = <_FilterOption>[];
    final seenPeriods = <String>{};
    final kinds = <_FilterOption>[];
    final seenKinds = <String>{};
    final unlocated = <MapLocationDto>[];
    for (final loc in visible) {
      if (!loc.hasReliableGeographicCoordinate) unlocated.add(loc);
      final eventId = loc.primaryEventId;
      final eventTitle = loc.primaryEventTitle;
      if (eventId != null && seenEvents.add(eventId)) {
        events.add(_FilterOption(eventId, eventTitle ?? 'Sự kiện'));
      }
      for (final ev in loc.events) {
        if (ev.eventId.isNotEmpty && seenEvents.add(ev.eventId)) {
          events.add(_FilterOption(ev.eventId, ev.title));
        }
        final code = ev.periodCode?.trim() ?? '';
        if (code.isNotEmpty && seenPeriods.add(code.toUpperCase())) {
          periods.add(_FilterOption(code, ev.periodTitle ?? code));
        }
      }
      if (seenKinds.add(loc.kind.toUpperCase())) {
        kinds.add(_FilterOption(loc.kind, loc.kindLabelVi));
      }
    }
    events.sort((a, b) => a.label.compareTo(b.label));
    periods.sort((a, b) => a.label.compareTo(b.label));

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFFFBF6EA),
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text('Bộ lọc bản đồ', style: DauVietTypography.headlineSmall),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tất cả Việt Nam'),
                trailing: _eventId == null && _periodCode == null
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () {
                  setState(() {
                    _eventId = null;
                    _periodCode = null;
                  });
                  Navigator.pop(ctx);
                  _fitVietnam();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Chỉ địa điểm đã mở khoá'),
                value: _unlockedOnly,
                onChanged: (v) => setState(() => _unlockedOnly = v),
              ),
              if (kinds.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Loại địa điểm', style: DauVietTypography.labelMedium),
                Wrap(
                  spacing: 6,
                  children: [
                    ChoiceChip(
                      label: const Text('Tất cả'),
                      selected: _kind == null,
                      onSelected: (_) => setState(() => _kind = null),
                    ),
                    for (final k in kinds)
                      ChoiceChip(
                        label: Text(k.label),
                        selected: _kind == k.id,
                        onSelected: (_) => setState(() => _kind = k.id),
                      ),
                  ],
                ),
              ],
              if (events.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Sự kiện', style: DauVietTypography.labelMedium),
                for (final ev in events)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(ev.label),
                    trailing: _eventId == ev.id
                        ? const Icon(Icons.check_rounded)
                        : null,
                    onTap: () {
                      setState(() {
                        _eventId = ev.id;
                        _periodCode = null;
                      });
                      Navigator.pop(ctx);
                      final focused = visible
                          .where((l) => l.matchesEvent(ev.id))
                          .toList();
                      _fitLocations(focused);
                    },
                  ),
              ],
              if (periods.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Thời kỳ', style: DauVietTypography.labelMedium),
                for (final p in periods)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(p.label),
                    trailing: _periodCode == p.id
                        ? const Icon(Icons.check_rounded)
                        : null,
                    onTap: () {
                      setState(() {
                        _periodCode = p.id;
                        _eventId = null;
                      });
                      Navigator.pop(ctx);
                      final focused = visible
                          .where((l) => l.matchesPeriod(p.id))
                          .toList();
                      _fitLocations(focused);
                    },
                  ),
              ],
              if (unlocated.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Chưa định vị (${unlocated.length})',
                  style: DauVietTypography.labelMedium,
                ),
                for (final loc in unlocated)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(loc.title),
                    subtitle: const Text('Chưa có tọa độ địa lý đáng tin cậy'),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _selectedId = loc.id);
                      _showPreview(loc);
                    },
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _FilterOption {
  final String id;
  final String label;
  const _FilterOption(this.id, this.label);
}

class _ContextBar extends StatelessWidget {
  final String label;
  final int count;
  final VoidCallback onPick;

  const _ContextBar({
    required this.label,
    required this.count,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xF2FFF8EC),
      child: InkWell(
        onTap: onPick,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.public_rounded, size: 16, color: Color(0xFF1A5642)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DauVietTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$count địa điểm',
                style: DauVietTypography.labelSmall.copyWith(
                  color: DauVietColors.inkMuted,
                ),
              ),
              const Icon(Icons.expand_more_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZoomControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;

  const _ZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _RoundBtn(icon: Icons.add_rounded, tooltip: 'Phóng to', onTap: onZoomIn),
        const SizedBox(height: 8),
        _RoundBtn(
          icon: Icons.remove_rounded,
          tooltip: 'Thu nhỏ',
          onTap: onZoomOut,
        ),
        const SizedBox(height: 8),
        _RoundBtn(
          icon: Icons.center_focus_strong_rounded,
          tooltip: 'Về toàn cảnh',
          onTap: onReset,
        ),
      ],
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _RoundBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xF6FFF8EC),
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, size: 20, color: const Color(0xFF1A5642)),
          ),
        ),
      ),
    );
  }
}
