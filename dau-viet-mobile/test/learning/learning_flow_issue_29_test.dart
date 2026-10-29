import 'package:dau_viet_mobile/core/api/api_error.dart';
import 'package:dau_viet_mobile/core/api/api_exception.dart';
import 'package:dau_viet_mobile/core/audio/dau_viet_audio_service.dart';
import 'package:dau_viet_mobile/core/widgets/gold_confetti_overlay.dart';
import 'package:dau_viet_mobile/core/widgets/kabi_mascot_widget.dart';
import 'package:dau_viet_mobile/core/widgets/mascot_speech_bubble.dart';
import 'package:dau_viet_mobile/core/widgets/sound_toggle_button.dart';
import 'package:dau_viet_mobile/core/widgets/shimmer_progress_bar.dart';
import 'package:dau_viet_mobile/features/energy/data/energy_dto.dart';
import 'package:dau_viet_mobile/features/energy/data/energy_providers.dart';
import 'package:dau_viet_mobile/features/learning/data/attempt_dtos.dart';
import 'package:dau_viet_mobile/features/learning/data/learning_dtos.dart';
import 'package:dau_viet_mobile/features/learning/data/learning_providers.dart';
import 'package:dau_viet_mobile/features/learning/presentation/lesson_entry_screen.dart';
import 'package:dau_viet_mobile/features/learning/presentation/lesson_player_screen.dart';
import 'package:dau_viet_mobile/features/learning/presentation/lesson_result_screen.dart';
import 'package:dau_viet_mobile/features/learning/presentation/renderers/activity_renderer.dart';
import 'package:dau_viet_mobile/features/meta/presentation/energy_management_screen.dart';
import 'package:dau_viet_mobile/features/rewards/data/reward_dtos.dart';
import 'package:dau_viet_mobile/features/saban/presentation/battle_saban_screen.dart';
import 'package:dau_viet_mobile/features/streak/data/streak_dto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../fakes/fake_attempt_repository.dart';
import '../fakes/fake_energy_repository.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Nhóm A (TC-NAV-05, TC-NAV-08, TC-NAV-09) — LessonEntryScreen', () {
    testWidgets(
      'TC-NAV-08: hiển thị tiêu đề, câu hỏi lịch sử trung tâm trên thẻ giấy dó, mục tiêu và nhãn BẮT ĐẦU HỌC › / TIẾP TỤC BÀI HỌC ›',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = FakeAttemptRepository()
          ..metadata = const LessonMetadataDto(
            id: 'l-bd-1',
            title: 'Trận Bạch Đằng năm 938',
            centralQuestion:
                'Vì sao Ngô Quyền có thể đánh bại thủy quân Nam Hán trên sông Bạch Đằng?',
            eventId: 'evt-bd-938',
            objectivesJson:
                '["Phân tích địa hình cửa sông Bạch Đằng", "Đánh giá vai trò của trận địa cọc ngầm"]',
          );

        // 1. Chế độ Bắt đầu mới (chưa có attempt IN_PROGRESS)
        await tester.pumpWidget(
          ProviderScope(
            overrides: [attemptRepositoryProvider.overrideWithValue(repo)],
            child: const MaterialApp(
              home: LessonEntryScreen(lessonId: 'l-bd-1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Trận Bạch Đằng năm 938'), findsOneWidget);
        expect(find.text('CÂU HỎI LỊCH SỬ TRUNG TÂM'), findsOneWidget);
        expect(
          find.textContaining('Vì sao Ngô Quyền có thể đánh bại'),
          findsOneWidget,
        );
        expect(find.text('MỤC TIÊU KHÁM PHÁ'), findsOneWidget);
        expect(
          find.text('Phân tích địa hình cửa sông Bạch Đằng'),
          findsOneWidget,
        );
        expect(find.text('BẮT ĐẦU HỌC ›'), findsOneWidget);
        expect(find.text('TIẾP TỤC BÀI HỌC ›'), findsNothing);

        // 2. Chế độ Tiếp tục bài học (đang có attempt IN_PROGRESS)
        repo.progressOverride = const MyProgressDto(
          completedCount: 0,
          inProgress: [
            AttemptSummaryDto(
              attemptId: 'att-resume-1',
              lessonId: 'l-bd-1',
              lessonVersionId: 'v-1',
              status: 'IN_PROGRESS',
              progress: AttemptProgressDto(
                completedRequired: 2,
                totalRequired: 5,
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [attemptRepositoryProvider.overrideWithValue(repo)],
            child: const MaterialApp(
              home: LessonEntryScreen(lessonId: 'l-bd-1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Đang học dở — đã hoàn thành 2/5 hoạt động'),
          findsOneWidget,
        );
        expect(find.text('TIẾP TỤC BÀI HỌC ›'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-NAV-05 & TC-NAV-09: xử lý lỗi 403 LESSON_LOCKED_BY_PATH kèm nút QUAY LẠI LỘ TRÌNH và Error + Retry khi tải metadata',
      (tester) async {
        final repo = FakeAttemptRepository()
          ..metadataError = const ApiException(
            ApiError(
              code: 'NETWORK_ERROR',
              message: 'Mất kết nối máy chủ bài học',
            ),
          );

        String? currentRoute;
        final router = GoRouter(
          initialLocation: '/learning/lesson/l-locked',
          routes: [
            GoRoute(
              path: '/learning/lesson/:id',
              builder: (_, state) =>
                  LessonEntryScreen(lessonId: state.pathParameters['id']!),
            ),
            GoRoute(
              path: '/journey',
              builder: (_, _) {
                currentRoute = '/journey';
                return const Scaffold(body: Text('JOURNEY_SCREEN'));
              },
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

        // Error state + Retry
        expect(find.text('THỬ LẠI'), findsOneWidget);

        // Retry thành công tải metadata, nhưng startOrResume trả 403 LESSON_LOCKED_BY_PATH
        repo.metadataError = null;
        await tester.tap(find.text('THỬ LẠI'));
        await tester.pumpAndSettle();
        expect(find.text('BẮT ĐẦU HỌC ›'), findsOneWidget);

        repo.startError = const ApiException(
          ApiError(
            code: 'LESSON_LOCKED_BY_PATH',
            message: 'Cần hoàn thành bài học trước trong lộ trình.',
          ),
          statusCode: 403,
        );
        await tester.ensureVisible(find.text('BẮT ĐẦU HỌC ›'));
        await tester.tap(find.text('BẮT ĐẦU HỌC ›'));
        await tester.pumpAndSettle();

        expect(
          find.text('Cần hoàn thành bài học trước trong lộ trình.'),
          findsOneWidget,
        );
        expect(find.text('QUAY LẠI LỘ TRÌNH'), findsOneWidget);

        await tester.tap(find.text('QUAY LẠI LỘ TRÌNH'));
        await tester.pumpAndSettle();
        expect(currentRoute, '/journey');
      },
    );
  });

  group('Nhóm B (TC-PLAYER-01..09) — LessonPlayerScreen Shell & Mascot', () {
    testWidgets(
      'TC-PLAYER-01, TC-PLAYER-02, TC-PLAYER-07: Header Energy/Streak/Sound và Mascot không báo nhầm câu 2 đáp án chữ dài là Đúng/Sai',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final energyRepo = FakeEnergyRepository()
          ..next = EnergyStateDto(current: 85, max: 100);
        final repo = FakeAttemptRepository()
          ..onGetCurrent = () => CurrentActivityDto(
            stage: const StageRefDto(
              id: 's-reason',
              type: 'REASONING',
              title: 'Suy luận chiến thuật',
            ),
            activity: ActivityRefDto.fromJson(const {
              'id': 'mcq-long-2',
              'type': 'MULTIPLE_CHOICE',
              'instruction': 'Chọn nhận định đúng nhất về địa hình Bạch Đằng.',
              'config': {
                'question':
                    'Vì sao Ngô Quyền chọn cửa sông Bạch Đằng làm nơi quyết chiến?',
                'multiSelect': false,
                'options': [
                  {
                    'id': 'opt-1',
                    'label':
                        'Quân Nam Hán đi đúng vào bãi cọc ngầm khi thủy triều đang dâng cao và bị chặn đánh lúc triều rút.',
                  },
                  {
                    'id': 'opt-2',
                    'label':
                        'Hoằng Thao phạm sai lầm khi chia nhỏ thuyền chiến đi đường bộ qua vùng núi hiểm trở.',
                  },
                ],
              },
            }),
            progress: const AttemptProgressDto(
              completedRequired: 1,
              totalRequired: 4,
            ),
          );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              attemptRepositoryProvider.overrideWithValue(repo),
              energyRepositoryProvider.overrideWithValue(energyRepo),
            ],
            child: const MaterialApp(
              home: LessonPlayerScreen(attemptId: 'att-1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Header elements & Energy badge
        expect(find.text('Suy luận chiến thuật'), findsOneWidget);
        expect(find.text('1/4'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('player-header-energy')),
          findsOneWidget,
        );
        expect(find.text('85'), findsOneWidget);
        expect(find.byType(SoundToggleButton), findsOneWidget);
        expect(find.byType(MascotSpeechBubble), findsOneWidget);
        expect(find.byType(KabiMascotWidget), findsWidgets);

        // Câu 2 lựa chọn chữ dài (dù chứa từ "đúng"/"sai" trong câu) KHÔNG bị nhận nhầm là câu Đúng/Sai
        expect(find.textContaining('chọn Đúng hoặc Sai'), findsNothing);
        expect(
          find.text(
            'Hãy phân tích sử liệu và chọn phương án chính xác nhất nhé!',
          ),
          findsOneWidget,
        );

        // TC-PLAYER-07: Toggle sound button
        final bool initialSound = DauVietAudioService.instance.isSoundEnabled;
        await tester.tap(find.byType(SoundToggleButton));
        await tester.pump();
        expect(DauVietAudioService.instance.isSoundEnabled, !initialSound);
        // Khôi phục trạng thái âm thanh
        DauVietAudioService.instance.setSoundEnabled(initialSound);
      },
    );

    testWidgets(
      'TC-PLAYER-08: Chặn truy cập Attempt của người học khác (403 ATTEMPT_NOT_OWNER) hiển thị nút VỀ TRANG CHỦ an toàn',
      (tester) async {
        final repo = FakeAttemptRepository()
          ..nextError = const ApiException(
            ApiError(
              code: 'ATTEMPT_NOT_OWNER',
              message: 'Bạn không có quyền truy cập lượt học này.',
            ),
            statusCode: 403,
          );

        final router = GoRouter(
          initialLocation: '/learning/attempt/other-user-attempt',
          routes: [
            GoRoute(
              path: '/learning/attempt/:id',
              builder: (_, state) =>
                  LessonPlayerScreen(attemptId: state.pathParameters['id']!),
            ),
            GoRoute(
              path: '/dashboard',
              builder: (_, _) => const Scaffold(body: Text('SAFE_DASHBOARD')),
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

        expect(find.text('VỀ TRANG CHỦ'), findsOneWidget);
        await tester.tap(find.text('VỀ TRANG CHỦ'));
        await tester.pumpAndSettle();
        expect(find.text('SAFE_DASHBOARD'), findsOneWidget);
      },
    );
  });

  group('Nhóm C (TC-ACT-01..20) — Kiểm thử Chi tiết 14 Activity Renderers', () {
    testWidgets(
      'TC-ACT-01: READ hiển thị sections[] và trích dẫn cổ thư callout',
      (tester) async {
        Map<String, dynamic>? submitted;
        final activity = ActivityRefDto.fromJson(const {
          'id': 'act-read-1',
          'type': 'READ',
          'config': {
            'title': 'Bối cảnh sông Bạch Đằng năm 938',
            'body':
                'Mùa đông năm 938, quân Nam Hán tiến vào vùng biển Đông Bắc.',
            'sections': [
              {
                'title': 'Địa thế hiểm yếu',
                'body': 'Lòng sông rộng, thủy triều lên xuống mạnh.',
              },
            ],
            'callout':
                '“Hoằng Thao là đứa trẻ khờ dại, đem quân từ xa đến, tình thế rất nguy.” — Đại Việt sử ký toàn thư',
            'source': 'Đại Việt sử ký toàn thư',
          },
        });

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ActivityRenderer(
                    activity: activity,
                    content: const LessonContentDto(
                      lessonId: 'l',
                      lessonVersionId: 'v',
                      content: {},
                    ),
                    submitting: false,
                    onSubmit: (a) async => submitted = a,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Địa thế hiểm yếu'), findsOneWidget);
        expect(
          find.textContaining('Hoằng Thao là đứa trẻ khờ dại'),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('ĐÃ ĐỌC XONG, TIẾP TỤC'));
        await tester.tap(find.text('ĐÃ ĐỌC XONG, TIẾP TỤC'));
        await tester.pump();
        expect(submitted, isEmpty);
      },
    );

    testWidgets(
      'TC-ACT-04 & TC-ERR-01: EXPLORE_MAP khôi phục priorOutputs và không đánh dấu visited khi submit lỗi mạng',
      (tester) async {
        final List<Map<String, dynamic>> calls = [];
        bool failSubmit = true;

        Widget buildMap({required bool hasError}) {
          return ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ActivityRenderer(
                    activity: ActivityRefDto.fromJson(const {
                      'id': 'map-1',
                      'type': 'EXPLORE_MAP',
                      'config': {
                        'prompt':
                            'Khám phá 2 điểm chiến lược trên sông Bạch Đằng',
                        'minMarkers': 2,
                        'markers': [
                          {'id': 'm1', 'label': 'Cửa biển Nam Triệu'},
                          {'id': 'm2', 'label': 'Bãi cọc Yên Giang'},
                        ],
                        'priorOutputs': {
                          'map-1': {
                            'discoveredMarkerIds': ['m1'],
                          },
                        },
                      },
                    }),
                    content: const LessonContentDto(
                      lessonId: 'l',
                      lessonVersionId: 'v',
                      content: {},
                    ),
                    submitting: false,
                    hasSubmitError: hasError,
                    onSubmit: (a) async {
                      calls.add(a);
                      if (failSubmit) {
                        throw Exception('Network error');
                      }
                    },
                  ),
                ),
              ),
            ),
          );
        }

        await tester.pumpWidget(buildMap(hasError: false));
        await tester.pumpAndSettle();

        // Hydrated m1 from priorOutputs -> 1/2
        expect(
          find.text('CHẠM VÀO TỪNG ĐIỂM ĐỂ KHÁM PHÁ (1/2)'),
          findsOneWidget,
        );

        // Chạm m2 khi mạng lỗi -> không tăng lên 2/2
        await tester.tap(find.text('Bãi cọc Yên Giang'));
        await tester.pump();
        expect(
          find.text('CHẠM VÀO TỪNG ĐIỂM ĐỂ KHÁM PHÁ (1/2)'),
          findsOneWidget,
        );

        // Khôi phục mạng -> chạm lại m2 -> tăng lên 2/2
        failSubmit = false;
        await tester.tap(find.text('Bãi cọc Yên Giang'));
        await tester.pump();
        expect(
          find.text('CHẠM VÀO TỪNG ĐIỂM ĐỂ KHÁM PHÁ (2/2)'),
          findsOneWidget,
        );
        expect(calls.last, {'markerId': 'm2'});
      },
    );

    testWidgets(
      'TC-ACT-07: EVIDENCE_SELECT kiểm tra minSelect/maxSelect và chọn bằng chứng',
      (tester) async {
        Map<String, dynamic>? submitted;
        final activity = ActivityRefDto.fromJson(const {
          'id': 'ev-sel-1',
          'type': 'EVIDENCE_SELECT',
          'config': {
            'visibleEvidenceIds': ['e1', 'e2', 'e3'],
            'minSelect': 2,
            'maxSelect': 2,
          },
        });
        const content = LessonContentDto(
          lessonId: 'l',
          lessonVersionId: 'v',
          content: {
            'evidence': [
              {'id': 'e1', 'title': 'Bãi cọc gỗ lim', 'source': 'Khảo cổ học'},
              {'id': 'e2', 'title': 'Thủy triều bán nhật', 'source': 'Địa lý'},
              {'id': 'e3', 'title': 'Tư liệu nhiễu', 'source': 'Truyền thuyết'},
            ],
          },
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ActivityRenderer(
                    activity: activity,
                    content: content,
                    submitting: false,
                    onSubmit: (a) async => submitted = a,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Đã chọn 0/2'), findsOneWidget);
        // Chọn e1 và e2 qua nút radio/check
        final checkButtons = find.byIcon(Icons.radio_button_off);
        await tester.tap(checkButtons.at(0));
        await tester.pump();
        expect(find.text('Đã chọn 1/2'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.radio_button_off).at(0));
        await tester.pump();
        expect(find.text('Đã chọn 2/2'), findsOneWidget);

        await tester.tap(find.text('GỬI CÂU TRẢ LỜI'));
        await tester.pump();
        expect(submitted?['selectedEvidenceIds'], ['e1', 'e2']);
      },
    );

    testWidgets(
      'TC-ACT-09 & TC-ACT-10: MATCHING hỗ trợ cả Kéo-Thả (Drag-and-Drop) và Chạm-Chọn (Tap Fallback) trên màn 360x800',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        Map<String, dynamic>? submitted;
        final activity = ActivityRefDto.fromJson(const {
          'id': 'match-1',
          'type': 'MATCHING',
          'config': {
            'leftItems': [
              {'id': 'L1', 'label': 'Ngô Quyền'},
              {'id': 'L2', 'label': 'Cọc gỗ bịt sắt'},
            ],
            'rightItems': [
              {'id': 'R1', 'label': 'Người chỉ huy trận Bạch Đằng năm 938'},
              {'id': 'R2', 'label': 'Vũ khí ngầm phá vỡ thuyền chiến Nam Hán'},
            ],
          },
        });

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ActivityRenderer(
                    activity: activity,
                    content: const LessonContentDto(
                      lessonId: 'l',
                      lessonVersionId: 'v',
                      content: {},
                    ),
                    submitting: false,
                    onSubmit: (a) async => submitted = a,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Kéo-Thả (Drag-and-Drop): kéo 'Ngô Quyền' thả vào 'Người chỉ huy trận Bạch Đằng năm 938'
        final Offset start = tester.getCenter(find.text('Ngô Quyền'));
        final Offset end = tester.getCenter(
          find.text('Người chỉ huy trận Bạch Đằng năm 938'),
        );
        await tester.dragFrom(start, end - start);
        await tester.pumpAndSettle();
        expect(find.text('Đã ghép 1/2'), findsOneWidget);

        // 2. Tap Fallback: chạm 'Cọc gỗ bịt sắt' -> chạm 'Vũ khí ngầm phá vỡ thuyền chiến Nam Hán'
        await tester.tap(find.text('Cọc gỗ bịt sắt'));
        await tester.pump();
        await tester.tap(find.text('Vũ khí ngầm phá vỡ thuyền chiến Nam Hán'));
        await tester.pumpAndSettle();
        expect(find.text('Đã ghép 2/2'), findsOneWidget);

        await tester.tap(find.text('GỬI CÂU TRẢ LỜI'));
        await tester.pump();
        expect(submitted?['pairs'], hasLength(2));
      },
    );

    testWidgets(
      'TC-ACT-11 & TC-ACT-12: DRAG_ORDER hỗ trợ nút Lên/Xuống (Tap Fallback >= 44x44dp) và khóa nút ở biên',
      (tester) async {
        Map<String, dynamic>? submitted;
        final activity = ActivityRefDto.fromJson(const {
          'id': 'order-1',
          'type': 'DRAG_ORDER',
          'config': {
            'items': [
              {'id': 'step-2', 'label': 'Nhử quân Nam Hán vượt qua bãi cọc'},
              {'id': 'step-1', 'label': 'Đóng cọc gỗ bịt sắt xuống lòng sông'},
              {'id': 'step-3', 'label': 'Phản công khi thủy triều rút mạnh'},
            ],
          },
        });

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ActivityRenderer(
                    activity: activity,
                    content: const LessonContentDto(
                      lessonId: 'l',
                      lessonVersionId: 'v',
                      content: {},
                    ),
                    submitting: false,
                    onSubmit: (a) async => submitted = a,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final upFinder = find.widgetWithIcon(
          IconButton,
          Icons.arrow_upward_rounded,
        );
        final downFinder = find.widgetWithIcon(
          IconButton,
          Icons.arrow_downward_rounded,
        );
        final upButtons = tester.widgetList<IconButton>(upFinder).toList();
        final downButtons = tester.widgetList<IconButton>(downFinder).toList();

        // Phần tử đầu tiên khóa nút Lên; phần tử cuối cùng khóa nút Xuống
        expect(upButtons.first.onPressed, isNull);
        expect(upButtons[1].onPressed, isNotNull);
        expect(downButtons.last.onPressed, isNull);

        // Kích thước vùng chạm >= 44x44dp
        final Size upSize = tester.getSize(upFinder.at(1));
        expect(upSize.width, greaterThanOrEqualTo(44));
        expect(upSize.height, greaterThanOrEqualTo(44));

        // Bấm nút Lên ở vị trí thứ 2 (step-1) để đưa lên vị trí đầu tiên
        await tester.tap(upFinder.at(1));
        await tester.pumpAndSettle();

        await tester.tap(find.text('GỬI CÂU TRẢ LỜI'));
        await tester.pump();
        expect(submitted, {
          'orderedIds': ['step-1', 'step-2', 'step-3'],
        });
      },
    );

    testWidgets(
      'TC-ACT-13, TC-ACT-14, TC-ACT-15, TC-ACT-17, TC-ACT-19: REASONING_CONNECT, HYPOTHESIS_CHOICE, VERIFICATION, CER_CHOICE, REFLECTION_PROMPT',
      (tester) async {
        // 1. HYPOTHESIS_CHOICE (TC-ACT-14): phải chọn cả giả thuyết lẫn bằng chứng hỗ trợ
        Map<String, dynamic>? hypSubmitted;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ActivityRenderer(
                    activity: ActivityRefDto.fromJson(const {
                      'id': 'hyp-1',
                      'type': 'HYPOTHESIS_CHOICE',
                      'config': {
                        'prompt': 'Đặt giả thuyết về chiến thuật của Ngô Quyền',
                        'hypotheses': [
                          {
                            'id': 'h-tide',
                            'text': 'Lợi dụng thủy triều và bãi cọc ngầm',
                          },
                        ],
                        'visibleEvidenceIds': ['e-tide'],
                      },
                    }),
                    content: const LessonContentDto(
                      lessonId: 'l',
                      lessonVersionId: 'v',
                      content: {
                        'evidence': [
                          {
                            'id': 'e-tide',
                            'title': 'Ghi chép về con nước triều',
                          },
                        ],
                      },
                    ),
                    submitting: false,
                    onSubmit: (a) async => hypSubmitted = a,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Mới chọn giả thuyết, chưa chọn bằng chứng -> nút GỬI CÂU TRẢ LỜI chưa mở
        await tester.tap(find.text('Lợi dụng thủy triều và bãi cọc ngầm'));
        await tester.pump();
        await tester.tap(find.text('GỬI CÂU TRẢ LỜI'));
        await tester.pump();
        expect(hypSubmitted, isNull);

        // Chọn thêm bằng chứng hỗ trợ -> nút GỬI CÂU TRẢ LỜI mở khóa
        await tester.tap(find.text('Ghi chép về con nước triều'));
        await tester.pump();
        await tester.tap(find.text('GỬI CÂU TRẢ LỜI'));
        await tester.pump();
        expect(hypSubmitted, {
          'hypothesisId': 'h-tide',
          'evidenceIds': ['e-tide'],
        });

        // 2. VERIFICATION (TC-ACT-15): hiển thị đúng nội dung tiếng Việt của giả thuyết từ stages
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ActivityRenderer(
                    activity: ActivityRefDto.fromJson(const {
                      'id': 'ver-1',
                      'type': 'VERIFICATION',
                      'config': {
                        'priorOutputs': {
                          'hyp-1': {'hypothesisId': 'h-tide'},
                        },
                      },
                    }),
                    content: const LessonContentDto(
                      lessonId: 'l',
                      lessonVersionId: 'v',
                      content: {
                        'stages': [
                          {
                            'id': 's-hyp',
                            'activities': [
                              {
                                'id': 'hyp-1',
                                'type': 'HYPOTHESIS_CHOICE',
                                'config': {
                                  'hypotheses': [
                                    {
                                      'id': 'h-tide',
                                      'text':
                                          'Lợi dụng thủy triều và bãi cọc ngầm',
                                    },
                                  ],
                                },
                              },
                            ],
                          },
                        ],
                      },
                    ),
                    submitting: false,
                    onSubmit: (_) async {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Lợi dụng thủy triều và bãi cọc ngầm'),
          findsOneWidget,
        );

        // 3. CER_CHOICE (TC-ACT-17): điền sẵn priorEvidenceSource + giữ dirty state đúng khi bỏ chọn evidence
        bool isDirty = false;
        Map<String, dynamic>? cerChoiceSubmitted;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ActivityRenderer(
                    activity: ActivityRefDto.fromJson(const {
                      'id': 'cer-c-1',
                      'type': 'CER_CHOICE',
                      'config': {
                        'priorEvidenceSource': 'ev-sel-1',
                        'priorOutputs': {
                          'ev-sel-1': {
                            'selectedEvidenceIds': ['e1'],
                          },
                        },
                        'claims': [
                          {'id': 'c1', 'text': 'Ngô Quyền thắng nhờ mưu略'},
                        ],
                        'evidenceOptions': [
                          {'id': 'e1'},
                        ],
                        'reasoningOptions': [
                          {'id': 'r1', 'text': 'Phối hợp thủy triều và cọc'},
                        ],
                      },
                    }),
                    content: const LessonContentDto(
                      lessonId: 'l',
                      lessonVersionId: 'v',
                      content: {
                        'evidence': [
                          {'id': 'e1', 'title': 'Bãi cọc Bạch Đằng'},
                        ],
                      },
                    ),
                    submitting: false,
                    onInputChanged: (d) => isDirty = d,
                    onSubmit: (a) async => cerChoiceSubmitted = a,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ngô Quyền thắng nhờ mưu略'));
        await tester.pump();
        expect(isDirty, isTrue);

        // Bỏ chọn rồi chọn lại e1 -> vẫn dirty vì claimId đã được chọn
        await tester.tap(find.text('Bãi cọc Bạch Đằng'));
        await tester.pump();
        expect(isDirty, isTrue);
        await tester.tap(find.text('Bãi cọc Bạch Đằng'));
        await tester.pump();

        await tester.tap(find.text('Phối hợp thủy triều và cọc'));
        await tester.pump();
        await tester.tap(find.text('GỬI CÂU TRẢ LỜI'));
        await tester.pump();
        expect(cerChoiceSubmitted, {
          'claimId': 'c1',
          'evidenceIds': ['e1'],
          'reasoningId': 'r1',
        });

        // 4. REFLECTION_PROMPT (TC-ACT-19): chặn gửi khi chỉ có khoảng trắng
        Map<String, dynamic>? reflSubmitted;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ActivityRenderer(
                    activity: ActivityRefDto.fromJson(const {
                      'id': 'refl-1',
                      'type': 'REFLECTION_PROMPT',
                      'config': {
                        'prompt': 'Bài học để lại cho bạn suy nghĩ gì?',
                      },
                    }),
                    content: const LessonContentDto(
                      lessonId: 'l',
                      lessonVersionId: 'v',
                      content: {},
                    ),
                    submitting: false,
                    onSubmit: (a) async => reflSubmitted = a,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), '    \n   ');
        await tester.pump();
        await tester.tap(find.text('GỬI CÂU TRẢ LỜI'));
        await tester.pump();
        expect(reflSubmitted, isNull);
      },
    );
  });

  group(
    'Nhóm D & E & F & H — Feedback 4 Tones, Energy Toast Overlap & Result Mastery',
    () {
      testWidgets(
        'TC-FB-02, TC-ENG-01, TC-VIS-02: Trả lời Sai hiện Toast -10 Thể lực không đè lên Feedback Card, trả lời Đúng gỡ ngay Toast cũ',
        (tester) async {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final energyRepo = FakeEnergyRepository()
            ..next = EnergyStateDto(current: 100, max: 100);
          var attemptCount = 0;
          final repo = FakeAttemptRepository();
          repo.onGetCurrent = () => CurrentActivityDto(
            stage: const StageRefDto(id: 's1', title: 'Kiểm chứng'),
            activity: ActivityRefDto.fromJson(const {
              'id': 'mcq-1',
              'type': 'MULTIPLE_CHOICE',
              'config': {
                'question': 'Trận Bạch Đằng diễn ra năm nào?',
                'multiSelect': false,
                'options': [
                  {'id': 'o1', 'label': 'Năm 938'},
                  {'id': 'o2', 'label': 'Năm 981'},
                ],
              },
              'feedback': {
                'wrong': 'Chưa đúng, năm 981 là thời Tiền Lê.',
                'right': 'Chính xác! Chiến thắng Bạch Đằng năm 938.',
              },
            }),
            progress: const AttemptProgressDto(
              completedRequired: 0,
              totalRequired: 2,
            ),
          );
          repo.onSubmit = (ans) {
            attemptCount++;
            if (attemptCount == 1) {
              return SubmitResultDto(
                status: 'ACCEPTED',
                evaluation: const EvaluationDto(
                  outcome: 'INCORRECT',
                  completed: false,
                  feedbackCode: 'wrong',
                ),
                activityCompleted: false,
                progress: const AttemptProgressDto(
                  completedRequired: 0,
                  totalRequired: 2,
                ),
                completion: const CompletionVerdictDto(complete: false),
                energyDeducted: 10,
                energy: EnergyStateDto(
                  current: 90,
                  max: 100,
                  canSubmitGraded: true,
                ),
              );
            }
            return SubmitResultDto(
              status: 'ACCEPTED',
              evaluation: const EvaluationDto(
                outcome: 'COMPLETED',
                completed: true,
                feedbackCode: 'right',
              ),
              activityCompleted: true,
              progress: const AttemptProgressDto(
                completedRequired: 1,
                totalRequired: 2,
              ),
              completion: const CompletionVerdictDto(complete: false),
              energyDeducted: 0,
              energy: EnergyStateDto(
                current: 90,
                max: 100,
                canSubmitGraded: true,
              ),
            );
          };

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                attemptRepositoryProvider.overrideWithValue(repo),
                energyRepositoryProvider.overrideWithValue(energyRepo),
              ],
              child: const MaterialApp(
                home: LessonPlayerScreen(attemptId: 'att-toast'),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Lượt 1: Chọn sai (Năm 981) -> bấm GỬI CÂU TRẢ LỜI
          await tester.tap(find.text('Năm 981'));
          await tester.pump();
          await tester.tap(find.text('GỬI CÂU TRẢ LỜI'));
          await tester.pump(const Duration(milliseconds: 300));

          // Header Energy giảm từ 100 xuống 90, Toast '-10 Thể lực' hiển thị, Feedback Card 'CHƯA CHÍNH XÁC' hiển thị
          expect(find.text('90'), findsOneWidget);
          expect(find.text('-10 Thể lực'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('feedback-card-error')),
            findsOneWidget,
          );
          expect(find.text('CHƯA CHÍNH XÁC'), findsOneWidget);

          // TC-VIS-02: Kiểm tra tọa độ Toast không đè lên Feedback Card
          final Rect toastRect = tester.getRect(find.text('-10 Thể lực'));
          final Rect feedbackRect = tester.getRect(
            find.byKey(const ValueKey('feedback-card-error')),
          );
          expect(toastRect.overlaps(feedbackRect), isFalse);

          // Lượt 2 (ngay lập tức khi chưa hết 2.2s): Chọn đúng (Năm 938) -> bấm GỬI CÂU TRẢ LỜI
          await tester.tap(find.text('Năm 938'));
          await tester.pump();
          await tester.tap(find.text('GỬI CÂU TRẢ LỜI'));
          await tester.pump(const Duration(milliseconds: 200));

          // Toast '-10 Thể lực' của lượt trước bị gỡ ngay lập tức!
          expect(find.text('-10 Thể lực'), findsNothing);
          expect(
            find.byKey(const ValueKey('feedback-card-success')),
            findsOneWidget,
          );
          expect(find.text('CHÍNH XÁC'), findsOneWidget);
          expect(find.text('TIẾP TỤC ›'), findsOneWidget);
          // Câu hỏi vẫn giữ trên màn hình để người học đối chiếu trước khi bấm TIẾP TỤC ›
          expect(find.text('Trận Bạch Đằng diễn ra năm nào?'), findsOneWidget);
        },
      );

      testWidgets(
        'TC-ENG-06: Đang học bị 409 ENERGY_DEPLETED -> sang Viện Thái Y (/energy) hiện nút QUAY LẠI BÀI HỌC -> quay lại nộp tiếp',
        (tester) async {
          final energyRepo = FakeEnergyRepository()
            ..next = EnergyStateDto(
              current: 20,
              max: 100,
              canSubmitGraded: true,
            );
          var callCount = 0;
          final repo = FakeAttemptRepository();
          repo.onGetCurrent = () => CurrentActivityDto(
            stage: const StageRefDto(id: 's1', title: 'Suy luận'),
            activity: ActivityRefDto.fromJson(const {
              'id': 'mcq-e',
              'type': 'MULTIPLE_CHOICE',
              'config': {
                'question': 'Ai lãnh đạo trận Bạch Đằng năm 938?',
                'multiSelect': false,
                'options': [
                  {'id': 'o1', 'label': 'Ngô Quyền'},
                  {'id': 'o2', 'label': 'Lê Hoàn'},
                ],
              },
            }),
            progress: const AttemptProgressDto(
              completedRequired: 1,
              totalRequired: 3,
            ),
          );
          repo.onSubmit = (_) {
            callCount++;
            if (callCount == 1) {
              throw const ApiException(
                ApiError(
                  code: 'ENERGY_DEPLETED',
                  message: 'Hết thể lực',
                  details: {'currentEnergy': 0},
                ),
                statusCode: 409,
              );
            }
            return const SubmitResultDto(
              status: 'ACCEPTED',
              evaluation: EvaluationDto(outcome: 'COMPLETED', completed: true),
              activityCompleted: true,
              progress: AttemptProgressDto(
                completedRequired: 2,
                totalRequired: 3,
              ),
              completion: CompletionVerdictDto(complete: false),
            );
          };

          final router = GoRouter(
            initialLocation: '/learning/attempt/att-roundtrip',
            routes: [
              GoRoute(
                path: '/learning/attempt/:id',
                builder: (_, state) =>
                    LessonPlayerScreen(attemptId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: '/energy',
                builder: (_, _) => const EnergyManagementScreen(),
              ),
            ],
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                attemptRepositoryProvider.overrideWithValue(repo),
                energyRepositoryProvider.overrideWithValue(energyRepo),
              ],
              child: MaterialApp.router(routerConfig: router),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('Ngô Quyền'));
          await tester.pump();
          await tester.tap(find.text('GỬI CÂU TRẢ LỜI'));
          await tester.pumpAndSettle();

          expect(find.text('Hết Thể lực'), findsOneWidget);
          await tester.tap(find.text('VIỆN THÁI Y'));
          await tester.pumpAndSettle();

          // Tại Viện Thái Y (/energy): hiển thị QUAY LẠI BÀI HỌC vì được push từ LessonPlayerScreen
          expect(find.text('QUẢN LÝ THỂ LỰC'), findsOneWidget);
          expect(find.text('QUAY LẠI BÀI HỌC'), findsOneWidget);

          await tester.ensureVisible(find.text('QUAY LẠI BÀI HỌC'));
          await tester.tap(find.text('QUAY LẠI BÀI HỌC'));
          await tester.pumpAndSettle();

          // Quay lại đúng câu đang làm dở, đáp án 'Ngô Quyền' vẫn được chọn, bấm GỬI CÂU TRẢ LỜI thành công
          expect(
            find.text('Ai lãnh đạo trận Bạch Đằng năm 938?'),
            findsOneWidget,
          );
          await tester.tap(find.text('GỬI CÂU TRẢ LỜI'));
          await tester.pumpAndSettle();
          expect(find.text('TIẾP TỤC ›'), findsOneWidget);
        },
      );

      testWidgets(
        'TC-RES-01, TC-RES-02, TC-RES-03, TC-RES-04: LessonResultScreen phân biệt Lần đầu (+100 XP, +50 Điểm, Mastered, Confetti, Streak) vs Ôn tập & Chưa Mastered',
        (tester) async {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final repo = FakeAttemptRepository();

          // 1. Lần đầu hoàn thành đạt MASTERED (knowledgeScore = 85%)
          await tester.pumpWidget(
            ProviderScope(
              overrides: [attemptRepositoryProvider.overrideWithValue(repo)],
              child: MaterialApp(
                home: LessonResultScreen(
                  attemptId: 'att-res-1',
                  initialResult: LessonResultDto(
                    attemptId: 'att-res-1',
                    lessonVersionId: 'v-1',
                    status: 'COMPLETED',
                    score: 100,
                    result: const {
                      'knowledgeScore': 85,
                      'mastered': true,
                      'summary': 'Nắm vững chiến thuật Bạch Đằng 938.',
                    },
                    rewards: const [
                      RewardTransactionDto(
                        id: 'r1',
                        rewardType: 'EXP',
                        amount: 100,
                        reason: 'LESSON_COMPLETED_FIRST_TIME',
                      ),
                      RewardTransactionDto(
                        id: 'r2',
                        rewardType: 'HISTORY_POINTS',
                        amount: 50,
                        reason: 'LESSON_COMPLETED_FIRST_TIME',
                      ),
                    ],
                    newlyRecordedStreak: const StreakInfoDto(
                      dayRecorded: true,
                      currentStreak: 3,
                      longestStreak: 5,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(GoldConfettiOverlay), findsOneWidget);
          expect(find.text('Bạn thật tuyệt vời!'), findsOneWidget);
          expect(find.text('THÔNG THẠO (MASTERED) • 85%'), findsOneWidget);
          expect(find.text('+100 XP'), findsOneWidget);
          expect(find.text('+50'), findsAtLeastNWidgets(1));
          expect(find.text('NGỌN LỬA HÀO KHÍ'), findsOneWidget);
          expect(find.text('Chuỗi 3 ngày học liên tiếp'), findsOneWidget);

          // 2. Hoàn thành nhờ hết lượt thử (knowledgeScore = 50% < 70%) & lượt ôn tập (rewards rỗng)
          await tester.pumpWidget(
            ProviderScope(
              overrides: [attemptRepositoryProvider.overrideWithValue(repo)],
              child: const MaterialApp(
                home: LessonResultScreen(
                  attemptId: 'att-res-2',
                  initialResult: LessonResultDto(
                    attemptId: 'att-res-2',
                    lessonVersionId: 'v-1',
                    status: 'COMPLETED',
                    score: 100,
                    result: {'knowledgeScore': 50, 'mastered': false},
                    rewards: [],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.text('HOÀN THÀNH LƯỢT HỌC • Kiến thức 50%'),
            findsOneWidget,
          );
          expect(
            find.textContaining(
              'Hãy ôn tập thêm các câu hỏi tư duy để đạt mức Thông thạo',
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'TC-VIS-01 & TC-VIS-03: Kiểm toán Không Tràn Giao diện (Zero RenderFlex Overflow) trên 360x800, 390x844, 430x932 với văn bản tiếng Việt dài',
        (tester) async {
          const viewports = [Size(360, 800), Size(390, 844), Size(430, 932)];
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final longTitle =
              'Chiến thắng Bạch Đằng năm 938: Nghệ thuật quân sự lợi dụng thủy triều và trận địa cọc gỗ bịt sắt chấm dứt hơn một thiên niên kỷ Bắc thuộc';
          final repo = FakeAttemptRepository()
            ..metadata = LessonMetadataDto(
              id: 'l-stress',
              title: longTitle,
              centralQuestion:
                  'Vì sao Ngô Quyền lại quyết định bố trí trận địa cọc ngầm tại vùng cửa sông Bạch Đằng để đón đánh đoàn thuyền chiến của Hoằng Thao?',
              eventId: 'evt-stress',
              objectivesJson:
                  '["Phân tích sự kết hợp giữa địa hình tự nhiên, quy luật thủy triều bán nhật và chiến thuật nghi binh nhử địch"]',
            );
          repo.onGetCurrent = () => CurrentActivityDto(
            stage: StageRefDto(id: 's-long', title: longTitle),
            activity: ActivityRefDto.fromJson({
              'id': 'act-stress-mcq',
              'type': 'MULTIPLE_CHOICE',
              'instruction':
                  'Hãy đọc kỹ câu hỏi nhiều mệnh đề dưới đây và lựa chọn phương án giải thích toàn diện nhất.',
              'graded': true,
              'incorrectPenalty': 10,
              'config': {
                'question': longTitle,
                'multiSelect': false,
                'options': [
                  {
                    'id': 'o1',
                    'label':
                        'Lợi dụng lúc nước triều dâng cao che khuất bãi cọc ngầm, cho thuyền nhẹ ra khiêu chiến rồi giả vờ thua rút chạy để nhử toàn bộ chiến thuyền Nam Hán lọt vào trận địa mai phục trước khi nước triều rút mạnh.',
                  },
                  {
                    'id': 'o2',
                    'label':
                        'Dựng phòng tuyến thành lũy kiên cố dọc hai bên bờ sông kết hợp với quân bộ binh phòng ngự lâu dài chờ viện binh từ các châu quận kéo đến bao vây.',
                  },
                ],
              },
            }),
            progress: const AttemptProgressDto(
              completedRequired: 3,
              totalRequired: 7,
            ),
          );

          for (final size in viewports) {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;

            await tester.pumpWidget(
              ProviderScope(
                overrides: [attemptRepositoryProvider.overrideWithValue(repo)],
                child: const MaterialApp(
                  home: LessonEntryScreen(lessonId: 'l-stress'),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);

            await tester.pumpWidget(
              ProviderScope(
                overrides: [attemptRepositoryProvider.overrideWithValue(repo)],
                child: const MaterialApp(
                  home: LessonPlayerScreen(attemptId: 'att-stress'),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        },
      );

      testWidgets(
        'Phase 01-04 Regressions: ShimmerProgressBar 0% full width, BattleSabanScreen 360x800 zero overflow, CerChoice synthesis card & LessonResultScreen metadata title',
        (tester) async {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          // 1. P2-01: ShimmerProgressBar at 0% (0/3) must NOT collapse to 2.4px width
          final repo = FakeAttemptRepository()
            ..metadata = const LessonMetadataDto(
              id: 'les-me-linh',
              title: 'Tiếng Trống Mê Linh: Nguyên Nhân và Sức Mạnh Khởi Nghĩa',
              eventId: 'evt-hbt-40',
            )
            ..content = const LessonContentDto(
              lessonId: 'les-me-linh',
              lessonVersionId: 'v-1',
              content: {},
            );
          repo.onGetCurrent = () => CurrentActivityDto(
            stage: const StageRefDto(id: 's1', title: 'Bối cảnh lịch sử'),
            activity: ActivityRefDto.fromJson(const {
              'id': 'act-read',
              'type': 'READ',
              'config': {'body': 'Nội dung tư liệu'},
            }),
            progress: const AttemptProgressDto(
              completedRequired: 0,
              totalRequired: 3,
            ),
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [attemptRepositoryProvider.overrideWithValue(repo)],
              child: const MaterialApp(
                home: LessonPlayerScreen(attemptId: 'att-0'),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final Size barSize = tester.getSize(find.byType(ShimmerProgressBar));
          expect(barSize.width, greaterThan(150));

          // 2. P1-05: BattleSabanScreen on 360x800 renders without RenderFlex overflow
          await tester.pumpWidget(
            ProviderScope(
              key: UniqueKey(),
              overrides: [attemptRepositoryProvider.overrideWithValue(repo)],
              child: const MaterialApp(home: BattleSabanScreen()),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Xem Chi Tiết Chiến Dịch'), findsOneWidget);
          expect(find.text('Bàn Học'), findsOneWidget);

          // 3. P4-02: LessonResultScreen resolves real lesson title from getLessonMetadata when snapshot content has no title
          await tester.pumpWidget(
            ProviderScope(
              key: UniqueKey(),
              overrides: [attemptRepositoryProvider.overrideWithValue(repo)],
              child: const MaterialApp(
                home: LessonResultScreen(
                  attemptId: 'att-0',
                  initialResult: LessonResultDto(
                    attemptId: 'att-0',
                    lessonVersionId: 'v-1',
                    status: 'COMPLETED',
                    score: 100,
                    result: {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(
              'Tiếng Trống Mê Linh: Nguyên Nhân và Sức Mạnh Khởi Nghĩa',
            ),
            findsAtLeastNWidgets(1),
          );
        },
      );
    },
  );
}
