---
title: "[UI/UX & QA] Đánh giá chi tiết và bộ Test Case toàn diện cho Luồng Học Tập Lịch Sử (Issue #29)"
description: "Kế hoạch đánh giá toàn diện UI/UX (UI/UX Pro Max & Di Sản Dấu Việt v2.0) và thực thi 68 kịch bản kiểm thử chi tiết xuyên suốt 7 chặng của Luồng Học Tập Lịch Sử trên dau-viet-mobile kết nối dau-viet-backend + PostgreSQL thật."
status: completed
priority: P1
effort: 12h
issue: https://github.com/longv0208/Dau_Viet/issues/29
branch: feat/issue-29-learning-flow-ui-ux
worktree: E:/Telegram Desktop/Dau viet/Dau_Viet-issue-29
tags: [mobile, backend, ui-ux-pro-max, learning-flow, e2e, accessibility, qa, issue-29]
created: 2026-10-28
---

# Kế Hoạch Chi Tiết — Issue #29 (`[UI/UX & QA] Đánh giá chi tiết và bộ Test Case toàn diện cho Luồng Học Tập Lịch Sử`)

> **GitHub Issue:** https://github.com/longv0208/Dau_Viet/issues/29  
> **Task ID:** `TASK-0029` (`tasks/TASK-0029/task.json`)  
> **Branch:** `feat/issue-29-learning-flow-ui-ux`  
> **Worktree:** `E:/Telegram Desktop/Dau viet/Dau_Viet-issue-29`

---

## 1. Mục tiêu & Phạm vi Đánh giá

Xây dựng bộ tiêu chuẩn **Đánh giá Toàn diện UI/UX & Kịch bản Kiểm thử Chi tiết (End-to-End UI/UX Audit & Test Suite)** cho toàn bộ **Luồng Học Tập Lịch Sử (Learning Flow)** trên ứng dụng `dau-viet-mobile` (kết nối `dau-viet-backend` + PostgreSQL thật).

### Hành trình người học được đánh giá xuyên suốt (7 Chặng):
1. **Chặng 1 — Điểm vào & Khám phá Lộ trình (`Discovery & Entry`):**
   - Trang chủ (`LearnerDashboardScreen` — `/dashboard`): Khối *"Bài học hôm nay"*, *"Tiếp tục hành trình"*, Huy hiệu Thể lực (`EnergyPill`) & Chuỗi ngày học (`Streak`).
   - Chọn Thời kỳ (`PeriodSelectionScreen` — `/journey`) & Hành trình Thời kỳ (`PeriodJourneyScreen` — `/journey/:periodCode`): Cây phân cấp `ERA -> PERIOD -> PHASE -> EVENT -> LESSON`, trạng thái mở khóa tuần tự (`LOCKED`, `AVAILABLE`, `IN_PROGRESS`, `COMPLETED`).
   - Chi tiết Chiến dịch & Sa bàn (`CampaignDetailScreen` `/campaign/:eventId`, `BattleSabanScreen` `/saban/:eventId`).
2. **Chặng 2 — Khởi tạo / Tiếp tục Bài học (`LessonEntryScreen` — `/learning/lesson/:lessonId`):**
   - Hiển thị bối cảnh, câu hỏi lịch sử trung tâm (`centralQuestion`), mục tiêu bài học, trạng thái bắt đầu mới (`Start`) hoặc tiếp tục (`Resume`) và kiểm tra quyền truy cập lộ trình (`LESSON_LOCKED_BY_PATH`).
3. **Chặng 3 — Khung Trình phát Bài học (`LessonPlayerScreen` Shell — `/learning/attempt/:attemptId`):**
   - Thanh tiêu đề bài học (`LessonHeaderTopBar`), thanh tiến trình (`ShimmerProgressBar`), tên Stage tư duy lịch sử, Huy hiệu Thể lực `⚡`, nút bật/tắt âm thanh (`SoundToggleButton`), Linh vật Kabi & Bóng thoại hướng dẫn (`KabiMascotWidget` + `MascotSpeechBubble`), và cơ chế bảo vệ dữ liệu đang nhập khi bấm Thoát (`PopScope` Exit Confirmation).
4. **Chặng 4 — Trải nghiệm Tương tác trên 12+ Loại Hoạt động Học tập (`ActivityRenderer`):**
   - Đánh giá chi tiết UI/UX, thao tác chạm/kéo-thả, khả năng tiếp cận (`Tap Fallback` & `Semantics`) cho toàn bộ các renderer:
     1. `READ` (`ReadRenderer` + `HistoricalAnimationPlayer` / `HtmlAnimationPlayer`)
     2. `VIEW_IMAGE` (`ViewImageRenderer`)
     3. `EXPLORE_MAP` (`ExploreMapRenderer`)
     4. `MULTIPLE_CHOICE` (`MultipleChoiceRenderer`)
     5. `EVIDENCE_SELECT` (`EvidenceSelectRenderer`)
     6. `MATCHING` (`MatchingRenderer`)
     7. `DRAG_ORDER` (`DragOrderRenderer`)
     8. `REASONING_CONNECT` (`ReasoningConnectRenderer`)
     9. `HYPOTHESIS_CHOICE` (`HypothesisRenderer`)
     10. `VERIFICATION` (`VerificationRenderer` + Nhánh quay lại sửa giả thuyết `Revise Loop`)
     11. `CER_CHOICE` (`CerChoiceRenderer`)
     12. `CER` (`CerRenderer`)
     13. `REFLECTION_PROMPT` (`ReflectionRenderer`)
     14. `UNKNOWN` (`UnsupportedRenderer`)
5. **Chặng 5 — Cơ chế Chấm điểm, Phản hồi Server, Giới hạn Lượt thử & Thể lực (`Feedback & Energy Loop`):**
   - Luồng `Nộp câu trả lời -> Khóa nút chống double-tap -> Hiển thị Thẻ Phản hồi từ Server (_feedbackCard) -> Chờ người học bấm TIẾP TỤC ›` (tuyệt đối không tự nhảy câu).
   - Xử lý trả lời sai câu có chấm điểm: Toast trừ Thể lực (`⚡ -10 Thể lực`), làm lại khi còn lượt (`maxAttempts`), cho phép đi tiếp khi hết lượt thử (`exhausted: true` không gây kẹt cứng / soft-lock).
   - Xử lý cạn Thể lực (`0/100 ⚡` -> `409 ENERGY_DEPLETED`): Hộp thoại cảnh báo hết Thể lực -> Điều hướng sang **Viện Thái Y (`/energy`)** -> Hồi phục Thể lực -> Quay lại bài học giữ nguyên tiến độ và câu đang làm.
6. **Chặng 6 — Tính Liên tục Phiên học (`Continuity, Reload & Version Pinning`):**
   - Tải lại trang (`page.reload()`), tắt/mở lại app, đổi thời kỳ rồi quay lại, hoặc Admin xuất bản `LessonVersion` mới khi người học đang làm dở phiên bản cũ.
7. **Chặng 7 — Hoàn thành Bài học, Tổng kết & Mở khóa Di sản (`LessonResultScreen` — `/learning/result/:attemptId`):**
   - Hiển thị điểm hoàn thành (`score`), điểm kiến thức (`knowledgeScore` / Mastery), phần thưởng lần đầu (`+100 EXP`, `+50 Điểm Sử Ký`), không cộng trùng khi học lại/retry, hiệu ứng Chuỗi ngày học (`Streak`), Dấu bằng chứng (`Evidence`), Hồ sơ lịch sử (`Dossiers`), Vật phẩm (`Items`), và Banner Địa điểm Di tích vừa mở (`UnlockedLocationBanner` -> `/heritage/:locationId` / `/map`).

---

## 2. Bộ Tiêu chuẩn Đánh giá UI/UX (`UI/UX Pro Max` & Di Sản Dấu Việt v2.0 Rubric)

| Mã trụ cột | Hạng mục Đánh giá | Tiêu chí Chuẩn Cần Đạt (Pass Criteria) |
|---|---|---|
| **UX-01** | **Thẩm mỹ Di sản & Phân cấp Thị giác (Visual Hierarchy)** | • Đồng bộ bảng màu `DauVietColors` (Giấy dó `#FFFBF4`/`#FFF1D5`, Đỏ chu sa `#A51F18`, Vàng ngự xưởng `#E7B451`, Xanh di sản `#1E4D3B`, Mực nho `#30251F`).<br>• Font `Noto Serif` cho tiêu đề/trích dẫn sử liệu và `Be Vietnam Pro` (`>= 14px`, `line-height 1.45–1.6`) cho nội dung học.<br>• Tương phản chữ/nền `>= 4.5:1` (văn bản chính `> 7:1`). Không dùng emoji thô thay thế icon hệ thống. |
| **UX-02** | **Đáp ứng Đa Kích thước & Không Tràn / Đè lớp (Zero Overflow & Overlap)** | • Kiểm tra trên 3 viewport điện thoại: **Nhỏ (`360×800`)**, **Chuẩn (`390×844`)**, **Lớn (`430×932`)**.<br>• `0` lỗi `RenderFlex overflowed` trong console.<br>• Không bị cắt chữ tiêu đề Stage/Bài học mất ý nghĩa; không cuộn ngang ngoài ý muốn.<br>• **Không đè lớp (Zero Overlap):** Toast `⚡ -10 Thể lực`, Bóng thoại Mascot Kabi, Thẻ Feedback Server (`_feedbackCard`), và Thanh nút hành động đáy không bao giờ che khuất nhau. |
| **UX-03** | **Công thái học Cảm ứng & Khả năng Tiếp cận (Touch & Accessibility)** | • Mọi nút bấm, thẻ đáp án, điểm hotspot trên map, nút âm thanh/thoát có vùng chạm tối thiểu **`44×44dp`** và khoảng cách `>= 8dp`.<br>• **Bắt buộc có Tap Fallback cho Kéo-Thả:** `MATCHING` hỗ trợ chạm lần lượt cột A -> cột B để ghép; `DRAG_ORDER` có nút mũi tên Lên/Xuống trên từng thẻ.<br>• Có nhãn ngữ nghĩa `Semantics` cho trình đọc màn hình và kiểm thử tự động. |
| **UX-04** | **Phản hồi Tương tác & Nhịp độ Sư phạm (Interaction Pacing)** | • Nút `GỬI CÂU TRẢ LỜI` / `KIỂM TRA` khóa ngay lập tức khi chưa chọn/nhập đủ dữ liệu và chuyển sang trạng thái `submitting` (chống bấm đúp) khi đang chờ server.<br>• **Không tự động chuyển câu (`No Auto-Advance`):** Sau khi server trả kết quả (`CORRECT`, `PARTIAL`, `INCORRECT`, `EXHAUSTED`), màn hình luôn giữ nguyên để người học đọc giải thích lịch sử và chỉ chuyển bước khi bấm `TIẾP TỤC ›` hoặc `HOÀN THÀNH BÀI HỌC`. |
| **UX-05** | **Tính Toàn vẹn Sư phạm & Bảo mật Đáp án (Pedagogical Integrity)** | • Không lộ đáp án đúng (`correctOptionId`, `answerKey`) trong payload tải bài học hoặc log console.<br>• Bóng thoại Mascot Kabi hiển thị lời dẫn đúng với loại câu hỏi hiện tại (không hiển thị nhầm câu 2 lựa chọn chữ dài thành câu Đúng/Sai).<br>• Tư liệu và bằng chứng (`Evidence`) có hiển thị nguồn trích dẫn sử học rõ ràng. |
| **UX-06** | **Bảo vệ Dữ liệu Đang làm & Liên tục Phiên học (State Continuity)** | • Khi người học đã gõ chữ/chọn phương án nhưng chưa bấm nộp mà bấm nút Back/Thoát -> bật **Dialog Xác nhận Thoát** để tránh mất dữ liệu vô ý.<br>• Khi `page.reload()` hoặc mở lại bài đang học dở -> khôi phục đúng `attemptId`, đúng `lessonVersionId` đã ghim và đúng `activity` hiện tại (`cursor`). |
| **UX-07** | **Xử lý Lỗi & Phục hồi Mượt mà (Error & Resource Resilience)** | • Mọi màn hình có đủ 4 trạng thái: `Loading`, `Ready`, `Empty`, `Error` (kèm nút `THỬ LẠI` hoạt động thật).<br>• Khi nộp bài gặp lỗi mạng/`500`/`503`: **giữ nguyên đáp án người học vừa chọn/nhập trên màn hình**, không xóa trắng form, không giả lập thành công (`no fake optimistic advance`). |

---

## 3. Danh mục 68 Test Cases Chi tiết (8 Nhóm `A`..`H`)

### Nhóm A: Luồng Khám phá, Lộ trình Thời kỳ & Điểm vào Bài học (`TC-NAV-01` .. `TC-NAV-09`)

| Mã TC | Tên kịch bản kiểm thử | Các bước thực hiện (Steps) | Kết quả UI/UX & Backend kỳ vọng (Expected Result) |
|---|---|---|---|
| **`TC-NAV-01`** | Khối *"Tiếp tục hành trình"* trên Trang chủ (`/dashboard`) khi người học mới tinh | 1. Đăng nhập tài khoản learner mới chưa học bài nào.<br>2. Mở `/dashboard` ở viewport `390×844`. | • Hiển thị lời chào cá nhân hóa, `EnergyPill` (`100/100 ⚡`), `Streak` (`0 ngày`).<br>• Khối *"Bài học hôm nay"* / *"Tiếp tục hành trình"* trỏ đúng vào bài học mở khóa đầu tiên của Thời kỳ đầu tiên.<br>• Không có lỗi tràn khung trên `360×800` và `390×844`. |
| **`TC-NAV-02`** | Khối *"Tiếp tục hành trình"* trên Trang chủ khi đang có bài học dở (`IN_PROGRESS`) | 1. Bắt đầu một bài học, làm xong Activity 1 rồi bấm Thoát về `/dashboard`.<br>2. Quan sát thẻ bài học trên Trang chủ. | • Thẻ hiển thị nhãn **`Đang học`** / nút **`TIẾP TỤC HỌC`** kèm thanh tiến trình phần trăm đã làm.<br>• Bấm vào đưa thẳng tới bài học đang dở để resume đúng Activity 2. |
| **`TC-NAV-03`** | Màn Chọn Thời kỳ (`PeriodSelectionScreen` — `/journey`) & quy tắc ẩn tầng `ERA` đơn lẻ | 1. Điều hướng sang tab Lộ trình (`/journey`).<br>2. Kiểm tra danh sách các Thời kỳ (`PERIOD`), tiến độ hoàn thành từng thời kỳ và huy hiệu trạng thái (`PathStatusBadge`). | • Mỗi thẻ Thời kỳ hiển thị rõ **cả Icon lẫn Nhãn chữ** (`Đang học`, `Đã mở`, `Đã hoàn thành`, `Đang khóa` + lý do khóa).<br>• Nếu lộ trình chỉ có `<= 1` đại thời kỳ (`ERA`), tự động ẩn tiêu đề tầng `ERA` thừa để giao diện gọn gàng. |
| **`TC-NAV-04`** | Màn Hành trình Thời kỳ (`PeriodJourneyScreen` — `/journey/:periodCode`) & cây `PHASE -> EVENT -> LESSON` | 1. Chạm vào một Thời kỳ đã mở.<br>2. Kiểm tra API `POST /api/v1/me/learning-path/periods/{code}/touch` và giao diện cây hành trình. | • Hiển thị đúng thứ tự Giai đoạn (`PHASE`) -> Sự kiện (`EVENT`) -> Bài học (`LESSON`).<br>• Phân biệt trực quan bài học **Bắt buộc (`REQUIRED`)** và **Tùy chọn (`OPTIONAL`)**. |
| **`TC-NAV-05`** | Chặn mở bài học đang bị khóa theo lộ trình tuần tự (`LOCKED`) | 1. Trên `PeriodJourneyScreen`, chạm vào một bài học đang ở trạng thái `LOCKED` (chưa hoàn thành bài bắt buộc đứng trước).<br>2. Thử truy cập thẳng URL `/learning/lesson/{lockedLessonId}` và bấm bắt đầu. | • Trên UI danh sách: hiển thị thông báo rõ cần hoàn thành bài học nào trước (không mở bài khóa).<br>• Nếu gọi API `POST /api/v1/lessons/{id}/attempts` trên bài khóa: server trả `403 LESSON_LOCKED_BY_PATH`, UI hiển thị thông báo khóa lộ trình và nút quay lại lộ trình. |
| **`TC-NAV-06`** | Đổi qua lại giữa các Thời kỳ không làm mất tiến độ | 1. Đang học dở ở Thời kỳ A (`periodCode = A`).<br>2. Quay ra `/journey` chọn Thời kỳ B rồi lại chọn về Thời kỳ A. | • `currentPeriodCode` cập nhật đúng nhưng tiến độ các bài đã hoàn thành / đang học ở Thời kỳ A được bảo toàn 100%. |
| **`TC-NAV-07`** | Điều hướng từ Chi tiết Chiến dịch (`/campaign/:eventId`) và Sa bàn (`/saban/:eventId`) vào Bài học | 1. Mở một Sự kiện lịch sử từ Trang chủ hoặc Bản đồ.<br>2. Xem danh sách bài học thuộc sự kiện và bấm vào một bài học. | • Hiển thị đúng danh sách bài học đã publish của sự kiện kèm trạng thái hoàn thành của từng bài.<br>• Chạm vào bài học điều hướng mượt sang `LessonEntryScreen`. |
| **`TC-NAV-08`** | Màn Giới thiệu Bài học (`LessonEntryScreen`) — Chế độ Bắt đầu mới vs. Tiếp tục học | 1. Mở `LessonEntryScreen` của bài chưa học -> kiểm tra UI.<br>2. Mở `LessonEntryScreen` của bài đang có attempt `IN_PROGRESS` -> kiểm tra UI. | • Hiển thị đầy đủ: Tiêu đề bài học, Câu hỏi lịch sử trung tâm (`centralQuestion`) nổi bật trên thẻ giấy dó, danh sách các Stage tư duy.<br>• Nút CTA đổi nhãn chính xác: **`BẮT ĐẦU HỌC ›`** (khi mới) hoặc **`TIẾP TỤC BÀI HỌC ›`** (khi có attempt dở). |
| **`TC-NAV-09`** | Trạng thái `Loading`, `Empty` và `Error + Retry` ở các màn Lộ trình & Điểm vào | 1. Giả lập mạng chậm (`Loading`) và lỗi `500` khi tải `/api/v1/me/learning-path` hoặc `/api/v1/lessons/{id}`.<br>2. Bấm nút `THỬ LẠI`. | • Khi đang tải: hiển thị `AsyncStateView.loading` với thông điệp lịch sử trang nhã.<br>• Khi lỗi: hiển thị thông báo tiếng Việt dễ hiểu + nút `THỬ LẠI` gọi lại API thành công mà không phải thoát màn hình. |

---

### Nhóm B: Khung Trình phát Bài học (`LessonPlayerScreen` Shell & Continuity — `TC-PLAYER-01` .. `TC-PLAYER-09`)

| Mã TC | Tên kịch bản kiểm thử | Các bước thực hiện (Steps) | Kết quả UI/UX & Backend kỳ vọng (Expected Result) |
|---|---|---|---|
| **`TC-PLAYER-01`** | Bố cục Header (`LessonHeaderTopBar`) & Thanh tiến trình (`ShimmerProgressBar`) | 1. Vào `LessonPlayerScreen` ở các bước `0/N`, `k/N`, `(N-1)/N`.<br>2. Kiểm tra trên cả viewport `360×800` và `390×844`. | • Hiển thị nút Thoát (`X` / Back `>= 44×44dp`), tên Stage hiện tại, tỷ lệ bước hoàn thành, nút Âm thanh (`SoundToggleButton`) và Huy hiệu Thể lực `⚡`.<br>• Thanh tiến trình tăng mượt theo tiến độ thực từ server, không tràn ngang ở màn `360px`. |
| **`TC-PLAYER-02`** | Linh vật Kabi (`KabiMascotWidget`) & Bóng thoại hướng dẫn (`MascotSpeechBubble`) | 1. Quan sát Kabi và bóng thoại qua từng loại activity (`READ`, `MULTIPLE_CHOICE` 2 đáp án chữ dài, `MULTIPLE_CHOICE` Đúng/Sai, `MATCHING`, `CER`).<br>2. Kiểm tra khi file Rive đang tải hoặc lỗi tải Rive. | • Bóng thoại hiển thị lời dẫn đúng ngữ cảnh từng loại activity (câu 2 đáp án chữ dài **không** bị báo nhầm là câu *"Chọn Đúng hoặc Sai"*).<br>• Khi Rive chưa tải xong hoặc lỗi, `KabiMascotWidget` hiển thị avatar tĩnh dự phòng đẹp mắt (không bị ô tròn trắng trơn). |
| **`TC-PLAYER-03`** | Bảo vệ dữ liệu chưa nộp khi bấm Thoát (`PopScope` & Exit Confirmation Dialog) | 1. Ở một activity có tương tác (đã chọn đáp án hoặc đã gõ văn bản vào ô `CER` / `REFLECTION_PROMPT` nhưng chưa bấm Nộp).<br>2. Bấm nút Thoát trên Header hoặc nút Back hệ thống. | • Bật đúng 1 hộp thoại xác nhận thoát (*"Bạn có dữ liệu chưa gửi. Bạn có chắc muốn rời bài học?"*) với 2 nút `Ở LẠI HỌC TIẾP` và `THOÁT`.<br>• Bấm `Ở LẠI HỌC TIẾP` giữ nguyên mọi dữ liệu vừa nhập; bấm lặp không mở chồng 2 dialog (`_exitDialogOpen` guard). |
| **`TC-PLAYER-04`** | Thoát rồi vào lại bài học đang làm dở (`Resume Cursor Accuracy`) | 1. Hoàn thành Activity 1 & 2, đang dừng ở đầu Activity 3.<br>2. Thoát ra Trang chủ rồi bấm vào lại bài học đó. | • `POST /api/v1/lessons/{id}/attempts` trả lại cùng `attemptId` đang `IN_PROGRESS`.<br>• `LessonPlayerScreen` mở thẳng vào Activity 3 (không bắt học lại Activity 1 & 2). |
| **`TC-PLAYER-05`** | Tải lại trang trình duyệt (`page.reload()`) giữa bài học khi Admin vừa xuất bản Version mới (`Version Pinning`) | 1. Bắt đầu attempt ở `LessonVersion v1` (tiến độ `1/3`).<br>2. Admin sửa nội dung bài học và publish `LessonVersion v2`.<br>3. Learner bấm `F5` / `page.reload()` ngay trên URL `/#/learning/attempt/{attemptId}`. | • Auth token được khôi phục trước khi gọi API (không bị văng về `/auth` hay lỗi `401`).<br>• Attempt vẫn gắn chặt với `lessonVersionId = v1` (nội dung, câu hỏi và đáp án chấm theo `v1`, không bị trộn hay hỏng bởi `v2`). |
| **`TC-PLAYER-06`** | Khả năng cuộn mượt khi nội dung tư liệu dài trên màn hình nhỏ (`360×800`) | 1. Mở một activity có đoạn tư liệu dài + 4 phương án trả lời dài ở viewport `360×800`.<br>2. Cuộn từ đầu xuống cuối màn hình và mở bàn phím ảo (với câu tự luận). | • Nội dung cuộn mượt trong vùng body; nút `GỬI CÂU TRẢ LỜI` luôn tiếp cận được (không bị che khuất vĩnh viễn bởi bàn phím hoặc tràn khỏi đáy màn hình). |
| **`TC-PLAYER-07`** | Bật / Tắt âm thanh (`SoundToggleButton`) trong lúc học | 1. Bấm nút loa trên Header để tắt âm thanh.<br>2. Trả lời câu hỏi và chuyển sang activity có hoạt họa lồng tiếng. | • Trạng thái tắt/bật âm thanh phản hồi tức thì trên icon và đồng bộ với `DauVietAudioService` + `HistoricalAnimationPlayer`. |
| **`TC-PLAYER-08`** | Chặn truy cập Attempt của người học khác (`403 ATTEMPT_NOT_OWNER` / `404`) | 1. Đăng nhập tài khoản Learner B.<br>2. Gõ URL `/#/learning/attempt/{attemptIdCuaLearnerA}`. | • Server từ chối truy cập (`403`/`404`), UI hiển thị màn hình lỗi an toàn kèm nút quay về Trang chủ, tuyệt đối không lộ tiến độ hay bài làm của Learner A. |
| **`TC-PLAYER-09`** | Mở URL `/#/learning/attempt/{completedAttemptId}` của một Attempt đã hoàn thành | 1. Sau khi đã hoàn thành bài học (`status = COMPLETED`), mở lại URL `/#/learning/attempt/{attemptId}`. | • Tự động điều hướng sang màn Kết quả (`/learning/result/{attemptId}`) hoặc hiển thị trạng thái đã hoàn thành mà không cho phép nộp đè lên attempt đã đóng. |

---

### Nhóm C: Kiểm thử Chi tiết UI/UX Từng Loại Hoạt động Học tập (`TC-ACT-01` .. `TC-ACT-20`)

| Mã TC | Loại Activity (`Renderer`) | Các bước thực hiện & Kịch bản kiểm thử | Kết quả UI/UX & Nghiệp vụ kỳ vọng |
|---|---|---|---|
| **`TC-ACT-01`** | `READ` (`ReadRenderer` — Văn bản sử liệu) | 1. Mở activity `READ` có tiêu đề, các đoạn văn (`sections`), trích dẫn cổ thư (`callout`).<br>2. Kiểm tra định dạng chữ và bấm `ĐÃ ĐỌC XONG, TIẾP TỤC`. | • Thẻ giấy dó trình bày thoáng, chữ mực nho sắc nét, trích dẫn cổ thư in nghiêng có viền vàng.<br>• Bấm nút gửi `{ "read": true }`, hiện phản hồi server trước khi bấm `TIẾP TỤC ›`. **Không trừ Thể lực.** |
| **`TC-ACT-02`** | `READ` kèm Hoạt họa Lịch sử (`HistoricalAnimationPlayer` / `HtmlAnimationPlayer`) | 1. Mở activity `READ` có nhúng cảnh hoạt họa (ví dụ: Sông Bạch Đằng / Sa bàn thủy triều hoặc HTML scene).<br>2. Thao tác Play / Pause / Replay / Tua / Tương tác điểm chạm trong cảnh hoạt họa. | • Khung hoạt họa co giãn đúng tỷ lệ (`aspectRatio`), không vỡ khung trên `360×800` và `390×844`.<br>• Khi chuyển sang câu kế tiếp, audio/timer của hoạt họa được `dispose()` sạch sẽ (không phát tiếng chồng ở câu sau). |
| **`TC-ACT-03`** | `VIEW_IMAGE` (`ViewImageRenderer` — Quan sát Tranh/Ảnh tư liệu) | 1. Mở activity `VIEW_IMAGE`.<br>2. Kiểm tra ảnh tư liệu, chú thích (`caption`), nguồn trích dẫn và trạng thái khi ảnh đang tải / lỗi ảnh. | • Hiển thị khung tranh di sản trang trọng kèm chú thích và nguồn.<br>• Khi ảnh mạng chậm có placeholder/loading; nếu ảnh lỗi hiển thị khung fallback rõ ràng, không vỡ layout. |
| **`TC-ACT-04`** | `EXPLORE_MAP` (`ExploreMapRenderer` — Khám phá Điểm nóng Bản đồ) | 1. Mở activity `EXPLORE_MAP` có các điểm marker/hotspot trên bản đồ.<br>2. Chạm vào từng hotspot để đọc thông tin khảo cổ/địa hình.<br>3. Kiểm tra trạng thái nút hoàn thành trước và sau khi mở đủ các hotspot bắt buộc. | • Các marker có hiệu ứng nổi bật, vùng chạm `>= 44×44dp`.<br>• Mỗi hotspot đã khám phá đổi trạng thái (đã xem ✓).<br>• Chỉ khi khám phá đủ số hotspot yêu cầu, nút xác nhận hoàn thành mới mở khóa. |
| **`TC-ACT-05`** | `MULTIPLE_CHOICE` (`MultipleChoiceRenderer` — Chọn 1 đáp án) | 1. Quan sát trạng thái ban đầu (chưa chọn đáp án nào).<br>2. Chạm chọn Phương án A -> đổi sang Phương án B -> bấm `GỬI CÂU TRẢ LỜI`. | • Khi chưa chọn: nút `GỬI CÂU TRẢ LỜI` ở trạng thái disabled.<br>• Khi chạm chọn: thẻ phương án đổi viền/nền nổi bật tức thì.<br>• Trong lúc đang gửi (`submitting = true`) và khi đang chờ bấm `TIẾP TỤC ›`: khóa không cho đổi phương án. |
| **`TC-ACT-06`** | `MULTIPLE_CHOICE` — Luồng Trả lời Sai rồi Trả lời Đúng | 1. Chọn phương án sai -> bấm Nộp -> đọc phản hồi sai.<br>2. Chọn lại phương án đúng -> bấm Nộp. | • Lượt 1 (Sai): hiển thị thẻ phản hồi lỗi màu đỏ/cam từ server + Toast `⚡ -10 Thể lực`; cho phép chọn lại phương án khác.<br>• Lượt 2 (Đúng): gỡ ngay Toast `-10 Thể lực` cũ, hiển thị thẻ phản hồi xanh lá từ server + nút `TIẾP TỤC ›`. |
| **`TC-ACT-07`** | `EVIDENCE_SELECT` (`EvidenceSelectRenderer` — Thu thập Bằng chứng Lịch sử) | 1. Mở activity `EVIDENCE_SELECT` hiển thị danh sách các thẻ tư liệu/bằng chứng.<br>2. Chạm chọn/bỏ chọn các thẻ bằng chứng theo số lượng yêu cầu (`minSelect`..`maxSelect`).<br>3. Bấm nộp. | • Mỗi thẻ bằng chứng hiển thị rõ tên tư liệu, tóm tắt và nguồn sử liệu.<br>• Hiển thị bộ đếm số bằng chứng đã chọn (VD: `Đã chọn 2/2 bằng chứng`).<br>• Sau khi nộp hợp lệ: các bằng chứng được ghi nhận vào Bộ sưu tập Dấu (`user_evidence`). |
| **`TC-ACT-08`** | `EVIDENCE_SELECT` — Phân biệt Chế độ Không chấm điểm (`graded=false`) và Có chấm điểm (`graded=true`) | 1. Thử chọn sai ở `EVIDENCE_SELECT` có `graded=false`.<br>2. Thử chọn sai ở `EVIDENCE_SELECT` có `graded=true`. | • Với `graded=false`: ghi nhận khám phá tư liệu, **không trừ Thể lực**.<br>• Với `graded=true`: nếu chọn sai bằng chứng nhiễu, server trả `INCORRECT`, trừ `-10 ⚡` đúng theo `ENGY-05`. |
| **`TC-ACT-09`** | `MATCHING` (`MatchingRenderer` — Ghép cặp bằng thao tác Chạm-Chọn `Tap Fallback`) | 1. Mở activity `MATCHING` gồm cột Vế trái và cột Vế phải.<br>2. Chạm vào 1 mục ở Vế trái -> chạm vào 1 mục ở Vế phải để tạo cặp.<br>3. Chạm lại vào cặp đã ghép để hủy ghép rồi ghép lại cặp mới.<br>4. Ghép đủ các cặp và bấm Nộp. | • Mục đang được chọn ở Vế trái sáng viền vàng/đỏ rõ ràng.<br>• Các cặp đã ghép hiển thị màu/nhãn liên kết đồng bộ.<br>• Cho phép hủy ghép / đổi cặp dễ dàng trước khi bấm Nộp.<br>• Nút Nộp chỉ bật khi đã ghép đủ số cặp yêu cầu. |
| **`TC-ACT-10`** | `MATCHING` — Thao tác Kéo-Thả (`Drag-and-Drop`) & Kiểm tra trên màn hình nhỏ `360×800` | 1. Kéo một thẻ từ cột trái thả vào ô đích ở cột phải.<br>2. Kiểm tra bố cục khi nội dung chữ trong thẻ ghép dài (3–4 dòng). | • Kéo-thả mượt mà, có hiệu ứng highlight vùng thả (`DragTarget`).<br>• Nội dung chữ dài tự xuống dòng, hai cột cân đối, không văng lỗi `RenderFlex overflowed`. |
| **`TC-ACT-11`** | `DRAG_ORDER` (`DragOrderRenderer` — Sắp xếp trình tự bằng Kéo-Thả) | 1. Mở activity `DRAG_ORDER` (sắp xếp chuỗi diễn biến lịch sử theo thời gian).<br>2. Nhấn giữ và kéo thẻ từ vị trí 3 lên vị trí 1. | • Thẻ đang kéo nổi lên có bóng đổ; số thứ tự (`1, 2, 3, 4...`) tự động cập nhật lại chính xác sau khi thả. |
| **`TC-ACT-12`** | `DRAG_ORDER` — Sắp xếp bằng Nút Lên / Xuống (`Tap Fallback` cho thiết bị nhỏ & Accessibility) | 1. Không dùng kéo-thả, bấm các nút mũi tên **Lên (`↑`)** và **Xuống (`↓`)** trên từng thẻ sự kiện.<br>2. Kiểm tra trạng thái nút `↑` ở phần tử đầu tiên và nút `↓` ở phần tử cuối cùng. | • Phần tử đầu tiên khóa nút `↑`; phần tử cuối cùng khóa nút `↓`.<br>• Bấm `↑`/`↓` hoán đổi vị trí tức thì và gửi đúng mảng thứ tự ID về server khi bấm Nộp. |
| **`TC-ACT-13`** | `REASONING_CONNECT` (`ReasoningConnectRenderer` — Nối Bằng chứng với Suy luận) | 1. Mở activity `REASONING_CONNECT`.<br>2. Chọn Bằng chứng A nối với Suy luận 1, Bằng chứng B nối với Suy luận 2.<br>3. Bấm Nộp và kiểm tra phản hồi. | • Hiển thị rõ mối quan hệ nhân quả *"Từ bằng chứng [X] ➔ Suy ra [Y]"*.<br>• Kiểm tra đúng quy tắc `graded=true/false` từ server. |
| **`TC-ACT-14`** | `HYPOTHESIS_CHOICE` (`HypothesisRenderer` — Đặt Giả thuyết & Chọn Bằng chứng Hỗ trợ) | 1. Mở activity `HYPOTHESIS_CHOICE`.<br>2. Chọn 1 giả thuyết lịch sử nhưng chưa chọn bằng chứng hỗ trợ -> kiểm tra nút Nộp.<br>3. Chọn đủ bằng chứng hỗ trợ -> bấm Nộp. | • Bắt buộc chọn cả **Giả thuyết** lẫn **Bằng chứng đi kèm** (nếu config yêu cầu) trước khi mở khóa nút Nộp.<br>• Không trừ Thể lực (đặt giả thuyết là bước tư duy khám phá theo `ENGY-06`). |
| **`TC-ACT-15`** | `VERIFICATION` (`VerificationRenderer` — Đối chiếu Giả thuyết với Sử liệu) | 1. Mở activity `VERIFICATION`.<br>2. Xem lại giả thuyết đã chọn ở bước trước và đối chiếu với tư liệu kiểm chứng mới.<br>3. Chọn kết luận kiểm chứng (`SUPPORTED` / `PARTIAL` / `CONTRADICTED`). | • Giao diện hiển thị lại giả thuyết ban đầu của người học để đối chiếu trực tiếp.<br>• Phản hồi rõ ý nghĩa của từng mức kiểm chứng (*Được củng cố / Phù hợp một phần / Mâu thuẫn với tư liệu*). |
| **`TC-ACT-16`** | `VERIFICATION` — Vòng lặp Quay lại Sửa Giả thuyết (`Revise Loop`) | 1. Trong kịch bản giả thuyết ban đầu bị `CONTRADICTED` và rule bài học cấu hình `fallback / revise`.<br>2. Bấm `TIẾP TỤC ›` sau khi nhận phản hồi kiểm chứng. | • Learning Engine đưa người học quay lại bước `HYPOTHESIS_CHOICE` để điều chỉnh giả thuyết phù hợp với bằng chứng mới.<br>• Thanh tiến trình và thông báo hướng dẫn giải thích rõ vì sao cần điều chỉnh giả thuyết. |
| **`TC-ACT-17`** | `CER_CHOICE` (`CerChoiceRenderer` — Kết luận Lịch sử dạng Chọn Khung `Claim – Evidence – Reasoning`) | 1. Mở activity `CER_CHOICE` có 3 phần: **Luận điểm (`Claim`)**, **Bằng chứng (`Evidence`)**, **Lập luận (`Reasoning`)**.<br>2. Chọn lần lượt từng phần và quan sát khung tổng hợp kết luận lịch sử.<br>3. Thử chọn sai 1 thành phần rồi chọn đúng cả 3 thành phần. | • Ba khối `Claim`, `Evidence`, `Reasoning` có nhãn tiếng Việt và màu sắc phân biệt rõ ràng.<br>• Chỉ mở nút Nộp khi đã chọn đủ cả 3 thành phần.<br>• Khi trả lời sai bị trừ `-10 ⚡` (`ENGY-05`); khi đúng hiển thị đoạn kết luận lịch sử hoàn chỉnh. |
| **`TC-ACT-18`** | `CER` (`CerRenderer` — Kết luận Lịch sử dạng Tự luận / Hỗn hợp) | 1. Mở activity `CER`.<br>2. Chọn bằng chứng tham chiếu từ danh sách đã thu thập và nhập nội dung `Claim` + `Reasoning`.<br>3. Kiểm tra giới hạn ký tự tối thiểu và bấm Nộp. | • Cho phép đính kèm các thẻ `Evidence` đã thu thập trong bài học.<br>• Khi đang gõ dở, cờ `onInputChanged(true)` kích hoạt bảo vệ chống thoát nhầm (`PopScope`). |
| **`TC-ACT-19`** | `REFLECTION_PROMPT` (`ReflectionRenderer` — Suy ngẫm Lịch sử cuối bài) | 1. Mở activity `REFLECTION_PROMPT`.<br>2. Thử bấm gửi khi ô nhập chỉ có khoảng trắng.<br>3. Nhập suy ngẫm hợp lệ và bấm Nộp. | • Chặn gửi khi chuỗi rỗng/chỉ có khoảng trắng.<br>• Khi gửi hợp lệ, ghi nhận hoàn thành bước Suy ngẫm (**không trừ Thể lực**). |
| **`TC-ACT-20`** | `UnsupportedRenderer` — Xử lý an toàn khi gặp `ActivityType` lạ | 1. Giả lập snapshot có `type: "FUTURE_AR_ACTIVITY"`.<br>2. Mở activity trong `LessonPlayerScreen`. | • Không crash ứng dụng (`No unhandled exception`); hiển thị thẻ thông báo lịch sự rằng loại hoạt động này cần phiên bản ứng dụng mới hơn. |

---

### Nhóm D: Cơ chế Nộp bài, Phản hồi Server & Giới hạn Lượt thử (`TC-FB-01` .. `TC-FB-06`)

| Mã TC | Tên kịch bản kiểm thử | Các bước thực hiện (Steps) | Kết quả UI/UX & Backend kỳ vọng (Expected Result) |
|---|---|---|---|
| **`TC-FB-01`** | Chống nhảy câu tự động (`Strict Submit -> Feedback -> Continue Gate`) | 1. Thực hiện nộp bài ở mọi loại activity (`READ`, `MULTIPLE_CHOICE`, `MATCHING`, `DRAG_ORDER`, `CER_CHOICE`). | • Ngay sau khi `POST .../submissions` trả về `200 OK`: `awaitingContinue == true`, hiển thị `_feedbackCard` chứa nguyên văn phản hồi từ server.<br>• Chỉ khi người học bấm nút `TIẾP TỤC ›` thì mới chuyển sang activity kế tiếp. |
| **`TC-FB-02`** | Phân biệt 4 Sắc thái Thẻ Phản hồi (`_FeedbackTone`: `success`, `info`, `warning`, `error`) | 1. Kiểm tra màu sắc, icon và tiêu đề của `_feedbackCard` tương ứng với các outcome: `CORRECT`, `COMPLETED` (ungraded), `PARTIAL`, `INCORRECT`. | • `CORRECT`: Xanh lá di sản, icon ✓.<br>• `PARTIAL`: Vàng cam, khích lệ tư duy một phần đúng.<br>• `INCORRECT` (còn lượt thử): Đỏ/cam cảnh báo kèm gợi ý xem lại tư liệu.<br>• `INCORRECT` + `exhausted: true` (hết lượt thử): Thông báo đã hết số lần thử và mở nút `TIẾP TỤC ›` để không bị kẹt. |
| **`TC-FB-03`** | Làm sai hết số lượt thử tối đa (`maxAttempts` / `exhausted: true`) — Không gây Soft-Lock | 1. Ở câu hỏi có `maxAttempts: 2`, nộp đáp án sai liên tiếp 2 lần.<br>2. Quan sát trạng thái sau lần sai thứ 2. | • Server trả `completed: true, exhausted: true, outcome: INCORRECT`.<br>• UI hiển thị phản hồi giải thích từ server và hiện nút **`TIẾP TỤC ›`** để người học đi tiếp hoàn thành bài học. |
| **`TC-FB-04`** | Chống Bấm đúp (`Double-Tap Guard`) trên nút `GỬI CÂU TRẢ LỜI` và `HOÀN THÀNH BÀI HỌC` | 1. Bấm liên tiếp 3 lần thật nhanh vào nút `GỬI CÂU TRẢ LỜI` hoặc `HOÀN THÀNH BÀI HỌC`. | • UI khóa nút ngay từ cú chạm đầu tiên (`submitting = true` / `_completing = true`).<br>• Chỉ có đúng 1 request được gửi đi, không bao giờ trừ Thể lực 2 lần cho 1 cú bấm. |
| **`TC-FB-05`** | Sinh `Idempotency-Key` mới khi người học nộp lại lần thứ 2 cho cùng câu hỏi | 1. Chọn đáp án A (sai) -> bấm Nộp -> server trả `INCORRECT`.<br>2. Không đổi đáp án và bấm Nộp lần 2. | • Do lần 1 đã nhận phản hồi authoritative từ server (`_needsFreshKey = true`), lần bấm thứ 2 sinh `Idempotency-Key` MỚI, được tính là `attemptNo = 2` hợp lệ. |
| **`TC-FB-06`** | Giữ nguyên `Idempotency-Key` khi Retry sau lỗi mạng mơ hồ (Timeout / Mất kết nối) | 1. Chọn đáp án A -> bấm Nộp -> giả lập đứt mạng trước khi nhận phản hồi.<br>2. Giữ nguyên đáp án A và bấm Nộp lại khi mạng có lại. | • Dùng lại **cùng `_submissionKey`** với cùng payload: nếu server thực ra đã xử lý request trước đó thì replay lại kết quả cũ, **không trừ Thể lực lần 2**. |

---

### Nhóm E: Tương tác Thể lực (`Energy`), Gate Cạn Thể lực & Luồng Khứ hồi Viện Thái Y (`TC-ENG-01` .. `TC-ENG-07`)

| Mã TC | Tên kịch bản kiểm thử | Các bước thực hiện (Steps) | Kết quả UI/UX & Backend kỳ vọng (Expected Result) |
|---|---|---|---|
| **`TC-ENG-01`** | Trừ `-10 ⚡` khi trả lời sai câu có chấm điểm & Không đè Toast lên Feedback | 1. Khi Thể lực đang `100/100`, trả lời sai 1 câu `MULTIPLE_CHOICE`.<br>2. Ngay sau đó (trong vòng `< 2 giây`), chọn lại đáp án ĐÚNG và bấm Nộp. | • Lượt sai: Huy hiệu Thể lực trên Header giảm từ `100` xuống `90`, hiện Toast `⚡ -10 Thể lực`.<br>• Lượt đúng: Toast `⚡ -10 Thể lực` của lượt trước **bị gỡ ngay lập tức**, không nằm đè lên khung phản hồi xanh lá của lượt đúng. |
| **`TC-ENG-02`** | Thể lực dương nhưng `< 10 ⚡` (`ENGY-10`: ví dụ còn `5/100 ⚡`) | 1. Đặt Thể lực của learner = `5/100 ⚡`.<br>2. Nộp câu trả lời có chấm điểm: thử trường hợp Đúng và trường hợp Sai. | • Vẫn cho phép nộp bài (không chặn khi `energy > 0`).<br>• Nếu trả lời Đúng: giữ nguyên `5/100 ⚡`.<br>• Nếu trả lời Sai: trừ `min(10, 5) = 5 ⚡` đưa Thể lực về `0/100 ⚡` (không bao giờ âm). |
| **`TC-ENG-03`** | Gate Chặn khi Thể lực `= 0/100 ⚡` (`409 ENERGY_DEPLETED` — `ENGY-09`) | 1. Khi Thể lực = `0/100 ⚡`, bấm nộp một câu hỏi có chấm điểm (`MULTIPLE_CHOICE`, `MATCHING`, `DRAG_ORDER`, `CER_CHOICE`). | • Server trả `409 ENERGY_DEPLETED` kèm `serverTime` và `nextRecoveryAt` (không làm mất lượt thử của câu hỏi).<br>• UI bật **Dialog/Sheet Hết Thể Lực** hiển thị đồng hồ đếm ngược hồi phục và nút **`ĐẾN VIỆN THÁI Y`** + nút **`ÔN TẬP / ĐỌC TƯ LIỆU`**. |
| **`TC-ENG-04`** | Thể lực `= 0/100 ⚡` vẫn cho phép hoàn thành Activity Không chấm điểm (`READ`, `VIEW_IMAGE`, `REFLECTION_PROMPT`) | 1. Khi Thể lực = `0/100 ⚡`, bấm hoàn thành một activity `READ` hoặc `REFLECTION_PROMPT`. | • Đi qua bình thường (`200 OK`), không bị chặn bởi zero-energy gate (`ENGY-09`). |
| **`TC-ENG-05`** | Thể lực `= 0/100 ⚡` ở câu cuối cùng đã làm xong vẫn cho phép bấm `HOÀN THÀNH BÀI HỌC` | 1. Ở câu hỏi cuối cùng của bài học, learner còn `10/100 ⚡`, nộp sai lượt cuối (`exhausted: true`) khiến Thể lực vừa chạm `0/100 ⚡` nhưng câu hỏi đã được đánh dấu `completed: true`.<br>2. Bấm `HOÀN THÀNH BÀI HỌC`. | • `POST /api/v1/attempts/{id}/complete` thành công `200 OK` (zero-energy gate không chặn bước đóng bài học khi các activity bắt buộc đã hoàn tất). |
| **`TC-ENG-06`** | Luồng Khứ hồi: Đang học bị `0/100 ⚡` ➔ Sang Viện Thái Y (`/energy`) bồi bổ ➔ Quay lại Bài học nộp tiếp | 1. Đang ở câu 2/3 của bài học, bị chặn bởi `409 ENERGY_DEPLETED` (`0/100 ⚡`).<br>2. Bấm **`ĐẾN VIỆN THÁI Y`** trên Dialog.<br>3. Tại Viện Thái Y (`/energy`), dùng **Nước Vối Tĩnh Tâm (`+20 ⚡`, Miễn phí)** hoặc **Trà Sen Tây Hồ (`+30 ⚡`, 30 Điểm)**.<br>4. Bấm nút Back / **`QUAY LẠI BÀI HỌC`**. | • Thanh Thể lực tại Viện Thái Y và trên Header bài học tăng lên `20/100 ⚡` (hoặc `30/100 ⚡`).<br>• Quay lại đúng màn hình câu 2/3 đang làm dở (không mất tiến độ), bấm `GỬI CÂU TRẢ LỜI` thành công ngay lập tức. |
| **`TC-ENG-07`** | Tự động mở khóa nộp bài khi chờ đủ 1 chu kỳ hồi tự nhiên (`+5 ⚡ / 15 phút`) | 1. Khi Thể lực = `0/100 ⚡` và thời gian trôi qua đủ 1 chu kỳ hồi tự nhiên trên server.<br>2. Người học bấm nộp câu hỏi có chấm điểm. | • Server tự động `applyLazyRecovery()` cộng `+5 ⚡` trước khi kiểm tra gate, cho phép nộp bài thành công mà không cần tải lại trang. |

---

### Nhóm F: Màn hình Kết quả Bài học (`LessonResultScreen`), Phần thưởng & Mở khóa Di sản (`TC-RES-01` .. `TC-RES-07`)

| Mã TC | Tên kịch bản kiểm thử | Các bước thực hiện (Steps) | Kết quả UI/UX & Backend kỳ vọng (Expected Result) |
|---|---|---|---|
| **`TC-RES-01`** | Hoàn thành Bài học Lần đầu tiên (`First-Time Completion Rewards`) | 1. Hoàn thành toàn bộ activity bắt buộc của một bài học mới.<br>2. Quan sát màn `LessonResultScreen` (`/learning/result/:attemptId`). | • Hiển thị Linh vật Rùa Kabi ăn mừng + pháo giấy vàng (`GoldConfettiOverlay`).<br>• Hiển thị rõ 3 thẻ chỉ số: **Điểm hoàn thành**, **`+100 EXP`**, **`+50 Điểm Sử Ký`**.<br>• Ví Điểm Sử Ký và tổng EXP trên Profile tăng đúng `+50` và `+100`. |
| **`TC-RES-02`** | Học lại / Ôn tập Bài học đã từng hoàn thành (`Replay / Second Attempt`) | 1. Bắt đầu một attempt mới trên bài học đã từng hoàn thành trước đó.<br>2. Hoàn thành lại bài học và xem màn Kết quả. | • Màn Kết quả hiển thị hoàn thành lượt ôn tập, **không cộng thêm `+100 EXP` và `+50 Điểm Sử Ký` lần 2** (`EXP-02`, `POINT-02`). |
| **`TC-RES-03`** | Phân biệt `LESSON_COMPLETED` (nhờ hết lượt thử) và `LESSON_MASTERED` (`knowledgeScore >= threshold`) | 1. Kịch bản 1: Làm đúng `>= 70%` câu chấm điểm.<br>2. Kịch bản 2: Làm sai hết lượt (`exhausted`) khiến `knowledgeScore < 70%`. | • Kịch bản 1: Đạt cả `COMPLETED` lẫn `MASTERED`.<br>• Kịch bản 2: Đạt `COMPLETED`, nhưng hiển thị khích lệ ôn tập thêm để đạt mức **Thông thạo (`MASTERED`)**. |
| **`TC-RES-04`** | Hiệu ứng Chuỗi Ngày Học (`Streak Celebration`) trên Màn Kết quả | 1. Hoàn thành bài học đầu tiên trong ngày (theo múi giờ `Asia/Ho_Chi_Minh`).<br>2. Hoàn thành bài học thứ hai trong cùng ngày. | • Bài đầu tiên trong ngày: hiển thị thông báo/hiệu ứng tăng Chuỗi ngày học (`currentStreak + 1`).<br>• Bài thứ hai trong cùng ngày: giữ nguyên số chuỗi ngày học, không tăng trùng. |
| **`TC-RES-05`** | Hiển thị Banner Địa điểm Di tích vừa mở khóa (`UnlockedLocationBanner` — Issue #25) | 1. Hoàn thành bài học là điều kiện mở khóa của một Địa điểm Di tích (`map_locations`).<br>2. Kiểm tra `UnlockedLocationBanner` trên `LessonResultScreen` và bấm nút xem địa điểm. | • Hiển thị `UnlockedLocationBanner` nổi bật đúng 1 lần kèm tên & ảnh địa điểm vừa mở.<br>• Bấm vào banner điều hướng sang hồ sơ địa điểm (`/heritage/:locationId`) hoặc Bản đồ Di sản (`/map`). |
| **`TC-RES-06`** | Mở khóa Hồ sơ Lịch sử (`Dossiers`) và Vật phẩm Thưởng (`Items`) khi Hoàn thành Sự kiện (`EVENT_COMPLETED`) | 1. Hoàn thành bài học bắt buộc cuối cùng của một Sự kiện lịch sử.<br>2. Kiểm tra Dialog chúc mừng mở khóa (`UnlockCelebrationDialog`). | • Hiển thị thông báo mở khóa Hồ sơ nhân vật/địa điểm/hiện vật (`user_dossier_unlocks`) và Vật phẩm (`user_inventory`) theo rule.<br>• Tải lại trang kết quả (`F5`) không bắn lại popup chúc mừng lần 2 (`isFreshCompletion == false`). |
| **`TC-RES-07`** | Điều hướng Tiếp nối sau Màn Kết quả (`Tiếp tục hành trình` / `Về bàn học tập`) | 1. Từ `LessonResultScreen`, bấm nút **`TIẾP TỤC HÀNH TRÌNH`**.<br>2. Kiểm tra trạng thái lộ trình trên `PeriodJourneyScreen` hoặc `CampaignDetailScreen`. | • Bài vừa học chuyển sang trạng thái **`Đã hoàn thành`** (`COMPLETED`) ngay lập tức.<br>• Bài học kế tiếp trong lộ trình tự động chuyển từ `LOCKED` sang `AVAILABLE`. |

---

### Nhóm G: Kiểm thử Đường lỗi Mạng/Server & Bảo mật (`TC-ERR-01` .. `TC-ERR-04`)

| Mã TC | Tên kịch bản kiểm thử | Các bước thực hiện (Steps) | Kết quả UI/UX & Backend kỳ vọng (Expected Result) |
|---|---|---|---|
| **`TC-ERR-01`** | Mất kết nối / Lỗi `503` khi đang bấm `GỬI CÂU TRẢ LỜI` | 1. Chọn đáp án (hoặc ghép cặp / sắp xếp xong) -> ngắt mạng hoặc giả lập `503` trên `POST .../submissions`.<br>2. Bấm `GỬI CÂU TRẢ LỜI`.<br>3. Khôi phục mạng và bấm gửi lại. | • Hiện thông báo lỗi mạng rõ ràng.<br>• **Giữ nguyên các lựa chọn người học vừa thao tác trên màn hình**, không nhảy bước giả, không bắt người học ghép/chọn lại từ đầu.<br>• Khi bấm gửi lại thì thành công. |
| **`TC-ERR-02`** | Lỗi `500` ở bước `POST /api/v1/attempts/{id}/complete` hoặc `GET .../result` | 1. Ở câu cuối cùng, bấm `HOÀN THÀNH BÀI HỌC` khi mạng chập chờn.<br>2. Bấm thử lại. | • Nếu `POST /complete` đã thành công nhưng `GET /result` lỗi: cờ `_completionAcknowledged = true` chỉ gọi lại `GET /result` mà không POST `/complete` thừa.<br>• Khi mạng khôi phục, mở đúng màn Kết quả. |
| **`TC-ERR-03`** | Hết hạn Access Token giữa lúc đang suy nghĩ câu hỏi (Auto Refresh Token) | 1. Mở câu hỏi, chờ Access Token hết hạn.<br>2. Bấm `GỬI CÂU TRẢ LỜI`. | • `withAuth()` tự động gọi `/api/v1/auth/refresh`, lấy token mới và gửi tiếp câu trả lời thành công trong suốt. |
| **`TC-ERR-04`** | Phiên đăng nhập hết hạn hoàn toàn (Refresh Token không hợp lệ) | 1. Thu hồi cả access token và refresh token.<br>2. Truy cập `/#/learning/attempt/{id}` hoặc bấm nộp bài. | • Chuyển hướng sạch về màn hình Đăng nhập (`/#/auth`), không treo ở màn hình loading vô tận. |

---

### Nhóm H: Kiểm thử Bố cục Đáp ứng, Không Tràn chữ & Accessibility (`TC-VIS-01` .. `TC-VIS-04`)

| Mã TC | Tên kịch bản kiểm thử | Các bước thực hiện (Steps) | Kết quả UI/UX kỳ vọng (Expected Result) |
|---|---|---|---|
| **`TC-VIS-01`** | Kiểm toán Không Tràn Giao diện (`Zero RenderFlex Overflow`) trên `360×800`, `390×844`, `430×932` | 1. Chạy tự động qua toàn bộ các màn hình của luồng học (`PeriodSelection`, `PeriodJourney`, `LessonEntry`, `LessonPlayer` với cả 12 loại activity, `EnergyManagement`, `LessonResult`) ở cả 3 kích thước viewport. | • `0` lỗi `RenderFlex overflowed by ... pixels` trong Flutter logs.<br>• Mọi phần tử nằm gọn trong khung nhìn (`boundingBox.right <= viewport.width`). |
| **`TC-VIS-02`** | Kiểm toán Không Đè lớp (`Zero Visual Overlap`) trong `LessonPlayerScreen` | 1. Kiểm tra tọa độ khung hình (`boundingBox`) của: Header Top Bar, Bóng thoại Mascot Kabi, Vùng nội dung Activity, Thẻ Phản hồi Server (`_feedbackCard`), Toast Thể lực, và Nút CTA đáy. | • Toast Thể lực không đè lên `_feedbackCard` hoặc nút `TIẾP TỤC ›`.<br>• Nội dung câu hỏi có padding đáy đủ lớn để khi cuộn kịch xuống dưới không bị che khuất bởi thanh nút cố định. |
| **`TC-VIS-03`** | Kiểm tra Độ dài Văn bản Cực hạn (Long Vietnamese Historical Text Stress Test) | 1. Kiểm tra bài học có tên sự kiện dài (> 80 ký tự), câu hỏi nhiều mệnh đề và phương án trả lời 4–5 dòng tiếng Việt có dấu. | • Text tự động xuống dòng (`softWrap: true`), tuyệt đối không bị cắt mất nội dung đáp án làm người học không đọc được câu trả lời. |
| **`TC-VIS-04`** | Kiểm tra Vùng chạm tối thiểu (`>= 44×44dp`) & Cây Ngữ nghĩa (`Semantics`) | 1. Bật kiểm tra Accessibility / Semantics tree trên các màn hình học tập. | • Tất cả các nút tương tác chính có kích thước vùng chạm đạt chuẩn.<br>• Các nút icon-only đều có `tooltip` / `semanticLabel` tiếng Việt đầy đủ. |

---

## 4. Đầu ra & Tiêu chí Nghiệm thu của Issue (Deliverables & Acceptance Criteria)

- [x] **AC-1 (Báo cáo Đánh giá UI/UX Chi tiết):** Rà soát thực tế toàn bộ 7 chặng của luồng học tập trên `360×800` và `390×844`, lập bảng ghi nhận mọi lỗi UI/UX (tràn bố cục, đè lớp, thiếu trạng thái, lệch màu/font, thiếu tap fallback) kèm ảnh chụp màn hình minh chứng.
- [x] **AC-2 (Khắc phục Triệt để các Lỗi UI/UX Phát hiện):** Sửa toàn bộ các điểm chưa đồng bộ hoặc lỗi hiển thị trên `LessonEntryScreen`, `LessonPlayerScreen`, 12 `ActivityRenderer`, `EnergyManagementScreen`, và `LessonResultScreen` theo đúng chuẩn `UI/UX Pro Max` & `DauVietColors`.
- [x] **AC-3 (Bộ Kiểm thử Tự động Bao phủ Luồng Học):** Thực thi và vượt qua bộ Widget Test / Integration Test (`flutter test`) và E2E Playwright (`390×844` & `360×800`) bao phủ các nhóm kịch bản `TC-NAV`, `TC-PLAYER`, `TC-ACT`, `TC-FB`, `TC-ENG`, `TC-RES`, `TC-ERR`, `TC-VIS`.
- [x] **AC-4 (Zero Runtime/Visual Errors):** `flutter analyze` đạt `0 issues`; khi chạy thực tế luồng học từ đầu đến cuối đạt `0` lỗi `console.error` / `FlutterError` / `RenderFlex overflowed`.

---

## 5. Kế hoạch Xử lý Triệt để Các Vấn đề Phát hiện qua Kiểm toán & Ảnh chụp E2E (5 Phases)

Qua quá trình chạy kiểm toán mã nguồn (`ScoutEntryPlayerResult`, `ScoutActivityRenderers`), chạy `flutter analyze` toàn repo và đối chiếu trực tiếp 17 ảnh chụp màn hình E2E (`360×800` & `390×844`), toàn bộ các vấn đề gặp phải được phân loại và lập kế hoạch xử lý trong 5 Phase chi tiết:

| Phase | Hồ sơ thiết kế chi tiết | Trọng tâm khắc phục | Độ ưu tiên |
|---|---|---|---|
| **Phase 01** | [`phase-01-dashboard-and-journey-ux.md`](./phase-01-dashboard-and-journey-ux.md) | • **Dashboard Hero Banner:** Sửa lỗi chữ phụ đề đè lên nón lá Rùa Kabi trên màn `360×800`.<br>• **Thẻ "Bài học hôm nay":** Thay chuỗi cứng `'Bài học đang tiếp diễn'` + mã thô `'Giai đoạn: ctx'` bằng tên bài học thật và tiến độ phần trăm.<br>• **Lộ trình (`/journey`):** Bổ sung lý do khóa thời kỳ/bài học và huy hiệu `Bắt buộc`/`Tùy chọn`.<br>• **Sa bàn (`/saban`):** Sửa lỗi `Row` + `DongSonButton(width: double.infinity)` gây crash `RenderFlex`. | **P0 (Critical UX)** |
| **Phase 02** | [`phase-02-lesson-entry-and-player-shell.md`](./phase-02-lesson-entry-and-player-shell.md) | • **`ShimmerProgressBar` (`0/N`):** Sửa lỗi `Stack` co rút về `2.4px` khi `progress = 0.0` khiến thanh tiến trình biến mất ở câu đầu tiên.<br>• **`LessonPlayerScreen` TopBar:** Tối ưu bố cục trên màn `360×800` để tiêu đề Stage không bị cắt cụt thành `'Bối cảnh lịc...'`.<br>• **`LessonEntryScreen`:** Thay ảnh chân trang `ancient_village_footer.png` bị lỗi (lộ ảnh chụp roadmap có số `6`, `7`) và bổ sung hiển thị danh sách các Stage tư duy lịch sử. | **P0 (Critical Visual)** |
| **Phase 03** | [`phase-03-activity-renderers-and-energy-loop.md`](./phase-03-activity-renderers-and-energy-loop.md) | • **`CerChoiceRenderer`:** Bổ sung huy hiệu màu phân biệt 3 phần `Claim – Evidence – Reasoning` và khung tổng hợp kết luận lịch sử trực tiếp (`TC-ACT-17`).<br>• **Hộp thoại Hết Thể lực:** Nâng cấp đồng hồ đếm ngược tự động cập nhật từng giây (`TC-ENG-03`).<br>• **Asset & Accessibility:** Hỗ trợ `LearningAssetImage` theo `assetId` cho `MultipleChoiceRenderer` (Đúng/Sai) và `MatchingRenderer`; khóa zoom ảnh khi đang `submitting`. | **P1 (Pedagogical & A11y)** |
| **Phase 04** | [`phase-04-lesson-result-and-repo-cleanliness.md`](./phase-04-lesson-result-and-repo-cleanliness.md) | • **`LessonResultScreen`:** Sửa lỗi hiển thị tiêu đề chung `'Hoàn thành bài học'` thay vì tên bài học thật (do snapshot không chứa `title`, cần lấy từ `LessonMetadataDto`); xử lý ảnh `kabi_celebration_victory.png` bị cắt chữ *"Bạn thật tuyệt vời!"* ở góc phải; bổ sung điều hướng `'TIẾP TỤC HÀNH TRÌNH'`.<br>• **Clean Repo Analyze:** Dọn sạch 10 cảnh báo `flutter analyze` còn lại ở các module `island`, `auth`, `profile` để `flutter analyze` toàn repo đạt `0 issues`. | **P1 (Visual & Hygiene)** |
| **Phase 05** | [`phase-05-e2e-verification-and-visual-regression.md`](./phase-05-e2e-verification-and-visual-regression.md) | • Chạy toàn bộ `flutter test`, `flutter analyze --no-pub`, build lại web bundle và chạy lại Playwright E2E để cập nhật bộ 17 ảnh chụp màn hình minh chứng trên `390×844` và `360×800`. | **P0 (Verification Gate)** |
