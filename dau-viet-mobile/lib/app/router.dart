import 'package:go_router/go_router.dart';
import '../core/api/api_config.dart';
import '../features/auth/data/auth_state.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/otp_verification_screen.dart';
import '../features/auth/presentation/reset_password_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/campaign/presentation/campaign_detail_screen.dart';
import '../features/collection/presentation/collection_detail_screen.dart';
import '../features/collection/presentation/collection_screen.dart';
import '../features/collection/presentation/dossier_detail_screen.dart';
import '../features/dashboard/presentation/learner_dashboard_screen.dart';
import '../features/demo/presentation/theme_showcase_screen.dart';
import '../features/learning/data/attempt_dtos.dart';
import '../features/learning/data/learning_providers.dart';
import '../features/learning/presentation/chronological_order_screen.dart';
import '../features/learning/presentation/context_reader_screen.dart';
import '../features/learning/presentation/cer_conclusion_screen.dart';
import '../features/learning/presentation/hypothesis_verification_screen.dart';
import '../features/learning/presentation/lesson_entry_screen.dart';
import '../features/learning/presentation/lesson_player_screen.dart';
import '../features/learning/presentation/lesson_result_screen.dart';
import '../features/learning/presentation/matching_board_screen.dart';
import '../features/learning/presentation/multiple_choice_quiz_screen.dart';
import '../features/map/presentation/historical_map_screen.dart';
import '../features/map/presentation/location_profile_screen.dart';
import '../features/meta/presentation/energy_management_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/island/presentation/island_screen.dart';
import '../features/island/presentation/island_shop_screen.dart';
import '../features/meta/presentation/inventory_screen.dart';
import '../features/rewards/presentation/event_victory_screen.dart';
import '../features/rewards/presentation/reward_claim_screen.dart';
import '../features/rewards/presentation/warship_artifact_detail_screen.dart';
import '../features/saban/presentation/battle_saban_screen.dart';
import '../features/streak/presentation/learning_streak_screen.dart';
import '../features/timeline/presentation/timeline_screen.dart';
import '../features/traces/presentation/traces_hub_screen.dart';

/// Đường đi học thật — real mode yêu cầu đăng nhập (guard chuyển về /auth).
const _learningPrefixes = [
  '/learning',
  '/streak',
  '/map',
  '/collection',
  '/energy',
  '/timeline',
  '/saban',
  '/island',
  '/journey',
  '/heritage',
];

/// Màn demo-only (nội dung hard-code, không có backend thật): giữ trong
/// USE_MOCK; real mode redirect về dashboard để không lộ dữ liệu bịa.
/// Reward screens M-18/19/21 cần attemptId hợp lệ — real mode không có.
/// Timeline/Sa Bàn đã được đồng bộ để mở được ở cả 2 chế độ.
/// Đảo Di Sản (/island) và Túi Đồ (/inventory) là sở hữu/trang trí THẬT
/// (nguồn /me/inventory) — KHÔNG gate ở đây, để learner mở được mọi lúc.
const _demoOnlyPrefixes = [
  '/rewards/victory',
  '/rewards/claim',
  '/rewards/artifact',
];

/// Bộ định tuyến toàn cục của Dấu Việt Mobile (go_router)
final appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: authRouterRefreshNotifier,
  redirect: (context, state) {
    // Đọc auth state qua container toàn cục (router tạo trước ProviderScope).
    final container = appContainer;
    if (container == null) return null;
    final auth = container.read(authSessionProvider);
    final loc = state.matchedLocation;

    // Mock mode: guest hợp lệ → không chặn gì.
    if (ApiConfig.useMock) return null;

    // Đang restore phiên (splash) → giữ nguyên; splash tự điều hướng.
    if (auth.status == AuthStatus.unknown) return null;

    // Đã login mà vào /auth hoặc /register → về dashboard.
    if (auth.status == AuthStatus.authenticated &&
        (loc == '/auth' || loc == '/register')) {
      return '/dashboard';
    }

    // Đã login mà vào màn phụ của auth flow → về dashboard.
    if (auth.status == AuthStatus.authenticated &&
        (loc == '/auth/otp' || loc == '/auth/forgot' || loc == '/auth/reset-password')) {
      return '/dashboard';
    }

    // Real mode: màn nội dung demo-only không có dữ liệu thật → dashboard.
    if (!ApiConfig.useMock && _demoOnlyPrefixes.any((p) => loc.startsWith(p))) {
      return '/dashboard';
    }

    // Chưa login mà vào đường học thật → bắt đăng nhập.
    final bool needsAuth = _learningPrefixes.any((p) => loc.startsWith(p));
    if (needsAuth && auth.status != AuthStatus.authenticated) {
      return '/auth';
    }
    return null;
  },
  routes: [
    // M-01: Splash Screen Thương hiệu
    GoRoute(
      path: '/',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),

    // M-02: Đăng Nhập & Chế Độ Khách
    GoRoute(
      path: '/auth',
      name: 'auth',
      builder: (context, state) => const AuthScreen(),
    ),

    // P0-03: Đăng ký tài khoản learner mới
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const RegisterScreen(),
    ),

    // Issue #34: quên mật khẩu — bước 1 (email → gửi OTP).
    GoRoute(
      path: '/auth/forgot',
      name: 'forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),

    // Issue #34: nhập mã OTP 6 số (đăng ký | quên mật khẩu).
    GoRoute(
      path: '/auth/otp',
      name: 'otp-verify',
      builder: (context, state) {
        final args = state.extra as OtpFlowArgs?;
        if (args == null) return const AuthScreen();
        return OtpVerificationScreen(args: args);
      },
    ),

    // Issue #34: quên mật khẩu — bước 2 (OTP + mật khẩu mới).
    GoRoute(
      path: '/auth/reset-password',
      name: 'reset-password',
      builder: (context, state) {
        final args = state.extra as ({String email, String otpCode})?;
        if (args == null) return const ForgotPasswordScreen();
        return ResetPasswordScreen(email: args.email, otpCode: args.otpCode);
      },
    ),

    // P1-02: Onboarding 3 bước — chỉ hiện lần đầu (splash điều hướng).
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) => OnboardingScreen(
        destination: state.uri.queryParameters['next'] ?? '/auth',
      ),
    ),

    // P0-02: Hồ sơ cá nhân — tab 3 của bottom nav chuẩn
    GoRoute(
      path: '/profile',
      name: 'profile',
      builder: (context, state) => const ProfileScreen(),
    ),

    // M-03: Bàn Học Tập Người Học (Dashboard)
    GoRoute(
      path: '/dashboard',
      name: 'dashboard',
      builder: (context, state) => const LearnerDashboardScreen(),
    ),

    // M-04: Dòng Thời Gian Lịch Sử (Timeline)
    GoRoute(
      path: '/timeline',
      name: 'timeline',
      builder: (context, state) => const TimelineScreen(),
    ),

    // Issue #36: `/journey` (danh sách chữ cũ) được hợp nhất vào Bản Đồ
    // Dấu Ấn `/map` — giữ redirect để deep-link cũ không gãy.
    GoRoute(
      path: '/journey',
      redirect: (context, state) => '/map',
      routes: [
        GoRoute(
          path: ':periodCode',
          redirect: (context, state) =>
              '/map?period=${state.pathParameters['periodCode'] ?? ''}',
        ),
      ],
    ),

    // A3 / E4 / E5: Hồ sơ địa điểm di sản (`/heritage/:locationId`)
    GoRoute(
      path: '/heritage/:locationId',
      name: 'heritage_location',
      builder: (context, state) => LocationProfileScreen(
        locationId: state.pathParameters['locationId'] ?? '',
      ),
    ),

    // TASK-0021: Bản Đồ Dấu Ấn Lịch Sử (unlock theo learner)
    GoRoute(
      path: '/map',
      name: 'historical_map',
      builder: (context, state) {
        final view = state.uri.queryParameters['view'];
        final period = state.uri.queryParameters['period'];
        final eventId = state.uri.queryParameters['eventId'];
        return HistoricalMapScreen(
          initialMode: view == 'timeline'
              ? ExploreViewMode.timeline
              : ExploreViewMode.map,
          initialPeriodCode: period,
          initialEventId: eventId,
        );
      },
    ),

    // M-06: Sa Bàn Chiến Thuật & Bản Đồ Sông Bạch Đằng
    GoRoute(
      path: '/saban',
      name: 'saban',
      builder: (context, state) => const BattleSabanScreen(),
    ),

    // M-07: Chi Tiết Chiến Dịch Lịch Sử (Campaign Detail)
    GoRoute(
      path: '/campaign/:eventId',
      name: 'campaign_detail',
      builder: (context, state) {
        final eventId = state.pathParameters['eventId'] ?? 'evt_bach_dang_938';
        return CampaignDetailScreen(eventId: eventId);
      },
    ),

    // M-08: Trung Tâm 4 Dấu Vết Lịch Sử (Traces Hub)
    GoRoute(
      path: '/traces/:eventId',
      name: 'traces_hub',
      builder: (context, state) {
        final eventId = state.pathParameters['eventId'] ?? 'evt_bach_dang_938';
        return TracesHubScreen(eventId: eventId);
      },
    ),

    // M-09: Đọc Bối Cảnh Lịch Sử & Thư Tịch Cổ (Context Reader)
    GoRoute(
      path: '/learning/context-reader',
      name: 'context_reader',
      builder: (context, state) => const ContextReaderScreen(),
    ),

    // M-11: Ghép Nối Dữ Kiện Nhân Vật & Chiến Thuật (Matching Board)
    GoRoute(
      path: '/learning/matching',
      name: 'matching',
      builder: (context, state) => const MatchingBoardScreen(),
    ),

    // M-12: Kéo Thả Sắp Xếp Niên Đại (Chronological Order)
    GoRoute(
      path: '/learning/order',
      name: 'chronological_order',
      builder: (context, state) => const ChronologicalOrderScreen(),
    ),

    // M-13: Kiểm Chứng Giả Thuyết Lịch Sử (Hypothesis Verification)
    GoRoute(
      path: '/learning/verification',
      name: 'hypothesis_verification',
      builder: (context, state) => const HypothesisVerificationScreen(),
    ),

    // M-14: Lập Luận Lịch Sử & Kết Luận CER (CER Conclusion)
    GoRoute(
      path: '/learning/cer',
      name: 'cer_conclusion',
      builder: (context, state) => const CerConclusionScreen(),
    ),

    // M-16: Hoạt Động Trắc Nghiệm Tư Liệu (Quiz)
    GoRoute(
      path: '/learning/quiz',
      name: 'quiz',
      builder: (context, state) => const MultipleChoiceQuizScreen(),
    ),

    // Learning journey thật (backend-connected)
    GoRoute(
      path: '/learning/lesson/:lessonId',
      name: 'lesson_entry',
      builder: (context, state) =>
          LessonEntryScreen(lessonId: state.pathParameters['lessonId']!),
    ),
    GoRoute(
      path: '/learning/attempt/:attemptId',
      name: 'lesson_player',
      builder: (context, state) =>
          LessonPlayerScreen(attemptId: state.pathParameters['attemptId']!),
    ),
    GoRoute(
      path: '/learning/result/:attemptId',
      name: 'lesson_result',
      builder: (context, state) => LessonResultScreen(
        attemptId: state.pathParameters['attemptId']!,
        initialResult: state.extra is LessonResultDto
            ? state.extra as LessonResultDto
            : null,
      ),
    ),

    // M-18: Khải Hoàn Chiến Dịch & Tổng Kết Điểm (Event Victory)
    GoRoute(
      path: '/rewards/victory',
      name: 'event_victory',
      builder: (context, state) {
        final eventId =
            state.uri.queryParameters['eventId'] ?? 'evt_bach_dang_938';
        return EventVictoryScreen(eventId: eventId);
      },
    ),

    // M-19: Nhận Thưởng & Rương Báu Chiến Dịch (Reward Claim)
    GoRoute(
      path: '/rewards/claim',
      name: 'reward_claim',
      builder: (context, state) => const RewardClaimScreen(),
    ),

    // M-21: Chi Tiết Cổ Vật Chiến Hạm Thủy Quân (Artifact Detail)
    GoRoute(
      path: '/rewards/artifact/:artifactId',
      name: 'artifact_detail',
      builder: (context, state) {
        final artifactId =
            state.pathParameters['artifactId'] ?? 'art_thuyen_chien_938';
        return WarshipArtifactDetailScreen(artifactId: artifactId);
      },
    ),

    // TASK-0022: Bộ Sưu Tập bằng chứng lịch sử đã thu thập
    GoRoute(
      path: '/collection',
      name: 'collection',
      builder: (context, state) => const CollectionScreen(),
    ),
    // GAME-04: dossier route phải đứng TRƯỚC /collection/:evidenceId —
    // GoRouter match theo thứ tự, ':evidenceId' sẽ nuốt 'dossiers'.
    GoRoute(
      path: '/collection/dossiers/:dossierId',
      name: 'dossier_detail',
      builder: (context, state) =>
          DossierDetailScreen(dossierId: state.pathParameters['dossierId']!),
    ),
    GoRoute(
      path: '/collection/:evidenceId',
      name: 'collection_detail',
      builder: (context, state) => CollectionDetailScreen(
        evidenceId: state.pathParameters['evidenceId']!,
      ),
    ),

    // M-22: Bản Đồ Đảo Di Sản Cá Nhân 2.5D (Heritage Island)
    GoRoute(
      path: '/island',
      name: 'heritage_island',
      builder: (context, state) => const IslandScreen(),
      routes: [
        GoRoute(
          path: 'shop',
          name: 'island_shop',
          builder: (context, state) => const IslandShopScreen(),
        ),
      ],
    ),

    // M-27: Túi Đồ & Kho Quản Lý Cổ Vật Sở Hữu (Inventory)
    GoRoute(
      path: '/inventory',
      name: 'inventory',
      builder: (context, state) => const InventoryScreen(),
    ),

    // M-28: Quản Lý Năng Lượng & Viện Thái Y (Energy Management)
    GoRoute(
      path: '/energy',
      name: 'energy_management',
      builder: (context, state) => const EnergyManagementScreen(),
    ),

    // STREAK-01: Chi Tiết Chuỗi Ngày Học — Ngọn Lửa Hào Khí
    GoRoute(
      path: '/streak',
      name: 'learning_streak',
      builder: (context, state) => const LearningStreakScreen(),
    ),

    // Demo Showcase Theme
    GoRoute(
      path: '/theme-showcase',
      name: 'theme_showcase',
      builder: (context, state) => const ThemeShowcaseScreen(),
    ),
  ],
);
