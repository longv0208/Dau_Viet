import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dau_viet_mobile/app/app.dart';
import 'package:dau_viet_mobile/core/widgets/energy_pill.dart';

void main() {
  testWidgets('DauVietApp full user journey: M-01 to M-16 & Phase M5 (M-11 Matching, M-12 Order)', (WidgetTester tester) async {
    // Cài đặt viewport chuẩn mobile (412 x 915)
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: DauVietApp(),
      ),
    );
    await tester.pump();

    // 1. Khởi động màn hình M-01 Splash
    expect(find.text('DẤU VIỆT'), findsWidgets);
    expect(find.text('Khám phá Hào khí Sử Việt qua Từng Dấu Vết'), findsOneWidget);

    // Chờ timer 3 giây để điều hướng sang M-02 AuthScreen
    await tester.pump(const Duration(milliseconds: 3000));
    await tester.pumpAndSettle();

    // 2. Xác nhận màn hình M-02 Đăng nhập / Chế độ Khách
    expect(find.text('SĨ TỬ NHẬP MÔN'), findsOneWidget);
    expect(find.text('Vào Học Ngay (Chế độ Khách)'), findsOneWidget);

    // Bấm nút Chế độ Khách để vào M-03 Learner Dashboard
    await tester.tap(find.text('Vào Học Ngay (Chế độ Khách)'));
    await tester.pumpAndSettle();

    // 3. Xác nhận màn hình M-03 Bàn Học Tập
    expect(find.text('Bàn Học Tập Sử Ký'), findsOneWidget);
    expect(find.text('Chiến Dịch Bạch Đằng 938'), findsOneWidget);
    expect(find.text('Tiếp tục bài học ngay ->'), findsOneWidget);

    // 4. Điều hướng sang M-04 Dòng Thời Gian (Lược Sử) qua Bottom Nav Bar
    await tester.tap(find.byIcon(Icons.auto_stories_outlined));
    await tester.pumpAndSettle();

    // Xác nhận đã vào M-04 Timeline
    expect(find.text('DÒNG THỜI GIAN LỊCH SỬ'), findsOneWidget);
    expect(find.text('Khởi Nghĩa Hai Bà Trưng'), findsOneWidget);

    // 5. Điều hướng sang M-06 Sa Bàn qua Bottom Nav Bar
    await tester.tap(find.byIcon(Icons.military_tech_outlined));
    await tester.pumpAndSettle();

    // Xác nhận đã vào M-06 Sa Bàn Thủy Chiến
    expect(find.text('SA BÀN THỦY CHIẾN BẠCH ĐẰNG'), findsOneWidget);
    expect(find.text('CHU KỲ THỦY TRIỀU CHIẾN THUẬT'), findsOneWidget);

    // Thử tương tác đổi con nước sang Giờ Mùi (Triều rút cạn)
    await tester.tap(find.textContaining('3. Giờ Mùi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Triều rút cạn'), findsWidgets);

    // 6. Điều hướng sang M-07 Chi Tiết Chiến Dịch từ nút trên Sa Bàn
    await tester.scrollUntilVisible(find.text('Xem Chi Tiết Chiến Dịch'), 100);
    await tester.tap(find.text('Xem Chi Tiết Chiến Dịch'));
    await tester.pumpAndSettle();

    // Xác nhận đã vào M-07 Campaign Detail
    expect(find.text('CHI TIẾT CHIẾN DỊCH'), findsOneWidget);
    expect(find.text('Kế Sách Cọc Ngầm Đè Bẹp Thủy Quân Nam Hán'), findsOneWidget);

    // 7. Bấm vào Bắt Đầu Khám Phá để mở M-08 Trung Tâm 4 Dấu Vết
    await tester.scrollUntilVisible(find.text('BẮT ĐẦU KHÁM PHÁ (4 DẤU VẾT) ›'), 100);
    await tester.tap(find.text('BẮT ĐẦU KHÁM PHÁ (4 DẤU VẾT) ›'));
    await tester.pumpAndSettle();

    // Xác nhận đã vào M-08 Traces Hub
    expect(find.text('4 DẤU VẾT LỊCH SỬ'), findsOneWidget);
    expect(find.text('Dấu Vết 1: Bối Cảnh & Quân Mưu'), findsOneWidget);

    // 8. Bấm nút Bắt đầu Dấu vết 1 để mở M-09 Đọc Bối Cảnh Lịch Sử
    await tester.scrollUntilVisible(find.text('BẮT ĐẦU DẤU VẾT 1: BỐI CẢNH (M-09) ›'), 100);
    await tester.tap(find.text('BẮT ĐẦU DẤU VẾT 1: BỐI CẢNH (M-09) ›'));
    await tester.pumpAndSettle();

    // Xác nhận đã vào M-09 Context Reader
    expect(find.text('BỐI CẢNH LỊCH SỬ'), findsOneWidget);
    expect(find.text('Khảo Cứu Quân Mưu Tiền Ngô Vương'), findsOneWidget);

    // 9. Bấm nút Làm Trắc Nghiệm để mở M-16 Multiple Choice Quiz
    await tester.scrollUntilVisible(find.text('LÀM TRẮC NGHIỆM TƯ LIỆU (M-16) ›'), 100);
    await tester.tap(find.text('LÀM TRẮC NGHIỆM TƯ LIỆU (M-16) ›'));
    await tester.pumpAndSettle();

    // Xác nhận đã vào M-16 Quiz Screen
    expect(find.text('KIỂM CHỨNG TƯ LIỆU'), findsOneWidget);
    expect(find.text('CÂU HỎI TRUNG TÂM SỬ KÝ'), findsOneWidget);

    // Chọn phương án A (đúng)
    await tester.tap(find.textContaining('con nước triều đang rút cạn lộ bãi'));
    await tester.pumpAndSettle();

    // Bấm nút Kiểm tra kết quả
    await tester.scrollUntilVisible(find.text('KIỂM TRA KẾT QUẢ'), 100);
    await tester.tap(find.text('KIỂM TRA KẾT QUẢ'));
    await tester.pumpAndSettle();

    // Xác nhận phản hồi sư phạm đúng
    expect(find.text('XUẤT SẮC! CĂN CỨ SỬ HỌC CHÍNH XÁC'), findsOneWidget);

    // Bấm hoàn thành quay lại Traces Hub
    await tester.scrollUntilVisible(find.text('HOÀN THÀNH DẤU VẾT 1 & TIẾP TỤC ›'), 100);
    await tester.tap(find.text('HOÀN THÀNH DẤU VẾT 1 & TIẾP TỤC ›'));
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
    await tester.tap(find.text('Quân Nam Hán'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Hạm đội xâm lược'));
    await tester.pumpAndSettle();

    // Bấm kiểm tra kết quả ghép nối
    await tester.scrollUntilVisible(find.text('KIỂM TRA KẾT QUẢ GHÉP NỐI'), 100);
    await tester.tap(find.text('KIỂM TRA KẾT QUẢ GHÉP NỐI'));
    await tester.pumpAndSettle();

    expect(find.text('XUẤT SẮC! GHÉP NỐI CHÍNH XÁC 100%'), findsOneWidget);

    // 11. Tiếp tục sang M-12 Sắp Xếp Niên Đại (Dấu Vết 3)
    await tester.scrollUntilVisible(find.textContaining('HOÀN THÀNH DẤU VẾT 2'), 100);
    await tester.tap(find.textContaining('HOÀN THÀNH DẤU VẾT 2'));
    await tester.pumpAndSettle();

    // Xác nhận đã vào M-12 Chronological Order
    expect(find.text('SẮP XẾP NIÊN ĐẠI'), findsOneWidget);
    expect(find.text('Địch Vượt Cửa Biển'), findsOneWidget);
    expect(find.text('Chuẩn Bị Cọc Ngầm'), findsOneWidget);

    // Điều chỉnh thứ tự: Di chuyển "Chuẩn Bị Cọc Ngầm" lên vị trí 1
    // Icon mũi tên lên đầu tiên có thể bấm được là của item index 1 ("Chuẩn Bị Cọc Ngầm")
    final upArrows = find.byIcon(Icons.keyboard_arrow_up_rounded);
    await tester.tap(upArrows.at(1));
    await tester.pumpAndSettle();

    // Di chuyển "Khiêu Chiến & Nhử Địch" (đang ở vị trí 4) lên vị trí 3
    await tester.tap(upArrows.at(3));
    await tester.pumpAndSettle();

    // Bấm nút kiểm tra thứ tự
    await tester.scrollUntilVisible(find.text('KIỂM TRA THỨ TỰ NIÊN ĐẠI'), 100, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('KIỂM TRA THỨ TỰ NIÊN ĐẠI'));
    await tester.pumpAndSettle();

    expect(find.text('TUYỆT VỜI! ĐÚNG TRÌNH TỰ CHIẾN THUẬT'), findsOneWidget);

    // Bấm hoàn thành quay lại Traces Hub
    await tester.scrollUntilVisible(find.textContaining('HOÀN THÀNH DẤU VẾT 3'), 100, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.textContaining('HOÀN THÀNH DẤU VẾT 3'));
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
    await tester.tap(find.textContaining('Giả thuyết nghi vấn là SAI'));
    await tester.pumpAndSettle();

    // Bấm kiểm tra kết luận đối chiếu
    await tester.scrollUntilVisible(find.text('KIỂM TRA KẾT LUẬN ĐỐI CHIẾU'), 100);
    await tester.tap(find.text('KIỂM TRA KẾT LUẬN ĐỐI CHIẾU'));
    await tester.pumpAndSettle();

    expect(find.text('CHÍNH XÁC! TƯ DUY PHẢN BIỆN KHOA HỌC'), findsOneWidget);

    // 13. Tiếp tục sang M-14 Lập Luận CER (CER Conclusion)
    await tester.scrollUntilVisible(find.textContaining('TIẾP TỤC SANG LẬP LUẬN CER (M-14)'), 100);
    await tester.tap(find.textContaining('TIẾP TỤC SANG LẬP LUẬN CER (M-14)'));
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
    await tester.scrollUntilVisible(find.textContaining('HOÀN THÀNH & KHẢI HOÀN CHIẾN DỊCH (M-18)'), 100);
    await tester.tap(find.textContaining('HOÀN THÀNH & KHẢI HOÀN CHIẾN DỊCH (M-18)'));
    await tester.pumpAndSettle();

    // Xác nhận đã vào M-18 Event Victory Screen
    expect(find.text('ĐẠI THẮNG BẠCH ĐẰNG'), findsOneWidget);
    expect(find.text('SĨ TỬ THÔNG TUỆ'), findsOneWidget);
    expect(find.text('4 DẤU VẾT ĐÃ CHINH PHỤC (100%):'), findsOneWidget);

    // 15. Bấm nhận phần thưởng để mở M-19 Reward Claim Screen
    await tester.scrollUntilVisible(find.textContaining('NHẬN PHẦN THƯỞNG CHIẾN DỊCH (M-19)'), 100);
    await tester.tap(find.textContaining('NHẬN PHẦN THƯỞNG CHIẾN DỊCH (M-19)'));
    await tester.pumpAndSettle();

    // Xác nhận đã vào M-19 Reward Claim Screen
    expect(find.text('RƯƠNG BẢO VẬT HOÀNG GIA'), findsOneWidget);
    expect(find.text('+500'), findsOneWidget);
    expect(find.text('Hào Khí Bạch Đằng: Định Quốc An Dân'), findsOneWidget);

    // 16. Bấm xem chi tiết cổ vật để mở M-21 Warship Artifact Detail Screen
    await tester.scrollUntilVisible(find.textContaining('CHIÊM NGƯỠNG BẢO VẬT CHIẾN THUYỀN (M-21)'), 100);
    await tester.tap(find.textContaining('CHIÊM NGƯỠNG BẢO VẬT CHIẾN THUYỀN (M-21)'));
    await tester.pumpAndSettle();

    // Xác nhận đã vào M-21 Warship Artifact Detail Screen
    expect(find.text('Mô hình Chiến thuyền Bạch Đằng'), findsOneWidget);
    expect(find.text('Bảo vật Quốc gia'), findsOneWidget);
    expect(find.text('THÔNG SỐ QUÂN SỰ CỔ TRUYỀN:'), findsOneWidget);

    // 17. Bấm cất vào túi đồ và quay về Bàn học tập Dashboard
    await tester.scrollUntilVisible(find.textContaining('CẤT VÀO TÚI ĐỒ & VỀ BÀN HỌC (M-03)'), 100);
    await tester.tap(find.textContaining('CẤT VÀO TÚI ĐỒ & VỀ BÀN HỌC (M-03)'));
    await tester.pumpAndSettle();

    // Xác nhận đã quay về M-03 Bàn Học Tập
    expect(find.text('Bàn Học Tập Sử Ký'), findsOneWidget);

    // 18. Mở M-22 Đảo Di Sản Cá Nhân qua Bottom Nav Bar (Tab Di Sản)
    await tester.tap(find.byIcon(Icons.landscape_outlined));
    await tester.pumpAndSettle();

    // Xác nhận đã vào M-22 Heritage Island Screen
    expect(find.text('ĐẢO DI SẢN CÁ NHÂN'), findsOneWidget);
    expect(find.text('Đình Cổ'), findsOneWidget);
    expect(find.text('Bến Thuyền'), findsOneWidget);

    // 19. Mở M-27 Túi Đồ & Kho Trang Trí từ nút trên Đảo
    await tester.scrollUntilVisible(find.textContaining('MỞ TÚI ĐỒ & KHO TRANG TRÍ (M-27)'), 100);
    await tester.tap(find.textContaining('MỞ TÚI ĐỒ & KHO TRANG TRÍ (M-27)'));
    await tester.pumpAndSettle();

    // Xác nhận đã vào M-27 Inventory Screen
    expect(find.text('TÚI ĐỒ SĨ TỬ'), findsOneWidget);
    expect(find.textContaining('Mô hình Chiến thuyền Bạch Đằng'), findsWidgets);

    // Bấm quay về Bàn học tập từ Túi đồ
    await tester.scrollUntilVisible(find.textContaining('VỀ BÀN HỌC TẬP (DASHBOARD)'), 100, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.textContaining('VỀ BÀN HỌC TẬP (DASHBOARD)'));
    await tester.pumpAndSettle();

    // 20. Mở M-28 Quản Lý Năng Lượng & Viện Thái Y bằng cách bấm vào EnergyPill
    expect(find.text('Bàn Học Tập Sử Ký'), findsOneWidget);
    await tester.tap(find.byType(EnergyPill));
    await tester.pumpAndSettle();

    // Xác nhận đã vào M-28 Energy Management Screen
    expect(find.text('QUẢN LÝ THỂ LỰC'), findsOneWidget);
    expect(find.text('THỂ LỰC HIỆN TẠI'), findsOneWidget);
    expect(find.textContaining('Tĩnh Tâm Ôn Luyện'), findsOneWidget);

    // Bấm quay về Bàn học tập từ Viện Thái Y
    await tester.scrollUntilVisible(find.textContaining('VỀ BÀN HỌC TẬP (DASHBOARD)'), 100, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.textContaining('VỀ BÀN HỌC TẬP (DASHBOARD)'));
    await tester.pumpAndSettle();

    // Xác nhận kết thúc trọn vẹn tại Bàn học tập
    expect(find.text('Bàn Học Tập Sử Ký'), findsOneWidget);
  });
}
