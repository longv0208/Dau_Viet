import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dau_viet_mobile/app/app.dart';
import 'package:dau_viet_mobile/features/auth/data/auth_state.dart';
import 'package:dau_viet_mobile/features/events/data/events_providers.dart';
import 'package:dau_viet_mobile/features/events/data/mock_events_repository.dart';
import 'package:dau_viet_mobile/features/learning/data/learning_providers.dart';
import 'package:dau_viet_mobile/features/learning_path/data/learning_path_providers.dart';
import 'package:dau_viet_mobile/features/learning_path/data/mock_learning_path_repository.dart';
import 'package:go_router/go_router.dart';

import 'fakes/fake_attempt_repository.dart';

/// Auth controller giả lập cho journey test: trạng thái guest sẵn sàng,
/// restore() no-op — tránh phụ thuộc backend/secure storage trong test.
class _StubAuthSession extends AuthSessionController {
  @override
  AuthState build() => const AuthState.guest();

  @override
  Future<void> restore() async {}
}

void main() {
  testWidgets(
    'DauVietApp full user journey: M-01 to M-16 & Phase M5 (M-11 Matching, M-12 Order)',
    (WidgetTester tester) async {
      // Đánh dấu onboarding đã xem — journey test nhắm vào luồng app chính,
      // không phải onboarding; splash sẽ bỏ qua màn 3 bước (P1-02).
      SharedPreferences.setMockInitialValues({'onboarding_seen_v1': true});

      // Cài đặt viewport chuẩn mobile (412 x 915)
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Override repository bằng bản mock — journey test không phụ thuộc
      // vào biến compile-time USE_MOCK (AC-5).
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eventsRepositoryProvider.overrideWithValue(MockEventsRepository()),
            learningPathRepositoryProvider.overrideWithValue(
              MockLearningPathRepository(),
            ),
            authSessionProvider.overrideWith(_StubAuthSession.new),
            attemptRepositoryProvider.overrideWithValue(
              FakeAttemptRepository(),
            ),
          ],
          child: const DauVietApp(),
        ),
      );
      await tester.pump();

      // 1. Khởi động màn hình M-01 Splash
      expect(find.text('DẤU VIỆT'), findsWidgets);
      expect(
        find.text('Khám phá Hào khí Sử Việt qua Từng Dấu Vết'),
        findsOneWidget,
      );

      // Chờ timer ~2.5s: auth stub trả guest → điều hướng sang dashboard
      // (cờ onboarding đã set sẵn nên không rẽ qua màn 3 bước).
      await tester.pump(const Duration(milliseconds: 3000));
      await tester.pumpAndSettle();

      // 3. Xác nhận đã vào Dashboard (P0-04: tiêu đề mới "Học tập").
      expect(find.text('Học tập'), findsWidgets);
      // Chưa có attempt đang học → card mời khám phá (dynamic, không
      // hard-code event title). eventsListProvider có delay 200ms —
      // đợi thêm rồi kiểm tra CTA hiển thị.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Bắt đầu hành trình'), findsOneWidget);
      expect(find.text('KHÁM PHÁ NGAY ›'), findsOneWidget);

      // Bottom nav chuẩn mới 4 tab (P0-01): Học tập / Khám phá / Sưu tập /
      // Cá nhân. Các màn demo (Timeline/Sa Bàn/Đảo/Energy) không còn là tab
      // và bị gate ở real mode — journey giờ đi qua route trực tiếp cho
      // các màn demo để giữ coverage, không qua bottom nav.

      // 4. Mở /timeline — từ Issue #36 tự động chuyển hướng sang /map
      // (Bản Đồ Dấu Ấn, trục học = learning-path).
      tester.element(find.text('Học tập').first).go('/timeline');
      await tester.pumpAndSettle();
      expect(find.text('Bản Đồ Dấu Ấn'), findsOneWidget);
      expect(find.text('Buổi đầu độc lập tự chủ'), findsWidgets);

      // 5. Mở M-06 Sa Bàn qua route trực tiếp (icon saban giờ trùng cả
      // trong nội dung và bottom nav — dùng route để tránh nhầm widget).
      tester.element(find.text('Bản Đồ Dấu Ấn')).go('/saban');
      await tester.pumpAndSettle();
      expect(find.text('SA BÀN THỦY CHIẾN BẠCH ĐẰNG'), findsOneWidget);
      expect(find.text('CHU KỲ THỦY TRIỀU CHIẾN THUẬT'), findsOneWidget);

      // Thử tương tác đổi con nước sang Giờ Mùi (Triều rút cạn)
      await tester.tap(find.textContaining('3. Giờ Mùi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Triều rút cạn'), findsWidgets);

      // 6. Điều hướng sang M-07 Chi Tiết Chiến Dịch từ nút trên Sa Bàn
      await tester.scrollUntilVisible(
        find.text('Xem Chi Tiết Chiến Dịch'),
        100,
      );
      await tester.tap(find.text('Xem Chi Tiết Chiến Dịch'));
      await tester.pumpAndSettle();

      // Xác nhận đã vào M-07 Campaign Detail — real mode hiển thị
      // event.title từ backend (không còn headline hard-code).
      expect(find.text('CHI TIẾT CHIẾN DỊCH'), findsOneWidget);
      expect(find.text('Đại Chiến Bạch Đằng 938'), findsWidgets);

      // 7. Vào M-08 Trung Tâm 4 Dấu Vết — nút demo "BẮT ĐẦU KHÁM PHÁ"
      // chỉ render khi USE_MOCK; test chạy real-mode nên điều hướng thẳng
      // bằng route để giữ coverage các màn demo phía sau.
      final BuildContext campaignCtx = tester.element(
        find.text('CHI TIẾT CHIẾN DỊCH'),
      );
      campaignCtx.go('/traces/evt_bach_dang_938');
      await tester.pumpAndSettle();

      // Xác nhận đã vào M-08 Traces Hub
      expect(find.text('4 DẤU VẾT LỊCH SỬ'), findsOneWidget);
      expect(find.text('Dấu Vết 1: Bối Cảnh & Quân Mưu'), findsOneWidget);

      // 8. Bấm nút Bắt đầu Dấu vết 1 để mở M-09 Đọc Bối Cảnh Lịch Sử
      await tester.scrollUntilVisible(
        find.text('BẮT ĐẦU DẤU VẾT 1: BỐI CẢNH (M-09) ›'),
        100,
      );
      await tester.tap(find.text('BẮT ĐẦU DẤU VẾT 1: BỐI CẢNH (M-09) ›'));
      await tester.pumpAndSettle();

      // Xác nhận đã vào M-09 Context Reader
      expect(find.text('BỐI CẢNH LỊCH SỬ'), findsOneWidget);
      expect(find.text('Khảo Cứu Quân Mưu Tiền Ngô Vương'), findsOneWidget);

      // 9. Bấm nút Làm Trắc Nghiệm để mở M-16 Multiple Choice Quiz
      await tester.scrollUntilVisible(
        find.text('LÀM TRẮC NGHIỆM TƯ LIỆU (M-16) ›'),
        100,
      );
      await tester.tap(find.text('LÀM TRẮC NGHIỆM TƯ LIỆU (M-16) ›'));
      await tester.pumpAndSettle();

      // Xác nhận đã vào M-16 Quiz Screen
      expect(find.text('KIỂM CHỨNG TƯ LIỆU'), findsOneWidget);
      expect(find.text('CÂU HỎI TRUNG TÂM SỬ KÝ'), findsOneWidget);

      // Chọn phương án A (đúng)
      await tester.tap(
        find.textContaining('con nước triều đang rút cạn lộ bãi'),
      );
      await tester.pumpAndSettle();

      // Bấm nút Kiểm tra kết quả
      await tester.scrollUntilVisible(find.text('KIỂM TRA KẾT QUẢ'), 100);
      await tester.tap(find.text('KIỂM TRA KẾT QUẢ'));
      await tester.pumpAndSettle();

      // Xác nhận phản hồi sư phạm đúng
      expect(find.text('XUẤT SẮC! CĂN CỨ SỬ HỌC CHÍNH XÁC'), findsOneWidget);

      // Bấm hoàn thành quay lại Traces Hub
      await tester.scrollUntilVisible(
        find.text('HOÀN THÀNH DẤU VẾT 1 & TIẾP TỤC ›'),
        100,
      );
      await tester.tap(find.text('HOÀN THÀNH DẤU VẾT 1 & TIẾP TỤC ›'));
      await tester.pumpAndSettle();

      // Xác nhận và đóng BiteSizedCompletionModal
      expect(find.text('TIẾP TỤC HÀNH TRÌNH ›'), findsOneWidget);
      await tester.tap(find.text('TIẾP TỤC HÀNH TRÌNH ›'));
      await tester.pumpAndSettle();
      expect(find.text('4 DẤU VẾT LỊCH SỬ'), findsOneWidget);

      // 10. Tiếp tục mở M-11 Ghép Nối Dữ Kiện (Dấu Vết 2)
      expect(find.text('Dấu Vết 2: Nhân Vật & Bố Phòng'), findsOneWidget);
      await tester.tap(find.text('Dấu Vết 2: Nhân Vật & Bố Phòng'));
      await tester.pumpAndSettle();

      // Xác nhận đã vào M-11 Matching Board
      expect(find.text('GHÉP NỐI DỮ KIỆN'), findsOneWidget);
      expect(find.text('Ngô Quyền'), findsOneWidget);

      // Ghép cặp 1: Ngô Quyền -> Chủ tướng mưu lược
      await tester.tap(find.text('Ngô Quyền'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Chủ tướng mưu lược'));
      await tester.pumpAndSettle();

      // Ghép cặp 2: Sông Bạch Đằng -> Địa bàn hiểm yếu
      await tester.tap(find.text('Sông Bạch Đằng'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Địa bàn hiểm yếu'));
      await tester.pumpAndSettle();

      // Ghép cặp 3: Bãi cọc gỗ lim -> Vót nhọn bịt sắt
      await tester.tap(find.text('Bãi cọc gỗ lim'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Vót nhọn bịt sắt'));
      await tester.pumpAndSettle();

      // Ghép cặp 4: Quân Nam Hán -> Hạm đội xâm lược
      await tester.scrollUntilVisible(find.text('Quân Nam Hán'), 100);
      await tester.tap(find.text('Quân Nam Hán'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('Hạm đội xâm lược'),
        100,
      );
      await tester.tap(find.textContaining('Hạm đội xâm lược'));
      await tester.pumpAndSettle();

      // Bấm kiểm tra kết quả ghép nối
      await tester.scrollUntilVisible(
        find.text('KIỂM TRA KẾT QUẢ GHÉP NỐI'),
        100,
      );
      await tester.tap(find.text('KIỂM TRA KẾT QUẢ GHÉP NỐI'));
      await tester.pumpAndSettle();

      expect(find.text('XUẤT SẮC! GHÉP NỐI CHÍNH XÁC 100%'), findsOneWidget);

      // 11. Tiếp tục sang M-12 Sắp Xếp Niên Đại (Dấu Vết 3)
      await tester.scrollUntilVisible(
        find.textContaining('HOÀN THÀNH DẤU VẾT 2'),
        100,
      );
      await tester.tap(find.textContaining('HOÀN THÀNH DẤU VẾT 2'));
      await tester.pumpAndSettle();

      // Xác nhận và đóng BiteSizedCompletionModal
      expect(find.text('TIẾP TỤC HÀNH TRÌNH ›'), findsOneWidget);
      await tester.tap(find.text('TIẾP TỤC HÀNH TRÌNH ›'));
      await tester.pumpAndSettle();

      // Xác nhận đã vào M-12 Chronological Order
      expect(find.text('SẮP XẾP NIÊN ĐẠI'), findsOneWidget);
      expect(find.text('Địch Vượt Cửa Biển'), findsOneWidget);
      expect(find.text('Chuẩn Bị Cọc Ngầm'), findsOneWidget);

      // Điều chỉnh thứ tự: Di chuyển "Chuẩn Bị Cọc Ngầm" lên vị trí 1
      final upArrows = find.byIcon(Icons.keyboard_arrow_up_rounded);
      await tester.tap(upArrows.at(1));
      await tester.pumpAndSettle();

      // Di chuyển "Khiêu Chiến & Nhử Địch" (đang ở vị trí 4) lên vị trí 3
      await tester.tap(upArrows.at(3));
      await tester.pumpAndSettle();

      // Bấm nút kiểm tra thứ tự
      await tester.scrollUntilVisible(
        find.text('KIỂM TRA THỨ TỰ NIÊN ĐẠI'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('KIỂM TRA THỨ TỰ NIÊN ĐẠI'));
      await tester.pumpAndSettle();

      expect(find.text('TUYỆT VỜI! ĐÚNG TRÌNH TỰ CHIẾN THUẬT'), findsOneWidget);

      // Bấm hoàn thành quay lại Traces Hub
      await tester.scrollUntilVisible(
        find.textContaining('HOÀN THÀNH DẤU VẾT 3'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.textContaining('HOÀN THÀNH DẤU VẾT 3'));
      await tester.pumpAndSettle();

      // Xác nhận và đóng BiteSizedCompletionModal
      expect(find.text('TIẾP TỤC HÀNH TRÌNH ›'), findsOneWidget);
      await tester.tap(find.text('TIẾP TỤC HÀNH TRÌNH ›'));
      await tester.pumpAndSettle();

      // Quay lại màn hình 4 Dấu Vết
      expect(find.text('4 DẤU VẾT LỊCH SỬ'), findsOneWidget);

      // 12. Tiếp tục mở M-13 Kiểm Chứng Giả Thuyết (Dấu Vết 4)
      expect(find.text('Dấu Vết 4: Khảo Cổ & Di Sản'), findsOneWidget);
      await tester.tap(find.text('Dấu Vết 4: Khảo Cổ & Di Sản'));
      await tester.pumpAndSettle();

      // Xác nhận đã vào M-13 Hypothesis Verification Screen
      expect(find.text('KIỂM CHỨNG GIẢ THUYẾT'), findsOneWidget);
      expect(find.textContaining('Giả thuyết nghi vấn là SAI'), findsOneWidget);

      // Chọn phương án A (đúng: Giả thuyết nghi vấn là SAI)
      await tester.scrollUntilVisible(
        find.textContaining('Giả thuyết nghi vấn là SAI'),
        100,
      );
      await tester.tap(find.textContaining('Giả thuyết nghi vấn là SAI'));
      await tester.pumpAndSettle();

      // Bấm kiểm tra kết luận đối chiếu
      await tester.scrollUntilVisible(
        find.text('KIỂM TRA KẾT LUẬN ĐỐI CHIẾU'),
        100,
      );
      await tester.tap(find.text('KIỂM TRA KẾT LUẬN ĐỐI CHIẾU'));
      await tester.pumpAndSettle();

      expect(find.text('CHÍNH XÁC! TƯ DUY PHẢN BIỆN KHOA HỌC'), findsOneWidget);

      // 13. Tiếp tục sang M-14 Lập Luận CER (CER Conclusion)
      await tester.scrollUntilVisible(
        find.textContaining('TIẾP TỤC SANG LẬP LUẬN CER (M-14)'),
        100,
      );
      await tester.tap(
        find.textContaining('TIẾP TỤC SANG LẬP LUẬN CER (M-14)'),
      );
      await tester.pumpAndSettle();

      // Xác nhận và đóng BiteSizedCompletionModal
      expect(find.text('TIẾP TỤC HÀNH TRÌNH ›'), findsOneWidget);
      await tester.tap(find.text('TIẾP TỤC HÀNH TRÌNH ›'));
      await tester.pumpAndSettle();

      // Xác nhận đã vào M-14 CER Conclusion Screen
      expect(find.text('KẾT LUẬN CER'), findsOneWidget);
      expect(find.textContaining('Bãi Cọc Yên Giang'), findsOneWidget);

      // Chọn bằng chứng mạnh nhất: Di chỉ khảo cổ bãi cọc Yên Giang
      await tester.tap(find.textContaining('Di Chỉ Khảo Cổ Bãi Cọc Yên Giang'));
      await tester.pumpAndSettle();

      // Bấm xác lập luận điểm CER
      await tester.scrollUntilVisible(find.text('XÁC LẬP LUẬN ĐIỂM CER'), 100);
      await tester.tap(find.text('XÁC LẬP LUẬN ĐIỂM CER'));
      await tester.pumpAndSettle();

      // Xác nhận hiển thị phần Reasoning và Danh hiệu Sử học Trẻ tuổi
      expect(find.textContaining('R — REASONING'), findsOneWidget);
      expect(find.text('🏅 NHÀ SỬ HỌC TRẺ'), findsOneWidget);

      // 14. Bấm hoàn thành để chuyển sang M-18 Khải Hoàn Chiến Dịch
      await tester.scrollUntilVisible(
        find.textContaining('HOÀN THÀNH & KHẢI HOÀN CHIẾN DỊCH (M-18)'),
        100,
      );
      await tester.tap(
        find.textContaining('HOÀN THÀNH & KHẢI HOÀN CHIẾN DỊCH (M-18)'),
      );
      await tester.pumpAndSettle();

      // Xác nhận và đóng BiteSizedCompletionModal — demo flow kết thúc
      // bằng điều hướng về dashboard (real mode không hiển thị fabricated
      // M-18/19/21 reward screens; các route đó chỉ sống trong USE_MOCK).
      expect(find.text('TIẾP TỤC HÀNH TRÌNH ›'), findsOneWidget);
      await tester.tap(find.text('TIẾP TỤC HÀNH TRÌNH ›'));
      await tester.pumpAndSettle();

      // Xác nhận đã quay về Dashboard — real mode không đi qua
      // fabricated victory/claim/artifact screens.
      expect(find.text('Học tập'), findsWidgets);

      // 15. Mở tab Sưu tập qua bottom nav mới (tab 2 /collection).
      await tester.tap(find.byIcon(Icons.auto_stories_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Bộ Sưu Tập Dấu Việt'), findsOneWidget);

      // Quay về tab Học tập qua bottom nav.
      await tester.tap(find.byIcon(Icons.school_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Học tập'), findsWidgets);

      // 16. Mở tab Cá nhân qua bottom nav (tab 3 /profile) — P0-02 mới.
      await tester.tap(find.byIcon(Icons.person_outline_rounded));
      await tester.pumpAndSettle();
      // Thẻ thành tích đọc rewardSummaryProvider (load async qua repo
      // chưa override → hiển thị loading). Kiểm tra khung màn đã vào đúng:
      // nhãn mục QUẢN LÝ + TÀI KHOẢN của Profile render ngay, và bottom nav
      // vẫn hiện tab Cá nhân đang chọn.
      expect(find.text('QUẢN LÝ'), findsOneWidget);
      expect(find.text('TÀI KHOẢN'), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    },
  );
}
