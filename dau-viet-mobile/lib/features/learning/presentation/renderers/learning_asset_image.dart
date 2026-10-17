import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_config.dart';
import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../data/learning_providers.dart';

/// Ảnh học liệu tải qua `GET /api/v1/assets/{id}/content` có Bearer.
/// Placeholder khi đang tải; fallback alt-text khi lỗi/mất mạng — không crash.
class LearningAssetImage extends ConsumerWidget {
  final String assetId;
  final String? altText;
  final double? height;
  final BoxFit fit;

  const LearningAssetImage({
    super.key,
    required this.assetId,
    this.altText,
    this.height,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<int>>(
      future: _fetch(ref),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _frame(
            const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final bytes = snapshot.data;
        if (snapshot.hasError || bytes == null || bytes.isEmpty) {
          return _frame(_Fallback(altText: altText));
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            Uint8List.fromList(bytes),
            height: height,
            width: double.infinity,
            fit: fit,
            errorBuilder: (_, e, st) => _frame(_Fallback(altText: altText)),
          ),
        );
      },
    );
  }

  Future<List<int>> _fetch(WidgetRef ref) {
    final repo = ref.read(attemptRepositoryProvider);
    if (ApiConfig.useMock) return repo.getAssetBytes(assetId);
    return ref
        .read(authRepositoryProvider)
        .withAuth(() => repo.getAssetBytes(assetId));
  }

  Widget _frame(Widget child) => Container(
    height: height ?? 200,
    width: double.infinity,
    decoration: BoxDecoration(
      color: DauVietColors.parchmentContainer.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: DauVietColors.outlineVariant),
    ),
    child: child,
  );
}

class _Fallback extends StatelessWidget {
  final String? altText;
  const _Fallback({this.altText});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.broken_image_outlined,
              color: DauVietColors.inkMuted,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              (altText != null && altText!.isNotEmpty)
                  ? altText!
                  : 'Không tải được hình ảnh.',
              textAlign: TextAlign.center,
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
