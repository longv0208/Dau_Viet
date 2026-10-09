# ĐẶC TẢ THIẾT KẾ COMPONENT M-C13 & M-C14 (v2.0)
## Thư viện Giao diện Tương tác Hoạt động Học tập (Learning Engine UI Spec)

> **Thuộc hệ thống:** Dấu Việt v2.0 — Stylized 2D Historical Illustrated Adventure  
> **Áp dụng cho:** Flutter Mobile Learner App (`dau-viet-mobile`)  
> **Màn hình sử dụng:** M-11 (Ghép nối), M-13 (Kiểm chứng), M-16 (Trắc nghiệm tư liệu)  
> **Nguyên tắc cốt lõi:**  
> 1. Không dùng pixel-art; toàn bộ thẻ bài và đường nối là vector/widget tương tác chuẩn 60fps.  
> 2. Đạt chuẩn trợ năng WCAG 2.1 AA (Tương phản văn bản $\ge 4.5:1$, vùng chạm $\ge 48\times 48\text{dp}$).  
> 3. Hỗ trợ song song cả cơ chế Kéo (Drag-to-connect) và Chạm 2 lần (Tap-to-pair fallback) cho thiết bị di động.

---

## 1. COMPONENT M-C13: CHOICE OPTION (Thẻ Lựa Chọn Trắc Nghiệm)

### 1.1 Mục đích & Bối cảnh
`M-C13 ChoiceOption` là phần tử giao diện hiển thị từng đáp án trong hoạt động trắc nghiệm sử liệu (`M-16`), câu hỏi kiểm chứng giả thuyết (`M-13`), hoặc phản xạ nhanh bối cảnh. Component này cần phản ánh rõ nét sự phân cấp thị giác giữa các trạng thái: Chưa chọn, Đang chọn, Đúng, Sai, và Khóa.

### 1.2 Cấu trúc Hình học & Layout
- **Chiều cao tối thiểu:** $58\text{dp}$ (vượt chuẩn touch target $48\text{dp}$).
- **Bán kính bo góc (Border Radius):** $12\text{dp}$ (`rounded-xl`).
- **Padding nội bộ:** $14\text{dp}$ ngang, $12\text{dp}$ dọc.
- **Bố cục hàng ngang (Row):**
  - **Khối đầu (Leading Badge):** Vòng tròn đường kính $32\text{dp}$ chứa ký tự chữ cái (A, B, C, D) font `Noto Serif` Bold $14\text{sp}$.
  - **Khối giữa (Content Text):** Đoạn văn bản đáp án sử học font `Be Vietnam Pro` Regular/SemiBold $14\text{sp}$, canh trái, tự động ngắt dòng (`softWrap: true`), line-height $1.4$.
  - **Khối cuối (Trailing Status Icon):** Đường kính $24\text{dp}$, chỉ hiển thị khi ở trạng thái Xác thực (Checkmark xanh lá hoặc Cross đỏ).

### 1.3 Bảng Ma trận Trạng thái (State Matrix)

| Trạng thái | Nền (Background) | Viền (Border) | Huy hiệu chữ cái (Badge) | Màu chữ (Text) | Icon biểu thị |
|---|---|---|---|---|:---:|
| **Default** (Mặc định) | `#FFFBF4` (Cream) | `1px solid #D4C1A5` | Nền `#F3E5CE`, Chữ `#613B28` | `#30251F` (Ink Primary) | Không |
| **Hover / Focus** | `#FFF1D5` (Parchment) | `1.5px solid #8C6747` | Nền `#E7D5BA`, Chữ `#30251F` | `#30251F` | Không |
| **Pressed** (Khi nhấn) | `#F5ECE0` | `2px solid #A51F18` | Nền `#A51F18`, Chữ `#FFFFFF` | `#30251F` | Không |
| **Selected** (Đã chọn) | `#FFF1D5` | `2px solid #A51F18` | Nền `#A51F18`, Chữ `#FFFFFF` | `#A51F18` (Bold) | Radio dot |
| **Correct** (Đáp án Đúng) | `#F4F9F1` (Green Tint) | `2px solid #64824C` | Nền `#64824C`, Chữ `#FFFFFF` | `#1E3A1A` (Bold) | `✓` Checkmark |
| **Incorrect** (Đáp án Sai) | `#FDF3F2` (Red Tint) | `2px solid #B3261E` | Nền `#B3261E`, Chữ `#FFFFFF` | `#751B19` (Bold) | `✕` Cross |
| **Disabled** (Bị vô hiệu) | `#F5ECE0` | `1px solid #E6E2DB` | Nền `#E6E2DB`, Chữ `#A09C94` | `#A09C94` | Không |

### 1.4 Hiệu ứng Chuyển động (Animation Spec)
- **Tap Animation:** Thu nhỏ nhẹ `transform: scale(0.98)` trong $80\text{ms}$ khi ngón tay chạm xuống (`Curves.easeOutQuad`).
- **State Transition:** `ColorLerp` mượt mà trong $200\text{ms}$ giữa các màu nền và màu viền khi chuyển từ Selected sang Verified Correct/Incorrect.
- **Haptic Feedback:** Rung nhẹ `HapticFeedback.lightImpact()` khi chọn đáp án; rung `selectionClick()` khi kiểm tra đúng.

### 1.5 Hợp đồng Lập trình Flutter (Dart Interface)
```dart
enum ChoiceState { defaultState, selected, correct, incorrect, disabled }

class ChoiceOptionWidget extends StatelessWidget {
  final String indexLabel; // 'A', 'B', 'C', 'D'
  final String text;
  final ChoiceState state;
  final VoidCallback? onTap;

  const ChoiceOptionWidget({
    Key? key,
    required this.indexLabel,
    required this.text,
    this.state = ChoiceState.defaultState,
    this.onTap,
  }) : super(key: key);
  
  // Implementation details with DauViet tokens
}
```

---

## 2. COMPONENT M-C14: MATCHING BOARD (Bàn Cờ Ghép Nối Hai Cột)

### 2.1 Mục đích & Bối cảnh
`M-C14 MatchingBoard` phục vụ các bài toán tư duy liên hệ lịch sử (`M-11`): nối Nhân vật với Chiến công, Địa danh với Diễn biến, hoặc Hiện vật khảo cổ với Niên đại thời kỳ.

### 2.2 Kiến trúc Tầng Lớp (Layer Hierarchy)
Component gồm 3 lớp xếp chồng nhau trong một Flutter `Stack`:
1. **Lớp Dưới (Column Cards Layer):** Hai cột dọc (Cột Trái: Thẻ Khởi nguồn `SourceItems`, Cột Phải: Thẻ Đích `TargetItems`).
2. **Lớp Giữa (Interactive Canvas Layer):** `CustomPaint` với `MatchingLinePainter` vẽ các đường cong Bezier lụa (`Silk thread lines`) kết nối các chốt neo (`Anchor Dots`).
3. **Lớp Trên (Gesture & Floating Touch Layer):** Bộ nhận diện cử chỉ `Listener` / `GestureDetector` theo dõi tọa độ ngón tay đang kéo hoặc điểm đang chạm.

### 2.3 Thuật toán Đường Cong Nối Chỉ Lụa (Cubic Bezier Spline)
Để tạo cảm giác chỉ son truyền thống mềm mại tự nhiên, đường nối giữa điểm đầu $P_0(x_0, y_0)$ trên mép phải thẻ trái và điểm cuối $P_3(x_3, y_3)$ trên mép trái thẻ phải được tính theo đường cong Bezier bậc 3:
$$\Delta x = |x_3 - x_0| \times 0.5$$
$$C_1 = (x_0 + \Delta x, y_0)$$
$$C_2 = (x_3 - \Delta x, y_3)$$
- **Độ dày nét vẽ:**
  - Đường tĩnh đã nối: $2.5\text{dp}$.
  - Đường động đang kéo: $3.0\text{dp}$ có hiệu ứng bóng tỏa ánh kim (`BoxShadow / MaskFilter.blur`).
- **Màu sắc chỉ lụa:**
  - Đang kéo nối (Active Dragging): Gradient son đỏ `#A51F18` $\rightarrow$ vàng kim `#E7B451`.
  - Nối chính xác (Matched Correct): Xanh thảo mộc `#64824C` kèm hiệu ứng sóng lượn vi mô.
  - Nối sai (Matched Incorrect): Đỏ trầm báo lỗi `#B3261E` (tự động đứt sau $600\text{ms}$).

### 2.4 Cơ chế Tương tác Song hành (Dual Interaction Strategy)
1. **Chế độ Kéo Thả (Drag-to-Connect):**
   - Người học đặt ngón tay vào Chốt neo (`Anchor dot`) của thẻ bên trái $\rightarrow$ Kéo ngón tay $\rightarrow$ Đường cong Bezier kéo giãn theo đầu ngón tay $\rightarrow$ Thả vào vùng thẻ bên phải $\rightarrow$ Tự động hít (`Snap`) vào điểm đích nếu khoảng cách $< 40\text{dp}$.
2. **Chế độ Chạm Hai Lần (Tap-to-Pair Fallback - Tối ưu cho người già & màn hình nhỏ):**
   - Chạm thẻ trái $\rightarrow$ Thẻ trái chuyển sang trạng thái Active (viền đỏ son phát sáng) $\rightarrow$ Chạm tiếp thẻ phải $\rightarrow$ Đường chỉ lụa tự động phóng ra nối liền hai điểm.

### 2.5 Hợp đồng Dữ liệu & Sự kiện Flutter
```dart
class MatchingPair<T> {
  final String sourceId;
  final String targetId;
  final bool isVerified;
}

class MatchingBoardWidget extends StatefulWidget {
  final List<MatchingItemData> leftItems;
  final List<MatchingItemData> rightItems;
  final Map<String, String> correctMapping; // sourceId -> targetId
  final Function(List<MatchingPair> currentPairs) onPairsChanged;
  final Function(bool isAllCorrect) onComplete;

  const MatchingBoardWidget({
    Key? key,
    required this.leftItems,
    required this.rightItems,
    required this.correctMapping,
    required this.onPairsChanged,
    required this.onComplete,
  }) : super(key: key);
}
```

---

## 3. BẢNG MÃ TOKEN VÀ CHỈ SỐ QUY CHUẨN

| Thành phần | Token Sử Dụng | Giá trị HEX / Numeric | Ghi chú |
|---|---|---|---|
| Nền bàn ghép | `surface.cream` | `#FFFBF4` | Giảm mỏi mắt cho người học |
| Thẻ bài | `surface.parchment` | `#FFF1D5` | Mô phỏng chất liệu giấy dó cổ |
| Viền thẻ mặc định | `outline.variant` | `#D4C1A5` | Tinh tế, không gây phân tán |
| Điểm chốt / Chỉ kéo | `brand.red.700` | `#A51F18` | Sắc đỏ chu sa truyền thống |
| Ánh sáng chọn | `heritage.gold.500` | `#E7B451` | Màu vàng kim cung đình |
| Trạng thái đúng | `nature.green` | `#64824C` | Báo đúng thân thiện, dịu mắt |
| Trạng thái sai | `state.error` | `#B3261E` | Cảnh báo sai chuẩn WCAG |
| Phông chữ tiêu đề | `typography.headline` | `Noto Serif` | Đậm, trang nhã, có hồn sử Việt |
| Phông chữ nội dung | `typography.body` | `Be Vietnam Pro` | Rõ ràng trên màn hình độ phân giải cao |
