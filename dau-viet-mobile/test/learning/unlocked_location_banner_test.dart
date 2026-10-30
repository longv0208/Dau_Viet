import 'dart:async';

import 'package:dau_viet_mobile/features/learning/data/attempt_dtos.dart';
import 'package:dau_viet_mobile/features/learning/data/learning_dtos.dart';
import 'package:dau_viet_mobile/features/learning/data/learning_providers.dart';
import 'package:dau_viet_mobile/features/learning/presentation/lesson_player_screen.dart';
import 'package:dau_viet_mobile/features/learning/presentation/lesson_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../fakes/fake_attempt_repository.dart';

const _locBachDang = UnlockedLocationCueDto(
  locationId: 'loc-bach-dang-01',
  slug: 'bai-coc-bach-dang',
  title: 'Bãi cọc Bạch Đằng (Yên Giang)',
  kind: 'HERITAGE_SITE',
  coverAssetId: 'asset-cover-01',
);

const _locNamTrieu = UnlockedLocationCueDto(
  locationId: 'loc-nam-trieu-02',
  slug: 'cua-song-nam-trieu',
  title: 'Cửa sông Nam Triệu',
  kind: 'BATTLEFIELD',
);

void main() {
  group('UnlockedLocationBanner & LessonResultScreen (E5 - Issue #25)', () {
    testWidgets('ẩn hoàn toàn khi newlyUnlockedLocations rỗng', (tester) async {
      final repo = FakeAttemptRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [attemptRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(
            home: LessonResultScreen(
              attemptId: 'a-1',
              initialResult: LessonResultDto(
                attemptId: 'a-1',
                lessonVersionId: 'v-1',
                status: 'COMPLETED',
                score: 95,
                result: {'summary': 'Hoàn thành xuất sắc'},
                newlyUnlockedLocations: [],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UnlockedLocationBanner), findsNothing);
      expect(find.text('ĐỊA ĐIỂM DI SẢN VỪA MỞ KHÓA'), findsNothing);
      expect(find.text('Xem địa điểm'), findsNothing);
      expect(find.text('Tiếp tục học'), findsNothing);
    });

    testWidgets(
      'hiển thị banner, thông tin địa điểm và 2 nút Xem địa điểm / Tiếp tục học khi newlyUnlockedLocations không rỗng',
      (tester) async {
        final repo = FakeAttemptRepository();
        UnlockedLocationCueDto? viewedLocation;
        bool continued = false;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [attemptRepositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(
              home: LessonResultScreen(
                attemptId: 'a-1',
                initialResult: const LessonResultDto(
                  attemptId: 'a-1',
                  lessonVersionId: 'v-1',
                  status: 'COMPLETED',
                  score: 100,
                  result: {},
                  newlyUnlockedLocations: [_locBachDang, _locNamTrieu],
                ),
                onViewLocation: (loc) => viewedLocation = loc,
                onContinueLearning: () => continued = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(UnlockedLocationBanner), findsOneWidget);
        expect(find.text('ĐÃ MỞ KHÓA 2 ĐỊA ĐIỂM DI SẢN'), findsOneWidget);
        expect(find.text('Bãi cọc Bạch Đằng (Yên Giang)'), findsOneWidget);
        expect(find.text('Di tích lịch sử'), findsOneWidget);
        expect(find.text('Cửa sông Nam Triệu'), findsOneWidget);
        expect(find.text('Chiến trường cổ'), findsOneWidget);
        expect(find.text('Xem địa điểm'), findsOneWidget);
        expect(find.text('Tiếp tục học'), findsOneWidget);

        await tester.ensureVisible(find.text('Xem địa điểm'));
        await tester.tap(find.text('Xem địa điểm'));
        await tester.pump();
        expect(viewedLocation?.locationId, 'loc-bach-dang-01');

        await tester.ensureVisible(find.text('Tiếp tục học'));
        await tester.tap(find.text('Tiếp tục học'));
        await tester.pump();
        expect(continued, isTrue);
      },
    );

    testWidgets(
      'nút Xem địa điểm ưu tiên /map?locationId=:locationId (mở LocationProfileSheet) và Tiếp tục học điều hướng tới /campaign/:eventId hoặc /journey',
      (tester) async {
        final repo = FakeAttemptRepository()
          ..metadata = const LessonMetadataDto(
            id: 'l-1',
            eventId: 'evt-bach-dang-938',
            title: 'Trận Bạch Đằng 938',
          )
          ..content = const LessonContentDto(
            lessonId: 'l-1',
            lessonVersionId: 'v-1',
            content: {'title': 'Trận Bạch Đằng 938'},
          );
        String? visitedMapLocationId;
        String? visitedCampaignEventId;

        final router = GoRouter(
          initialLocation: '/learning/result/a-1',
          initialExtra: const LessonResultDto(
            attemptId: 'a-1',
            lessonVersionId: 'v-1',
            status: 'COMPLETED',
            score: 100,
            result: {},
            newlyUnlockedLocations: [_locBachDang],
          ),
          routes: [
            GoRoute(
              path: '/learning/result/:attemptId',
              builder: (context, state) => LessonResultScreen(
                attemptId: state.pathParameters['attemptId']!,
                initialResult: state.extra is LessonResultDto
                    ? state.extra as LessonResultDto
                    : null,
              ),
            ),
            GoRoute(
              path: '/heritage/:locationId',
              builder: (context, state) => Scaffold(
                body: Text('HERITAGE:${state.pathParameters['locationId']}'),
              ),
            ),
            GoRoute(
              path: '/campaign/:eventId',
              builder: (context, state) {
                visitedCampaignEventId = state.pathParameters['eventId'];
                return Scaffold(
                  body: Text('CAMPAIGN:$visitedCampaignEventId'),
                );
              },
            ),
            GoRoute(
              path: '/journey',
              builder: (context, state) =>
                  const Scaffold(body: Text('JOURNEY_SCREEN')),
            ),
            GoRoute(
              path: '/map',
              builder: (context, state) {
                visitedMapLocationId = state.uri.queryParameters['locationId'];
                return Scaffold(
                  body: Text('MAP_SCREEN:${visitedMapLocationId ?? ''}'),
                );
              },
            ),
            GoRoute(
              path: '/dashboard',
              builder: (context, state) =>
                  const Scaffold(body: Text('DASHBOARD_HOME')),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [attemptRepositoryProvider.overrideWithValue(repo)],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('ĐỊA ĐIỂM DI SẢN VỪA MỞ KHÓA'), findsOneWidget);

        await tester.ensureVisible(find.text('Xem địa điểm'));
        await tester.tap(find.text('Xem địa điểm'));
        await tester.pumpAndSettle();

        expect(visitedMapLocationId, 'loc-bach-dang-01');
        expect(find.text('MAP_SCREEN:loc-bach-dang-01'), findsOneWidget);

        // Quay lại màn kết quả rồi bấm Tiếp tục học -> điều hướng về /campaign/evt-bach-dang-938
        router.go(
          '/learning/result/a-1',
          extra: const LessonResultDto(
            attemptId: 'a-1',
            lessonVersionId: 'v-1',
            status: 'COMPLETED',
            score: 100,
            result: {},
            newlyUnlockedLocations: [_locBachDang],
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Tiếp tục học'));
        await tester.tap(find.text('Tiếp tục học'));
        await tester.pumpAndSettle();

        expect(visitedCampaignEventId, 'evt-bach-dang-938');
        expect(find.text('CAMPAIGN:evt-bach-dang-938'), findsOneWidget);
      },
    );

    testWidgets(
      'AC: hoàn thành từ player phát animation 1 lần; deep-link mở lại kết quả không phát lại animation',
      (tester) async {
        final repo = FakeAttemptRepository()
          ..onGetCurrent = (() => const CurrentActivityDto(
            progress: AttemptProgressDto(
              completedRequired: 2,
              totalRequired: 2,
            ),
          ))
          ..completeResult = const CompleteResultDto(
            attemptId: 'a-1',
            status: 'COMPLETED',
            alreadyCompleted: false,
            completion: CompletionVerdictDto(complete: true),
            progress: AttemptProgressDto(
              completedRequired: 2,
              totalRequired: 2,
            ),
            newlyUnlockedLocations: [_locBachDang],
          )
          ..result = const LessonResultDto(
            attemptId: 'a-1',
            lessonVersionId: 'v-1',
            status: 'COMPLETED',
            score: 100,
            result: {'summary': 'Thắng lợi Bạch Đằng'},
          );

        final router = GoRouter(
          initialLocation: '/learning/attempt/a-1',
          routes: [
            GoRoute(
              path: '/learning/attempt/:id',
              builder: (context, state) =>
                  LessonPlayerScreen(attemptId: state.pathParameters['id']!),
            ),
            GoRoute(
              path: '/learning/result/:id',
              builder: (context, state) => LessonResultScreen(
                attemptId: state.pathParameters['id']!,
                initialResult: state.extra is LessonResultDto
                    ? state.extra as LessonResultDto
                    : null,
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [attemptRepositoryProvider.overrideWithValue(repo)],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Hoàn thành bài học từ player → chuyển sang màn kết quả kèm extra
        await tester.tap(find.text('HOÀN THÀNH BÀI HỌC'));
        await tester.pumpAndSettle();

        expect(find.byType(UnlockedLocationBanner), findsOneWidget);
        expect(find.text('Bãi cọc Bạch Đằng (Yên Giang)'), findsOneWidget);

        final bannerState = tester.state<UnlockedLocationBannerState>(
          find.byType(UnlockedLocationBanner),
        );
        expect(bannerState.hasAnimated, isTrue);
        expect(bannerState.animationRunCount, 1);

        // 2. Mở lại kết quả qua deep-link (không có state.extra)
        router.go('/learning/result/a-1');
        await tester.pumpAndSettle();

        // GET /result không trả newlyUnlockedLocations → không hiện lại banner / không phát lại animation
        expect(find.text('HOÀN THÀNH BÀI HỌC'), findsOneWidget);
        expect(find.byType(UnlockedLocationBanner), findsNothing);
      },
    );

    testWidgets(
      'AC: deep-link mở trực tiếp (initialResult == null) không phát animation kể cả khi dữ liệu có newlyUnlockedLocations, và rebuild không phát lại animation',
      (tester) async {
        final contentCompleter = Completer<LessonContentDto>();
        final repo = _DelayedContentFakeAttemptRepository(contentCompleter)
          ..result = const LessonResultDto(
            attemptId: 'a-1',
            lessonVersionId: 'v-1',
            status: 'COMPLETED',
            score: 90,
            result: {},
            newlyUnlockedLocations: [_locBachDang],
          );

        // 1. Deep-link mount (initialResult: null) → isFreshCompletion = false → animate = false
        await tester.pumpWidget(
          ProviderScope(
            overrides: [attemptRepositoryProvider.overrideWithValue(repo)],
            child: const MaterialApp(
              home: LessonResultScreen(attemptId: 'a-1'),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(UnlockedLocationBanner), findsOneWidget);
        final deepLinkState = tester.state<UnlockedLocationBannerState>(
          find.byType(UnlockedLocationBanner),
        );
        expect(deepLinkState.hasAnimated, isFalse);
        expect(deepLinkState.animationRunCount, 0);
        expect(deepLinkState.animationController.isAnimating, isFalse);
        expect(deepLinkState.animationController.value, 1.0);

        // 2. Khi _recapContentProvider hoàn tất khiến LessonResultScreen rebuild,
        // animation vẫn tuyệt đối không phát lại.
        contentCompleter.complete(
          const LessonContentDto(
            lessonId: 'l-1',
            lessonVersionId: 'v-1',
            content: {'title': 'Trận Bạch Đằng 938'},
          ),
        );
        await tester.pumpAndSettle();

        expect(deepLinkState.hasAnimated, isFalse);
        expect(deepLinkState.animationRunCount, 0);
      },
    );

    test(
      'BUG-01: LessonResultDto.fromJson parse newlyUnlockedLocations & newlyUnlockedDossiers từ top-level và fallback result.unlockedLocations / result.unlockedDossiers',
      () {
        final topLevelDto = LessonResultDto.fromJson({
          'attemptId': 'a-top',
          'lessonVersionId': 'v-1',
          'status': 'COMPLETED',
          'score': 95,
          'result': {'summary': 'Đạt'},
          'newlyUnlockedDossiers': ['dossier-01', 'dossier-02'],
          'newlyUnlockedLocations': [
            {
              'locationId': 'loc-bach-dang-01',
              'slug': 'bai-coc-bach-dang',
              'title': 'Bãi cọc Bạch Đằng (Yên Giang)',
              'kind': 'HERITAGE_SITE',
            },
          ],
        });
        expect(
          topLevelDto.newlyUnlockedDossiers,
          equals(['dossier-01', 'dossier-02']),
        );
        expect(topLevelDto.newlyUnlockedLocations, hasLength(1));
        expect(
          topLevelDto.newlyUnlockedLocations.first.locationId,
          'loc-bach-dang-01',
        );

        final fallbackDto = LessonResultDto.fromJson({
          'attemptId': 'a-fallback',
          'lessonVersionId': 'v-1',
          'status': 'COMPLETED',
          'score': 100,
          'result': {
            'summary': 'Thắng lợi Bạch Đằng',
            'unlockedDossiers': ['dossier-ngo-quyen'],
            'unlockedLocations': [
              {
                'locationId': 'loc-nam-trieu-02',
                'slug': 'cua-song-nam-trieu',
                'title': 'Cửa sông Nam Triệu',
                'kind': 'BATTLEFIELD',
              },
            ],
          },
        });
        expect(
          fallbackDto.newlyUnlockedDossiers,
          equals(['dossier-ngo-quyen']),
        );
        expect(fallbackDto.newlyUnlockedLocations, hasLength(1));
        expect(
          fallbackDto.newlyUnlockedLocations.first.title,
          'Cửa sông Nam Triệu',
        );
      },
    );

    testWidgets(
      'BUG-01: reload LessonResultScreen (initialResult == null) vẫn hiển thị UnlockedLocationBanner và _DossierUnlockBanner từ GET /attempts/{id}/result mà không phát lại animation',
      (tester) async {
        final parsedReloadResult = LessonResultDto.fromJson({
          'attemptId': 'a-reload',
          'lessonVersionId': 'v-1',
          'status': 'COMPLETED',
          'score': 100,
          'result': {
            'summary': 'Hoàn thành xuất sắc',
            'unlockedDossiers': ['dossier-bach-dang-01'],
            'unlockedLocations': [_locBachDang.toJson()],
          },
        });
        final repo = FakeAttemptRepository()..result = parsedReloadResult;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [attemptRepositoryProvider.overrideWithValue(repo)],
            child: const MaterialApp(
              home: LessonResultScreen(attemptId: 'a-reload'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(UnlockedLocationBanner), findsOneWidget);
        expect(find.text('Bãi cọc Bạch Đằng (Yên Giang)'), findsOneWidget);
        expect(find.text('ĐÃ MỞ KHÓA 1 HỒ SƠ LỊCH SỬ'), findsOneWidget);

        final bannerState = tester.state<UnlockedLocationBannerState>(
          find.byType(UnlockedLocationBanner),
        );
        expect(bannerState.hasAnimated, isFalse);
        expect(bannerState.animationRunCount, 0);
      },
    );
  });
}

class _DelayedContentFakeAttemptRepository extends FakeAttemptRepository {
  final Completer<LessonContentDto> _completer;
  _DelayedContentFakeAttemptRepository(this._completer);

  @override
  Future<LessonContentDto> getAttemptContent(String attemptId) =>
      _completer.future;
}
