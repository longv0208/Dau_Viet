import 'dart:ui';

/// Vị trí một node trên canvas hành trình — pure function, testable.
/// Đường đi zigzag trái ↔ phải theo index, KHÔNG phụ thuộc lat/lng.
class JourneyLayout {
  /// Tỉ lệ chiều rộng canvas cho vị trí node ở index chẵn (trái) / lẻ (phải).
  static const List<double> _lanes = [0.28, 0.72];

  /// Khoảng dọc giữa 2 node liên tiếp.
  static const double rowGap = 148.0;

  /// Padding trên/dưới để node đầu/cuối không dính mép.
  static const double padTop = 96.0;
  static const double padBottom = 110.0;

  /// Tổng chiều cao canvas cho [count] node — tối thiểu 1 node vẫn đẹp.
  static double canvasHeight(int count) =>
      padTop + padBottom + (count <= 0 ? 0 : (count - 1) * rowGap) + 60;

  /// Tâm node [index] trong canvas rộng [width].
  static Offset nodeCenter(int index, double width) {
    final lane = _lanes[index % _lanes.length];
    return Offset(width * lane, padTop + index * rowGap);
  }

  /// Tâm tất cả node.
  static List<Offset> centers(int count, double width) => [
    for (int i = 0; i < count; i++) nodeCenter(i, width),
  ];
}
