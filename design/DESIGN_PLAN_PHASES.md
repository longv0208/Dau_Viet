# DẤU VIỆT — KẾ HOẠCH CHI TIẾT THỰC HIỆN THEO TỪNG PHASE v2.0

> **Cập nhật theo tiêu chuẩn mới:**  
> - [ART_DIRECTION.md v2.0](file:///c:/Users/Admin/Desktop/4user/DauViet/design/ART_DIRECTION.md): Chuyển đổi từ Pixel Art sang **Stylized 2D Historical Illustrated Adventure** (Minh họa 2D vẽ tay, isometric 2.5D cho đảo, không baked-in text, Be Vietnam Pro & Noto Serif).  
> - [UI_COMPONENT_SPEC.md v2.0](file:///c:/Users/Admin/Desktop/4user/DauViet/design/UI_COMPONENT_SPEC.md): Thư viện component Flutter `M-C01..M-C28` và Next.js Admin `A-C01..A-C20`.  
> - [ASSET_GENERATION_GUIDELINES.md v2.0](file:///c:/Users/Admin/Desktop/4user/DauViet/design/ASSET_GENERATION_GUIDELINES.md): Quy chuẩn tạo asset (Prompt Brief có cấu trúc, đặt tên `dv_{cat}_{era}_{subject}_{variant}_v{n}.{ext}`, kiểm duyệt sử liệu và tách lớp).  
>  
> **Nguyên tắc thực thi bất biến:**  
> 1. Mỗi lần thực hiện chỉ sản xuất **từ 1 đến 3 items** (Màn hình / Asset / Image / Component Element).  
> 2. Sau mỗi phase, tạo tài liệu nghiệm thu trực quan (`phase_X_review.md`), **dừng lại đợi người dùng kiểm tra và phê duyệt** mới được làm tiếp phase sau.

---

## BẢNG TỔNG HỢP CÁC PHASE THỰC THI (18 PHASES)

| Phase | Tên giai đoạn | Phân loại | Số lượng | Danh sách Item cụ thể (Tối đa 3 items) | Trạng thái |
|---|---|---|:---:|---|:---:|
| **Phase 1** | Dòng thời gian & Sa bàn thời kỳ (2D v2.0) | Mobile | 3 | • Màn hình `M-04`: Dòng thời gian lịch sử<br>• Màn hình `M-06`: Bản đồ thời kỳ & Sa bàn<br>• Asset `dv_MAP_ngoquyen_bachdang-base_v01`: Map base 2D tách lớp | **ĐÃ HOÀN THÀNH — CHỜ REVIEW** |
| **Phase 2** | Chi tiết Sự kiện & 4 Dấu Vết Lịch Sử | Mobile | 3 | • Màn hình `M-07`: Chi tiết Sự kiện Bạch Đằng 938<br>• Màn hình `M-08`: Trung tâm 4 Dấu Vết Lịch Sử<br>• Asset `dv_EVT_ngoquyen_bachdang_hero_v01`: Tranh minh họa 2D đại chiến Bạch Đằng | **ĐÃ HOÀN THÀNH — CHỜ REVIEW** |
| **Phase 3** | Học tập tư liệu: Trắc nghiệm & Ghép nối | Mobile / Activity | 3 | • Màn hình `M-16`: Trắc nghiệm tư liệu (Quiz)<br>• Màn hình `M-11`: Ghép thông tin (Matching)<br>• Component `M-C13 & M-C14`: ChoiceOption & MatchingBoard UI Spec | **ĐÃ HOÀN THÀNH — CHỜ REVIEW** |
| **Phase 4** | Học tập tương tác: Kéo thả & Sắp xếp | Mobile / Activity | 3 | • Màn hình `M-12 (Kéo thả)`: Drag-drop vào slot 1-2-3-4<br>• Màn hình `M-12 (Sắp xếp)`: Reorder list có chốt kéo 3 gạch<br>• Component `M-C15`: DragOrderList & Tap fallback | **ĐÃ HOÀN THÀNH — CHỜ REVIEW** |
| **Phase 5** | Khám phá Bối cảnh & Kết luận CER | Mobile / Inquiry | 3 | • Màn hình `M-09`: Đọc bối cảnh (Context Reader)<br>• Màn hình `M-13`: Kiểm chứng giả thuyết (Verification)<br>• Màn hình `M-14`: Kết luận lịch sử CER (`M-C20`) | **ĐÃ HOÀN THÀNH — CHỜ REVIEW** |
| **Phase 6** | Tái hiện Chiến dịch & Hoàn thành | Mobile / Result | 3 | • Màn hình `M-17`: Tranh cuộn sử thi (StoryScene `M-C22`)<br>• Màn hình `M-18`: Hoàn thành sự kiện lịch sử<br>• Asset `dv_ACH_shared_victory-banner_v01`: Dải băng vinh danh | **ĐÃ HOÀN THÀNH — CHỜ REVIEW** |
| **Phase 7** | Phần thưởng & Sưu tập Cổ vật | Mobile / Reward | 3 | • Màn hình `M-19`: Nhận thưởng (RewardSummary `M-C23`)<br>• Màn hình `M-20`: Mở khóa Thành tích Hào khí Bạch Đằng<br>• Màn hình `M-21`: Thẻ bài Cổ vật Thuyền chiến Bạch Đằng | **ĐÃ HOÀN THÀNH — CHỜ REVIEW** |
| **Phase 8** | Khởi động, Xác thực & Dashboard | Mobile / Foundation | 3 | • Màn hình `M-01`: Splash screen thương hiệu (`M-C01`)<br>• Màn hình `M-02`: Đăng nhập & Chế độ khách (Auth/Guest)<br>• Màn hình `M-03`: Bàn học tập người học (Dashboard resume) | **ĐÃ HOÀN THÀNH — CHỜ REVIEW** |
| **Phase 9** | Bản đồ Đảo cá nhân & Nâng cấp | Meta-game | 3 | • Màn hình `M-22`: Bản đồ Đảo cá nhân Cấp 1 (`M-C24`)<br>• Màn hình `M-23`: Nâng cấp Đảo Cấp 2 & Cấp 3<br>• Asset `dv_ISL_generic_island-base-tiers_v01`: Sprite 3 cấp đảo isometric | **ĐÃ HOÀN THÀNH — CHỜ REVIEW** |
| **Phase 10** | Kho trang trí & Công trình di sản | Meta-game | 2 | • Màn hình `M-24`: Kho trang trí & Chế độ đặt đồ (`M-C25`)<br>• Asset `dv_ISL_heritage_decor-pack-1_v01`: Cây đa, Cầu gỗ, Nhà tranh, Hồ sen | **ĐÃ HOÀN THÀNH — CHỜ REVIEW** |
| **Phase 11** | Cửa hàng vật phẩm & Quản lý Túi đồ | Kinh tế | 3 | • Màn hình `M-25`: Cửa hàng thường (Điểm Sử Ký)<br>• Màn hình `M-26`: Cửa hàng cao cấp (Kim Cương)<br>• Màn hình `M-27`: Túi đồ cá nhân (Inventory `M-C26`) | **ĐÃ HOÀN THÀNH — CHỜ REVIEW** |
| **Phase 12** | Hệ thống Năng lượng & Cửa sổ Nạp | Kinh tế | 2 | • Màn hình `M-28`: Quản lý Thể lực (EnergyIndicator `M-C27`)<br>• Asset `dv_UI_shared_energy-packs_v01`: Icon tia sét & 3 gói nạp | **ĐÃ HOÀN THÀNH — CHỜ REVIEW** |
| **Phase 13** | Admin: Bàn làm việc & Danh mục Sự kiện | Web Admin | 3 | • Màn hình `A-01`: Admin Login (`A-C01`)<br>• Màn hình `A-02`: Admin Dashboard & Cảnh báo (`A-C02`)<br>• Màn hình `A-03`: Danh mục Sự kiện lịch sử (`A-C03`) | **ĐÃ HOÀN THÀNH — CHỜ REVIEW** |
| **Phase 14** | Admin: Soạn Sự kiện & Quản lý Bài học | Web Admin | 3 | • Màn hình `A-04`: Soạn thảo Sự kiện (`A-C05`)<br>• Màn hình `A-05`: Danh mục Bài học (`A-C03`)<br>• Màn hình `A-06`: Wizard Khởi tạo bài học mới (`A-C07`) | **ĐÃ HOÀN THÀNH — CHỜ REVIEW** |
| **Phase 15** | Admin: Thông tin Bài học & Cấu trúc Stage | Web Admin | 2 | • Màn hình `A-07`: Thông tin cơ bản Bài học (`A-C06`)<br>• Màn hình `A-08`: Trình quản lý Cấu trúc Giai đoạn (`A-C08`) | **ĐÃ HOÀN THÀNH — CHỜ REVIEW** |
| **Phase 16** | Admin: Soạn Hoạt động & Quản lý Chứng cứ | Web Admin | 2 | • Màn hình `A-09`: Trình cấu hình Hoạt động (`A-C09 & A-C10`)<br>• Màn hình `A-10`: Trình quản lý Nguồn & Bằng chứng (`A-C11`) | **ĐÃ HOÀN THÀNH — CHỜ REVIEW** |
| **Phase 17** | Admin: Thư viện Media & Quy tắc Gợi ý | Web Admin | 2 | • Màn hình `A-11`: Thư viện Tài nguyên Media (`A-C12 & A-C18`)<br>• Màn hình `A-12`: Cấu hình Quy tắc phản hồi (`A-C13`) | **ĐÃ HOÀN THÀNH — CHỜ REVIEW** |
| **Phase 18** | Admin: Preview Di động & Thẩm định Xuất bản | Web Admin | 3 | • Màn hình `A-13`: Xem trước Di động (`A-C15`)<br>• Màn hình `A-14`: Bảng Thẩm định & Xuất bản (`A-C14`)<br>• Màn hình `A-15`: Lịch sử Phiên bản Bài học (`A-C16`) | **ĐÃ HOÀN THÀNH — CHỜ REVIEW (HOÀN TẤT TOÀN BỘ 18/18 PHASES)** |

---

## CHI TIẾT ĐẶC TẢ TỪNG PHASE v2.0 (QUY CHUẨN MỚI)

### 📱 KHỐI 1: MOBILE LEARNER APP (HỌC TẬP & ĐIỀU TRA)

#### Phase 1: Dòng thời gian & Sa bàn thời kỳ (2D v2.0)
- **Item 1 (Màn hình `M-04`):** Dòng thời gian lịch sử Việt Nam
  * Áp dụng font `Noto Serif` cho tiêu đề các niên đại, `Be Vietnam Pro` cho phần mô tả.
  * Thẻ `M-C07 EraTimelineItem` nền kem sáng `#FFFBF4` viền mộc thanh thoát, không dùng pixel grid.
- **Item 2 (Màn hình `M-06`):** Bản đồ thời kỳ & Sa bàn Bạch Đằng
  * Áp dụng component `M-C08 HistoricalMapCanvas` (ảnh nền sa bàn chỉ chứa địa hình sông nước Bạch Đằng, rừng núi Bắc Bộ).
  * Lớp `M-C09 MapEventMarker`: Các điểm mốc sự kiện (937, 938, 938, 944) là overlay data riêng mang tọa độ normalized `(x, y)`, không nướng vào tranh.
- **Item 3 (Asset `dv_MAP_ngoquyen_bachdang-base_v01`):**
  * Nền bản đồ 2D minh họa vẽ tay cổ phong, tỷ lệ cao, sẵn sàng pan/zoom, không chứa chữ và nút bấm.

#### Phase 2: Chi tiết Sự kiện & 4 Dấu Vết Lịch Sử
- **Item 1 (Màn hình `M-07`):** Chi tiết Sự kiện Trận Bạch Đằng 938
  * Hero card `M-C06 EventHeroCard` hiển thị tranh minh họa 2D hoành tráng, kèm tóm lược lịch sử, câu hỏi trung tâm bài học.
  * Nút `M-C04 PrimaryActionButton` đỏ chu sa `#A51F18`: "BẮT ĐẦU KHÁM PHÁ".
- **Item 2 (Màn hình `M-08`):** Trung tâm 4 Dấu Vết Lịch Sử
  * Lưới 2x2 gồm 4 thẻ bài `M-C10 FourTraceCard` (Bối cảnh, Nhân vật, Diễn biến, Ý nghĩa).
  * Ảnh minh họa chủ đề 2D vẽ tay, kích thước hình học đồng nhất, hiển thị nhãn trạng thái và tiến độ.
- **Item 3 (Asset `dv_EVT_ngoquyen_bachdang_hero_v01`):**
  * Tranh minh họa 2D đại cảnh Tiền Ngô Vương Ngô Quyền và chiến thuyền cọc ngầm Bạch Đằng (không chứa text hay nút).

#### Phase 3: Học tập tư liệu: Trắc nghiệm & Ghép nối
- **Item 1 (Màn hình `M-16`):** Trắc nghiệm tư liệu lịch sử (Quiz)
  * Sử dụng khung học `M-C12 ActivityShell` (thanh tiến độ, tiêu đề, nút nộp bài kiểm tra).
  * Tùy chọn trắc nghiệm `M-C13 ChoiceOption`: nền kem sáng `#FFFBF4`, khi đúng đổi viền ngọc bích `#64824C`, phản hồi chứng cứ trích dẫn rõ ràng.
- **Item 2 (Màn hình `M-11`):** Ghép thông tin lịch sử (Matching)
  * Khung sa bàn `M-C14 MatchingBoard` kết nối 2 cột: Đối tượng $\leftrightarrow$ Vai trò.
  * Hỗ trợ chạm chọn cặp (tap-pair fallback) cho người dùng không dùng thao tác kéo thả phức tạp.
- **Item 3 (Component Spec `M-C13 & M-C14`):**
  * Đặc tả chi tiết trạng thái tương tác: Unselected, Selected, Correct, Incorrect, Disabled, kèm nhãn Accessibility.

---

#### Phase 4: Học tập tương tác: Kéo thả & Sắp xếp diễn biến *(KẾ TIẾP CẦN TRIỂN KHAI)*
- **Item 1 (Màn hình `M-12 - Kéo thả`):** Kéo thả mảnh sự kiện vào 4 ô thứ tự 1-2-3-4
  * 4 ô đích (Slot 1, 2, 3, 4) và ngân hàng các mảnh sự kiện bên dưới.
  * Hỗ trợ nút mũi tên di chuyển / chọn nhanh (tap alternative) theo yêu cầu accessibility trong `UI_COMPONENT_SPEC.md`.
- **Item 2 (Màn hình `M-12 - Sắp xếp`):** Sắp xếp diễn biến chiến dịch từ đầu đến cuối
  * Danh sách thẻ bài có chốt kéo 3 gạch (`M-C15 DragOrderList`) sắp xếp theo thứ tự thời gian.
  * Kèm nút kiểm tra đáp án gửi submission lên backend.
- **Item 3 (Component Spec `M-C15 DragOrderList`):**
  * Đặc tả chi tiết cơ chế kéo thả, trạng thái idle, dragging, placed, error, và phương án tap up/down dành cho accessibility.

#### Phase 5: Khám phá Bối cảnh & Kết luận CER
- **Item 1 (Màn hình `M-09`):** Khám phá Bối cảnh (Context Reader / Trình đọc tư liệu)
  * Screen ID: `ef058009c6ab4fe7a7165ff101df9971`
  * Hiển thị tư liệu trích dẫn nguồn sử ký (`M-C11 EvidenceCard`), tranh minh họa Thành Đại La, audio player dẫn chuyện, hộp 3 điểm cốt lõi cần ghi nhớ.
- **Item 2 (Màn hình `M-13`):** Kiểm chứng Giả thuyết (Verification Feedback `M-C19`)
  * Screen ID: `ecf421e55dac40c88606aeb860d72bf7`
  * Đối chiếu giả thuyết với chứng cứ thực tế, hiển thị 3 trạng thái đánh giá: Phù hợp (Supported), Một phần (Partial), Mâu thuẫn (Contradicted). Có khối chứng cứ đối sánh khảo cổ & thủy văn cổ.
- **Item 3 (Màn hình `M-14`):** Kết luận lịch sử CER (`M-C20 CERComposer`)
  * Screen ID: `312a788715174669864a72b0f0bd0d5a`
  * Soạn thảo kết luận theo 3 thành phần: Claim (Khẳng định) $\rightarrow$ Evidence (Dẫn chứng) $\rightarrow$ Reasoning (Suy luận logic). Tự động lưu nháp và mở khóa kết thúc điều tra.

#### Phase 6: Tái hiện Chiến dịch & Hoàn thành
- **Item 1 (Màn hình `M-17`):** Tái hiện diễn biến lịch sử (`M-C22 StoryScene`)
  * Screen ID: `46a7215fc65346518f6f05d931093b7e`
  * Tranh cuộn sử thi 2D tái hiện toàn cảnh chiến thắng Bạch Đằng khi triều rút, thuyền giặc đâm cọc ngầm tan vỡ, phụ đề trích dẫn Đại Việt Sử Ký Toàn Thư, trình phát audio giọng đọc hào hùng, nút bỏ qua (Skip).
- **Item 2 (Màn hình `M-18`):** Màn hình Hoàn thành sự kiện lịch sử
  * Screen ID: `3f85b8b7904b4500879eceb6f3cf8013`
  * Thông báo hoàn thành điều tra, vinh danh danh hiệu 'Thám tử Sử học Xuất sắc' với triện đỏ, tổng kết trọn vẹn 4 Dấu Vết Lịch Sử (100%), chỉ số đánh giá CER (98% chính xác), bảng phần thưởng chiến lợi phẩm.
- **Item 3 (Asset `dv_ACH_shared_victory-banner_v01`):**
  * File: `design/assets/dv_ACH_shared_victory-banner_v01.jpg` + `.meta.json`
  * Dải băng chiến thắng vinh quang, vương hiệu rồng thời Ngô / Lý, mặt trống đồng Đông Sơn, vòng nguyệt quế vàng đồng `#E7B451` và dải lụa đỏ son `#A51F18` viền thêu chỉ vàng. Tách biệt hoàn toàn, không nướng chữ.

#### Phase 7: Hệ thống Phần thưởng & Sưu tập Cổ vật
- **Item 1 (Màn hình `M-19`):** Nhận thưởng (`M-C23 RewardSummary`)
  * Screen ID: `882942ec459f43128f5f688c6e0c5092`
  * Hiển thị rương báu sơn mài cẩn đồng mở tỏa ánh sáng hoàng kim, danh mục 4 chiến lợi phẩm (+500 Điểm Sử Ký, +300 XP lên cấp Học Giả Sử Ký, 01 Rương Cổ Vật Hiếm, Huy Hiệu Hào Khí Bạch Đằng), chứng thực máy chủ idempotent key bảo mật.
- **Item 2 (Màn hình `M-20`):** Mở khóa Thành tích (*Hào khí Bạch Đằng*)
  * Screen ID: `14fb87d7aaa3431c9792060103bb040f`
  * Huy hiệu đồng cổ Đông Sơn hào quang tỏa rạng dải lụa đỏ son, câu đối sử ký vinh danh, chỉ số thành tựu Top 5% người học, nút chia sẻ và chiêm ngưỡng cổ vật.
- **Item 3 (Màn hình `M-21`):** Thẻ bài chi tiết Cổ vật (*Mô hình Thuyền chiến Bạch Đằng*)
  * Screen ID: `381119d541bd41588ed0d97e9a1a9aa1`
  * Thẻ di sản trưng bày bảo tàng mô hình thuyền chiến Bạch Đằng thế kỷ X (mũi rồng, khiên đồng, 32 mái chèo), bảng 4 thông số khảo cổ & kỹ thuật quân sự, thuyết minh âm thanh, nút đưa vào bộ sưu tập Đảo di sản.

#### Phase 8: Khởi động, Xác thực & Dashboard học tập
- **Item 1 (Màn hình `M-01`):** Màn hình Khởi động (`M-C01 AppScaffold`)
  * Screen ID: `139854a443aa43d990889cc92f9457b5`
  * Nền giấy dó parchment cổ kính, biểu trưng Trống đồng Đông Sơn kết hợp Rồng thời Lý – Tiền Ngô dát vàng hoàng kim `#E7B451`, ấn triện son đỏ 'ẤN TRIỆN DẤU VIỆT', dòng đề từ "Ngàn năm văn hiến • Rạng rỡ sơn hà", thanh nạp sử liệu 78% và thông tin bảo trợ Viện Sử Học.
- **Item 2 (Màn hình `M-02`):** Đăng nhập & Chế độ khách (Auth & Guest Mode)
  * Screen ID: `9e65a440c9244bb7876475809e791244`
  * Form đăng nhập parchment sạch sẽ, trường định danh sĩ tử / mật mã, nút đỏ chu sa 'Vào Hành Trình Lịch Sử ›', thẻ nổi bật 'Thẻ Thông Hành Tạm Thời' (Chế độ khách miễn phí không cần tạo tài khoản, lưu tiến độ trên máy), liên kết Google/Apple.
- **Item 3 (Màn hình `M-03`):** Bàn học tập người học (Learner Dashboard)
  * Screen ID: `841c7aa339ca4a7cb3f474a1b0224ad3`
  * Header avatar sĩ tử kèm danh hiệu 'Học Giả Sử Ký (Cấp 5)', 3 chỉ số năng lượng / điểm sử ký / kim cương, thẻ hero tiếp tục bài học gần nhất (Đại thắng Bạch Đằng 938 - 75%), thanh tiến trình các thời kỳ lịch sử, nhiệm vụ hằng ngày và thanh điều hướng đáy cổ phong.

---

### 🏝️ KHỐI 2: META-GAME, KINH TẾ & NĂNG LƯỢNG

#### Phase 9: Bản đồ Đảo cá nhân & Nâng cấp cấp độ
- **Trạng thái:** **ĐÃ HOÀN THÀNH — CHỜ REVIEW**
- **Item 1 (Màn hình `M-22`):** Bản đồ Đảo cá nhân Cấp 1 (`M-C24 IslandScene`)
  * Screen ID: `688e7d4026b24e1a9747adffe857c6a0`
  * Hòn đảo nổi hoang sơ sông nước Bắc Bộ mô phỏng isometric 2.5D minh họa vẽ tay, bến tàu bến thuyền mộc mạc, cây đa cổ thụ, ruộng lúa và các vị trí ô đất slot viền nét đứt vàng óng để bày trí cổ vật di sản.
- **Item 2 (Màn hình `M-23`):** Giao diện Nâng cấp Đảo Cấp 2 & Cấp 3
  * Screen ID: `8a35f6bbaced47dfa05db5c2e8f02814`
  * Modal nâng cấp hoàng kim parchment, preview đảo Cấp 2 (Bến Phù Sa Mở Rộng + 6 ô bày trí + Đình làng cổ), thanh điều kiện mở khóa (đạt Cấp 6, 2.500 Điểm Sử Ký, hoàn thành Chương Bạch Đằng 938), nút nâng cấp son đỏ.
- **Item 3 (Asset `dv_ISL_generic_island-base-tiers_v01`):**
  * File: `design/assets/dv_ISL_generic_island-base-tiers_v01.jpg` + `.meta.json`
  * Tranh nền đảo isometric 2.5D vẽ tay phong cách di sản Việt: dòng nước xanh ngọc, ruộng bậc thang, bến thuyền hoa sen, cây đa, khóm tre làng, miếu cổ; không chứa text bake-in, sẵn sàng làm nền tảng cho M-C24.

#### Phase 10: Kho trang trí Đảo & Bộ công trình di sản
- **Trạng thái:** **ĐÃ HOÀN THÀNH — CHỜ REVIEW**
- **Item 1 (Màn hình `M-24`):** Kho trang trí & Chế độ đặt đồ (`M-C25 InventoryItemCard`)
  * Screen ID: `86cf2a4fd78944b3bb50d066feb59b6a`
  * Chế độ sa bàn đặt đồ 2.5D: hiển thị ô đất phù sa #2 đang chọn với viền đứt nét vàng kim (`#E7B451`), ô #1 đã đặt Thuyền chiến Bạch Đằng, ngăn kéo Draggable Bottom Drawer chứa lưới thẻ bài di sản (`M-C25 InventoryItemCard`), bộ lọc loại hình (Tất cả, Cổ vật, Kiến trúc, Thủy sinh), nút chính son đỏ 'ĐẶT VÀO Ô ĐẤT NÀY ›'.
- **Item 2 (Asset `dv_ISL_heritage_decor-pack-1_v01`):**
  * File: `design/assets/dv_ISL_heritage_decor-pack-1_v01.jpg` + `.meta.json`
  * Bộ 4 công trình dân gian di sản vẽ isometric 2.5D tách biệt trên nền sạch: Cây đa miếu cổ, Cầu kiều gỗ mộc mạc, Nhà tranh vách đất Đại Việt, Hồ sen tròn đá ngát hương; không chứa chữ bake-in.

#### Phase 11: Cửa hàng vật phẩm & Quản lý Túi đồ
- **Trạng thái:** **ĐÃ HOÀN THÀNH — CHỜ REVIEW**
- **Item 1 (Màn hình `M-25`):** Cửa hàng vật phẩm thường (`M-C26 ShopItemCard`)
  * Screen ID: `31e1353130aa49f481d5424386e314e7`
  * Chợ Phiên Di Sản: đổi Điểm Sử Ký lấy công trình truyền thống (Cây đa miếu cổ 650★, Cầu kiều 450★, Nhà tranh vách đất - Đã sở hữu, Hồ sen 350★, Lũy tre 200★, Bia đá 800★); banner mùa thu, tab bộ lọc danh mục và thanh tiền tệ chuẩn.
- **Item 2 (Màn hình `M-26`):** Cửa hàng vật phẩm cao cấp
  * Screen ID: `84f76b55d0064bab9f0910278f581f5b`
  * Ngự Bảo Các Cao Cấp: giao dịch bảo vật hoàng gia bằng Ngọc Bích (💎 45); Hero Card Kỳ Đài - Điện Kính Thiên thu nhỏ (120💎), lưới bảo vật Chùa Trấn Quốc & Tháp Báo Thiên (85💎), Thuyền Rồng Hoàng Gia (95💎), Ngọ Môn (150💎), Trống Đồng Ngọc Lũ (70💎); thanh gạt chuyển nhanh Chợ Phiên / Ngự Bảo Các.
- **Item 3 (Màn hình `M-27`):** Túi đồ cá nhân (Inventory)
  * Screen ID: `4d5679943ce14ce39b649f97e2394e93`
  * Hòm Đồ Di Sản Sĩ Tử: hiển thị sức chứa 6/20 ô, bộ lọc đa tầng (Tất cả, Đang bày trí, Trong hòm đồ), lưới thẻ `M-C25 InventoryItemCard` với Thuyền chiến Bạch Đằng (Đang bày trí Ô #1 - nút Thu hồi) và các công trình sẵn sàng bày trí (Nhà tranh, Cây đa, Hồ sen x2, Cầu kiều, Bụi tre - nút Bày trí lên Đảo ›).

#### Phase 12: Hệ thống Năng lượng & Cửa sổ Nạp
- **Trạng thái:** **ĐÃ HOÀN THÀNH — CHỜ REVIEW**
- **Item 1 (Màn hình `M-28`):** Quản lý Năng lượng (`M-C27 EnergyIndicator`)
  * Screen ID: `66f3a69e46ec4ddabcc5737331ea41d6`
  * Màn hình Viện Thái Y Sĩ Tử: đồng hồ hướng tâm đo sinh lực cách điệu Trống đồng Đông Sơn (`M-C27 EnergyIndicator`) hiển thị 35/100 ⚡, quy luật hồi phục tự nhiên +1⚡/30 phút, bộ 3 gói bồi bổ ngự y (Trà Sen Thảo Mộc +30⚡ miễn phí, Thang Thuốc Bổ Thái Y +100⚡ đầy bình, Sâm Nhung Thượng Hạng Cung Đình +300⚡ vượt ngưỡng), lời dặn sư phạm học tập điều độ.
- **Item 2 (Asset `dv_UI_shared_energy-packs_v01`):**
  * File: `design/assets/dv_UI_shared_energy-packs_v01.jpg` + `.meta.json`
  * Bộ minh họa 2D vẽ tay gouache di sản: Biểu tượng Nhật quang Trống đồng (tia sét sinh lực), Tách trà sen gốm hoa nâu bốc khói, Thang thuốc bắc buộc chỉ đỏ son, Hòm sơn mài cẩn rồng phượng chứa sâm nhung hoàng gia; không chứa chữ bake-in.

*Ghi chú quan trọng: Hoàn tất Phase 12 chính thức khép lại toàn bộ KHỐI 2 (Meta-game, Kinh tế & Năng lượng)!*

---

### 💻 KHỐI 3: WEB ADMIN LESSON BUILDER (NEXT.JS)

#### Phase 13: Admin: Bàn làm việc & Danh mục Sự kiện
- **Trạng thái:** **ĐÃ HOÀN THÀNH — CHỜ REVIEW**
- **Item 1 (Màn hình `A-01`):** Màn hình Đăng nhập Quản trị viên (`A-C01 AdminShell`)
  * Screen ID: `57d4d48f3ebf405abf4e06c0b34a1c4f`
  * Cổng đăng nhập chuyên gia & ban thẩm định Viện Sử Học (Desktop 1440px): Cột trái sơn mài đỏ chu sa giới thiệu 3 chuẩn (Bảo mật cấp viện RBAC, Bất biến phiên bản, Thẩm định đa tầng); Cột phải form giấy dó với xác thực 2 yếu tố TOTP 6 số, tích hợp cổng EduID và nhật ký kiểm toán Audit Log.
- **Item 2 (Màn hình `A-02`):** Dashboard Quản trị & Cảnh báo (`A-C02 PageHeader`)
  * Screen ID: `478cc6bf023244beb7869fc503ef59cd`
  * Bàn điều phối biên soạn sử liệu: 4 Key MetricCards (38 Đã xuất bản bất biến, 5 Sẵn sàng duyệt, 11 Bản nháp, 1 Cảnh báo dữ liệu); Bố cục 2 cột (65%/35%) theo dõi tiến độ các chiến dịch Bạch Đằng 938, Hai Bà Trưng, Đống Đa 1789, kèm hộp cảnh báo lệch hash ảnh `ERR_REF_HASH_0938` và nhật ký phê duyệt thời gian thực.
- **Item 3 (Màn hình `A-03`):** Danh mục Sự kiện Lịch sử (`A-C03 DataTable`)
  * Screen ID: `8057101d0ab6452da61e3f2336d679a6`
  * Bảng dữ liệu quản lý 54 sự kiện lịch sử toàn quốc: thanh công cụ tìm kiếm Ctrl+K, bộ lọc 6 thời kỳ, tabs trạng thái (Tất cả, Đã xuất bản, Sẵn sàng duyệt, Bản nháp), bảng `A-C03 DataTable` hiển thị chi tiết tiến độ 4 Dấu Vết, mã khóa SHA-256 LessonVersion bất biến, tác giả và các nút thao tác chuyên sâu (Biên tập, Thẩm định ngay, Xem trước).

#### Phase 14: Admin: Soạn Sự kiện & Quản lý Bài học
- **Trạng thái:** **ĐÃ HOÀN THÀNH — CHỜ REVIEW**
- **Item 1 (Màn hình `A-04`):** Trình soạn thảo Sự kiện (`A-C05 EventEditorForm`)
  * Screen ID: `36e0ecda1a4843e597ead4f343bc9e08`
  * Form soạn thảo sự kiện lịch sử chuyên sâu (Bạch Đằng 938): Bố cục 2 cột (65%/35%); Cột trái gồm thông tin định danh cổ thư, thời kỳ, nhân vật Ngô Quyền, trình soạn thảo trích dẫn Hán Nôm, định vị tọa độ GPS bãi cọc Yên Hưng trên mini cartographic map picker, khung năng lực GDPT 2018 (CER, khảo cổ); Cột phải gồm ảnh bìa 16:9, độ khó THCS/THPT, điểm thưởng và công tắc khóa bất biến SHA-256.
- **Item 2 (Màn hình `A-05`):** Danh mục Bài học theo Sự kiện (`A-C03 DataTable`)
  * Screen ID: `e7d093537f8f4213b25a7d73a2baf50c`
  * Quản lý chuỗi bài học thuộc sự kiện Bạch Đằng 938: Banner ngữ cảnh sự kiện (4 KPIs, 18 hoạt động, 86.4% hoàn thành), bảng `A-C03 DataTable` hiển thị 4 Hồi bài học (Hồi 1 Bối cảnh, Hồi 2 Cọc ngầm, Hồi 3 Quyết chiến, Hồi 4 Hào khí muôn đời - Draft), mã khóa băm `LessonVersion (v2.1.0 🔒 / v2.2.0-draft 📝)` và cam kết bất biến ghim chặt với học sinh.
- **Item 3 (Màn hình `A-06`):** Wizard Khởi tạo bài học mới (`A-C07 TemplatePicker`)
  * Screen ID: `316e3dffa4c242c1bbf1b76c4c7302c3`
  * Stepper 4 bước khởi tạo bài học: Bước 2 (Chọn mẫu bài học) hiển thị 3 thẻ mẫu tương tác gồm Mẫu 1 Khám Phá Sử Liệu 4 Dấu Vết (Chuẩn GDPT 2018 - Đang chọn), Mẫu 2 Sa Bàn Chiến Dịch & Thủy Bộ (Sa bàn 3D), Mẫu 3 Bí Ẩn Nhân Vật Lịch Sử; Drawer cấu hình nhanh tên bài học Hồi 5, độ khó và nút CTA son đỏ tiếp tục sang cấu hình chi tiết.

#### Phase 15: Admin: Thông tin Bài học & Cấu trúc Stage
- **Trạng thái:** **ĐÃ HOÀN THÀNH — CHỜ REVIEW**
- **Item 1 (Màn hình `A-07`):** Thông tin cơ bản Bài học (`A-C06 LessonMetadataForm`)
  * Screen ID: `623882cacc004472a2c481dfbbf59493`
  * Form thiết lập metadata sư phạm bài học (Hồi 2: Kế sách cọc ngầm & Sa bàn thủy chiến): Hộp câu hỏi nghiên cứu trung tâm viền vàng kim (#E7B451), 3 thẻ chuẩn đầu ra CER (Claim, Evidence, Reasoning), phân loại lớp THCS/THPT, cấu hình 20 phút / 20 thể lực / 150 Điểm Sử Ký, hiện vật cổ vật liên kết, và công tắc khóa bất biến SHA-256 (`8f3a9e...c74b`).
- **Item 2 (Màn hình `A-08`):** Trình quản lý Cấu trúc Giai đoạn (`A-C08 StageOutline`)
  * Screen ID: `3ff65f909a194d3696fe74a74cdaf4b6`
  * Cây cấu trúc tiến trình sư phạm 4 Giai đoạn & 5 Hoạt động (Bố cục 70% Tree Editor / 30% Inspector Panel): Giai đoạn 1 Bối cảnh (M-09 & M-11), Giai đoạn 2 Tác chiến sa bàn & Đo thủy triều (M-12 & Sa bàn 3D), Giai đoạn 3 Kiểm chứng giả thuyết & Lập luận CER (M-14); Bảng thuộc tính Hoạt động 3.1 bên phải thiết lập trọng số điểm, điều kiện vượt qua 80%, cơ chế gợi ý hint bế tắc; thanh trạng thái kiểm định tính toàn vẹn 0 broken refs.

#### Phase 16: Admin: Soạn Hoạt động & Quản lý Chứng cứ
- **Trạng thái:** **ĐÃ HOÀN THÀNH — CHỜ REVIEW**
- **Item 1 (Màn hình `A-09`):** Trình cấu hình Hoạt động (`A-C09 ActivityTypePicker & A-C10 ConfigEditor`)
  * Screen ID: `c99aff667ee6429284e9f7c86d12140f`
  * Trình cấu hình hoạt động tương tác sư phạm (Desktop 1440px): Bộ chọn `A-C09 ActivityTypePicker` 4 loại hình (MCQ, Matching, Drag Order [Đang chọn], CER). Trình biên soạn `A-C10 ConfigEditor` bố cục 2 cột: Cột trái thiết lập tham số, prompt câu hỏi rich text và danh sách 4 thẻ mốc thời gian kéo thả (Chuẩn bị cọc, Địch tiến, Nhử địch triều dâng, Phản công triều rút); Cột phải thực thi bất biến bảo mật Server Invariant với cảnh báo an ninh, đáp án chuẩn băm SHA-256 mã hóa Server Private Only không lộ xuống client, quy tắc phạt hint, thưởng Danh vọng và kiểm định JSON Schema v2.1.
- **Item 2 (Màn hình `A-10`):** Trình quản lý Nguồn & Bằng chứng lịch sử (`A-C11 EvidenceSourceEditor`)
  * Screen ID: `c73e60321770461bb5f0a2057a0136d5`
  * Quản lý chứng thư sử liệu và căn cứ khoa học thực địa (Desktop 1440px): Bố cục Split Panel 2 cột (35%/65%); Cột trái danh mục nguồn khảo cứu liên kết (Di chỉ Bãi cọc Yên Giang, Đại Việt Sử Ký Toàn Thư, Việt Sử Lược, Bãi cọc Đồng Má Ngựa & Đồng Vạn Muối); Cột phải hồ sơ chi tiết nguồn Bãi cọc Yên Giang (Mã tư liệu EVI-0938-YG, cơ quan Viện Khảo cổ học Việt Nam, niên đại C14 thế kỷ X, độ tin cậy tối cao 5/5 sao, trích dẫn chi tiết kích thước cọc gỗ lim, 3 ảnh khảo sát thực địa & phiếu phân tích C-14, ánh xạ vào Hoạt động #2 và #4 CER, cùng dấu mộc thẩm định số HIS-VN-0938/BĐ).

#### Phase 17: Admin: Thư viện Media & Quy tắc Gợi ý
- **Trạng thái:** **ĐÃ HOÀN THÀNH — CHỜ REVIEW**
- **Item 1 (Màn hình `A-11`):** Thư viện Tài nguyên Media (`A-C12 Picker & A-C18 UploadDropzone`)
  * Screen ID: `cedc2c942c0749c5a97facf698b35683`
  * Quản trị kho tài nguyên số và hiện vật khảo cổ (Desktop 1440px): Lưới tài nguyên `A-C12 AssetLibraryPicker` 3 cột hiển thị 128 tệp (Minh họa 2D đại chiến Bạch Đằng, Cọc gỗ lim Yên Giang C-14, Mô hình 3D Thuyền chiến thời Ngô xoay 360°, Sa bàn thủy văn, Âm thanh tư liệu); Khung kéo thả `A-C18 UploadDropzone` kiểm soát kỹ thuật tối đa 15MB, tỷ lệ 16:9/1:1, kiểm tra giấy phép bản quyền Viện Sử Học / CC BY-SA, mã hóa băm SHA-256 (`8f3a9e...c74b`), khung soạn thảo Alt-text trợ năng A11y chuẩn WCAG 2.1 và danh sách 3 bài học đang liên kết.
- **Item 2 (Màn hình `A-12`):** Cấu hình Quy tắc phản hồi & Gợi ý (`A-C13 RuleEditor`)
  * Screen ID: `836468f332cb42838d61b69d2ce9b82a`
  * Trình cấu hình sư phạm và phân nhánh thích ứng (Desktop 1440px): Bố cục Multi-card Flow gồm 4 khối chuyên sâu:
    1. Phản hồi Thành công Hoàn hảo (Mastery State): Kích hoạt khi xếp đúng 4 mốc, tự động trích dẫn *Đại Việt Sử Ký Toàn Thư*, thưởng +50 EXP, +100 Điểm Sử Ký, mở khóa thẻ cổ vật *Chiến thuyền Bạch Đằng (M-21)*.
    2. Phản hồi Lỗi Nhận thức & Phân nhánh Sư phạm: Bóc tách ngộ nhận thời điểm cắm cọc (chuẩn bị từ tháng 10/938 chứ không phải lúc giặc đã vào) và ngộ nhận chiến thuật nghi binh thuyền nhẹ, kèm nhánh làm lại hoặc quay lại xem bối cảnh M-09.
    3. Bậc thang Gợi ý sư phạm (Scaffolding Hint Ladder 3 cấp độ): Cấp 1 khơi gợi nhẹ (0 EXP), Cấp 2 chỉ dẫn mốc thời gian (-10 EXP), Cấp 3 then chốt (-20 EXP).
    4. Vòng lặp Sửa đổi Giả thuyết (Hypothesis Revision Loop cho CER M-14): Tự động mở hộp thoại Socrates định hướng quay lại Bàn chứng cứ M-08 / A-10 bổ sung dữ kiện khảo cổ khi độ tin cậy < 70% mà không phạt điểm.

#### Phase 18: Admin: Preview Di động & Thẩm định Xuất bản
- **Trạng thái:** **ĐÃ HOÀN THÀNH — CHỜ REVIEW (HOÀN TẤT TOÀN BỘ 18/18 PHASES)**
- **Item 1 (Màn hình `A-13`):** Xem trước Di động (`A-C15 LearnerPreviewFrame`)
  * Screen ID: `a5f5171b144145f18ec9fd4db8c32983`
  * Môi trường Sandbox giả lập di động (Desktop 1440px): Bố cục Split Simulation gồm Mockup iPhone 15 Pro (390x844px) chạy bài học tương tác thời gian thực M-12 (Giai đoạn 2 Bày trận cọc ngầm) với 4 thẻ kéo thả Đông Sơn, nút gợi ý, chỉ số sinh lực; Bảng điều khiển kiểm thử bên phải: Bộ chuyển thiết bị (iPhone, Pixel 8, iPad), công tắc A11y Text Scaling 120%, bộ giả lập Persona học sinh THCS vs Hội đồng thẩm định, và khung terminal Websocket Live Event Stream ghi nhận log mã băm SHA-256, sự kiện kéo thả và xác thực che giấu đáp án server-side.
- **Item 2 (Màn hình `A-14`):** Bảng Thẩm định & Xuất bản bất biến (`A-C14 PublishChecklist`)
  * Screen ID: `ba097b4a7eb745738da533ac323877ba`
  * Bảng kiểm thẩm định và ký số niêm phong bài học (Desktop 1440px): Lưới 2x2 kiểm soát 4 trụ cột chất lượng (Sư phạm GDPT 2018 4 Dấu Vết và CER 100% ĐẠT; Chứng thư khảo cổ C-14 Yên Giang và Zero baked-in text 100% ĐẠT; An toàn máy chủ Server Invariant băm SHA-256 và Idempotency Key 100% ĐẠT; Chữ ký số Viện Sử Học `v2.2.0-immutable`); Hộp cảnh báo cơ chế đóng băng bất biến vĩnh viễn (Immutable Alert); Khối phê duyệt triện đỏ *QUỐC GIA ĐẠI VIỆT THẨM ĐỊNH CHI BẢO* và nút hành động chính *KÝ SỐ DUYỆT & XUẤT BẢN BẤT BIẾN*.
- **Item 3 (Màn hình `A-15`):** Lịch sử Phiên bản Bài học (`A-C16 VersionHistory`)
  * Screen ID: `ef0781167317435fb6732c8bda75510e`
  * Nhật ký kiểm toán phả hệ phiên bản và bất biến tiến trình (Desktop 1440px): Cột trái Cây phả hệ phiên bản `A-C16` hiển thị bản `v2.2.0 (Active - 12,450 học sinh đang học, băm SHA-256)`, bản `v2.1.0 (Archived - Ghim bất biến Pinned Invariant cho 3,210 học sinh làm dở)`, bản `v2.0.0 (Bản gốc thí điểm)`; Cột phải Semantic Diff Engine so sánh 3 cấp độ (`[+] Thêm mới` bãi cọc Đồng Má Ngựa 2020, `[~] Cập nhật` gợi ý Socrates 0 EXP, `[=] Bảo toàn 100%` trích dẫn Hán Nôm và sa bàn thủy văn); Công cụ nhân bản thành bản nháp mới `v2.3.0-draft` từ snapshot.
