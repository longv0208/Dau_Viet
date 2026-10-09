# ĐẶC TẢ THIẾT KẾ COMPONENT M-C15 (v2.0)
## Thư viện Giao diện Sắp xếp Diễn biến Thời gian (DragOrderList & Reorder Mechanics)

> **Thuộc hệ thống:** Dấu Việt v2.0 — Stylized 2D Historical Illustrated Adventure  
> **Áp dụng cho:** Flutter Mobile Learner App (`dau-viet-mobile`)  
> **Màn hình sử dụng:** M-12 (Kéo thả vào ô đích & Sắp xếp danh sách diễn biến)  
> **Nguyên tắc cốt lõi:**  
> 1. Không dùng pixel art; giao diện tương tác động chuẩn 60fps trên Flutter.  
> 2. Phản hồi xúc giác (Haptics) và chỉ báo vị trí thả (Drop insertion line) trực quan rõ ràng.  
> 3. Hỗ trợ song song cả cơ chế Kéo thả (Drag & Drop) và Nút bấm dịch chuyển (Tap-to-move arrows) để đảm bảo trợ năng (Accessibility).

---

## 1. TỔNG QUAN COMPONENT M-C15: DRAG ORDER LIST

### 1.1 Mục đích & Bối cảnh Sử dụng
`M-C15 DragOrderList` là thành phần tương tác giúp người học rèn luyện tư duy lịch sử về nguyên nhân - diễn biến - kết quả bằng cách sắp xếp lại các sự kiện chiến dịch, giai đoạn triều đại hoặc các bước chiến thuật theo đúng tiến trình thời gian thực tế.

### 1.2 Hai Chế độ Hiển thị (Two Operational Modes)
Component hỗ trợ 2 chế độ cấu hình linh hoạt:
1. **Chế độ Danh sách Đổi chỗ (Linear Reorderable List):** Toàn bộ các thẻ sự kiện nằm trong một danh sách dọc duy nhất; người học kéo đổi vị trí giữa các phần tử với nhau.
2. **Chế độ Ô đích & Kho mảnh ghép (Slot Target & Piece Pool):** Khu vực trên là 4 ô đích thời gian (Giai đoạn 1 đến 4); khu vực dưới là kho mảnh ghép (Piece pool); người học nhấc mảnh ghép thả vào từng ô đích tương ứng.

---

## 2. CẤU TRÚC CHI TIẾT THẺ BÀI SỰ KIỆN (DRAG ORDER TILE)

### 2.1 Bố cục Hình học & Layout Thẻ
- **Chiều cao thẻ:** Tự động theo nội dung, tối thiểu $72\text{dp}$.
- **Bán kính bo góc (Border Radius):** $12\text{dp}$ (`rounded-xl`).
- **Padding nội bộ:** $14\text{dp}$ ngang, $12\text{dp}$ dọc.
- **Bố cục 3 phần theo chiều ngang:**
  1. **Khối Thứ tự (Index Badge):** Vòng tròn đường kính $36\text{dp}$, nền mộc `#F3E5CE`, viền `#D4C1A5`, số thứ tự font `Noto Serif` Bold $16\text{sp}$ màu mực sẫm `#30251F`.
  2. **Khối Nội dung (Content & Metadata Block):**
     - Nhãn thời kỳ / Tag chiến thuật: Chip nhỏ nền `#FFF1D5`, chữ in hoa $11\text{sp}$ màu nâu đất `#613B28`.
     - Đoạn mô tả sự kiện lịch sử: Phông `Be Vietnam Pro` Regular $14\text{sp}$, canh trái, line-height $1.4$, màu `#30251F`.
  3. **Khối Điều khiển Kép (Dual Control Block):**
     - **Cặp nút mũi tên Chạm (Tap Arrows):** Nút ▲ (Di chuyển lên) và ▼ (Di chuyển xuống) kích thước $32\times 32\text{dp}$, vùng chạm $44\times 44\text{dp}$.
     - **Chốt kéo xúc giác (Drag Handle Grip):** Biểu tượng 3 gạch ngang (`drag_handle`) đường kính chạm $44\text{dp}$, màu viền mộc `#8C6747`.

### 2.2 Bảng Ma trận Trạng thái (State Matrix)

| Trạng thái | Nền (Background) | Viền (Border) | Độ nổi (Elevation) | Hiệu ứng hình học |
|---|---|---|:---:|---|
| **Idle** (Tĩnh / Chờ) | `#FFFBF4` (Cream) | `1px solid #D4C1A5` | $1\text{dp}$ | Tiêu chuẩn |
| **Hover / Focus** | `#FFF1D5` (Parchment) | `1.5px solid #8C6747` | $2\text{dp}$ | Nổi nhẹ |
| **Grabbed** (Vừa nhấc lên) | `#FFF1D5` | `2px solid #E7B451` (Vàng kim) | $6\text{dp}$ | Phóng to $1.02\times$, rung nhẹ |
| **Dragging** (Đang kéo di chuyển) | `#FFF1D5` | `2px solid #E7B451` | $8\text{dp}$ | Nghiêng tự nhiên $1.5^\circ$, bóng đổ amber |
| **Drop Target Line** (Vạch chỉ báo) | N/A (Đường kẻ) | `2px dashed #E7B451` | N/A | Nhãn `↓ Vị trí thả mới` nhấp nháy |
| **Verified Correct** (Đúng thứ tự) | `#F4F9F1` (Green Tint) | `2px solid #64824C` | $1\text{dp}$ | Huy hiệu tick xanh `✓ Chính xác` |
| **Verified Incorrect** (Sai thứ tự) | `#FDF3F2` (Red Tint) | `2px solid #B3261E` | $1\text{dp}$ | Huy hiệu cảnh báo đỏ `✕ Sai vị trí` |

---

## 3. THIẾT KẾ TƯƠNG TÁC & PHẢN HỒI XÚC GIÁC (HAPTICS & PHYSICS)

### 3.1 Quy trình Nhấc & Thả (Lift, Drag & Settle Physics)
1. **Bắt đầu nhấc (Long Press / Immediate Drag on Handle):**
   - Khi ngón tay ấn vào chốt kéo hoặc giữ thẻ $150\text{ms}$:
   - Thẻ nâng cao độ nổi lên $8\text{dp}$, bóng đổ mềm ngả sắc vàng kim.
   - Thẻ nghiêng một góc nhỏ $+1.5^\circ$ tạo cảm giác cầm thẻ bài vật lý thực.
   - Rung xác thực: `HapticFeedback.heavyImpact()`.
2. **Quá trình di chuyển (Dragging & Swapping):**
   - Khi tâm thẻ di chuyển vượt qua $50\%$ chiều cao của thẻ liền kề:
   - Các thẻ phía dưới dạt ra tạo khoảng trống $76\text{dp}$.
   - Xuất hiện đường chỉ báo vị trí thả mới (`Drop Insertion Line`) viền nét đứt vàng kim.
   - Rung chuyển vị trí: `HapticFeedback.selectionClick()`.
3. **Thả và Hạ cánh (Settle):**
   - Ngón tay rời màn hình: Thẻ trượt về vị trí mới trong $180\text{ms}$ theo đường cong `Curves.easeOutBack`.
   - Độ nghiêng trở về $0^\circ$, độ nổi trở về $1\text{dp}$.
   - Rung nhẹ chốt vị trí: `HapticFeedback.lightImpact()`.

### 3.2 Cơ chế Hỗ trợ Tiếp cận (Accessibility Tap Fallback)
Đối với người học có hạn chế về vận động ngón tay, người cao tuổi hoặc thiết bị màn hình nhỏ:
- Ấn nút mũi tên ▲: Thẻ đổi vị trí ngay lập tức với thẻ phía trên kèm hiệu ứng trượt trơn tru trong $150\text{ms}$.
- Ấn nút mũi tên ▼: Thẻ đổi vị trí ngay lập tức với thẻ phía dưới.
- Nếu thẻ ở vị trí đầu tiên (Top), nút ▲ tự động mờ và vô hiệu (`disabled`); tương tự với nút ▼ ở thẻ cuối cùng.

---

## 4. HỢP ĐỒNG LẬP TRÌNH FLUTTER (DART INTERFACE CONTRACT)

```dart
class DragOrderItemData {
  final String id;
  final int correctIndex;
  final String title;
  final String tacticalTag;
  final String? iconAsset;

  const DragOrderItemData({
    required this.id,
    required this.correctIndex,
    required this.title,
    required this.tacticalTag,
    this.iconAsset,
  });
}

class DragOrderListWidget extends StatefulWidget {
  final List<DragOrderItemData> items;
  final bool isVerified;
  final ValueChanged<List<DragOrderItemData>> onReorder;
  final VoidCallback? onReset;

  const DragOrderListWidget({
    Key? key,
    required this.items,
    this.isVerified = false,
    required this.onReorder,
    this.onReset,
  }) : super(key: key);

  @override
  State<DragOrderListWidget> createState() => _DragOrderListWidgetState();
}
```

---

## 5. BẢNG MÃ TOKEN VÀ CHỈ SỐ QUY CHUẨN

| Thành phần | Token Sử Dụng | Giá trị HEX / Numeric | Ghi chú |
|---|---|---|---|
| Nền trang chính | `surface.cream` | `#FFFBF4` | Dịu mắt, thuần giấy dó |
| Nền thẻ sự kiện | `surface.parchment` | `#FFF1D5` | Tông ấm cổ kính |
| Viền thẻ mặc định | `outline.variant` | `#D4C1A5` | Thanh mảnh, tinh tế |
| Viền khi đang kéo | `heritage.gold.500` | `#E7B451` | Hoàng kim rực rỡ |
| Chốt kéo xúc giác | `wood.brown` / `brand.red` | `#8C6747` / `#A51F18` | Nhận diện rõ ràng |
| Chỉ báo vị trí thả | `heritage.gold.500` | `#E7B451` (Dashed) | Đường định hướng |
| Trạng thái đúng | `nature.green` | `#64824C` | Báo đúng chuẩn mực |
| Trạng thái sai | `state.error` | `#B3261E` | Báo sai rõ nét |
| Phông tiêu đề | `typography.headline` | `Noto Serif` | Đậm, trang nhã, hào hùng |
| Phông nội dung | `typography.body` | `Be Vietnam Pro` | Rõ ràng, hỗ trợ tiếng Việt tối ưu |
