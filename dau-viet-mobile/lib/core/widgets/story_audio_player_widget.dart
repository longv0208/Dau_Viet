import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../audio/dau_viet_audio_service.dart';
import '../theme/dau_viet_colors.dart';
import '../theme/dau_viet_typography.dart';

/// Widget phát âm thanh giọng đọc sử liệu với hiệu ứng sóng âm (Audio Waveform)
/// mô phỏng chế độ Story Reading Mode đặc trưng của Duolingo mang phong vị Dấu Việt.
class StoryAudioPlayerWidget extends StatefulWidget {
  final String title;
  final String? audioAsset;
  final bool compact;

  const StoryAudioPlayerWidget({
    super.key,
    this.title = 'Giọng đọc sử liệu: Đại Việt Sử Ký Toàn Thư',
    this.audioAsset,
    this.compact = false,
  });

  @override
  State<StoryAudioPlayerWidget> createState() => _StoryAudioPlayerWidgetState();
}

class _StoryAudioPlayerWidgetState extends State<StoryAudioPlayerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DauVietAudioService.instance,
      builder: (context, _) {
        final audioService = DauVietAudioService.instance;
        final isPlaying = audioService.isNarrationPlaying;

        // Quản lý animation sóng âm theo trạng thái phát
        if (isPlaying && !_waveController.isAnimating) {
          _waveController.repeat();
        } else if (!isPlaying && _waveController.isAnimating) {
          _waveController.stop();
        }

        final currentPos = audioService.narrationPosition;
        final totalDur = audioService.narrationDuration;

        if (widget.compact) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: DauVietColors.parchmentContainer,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: DauVietColors.imperialGold.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    if (isPlaying) {
                      audioService.pauseNarration();
                    } else {
                      audioService.playNarration(
                        assetPath:
                            widget.audioAsset ??
                            DauVietAudioService.defaultNarrationPath,
                      );
                    }
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: DauVietColors.cinnabarRed,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPlaying ? Icons.pause_rounded : Icons.volume_up_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildWaveformBars(isPlaying, count: 5, barMaxHeight: 16),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(currentPos),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: DauVietColors.inkText,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: DauVietColors.parchmentContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPlaying
                  ? DauVietColors.cinnabarRed
                  : DauVietColors.imperialGold,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    (isPlaying
                            ? DauVietColors.cinnabarRed
                            : DauVietColors.imperialGold)
                        .withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Nút Play / Pause tròn kiểu 3D
                  GestureDetector(
                    onTap: () {
                      if (isPlaying) {
                        audioService.pauseNarration();
                      } else {
                        audioService.playNarration(
                          assetPath:
                              widget.audioAsset ??
                              DauVietAudioService.defaultNarrationPath,
                        );
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isPlaying
                              ? [
                                  DauVietColors.cinnabarRed,
                                  DauVietColors.cinnabarRedDark,
                                ]
                              : [
                                  DauVietColors.imperialGold,
                                  DauVietColors.woodBrown,
                                ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Thông tin bài đọc & trạng thái
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: DauVietTypography.headlineMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: DauVietColors.inkText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isPlaying
                              ? 'Đang truyền cảm sử thi...'
                              : 'Bấm để nghe giọng dẫn truyền cảm',
                          style: TextStyle(
                            fontSize: 11,
                            color: isPlaying
                                ? DauVietColors.cinnabarRed
                                : DauVietColors.inkMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Nút dừng (Stop) nếu đang phát
                  if (isPlaying)
                    IconButton(
                      tooltip: 'Dừng đọc',
                      icon: const Icon(
                        Icons.stop_circle_outlined,
                        size: 22,
                        color: DauVietColors.cinnabarRed,
                      ),
                      onPressed: () => audioService.stopNarration(),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              // Hàng sóng âm hoạt họa và thanh tiến độ
              Row(
                children: [
                  _buildWaveformBars(isPlaying, count: 7, barMaxHeight: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: totalDur.inMilliseconds > 0
                            ? (currentPos.inMilliseconds /
                                      totalDur.inMilliseconds)
                                  .clamp(0.0, 1.0)
                            : 0.0,
                        backgroundColor: DauVietColors.imperialGold.withValues(
                          alpha: 0.2,
                        ),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          DauVietColors.cinnabarRed,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_formatDuration(currentPos)} / ${_formatDuration(totalDur)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: DauVietColors.inkText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWaveformBars(
    bool isPlaying, {
    int count = 6,
    double barMaxHeight = 20,
  }) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(count, (index) {
            final phase = (index / count) * 2 * math.pi;
            final progress = _waveController.value * 2 * math.pi;
            final waveVal = isPlaying
                ? (math.sin(progress + phase) + 1.0) / 2.0
                : 0.25;
            final height = 5.0 + (barMaxHeight - 5.0) * waveVal;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 3.5,
              height: height,
              decoration: BoxDecoration(
                color: isPlaying
                    ? DauVietColors.cinnabarRed
                    : DauVietColors.outline.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
