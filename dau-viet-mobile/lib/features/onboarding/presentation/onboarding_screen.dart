import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/prefs/onboarding_flag.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/dong_son_button.dart';

/// Onboarding 3 bước cho lần đầu mở app (P1-02).
/// Có nút Bỏ qua; hoàn thành hoặc bỏ qua đều ghi [OnboardingFlag.markSeen]
/// và đưa về đích đã chọn (auth nếu chưa đăng nhập, dashboard nếu đã có).
class OnboardingScreen extends ConsumerStatefulWidget {
  /// Đích đến sau khi xem/bỏ qua — splash truyền theo auth state.
  final String destination;

  const OnboardingScreen({super.key, this.destination = '/auth'});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const List<({IconData icon, String title, String body})> _steps = [
    (
      icon: Icons.explore_rounded,
      title: 'Học sử như điều tra',
      body:
          'Khám phá từng sự kiện lịch sử Việt Nam qua hành trình: đọc bối cảnh, '
          'giải hoạt động, thu thập bằng chứng — thay vì đọc thuộc.',
    ),
    (
      icon: Icons.auto_stories_rounded,
      title: 'Bằng chứng thật, tiến độ thật',
      body:
          'Mỗi bài học hoàn thành mở khoá bằng chứng trong Sưu tập và điểm '
          'kinh nghiệm — tất cả lưu trên tài khoản của bạn.',
    ),
    (
      icon: Icons.map_rounded,
      title: 'Hành trình theo chương',
      body:
          'Bản đồ Dấu Ấn dẫn bạn qua các chương mở khoá dần. Bắt đầu ở sự '
          'kiện đầu tiên và theo vết đến hết câu chuyện.',
    ),
  ];

  final PageController _pageCtrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await OnboardingFlag.markSeen();
    if (!mounted) return;
    context.go(widget.destination);
  }

  void _next() {
    if (_page < _steps.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLast = _page == _steps.length - 1;
    return Scaffold(
      backgroundColor: DauVietColors.parchmentSurface,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [DauVietColors.parchmentSurface, Color(0xFFFAF2E4)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  // Hàng Bỏ qua — luôn có để không kẹt người dùng.
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _finish,
                      child: Text(
                        'Bỏ qua',
                        style: DauVietTypography.labelMedium.copyWith(
                          color: DauVietColors.inkMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageCtrl,
                      itemCount: _steps.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (context, i) {
                        final step = _steps[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: DauVietColors.parchmentContainer,
                                  border: Border.all(
                                    color: DauVietColors.imperialGold,
                                    width: 2.5,
                                  ),
                                  boxShadow: DauVietColors.heritageShadow,
                                ),
                                child: Icon(
                                  step.icon,
                                  size: 54,
                                  color: DauVietColors.cinnabarRed,
                                ),
                              ),
                              const SizedBox(height: 28),
                              Text(
                                step.title,
                                textAlign: TextAlign.center,
                                style: DauVietTypography.headlineMedium
                                    .copyWith(
                                      color: DauVietColors.cinnabarRed,
                                      fontSize: 22,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                step.body,
                                textAlign: TextAlign.center,
                                style: DauVietTypography.bodyMedium.copyWith(
                                  color: DauVietColors.inkText,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Chỉ báo trang
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < _steps.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _page ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _page
                                ? DauVietColors.cinnabarRed
                                : DauVietColors.outlineVariant,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: DongSonButton(
                      label: isLast ? 'BẮT ĐẦU' : 'TIẾP TỤC',
                      icon: isLast
                          ? Icons.flag_rounded
                          : Icons.arrow_forward_rounded,
                      variant: DongSonButtonVariant.primaryCinnabar,
                      height: 52,
                      onPressed: _next,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
