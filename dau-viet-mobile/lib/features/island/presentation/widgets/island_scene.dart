import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../data/island_dto.dart';
import 'island_slot_widget.dart';

/// Canvas isometric 2.5D hiển thị đảo di sản, hỗ trợ pan & zoom qua [InteractiveViewer].
class IslandScene extends StatefulWidget {
  final IslandDto island;
  final String? selectedSlotId;
  final ValueChanged<IslandSlotDto?> onSelectSlot;
  final TransformationController? transformationController;

  const IslandScene({
    super.key,
    required this.island,
    required this.selectedSlotId,
    required this.onSelectSlot,
    this.transformationController,
  });

  @override
  State<IslandScene> createState() => _IslandSceneState();
}

class _IslandSceneState extends State<IslandScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waterController;
  late final Animation<double> _waterRipple;

  // Kích thước canvas ảo cho bản đồ 2.5D — đọc từ layout metadata (ISLAND-03).
  // Fallback 960x720 nếu backend chưa trả layout fields (backward compat).
  static const double _defaultCanvasWidth = 960.0;
  static const double _defaultCanvasHeight = 720.0;

  @override
  void initState() {
    super.initState();
    _waterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    _waterRipple = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waterController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _waterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Canvas size từ layout metadata; fallback 960x720 cho mock/backward compat.
    final canvasWidth = widget.island.canvasWidth > 0
        ? widget.island.canvasWidth
        : _defaultCanvasWidth;
    final canvasHeight = widget.island.canvasHeight > 0
        ? widget.island.canvasHeight
        : _defaultCanvasHeight;

    // Sắp xếp các slot theo zIndex tăng dần để slot trước đè lên slot sau
    final sortedSlots = List<IslandSlotDto>.from(widget.island.slots)
      ..sort((a, b) {
        if (a.zIndex != b.zIndex) return a.zIndex.compareTo(b.zIndex);
        // Fallback: nếu zIndex bằng nhau, so sánh theo trục y (y lớn hơn ở phía dưới màn hình)
        return a.y.compareTo(b.y);
      });

    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: InteractiveViewer(
            transformationController: widget.transformationController,
            minScale: 0.65,
            maxScale: 2.2,
            boundaryMargin: const EdgeInsets.all(120),
            constrained: false,
            child: GestureDetector(
              onTap: () => widget.onSelectSlot(null),
              behavior: HitTestBehavior.translucent,
              child: SizedBox(
                width: canvasWidth,
                height: canvasHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 1. Lớp Nền Biển Nước & Hiệu ứng sóng nhẹ
                    Positioned.fill(child: _buildWaterBackground()),

                    // 2. Lớp Đảo Di Sản 2.5D (Artwork Base)
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/dv_ISL_generic_island-base-tiers_v01.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildFallbackIslandGraphics();
                        },
                      ),
                    ),

                    // 3. Lớp gợn sóng biển viền đảo (Ambient Ripple Overlay)
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _waterRipple,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: _WaterAmbientPainter(
                              progress: _waterRipple.value,
                            ),
                          );
                        },
                      ),
                    ),

                    // 4. Lớp Các Slot Vật Phẩm (Sắp xếp theo zIndex)
                    ...sortedSlots.map((slot) {
                      final left = (slot.x * canvasWidth) - 50.0;
                      final top = (slot.y * canvasHeight) - 55.0;
                      final isSelected = slot.slotId == widget.selectedSlotId;

                      return Positioned(
                        left: left,
                        top: top,
                        child: IslandSlotWidget(
                          slot: slot,
                          isSelected: isSelected,
                          onTap: () => widget.onSelectSlot(slot),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Nền nước biển chuyển sắc xanh lam giang
  Widget _buildWaterBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.85,
          colors: [
            Color(0xFF86B9CF), // Xanh biển tươi ở tâm
            Color(0xFF4A89A6), // Xanh sẫm ngoài rìa
          ],
        ),
      ),
    );
  }

  /// Nền đảo dự phòng khi asset ảnh chưa nạp xong
  Widget _buildFallbackIslandGraphics() {
    return Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE8F4F8), Color(0xFFC7E2E6)],
        ),
      ),
      child: Container(
        width: 600,
        height: 380,
        decoration: BoxDecoration(
          color: const Color(0xFFD6C29E),
          borderRadius: BorderRadius.all(Radius.elliptical(600, 380)),
          border: Border.all(color: DauVietColors.woodBrown, width: 4),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              offset: Offset(0, 16),
              blurRadius: 24,
            ),
          ],
        ),
      ),
    );
  }
}

/// Painter vẽ các đường gợn sóng nước phản chiếu ánh sáng nhẹ.
class _WaterAmbientPainter extends CustomPainter {
  final double progress;

  _WaterAmbientPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08 + (progress * 0.06))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Vài đường gợn nước elip góc biển
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.22, size.height * 0.78),
        width: 140 + (progress * 20),
        height: 40 + (progress * 10),
      ),
      paint,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.82, size.height * 0.32),
        width: 180 + (progress * 25),
        height: 50 + (progress * 12),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _WaterAmbientPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
