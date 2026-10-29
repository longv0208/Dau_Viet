import 'package:dau_viet_mobile/core/api/api_error.dart';
import 'package:dau_viet_mobile/core/api/api_exception.dart';
import 'package:dau_viet_mobile/features/learning_path/data/learning_path_dto.dart';
import 'package:dau_viet_mobile/features/learning_path/data/learning_path_providers.dart';
import 'package:dau_viet_mobile/features/learning_path/data/learning_path_repository.dart';
import 'package:dau_viet_mobile/features/map/data/map_location_dto.dart';
import 'package:dau_viet_mobile/features/map/data/map_providers.dart';
import 'package:dau_viet_mobile/features/map/data/map_repository.dart';
import 'package:dau_viet_mobile/features/map/presentation/event_action_sheet.dart';
import 'package:dau_viet_mobile/features/map/presentation/historical_map_screen.dart';
import 'package:dau_viet_mobile/features/map/presentation/path_event_node.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakePathRepo extends LearningPathRepository {
  LearningPathDto path;
  Object? error;
  final List<String> touchedPeriods = [];

  _FakePathRepo(this.path);

  @override
  Future<LearningPathDto> getMyLearningPath() async {
    if (error != null) throw error!;
    return path;
  }

  @override
  Future<TouchPeriodResponseDto> touchPeriod(String periodCode) async {
    touchedPeriods.add(periodCode);
    path = path.copyWith(lastPeriodCode: periodCode);
    return TouchPeriodResponseDto(
      periodCode: periodCode,
      chapterId: 'ch-$periodCode',
    );
  }

  @override
  Future<LearningPathDto> getPublishedLearningPath({
    String code = defaultLearningPathCode,
  }) async {
    return getMyLearningPath();
  }
}

class _FakeMapRepo implements MapRepository {
  final Map<String, List<MapLocationDto>> byEventId;
  final List<MapLocationDto> all;

  _FakeMapRepo({this.byEventId = const {}, List<MapLocationDto>? all})
    : all = all ?? const [];
  @override
  Future<List<MapLocationDto>> listLocations({
    String? periodCode,
    String? eventId,
    String? kind,
    bool? unlocked,
  }) async {
    if (eventId != null && eventId.isNotEmpty) {
      return byEventId[eventId] ?? const [];
    }
    return all;
  }

  @override
  Future<MapLocationDto> getLocationDetail(String locationId) async {
    for (final locs in byEventId.values) {
      for (final l in locs) {
        if (l.id == locationId) return l;
      }
    }
    throw const ApiException(
      ApiError(code: 'NOT_FOUND', message: 'not found'),
    );
  }
}

LearningPathDto _path({required List<LearningPathChapterDto> chapters}) {
  return LearningPathDto(
    pathCode: 'HISTORY_MAIN',
    pathVersion: 1,
    enrolled: true,
    chapters: chapters,
    lastPeriodCode: chapters.isNotEmpty ? chapters.first.code : null,
  );
}

LearningPathChapterDto _period({
  required String id,
  required String code,
  required String title,
  String? parentId,
  int sortOrder = 0,
  List<LearningPathEventNodeDto> events = const [],
}) {
  return LearningPathChapterDto(
    chapterId: id,
    parentId: parentId,
    nodeType: PathNodeType.period,
    code: code,
    title: title,
    sortOrder: sortOrder,
    events: events,
  );
}

LearningPathEventNodeDto _event({
  required String nodeId,
  required String eventId,
  required String title,
  LearnerPathStatus status = LearnerPathStatus.available,
  int sortOrder = 0,
  List<LearningPathLessonNodeDto> lessons = const [],
}) {
  return LearningPathEventNodeDto(
    eventNodeId: nodeId,
    eventId: eventId,
    title: title,
    yearLabel: 'Năm 938',
    sortOrder: sortOrder,
    status: status,
    lessons: lessons,
  );
}

const _lesson = LearningPathLessonNodeDto(
  lessonId: 'les-1',
  title: 'Trận Bạch Đằng',
  sortOrder: 0,
  status: LearnerPathStatus.available,
);

void main() {
  Widget buildApp(
    _FakePathRepo pathRepo, {
    _FakeMapRepo? mapRepo,
    List<RouteBase>? extraRoutes,
  }) {
    final router = GoRouter(
      initialLocation: '/map',
      routes: [
        GoRoute(
          path: '/map',
          builder: (_, state) => HistoricalMapScreen(
            initialPeriodCode: state.uri.queryParameters['period'],
          ),
        ),
        GoRoute(
          path: '/learning/lesson/:lessonId',
          builder: (_, state) => Scaffold(
            body: Text('LESSON:${state.pathParameters['lessonId']}'),
          ),
        ),
        GoRoute(
          path: '/campaign/:eventId',
          builder: (_, state) => Scaffold(
            body: Text('CAMPAIGN:${state.pathParameters['eventId']}'),
          ),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (_, _) => const Scaffold(body: Text('DASHBOARD')),
        ),
        ...?extraRoutes,
      ],
    );
    return ProviderScope(
      overrides: [
        learningPathRepositoryProvider.overrideWithValue(pathRepo),
        if (mapRepo != null) mapRepositoryProvider.overrideWithValue(mapRepo),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  group('HistoricalMapScreen — learning-path axis (Issue #36)', () {
    testWidgets(
      'AC-1 & AC-2: render nút sự kiện theo lộ trình, bài không gắn di tích vẫn hiển thị',
      (tester) async {
        tester.view.physicalSize = const Size(412, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final path = _path(
          chapters: [
            _period(
              id: 'p1',
              code: 'EARLY_INDEPENDENCE',
              title: 'Buổi đầu độc lập tự chủ',
              events: [
                _event(
                  nodeId: 'n1',
                  eventId: 'evt-bach-dang',
                  title: 'Đại Chiến Bạch Đằng 938',
                  status: LearnerPathStatus.available,
                  lessons: const [_lesson],
                ),
                _event(
                  nodeId: 'n2',
                  eventId: 'evt-no-location',
                  title: 'Sự kiện không có di tích',
                  status: LearnerPathStatus.locked,
                  lessons: const [
                    LearningPathLessonNodeDto(
                      lessonId: 'les-2',
                      title: 'Bài khóa',
                      sortOrder: 0,
                      status: LearnerPathStatus.locked,
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
        final pathRepo = _FakePathRepo(path);
        final mapRepo = _FakeMapRepo(
          byEventId: {
            'evt-bach-dang': [
              const MapLocationDto(
                id: 'loc-1',
                eventId: 'evt-bach-dang',
                title: 'Bãi cọc Bạch Đằng',
                latitude: 20.9,
                longitude: 106.8,
                unlocked: true,
                unlockState: MapUnlockState.unlocked,
              ),
            ],
            // evt-no-location: không có địa điểm nào.
          },
        );

        await tester.pumpWidget(buildApp(pathRepo, mapRepo: mapRepo));
        await tester.pumpAndSettle();

        // Cả 2 sự kiện đều render — kể cả sự kiện không gắn di tích (AC-2).
        expect(find.byType(PathEventNode), findsNWidgets(2));
        expect(find.text('Đại Chiến Bạch Đằng 938'), findsWidgets);
        expect(find.text('Sự kiện không có di tích'), findsWidgets);

        // Legend trục học.
        expect(find.text('Đã hoàn thành'), findsOneWidget);
        expect(find.text('Sẵn sàng'), findsOneWidget);
        expect(find.text('Đang khóa'), findsWidgets);
      },
    );

    testWidgets(
      'AC-1: chạm nút AVAILABLE mở sheet và CTA "BẮT ĐẦU HỌC" điều hướng thẳng lesson',
      (tester) async {
        tester.view.physicalSize = const Size(412, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final path = _path(
          chapters: [
            _period(
              id: 'p1',
              code: 'EARLY_INDEPENDENCE',
              title: 'Buổi đầu độc lập tự chủ',
              events: [
                _event(
                  nodeId: 'n1',
                  eventId: 'evt-bach-dang',
                  title: 'Đại Chiến Bạch Đằng 938',
                  status: LearnerPathStatus.available,
                  lessons: const [_lesson],
                ),
              ],
            ),
          ],
        );
        final pathRepo = _FakePathRepo(path);

        await tester.pumpWidget(buildApp(pathRepo));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Đại Chiến Bạch Đằng 938').first);
        await tester.pumpAndSettle();

        expect(find.byType(EventActionSheet), findsOneWidget);
        expect(find.text('BẮT ĐẦU HỌC'), findsOneWidget);
        expect(find.text('Chi tiết chiến dịch'), findsOneWidget);

        await tester.tap(find.text('BẮT ĐẦU HỌC'));
        await tester.pumpAndSettle();
        expect(find.text('LESSON:les-1'), findsOneWidget);
      },
    );

    testWidgets(
      'AC-1: nút LOCKED hiện điều kiện, không có CTA học',
      (tester) async {
        tester.view.physicalSize = const Size(412, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final path = _path(
          chapters: [
            _period(
              id: 'p1',
              code: 'P1',
              title: 'Thời kỳ',
              events: [
                _event(
                  nodeId: 'n1',
                  eventId: 'evt-locked',
                  title: 'Sự kiện khóa',
                  status: LearnerPathStatus.locked,
                  lessons: const [_lesson],
                ),
              ],
            ),
          ],
        );
        await tester.pumpWidget(buildApp(_FakePathRepo(path)));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Sự kiện khóa').first);
        await tester.pumpAndSettle();

        expect(find.text('BẮT ĐẦU HỌC'), findsNothing);
        expect(find.text('TIẾP TỤC HỌC'), findsNothing);
        expect(find.textContaining('Hoàn thành sự kiện trước'), findsOneWidget);
      },
    );

    testWidgets(
      'AC-3: ghim di tích vệ tinh chỉ hiện khi địa điểm đã unlocked',
      (tester) async {
        tester.view.physicalSize = const Size(412, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final path = _path(
          chapters: [
            _period(
              id: 'p1',
              code: 'P1',
              title: 'Thời kỳ',
              events: [
                _event(
                  nodeId: 'n1',
                  eventId: 'evt-bd',
                  title: 'Sự kiện Bạch Đằng',
                  status: LearnerPathStatus.available,
                  lessons: const [_lesson],
                ),
              ],
            ),
          ],
        );
        final mapRepo = _FakeMapRepo(
          byEventId: {
            'evt-bd': [
              const MapLocationDto(
                id: 'loc-open',
                eventId: 'evt-bd',
                title: 'Bãi cọc đã mở',
                latitude: 20.9,
                longitude: 106.8,
                unlocked: true,
                unlockState: MapUnlockState.unlocked,
              ),
              const MapLocationDto(
                id: 'loc-locked-hidden',
                eventId: 'evt-bd',
                title: 'Di tích ẩn khi khóa',
                latitude: 21.0,
                longitude: 106.9,
                unlocked: false,
                unlockState: MapUnlockState.locked,
                visibility: 'HIDDEN_UNTIL_UNLOCKED',
              ),
            ],
          },
        );

        await tester.pumpWidget(
          buildApp(_FakePathRepo(path), mapRepo: mapRepo),
        );
        await tester.pumpAndSettle();

        // Ghim vệ tinh chỉ cho địa điểm đã mở.
        expect(
          find.bySemanticsLabel('Địa điểm Bãi cọc đã mở — đã mở khóa'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Địa điểm Di tích ẩn khi khóa — đã mở khóa'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'đổi chặng gọi touchPeriod và hiển thị sự kiện của chặng mới',
      (tester) async {
        tester.view.physicalSize = const Size(412, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final path = _path(
          chapters: [
            _period(
              id: 'p1',
              code: 'PERIOD_A',
              title: 'Thời kỳ A',
              sortOrder: 0,
              events: [
                _event(
                  nodeId: 'n1',
                  eventId: 'evt-a',
                  title: 'Sự kiện A',
                  lessons: const [_lesson],
                ),
              ],
            ),
            _period(
              id: 'p2',
              code: 'PERIOD_B',
              title: 'Thời kỳ B',
              sortOrder: 1,
              events: [
                _event(
                  nodeId: 'n2',
                  eventId: 'evt-b',
                  title: 'Sự kiện B',
                  lessons: const [_lesson],
                ),
              ],
            ),
          ],
        );
        final pathRepo = _FakePathRepo(path);
        await tester.pumpWidget(buildApp(pathRepo));
        await tester.pumpAndSettle();

        // Chặng đầu tiên auto-touch.
        expect(pathRepo.touchedPeriods, contains('PERIOD_A'));
        expect(find.text('Sự kiện A'), findsWidgets);
        expect(find.text('Sự kiện B'), findsNothing);

        await tester.tap(find.byTooltip('Chặng sau'));
        await tester.pumpAndSettle();

        expect(pathRepo.touchedPeriods, contains('PERIOD_B'));
        expect(find.text('Sự kiện B'), findsWidgets);
        expect(find.text('Sự kiện A'), findsNothing);
      },
    );

    testWidgets(
      '?period= deep-link chọn đúng chặng ban đầu',
      (tester) async {
        tester.view.physicalSize = const Size(412, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final path = _path(
          chapters: [
            _period(
              id: 'p1',
              code: 'PERIOD_A',
              title: 'Thời kỳ A',
              sortOrder: 0,
              events: [
                _event(
                  nodeId: 'n1',
                  eventId: 'evt-a',
                  title: 'Sự kiện A',
                  lessons: const [_lesson],
                ),
              ],
            ),
            _period(
              id: 'p2',
              code: 'PERIOD_B',
              title: 'Thời kỳ B',
              sortOrder: 1,
              events: [
                _event(
                  nodeId: 'n2',
                  eventId: 'evt-b',
                  title: 'Sự kiện B',
                  lessons: const [_lesson],
                ),
              ],
            ),
          ],
        );
        final router = GoRouter(
          initialLocation: '/map?period=PERIOD_B',
          routes: [
            GoRoute(
              path: '/map',
              builder: (_, state) => HistoricalMapScreen(
                initialPeriodCode: state.uri.queryParameters['period'],
              ),
            ),
          ],
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              learningPathRepositoryProvider.overrideWithValue(
                _FakePathRepo(path),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sự kiện B'), findsWidgets);
        expect(find.text('Sự kiện A'), findsNothing);
      },
    );

    testWidgets('error state có retry gọi lại repository', (tester) async {
      final repo = _FakePathRepo(_path(chapters: const []))
        ..error = const ApiException(
          ApiError(code: 'NETWORK_ERROR', message: 'down'),
        );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [learningPathRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: HistoricalMapScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Chưa tải được sử liệu'), findsOneWidget);

      repo.error = null;
      repo.path = _path(
        chapters: [
          _period(
            id: 'p1',
            code: 'P1',
            title: 'Thời kỳ',
            events: [
              _event(
                nodeId: 'n1',
                eventId: 'evt-1',
                title: 'Sự kiện 1',
                lessons: const [_lesson],
              ),
            ],
          ),
        ],
      );
      await tester.tap(find.text('THỬ LẠI'));
      await tester.pumpAndSettle();
      expect(find.text('Sự kiện 1'), findsWidgets);
    });
  });
}
