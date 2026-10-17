import '../models/timeline_models.dart';

/// Dữ liệu mẫu Trục Thời Gian Lịch Sử Việt Nam (M-04)
class MockTimelineData {
  MockTimelineData._();

  static const List<String> eras = [
    'Tất cả',
    'Khởi nghĩa Bắc thuộc (40 - 937)',
    'Thời Ngô - Đinh - Tiền Lê (938 - 1009)',
    'Thời Lý - Trần (1009 - 1400)',
    'Hậu Lê - Tây Sơn (1428 - 1802)',
  ];

  static const List<TimelineMilestoneModel> milestones = [
    TimelineMilestoneModel(
      id: 'ms_hai_ba_trung',
      yearLabel: '40 – 43 SCN',
      yearValue: 40,
      title: 'Khởi Nghĩa Hai Bà Trưng',
      subtitle: 'Trưng Trắc - Trưng Nhị phất cờ tại Mê Linh',
      description:
          'Khởi nghĩa quật khởi đầu tiên đánh đuổi thái thú Tô Định, xưng vương dựng nền độc lập ngắn ngủi nhưng chói lọi.',
      era: 'Khởi nghĩa Bắc thuộc (40 - 937)',
      badgeText: 'Mê Linh quật khởi',
    ),
    TimelineMilestoneModel(
      id: 'ms_ly_nam_de',
      yearLabel: '544 – 602 SCN',
      yearValue: 544,
      title: 'Nhà Nước Vạn Xuân (Tiền Lý)',
      subtitle: 'Lý Bí khởi nghĩa xưng Lý Nam Đế',
      description:
          'Lập nên nhà nước Vạn Xuân độc lập tự chủ với kinh đô tại Long Biên, đúc tiền riêng, dựng chùa Trấn Quốc.',
      era: 'Khởi nghĩa Bắc thuộc (40 - 937)',
      badgeText: 'Khai sinh Vạn Xuân',
    ),
    TimelineMilestoneModel(
      id: 'ms_khuc_thua_du',
      yearLabel: '905 SCN',
      yearValue: 905,
      title: 'Khúc Thừa Dụ Xưng Tiết Độ Sứ',
      subtitle: 'Chính quyền tự chủ họ Khúc',
      description:
          'Tận dụng nhà Đường suy thoái, Khúc Thừa Dụ tiến vào thành Đại La xưng Tiết độ sứ, mở đầu thời kỳ độc lập tự chủ trên thực tế.',
      era: 'Khởi nghĩa Bắc thuộc (40 - 937)',
      badgeText: 'Mở nền tự chủ',
    ),
    TimelineMilestoneModel(
      id: 'ms_duong_dinh_nghe',
      yearLabel: '931 SCN',
      yearValue: 931,
      title: 'Dương Đình Nghệ Phá Quân Nam Hán',
      subtitle: 'Đại thắng tại thành Đại La',
      description:
          'Đánh tan đội quân tiếp viện của Trần Bảo, thu hồi hoàn toàn bờ cõi Giao Châu, chuẩn bị nền tảng cho trận quyết chiến 938.',
      era: 'Khởi nghĩa Bắc thuộc (40 - 937)',
      badgeText: 'Đại phá Trần Bảo',
    ),
    TimelineMilestoneModel(
      id: 'ms_bach_dang_938',
      yearLabel: 'Mùa Đông 938 SCN',
      yearValue: 938,
      title: 'Đại Chiến Bạch Đằng 938',
      subtitle: 'Tiền Ngô Vương Ngô Quyền & Kế sách cọc ngầm',
      description:
          'Trận thủy chiến kinh điển cắm cọc gỗ lim bịt sắt lợi dụng con nước triều, tiêu diệt hoàn toàn thủy quân Nam Hán của Lưu Hoằng Tháo, chính thức chấm dứt hơn 1.000 năm Bắc thuộc.',
      era: 'Thời Ngô - Đinh - Tiền Lê (938 - 1009)',
      isActive: true,
      eventId: 'evt_bach_dang_938',
      badgeText: 'Mốc son chói lọi • Đang mở',
    ),
    TimelineMilestoneModel(
      id: 'ms_dinh_bo_linh',
      yearLabel: '968 SCN',
      yearValue: 968,
      title: 'Đinh Bộ Lĩnh Lập Nước Đại Cồ Việt',
      subtitle: 'Dẹp loạn 12 sứ quân, định đô Hoa Lư',
      description:
          'Vạn Thắng Vương quy tụ giang sơn về một mối, xưng Hoàng đế (Đinh Tiên Hoàng), khẳng định vị thế quốc gia ngang hàng phương Bắc.',
      era: 'Thời Ngô - Đinh - Tiền Lê (938 - 1009)',
      badgeText: 'Đại Cồ Việt hưng khởi',
    ),
    TimelineMilestoneModel(
      id: 'ms_le_hoan_981',
      yearLabel: '981 SCN',
      yearValue: 981,
      title: 'Lê Hoàn Phá Tống Trên Sông Bạch Đằng',
      subtitle: 'Chiến dịch chống quân xâm lược nhà Tống',
      description:
          'Kế thừa nghệ thuật thủy chiến Bạch Đằng của Ngô Quyền, Lê Đại Hành tiếp tục đánh bại thủy bộ quân Tống bảo vệ vững chắc biên cương.',
      era: 'Thời Ngô - Đinh - Tiền Lê (938 - 1009)',
      badgeText: 'Phá Tống Bạch Đằng',
    ),
    TimelineMilestoneModel(
      id: 'ms_ly_thai_to',
      yearLabel: '1010 SCN',
      yearValue: 1010,
      title: 'Lý Thái Tổ Dời Đô Về Thăng Long',
      subtitle: 'Khởi đầu Vương triều Lý rực rỡ',
      description:
          'Chiếu dời đô từ Hoa Lư về thành Đại La đổi tên là Thăng Long, mở ra thời kỳ văn hóa Lý - Trần đỉnh cao văn hiến.',
      era: 'Thời Lý - Trần (1009 - 1400)',
      badgeText: 'Chiếu Dời Đô',
    ),
    TimelineMilestoneModel(
      id: 'ms_bach_dang_1288',
      yearLabel: '1288 SCN',
      yearValue: 1288,
      title: 'Trần Hưng Đạo Đại Thắng Bạch Đằng 1288',
      subtitle: 'Tiêu diệt đoàn thuyền lương Ô Mã Nhi',
      description:
          'Lần thứ ba sông Bạch Đằng chứng kiến nghệ thuật cọc ngầm đánh tan hạm đội bách chiến bách thắng của đế quốc Mông - Nguyên.',
      era: 'Thời Lý - Trần (1009 - 1400)',
      badgeText: 'Hào khí Đông A',
    ),
  ];
}
