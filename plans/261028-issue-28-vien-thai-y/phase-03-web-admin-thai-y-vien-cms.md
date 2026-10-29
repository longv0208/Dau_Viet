# Phase 03 — Trang Quản trị Web Admin (`dau-viet-admin` — `/thai-y-vien`)

## 1. Mục tiêu
Xây dựng trang quản trị **Viện Thái Y & Thể lực** (`/thai-y-vien`) trên `dau-viet-admin` (Next.js 15 + TypeScript + TanStack Query) để Admin:
1. Cấu hình trực tiếp quy tắc Thể lực toàn cục (`enabled`, `maxEnergy`, `incorrectPenalty`, `recoveryAmount`, `recoveryIntervalSeconds`).
2. Xem danh sách, thêm mới, chỉnh sửa, bật/tắt và xóa các vật phẩm / liệu pháp hồi phục Thể lực tại Viện Thái Y (`energy_remedies`).
3. Xem trước (Preview) thẻ vật phẩm mô phỏng giao diện Mobile.

## 2. Danh sách File Tạo mới / Chỉnh sửa

### Chỉnh sửa:
- `dau-viet-admin/src/components/admin-shell.tsx`: Thêm mục `{ href: "/thai-y-vien", label: "Viện Thái Y & Thể lực", icon: HeartPulse }` vào `NAV_ITEMS`.

### Tạo mới:
- `dau-viet-admin/src/app/(admin)/thai-y-vien/page.tsx`
- `dau-viet-admin/src/features/thai-y-vien/thai-y-vien-api.ts`
- `dau-viet-admin/src/features/thai-y-vien/thai-y-vien-manager.tsx`

## 3. Chi tiết Giao diện & Chức năng

### 3.1. Khối 1: Cấu hình Quy tắc Thể lực Toàn cục (`Global Energy Policy Card`)
- Hiển thị form chỉnh sửa trực quan:
  - **Trạng thái hệ thống (`enabled`):** Checkbox / Toggle bật hoặc tắt trừ Thể lực khi trả lời sai.
  - **Thể lực tối đa (`maxEnergy`):** Input số `1..100` (mặc định `100 ⚡`).
  - **Mức trừ khi trả lời sai câu chấm điểm (`incorrectPenalty`):** Input số `1..100` (mặc định `10 ⚡`).
  - **Lượng hồi tự nhiên mỗi chu kỳ (`recoveryAmount`):** Input số `1..100` (mặc định `5 ⚡`).
  - **Chu kỳ hồi tự nhiên (`recoveryIntervalMinutes`):** Input theo phút (`1..1440` phút, quy đổi sang giây `>= 60s`, mặc định `15 phút`).
- **Hộp mô phỏng tự động (Live Balance Preview):**
  - Tính tự động:
    - Số câu sai tối đa trước khi cạn bình: `ceil(maxEnergy / incorrectPenalty)` lần.
    - Thời gian tự hồi đầy từ `0 -> maxEnergy`: `ceil(maxEnergy / recoveryAmount) * recoveryIntervalMinutes` phút (hiển thị dạng `X giờ Y phút`).
- Nút **"Lưu quy tắc Thể lực"** gọi `PUT /api/v1/admin/energy/settings` kèm thông báo thành công/lỗi rõ ràng.

### 3.2. Khối 2: Danh mục Vật phẩm / Liệu pháp Viện Thái Y (`Remedy Catalog Table`)
- Bảng liệt kê đầy đủ các vật phẩm từ `GET /api/v1/admin/energy/remedies`:
  - Cột **Thứ tự (`sortOrder`)**
  - Cột **Mã & Tên vật phẩm (`code`, `title`, `description`)**
  - Cột **Phẩm cấp (`rarity`):** Badge màu chuẩn (`COMMON` Thường, `UNCOMMON` Thanh tao, `RARE` Quý hiếm, `EPIC` Bảo vật)
  - Cột **Lượng hồi (`energyGain`):** Badge xanh lá **`+X ⚡`**
  - Cột **Giá mua (`pointsCost`):** Hiển thị **`Miễn phí (0 Điểm)`** hoặc **`X Điểm Sử Ký`**
  - Cột **Hồi chiêu (`cooldownSeconds`):** Hiển thị dạng dễ đọc (`24 giờ`, `12 giờ`, `4 giờ`, `30 phút`, hoặc `Không giới hạn`)
  - Cột **Trạng thái (`active`):** Badge `Đang mở` / `Tạm ẩn`
  - Cột **Thao tác:** Nút **Xem trước**, **Chỉnh sửa**, **Bật/Tắt nhanh**, **Xóa**

### 3.3. Modal Thêm mới / Chỉnh sửa Vật phẩm & Modal Xem trước
- **Modal Thêm / Sửa Vật phẩm:**
  - `code` (chỉ nhập khi tạo mới, tự động viết hoa `UPPER_SNAKE_CASE`, VD: `NUOC_VOI`, `TRA_SEN`)
  - `title` (Tên hiển thị)
  - `description` (Mô tả công dụng)
  - `rarity` (`COMMON` | `UNCOMMON` | `RARE` | `EPIC`)
  - `iconKey` (Chọn từ bộ 4 minh họa chuẩn: `energy_nuoc_voi`, `energy_tra_sen`, `energy_linh_chi`, `energy_sam_ngoc_linh`)
  - `energyGain` (`1..100 ⚡`)
  - `pointsCost` (`>= 0 Điểm Sử Ký`, có nút gạt nhanh **"Miễn phí (0 Điểm)"**)
  - `cooldownHours` / `cooldownMinutes` (quy đổi ra `cooldownSeconds`)
  - `sortOrder` & checkbox `active`
- **Modal Xem trước (Mobile Preview Card):**
  - Hiển thị thẻ vật phẩm trên nền giấy dó giống hệt giao diện Mobile Viện Thái Y (`M-28`).
