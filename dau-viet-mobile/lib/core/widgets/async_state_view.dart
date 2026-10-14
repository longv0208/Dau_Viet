import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../theme/dau_viet_colors.dart';
import '../theme/dau_viet_typography.dart';
import 'dong_son_button.dart';
import 'parchment_card.dart';

/// Khối hiển thị trạng thái async dùng chung cho các màn hình dữ liệu:
/// loading / lỗi + nút thử lại / rỗng. Giữ tone giấy dó Đồng Sơn.
class AsyncStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final bool isLoading;

  const AsyncStateView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.onRetry,
    this.isLoading = false,
  });

  /// Trạng thái đang tải — spinner thương hiệu trên nền giấy dó.
  factory AsyncStateView.loading({Key? key, String? message}) {
    return AsyncStateView(
      key: key,
      icon: Icons.history_edu_rounded,
      title: 'Đang nạp sử liệu...',
      message: message,
      isLoading: true,
    );
  }

  /// Trạng thái lỗi — kèm nút "Thử lại" (retry tường minh, không vòng lặp).
  factory AsyncStateView.error({
    Key? key,
    required Object error,
    required VoidCallback onRetry,
  }) {
    return AsyncStateView(
      key: key,
      icon: Icons.cloud_off_rounded,
      title: 'Chưa tải được sử liệu',
      message: _friendlyMessage(error),
      onRetry: onRetry,
    );
  }

  /// Trạng thái rỗng — danh sách API trả về không có phần tử.
  factory AsyncStateView.empty({Key? key, String? message}) {
    return AsyncStateView(
      key: key,
      icon: Icons.auto_stories_outlined,
      title: 'Chưa có sự kiện nào',
      message: message ?? 'Hồ sơ sử liệu đang được biên soạn, quay lại sau nhé.',
    );
  }

  static String _friendlyMessage(Object error) {
    if (error is ApiException) {
      if (error.isNotFound) {
        return 'Không tìm thấy hồ sơ sự kiện này.';
      }
      return error.error.message;
    }
    return 'Đã có lỗi xảy ra, vui lòng thử lại.';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ParchmentCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: DauVietColors.cinnabarRed,
                  ),
                )
              else
                Icon(icon, size: 40, color: DauVietColors.cinnabarRed),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: DauVietTypography.headlineMedium.copyWith(
                  fontSize: 16,
                  color: DauVietColors.inkText,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.inkMuted,
                    height: 1.4,
                  ),
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: 18),
                DongSonButton(
                  label: 'THỬ LẠI',
                  icon: Icons.refresh_rounded,
                  variant: DongSonButtonVariant.primaryCinnabar,
                  height: 44,
                  onPressed: onRetry,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
