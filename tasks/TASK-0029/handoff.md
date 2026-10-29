# Handoff — TASK-0029 ([UI/UX & QA] Đánh giá chi tiết và bộ Test Case toàn diện cho Luồng Học Tập Lịch Sử — Issue #29)

## 1. Bảng Đánh giá UI/UX & Các lỗi đã phát hiện / khắc phục xuyên suốt 7 Chặng (`AC-1`, `AC-2`)

| Mã lỗi | Chặng / Mã TC | File & Vị trí | Mô tả lỗi UI/UX phát hiện | Giải pháp khắc phục đã triển khai |
|---|---|---|---|---|
| **F-01** | Chặng 5 (`TC-ENG-01`, `TC-VIS-02`, `UX-02`) | `lesson_player_screen.dart` | `_EnergyPenaltyToast` (`-10 Thể lực`) không lưu tham chiếu `OverlayEntry` và đặt ở `bottom: 110`, gây đè lên `_feedbackCard` khi nội dung dài và vẫn lơ lửng đè lên màn phản hồi xanh lá khi người học trả lời đúng ngay sau đó (`< 2.2s`). | Lưu `_energyToastEntry`, bổ sung `_dismissEnergyPenaltyToast()` gọi ngay khi nộp câu đúng kế tiếp, khi chuyển câu, hoặc khi `dispose()`; dời vị trí toast lên `Alignment.topCenter` (`top: 72`) ngay dưới TopBar để tuyệt đối không đè lên `_feedbackCard` và nút `TIẾP TỤC ›`. |
| **F-02** | Chặng 3 & 5 (`TC-FB-01`, `TC-FB-02`, `UX-04`) | `lesson_player_screen.dart` | Khi `awaitingContinue && feedback != null`, `_buildPlayer` thay thế toàn bộ nội dung câu hỏi bằng `_buildCelebrationScreen` (chỉ phân biệt 2 trạng thái Đúng/Sai và làm mất ngữ cảnh câu hỏi đang xem). | Giữ nguyên Activity trên màn hình (ở trạng thái khóa `submitting: true`) kèm `_buildBottomBar` hiển thị `_feedbackCard` phân biệt rõ 4 sắc thái (`CHÍNH XÁC`, `ĐÚNG MỘT PHẦN`, `CHƯA CHÍNH XÁC`, `ĐÃ GHI NHẬN` với `ValueKey('feedback-card-${tone}')`) và nút `TIẾP TỤC ›`. |
| **F-03** | Chặng 3 (`TC-PLAYER-02`, `UX-01`, `UX-05`) | `lesson_player_screen.dart`, `multiple_choice_renderer.dart` | `_resolveMascotPrompt` kiểm tra `opts.length == 2` và báo nhầm mọi câu 2 phương án chữ dài là câu *"Chọn Đúng hoặc Sai"*; `_isTrueFalse` dùng `.contains('đúng')`/`.contains('sai')` gây nhận diện sai câu văn dài chứa từ `"đúng"`/`"sai"`; dùng emoji thô `💪`. | Chuẩn hóa `_isTrueFalseOptions` / `_isTrueFalse` so khớp token chính xác (`{'đúng', 'sai', 'true', 'false', 'yes', 'no'}`), bổ sung lời dẫn sư phạm riêng cho cả 13 loại Activity và loại bỏ hoàn toàn emoji thô. |
| **F-04** | Chặng 3 (`TC-PLAYER-02`, `UX-01`) | `kabi_mascot_widget.dart`, `mascot_speech_bubble.dart` | Khi Rive đang tải hoặc lỗi/chạy test, `_buildFallbackMascot` trả về `SizedBox` rỗng khiến khung avatar trong `MascotSpeechBubble` thành ô tròn trắng trơn. | Hiển thị ảnh linh vật tĩnh dự phòng (`turtle_welcome.png` / `kabi_celebration_victory.png` kèm icon fallback di sản) và nhãn ngữ nghĩa `Semantics`. |
| **F-05** | Chặng 3 & 5 (`TC-PLAYER-01`, `TC-ENG-01`) | `lesson_player_screen.dart` | Thanh Header của `LessonPlayerScreen` thiếu huy hiệu Thể lực (`⚡`), chỉ hiển thị Streak và tiến độ. | Bổ sung `_EnergyBadge` (`ValueKey('player-header-energy')`) đồng bộ trực tiếp với `energyProvider` trên TopBar và dẫn sang `/energy` khi chạm. |
| **F-06** | Chặng 2 (`TC-NAV-05`, `TC-NAV-08`, `UX-01`) | `lesson_entry_screen.dart` | `LessonEntryScreen` hiển thị `centralQuestion` bằng chữ xám nhỏ `13px` không có khung giấy dó, không hiển thị mục tiêu bài học (`objectivesJson`), nút Resume ghi `'TIẾP TỤC HỌC ›'` thay vì `'TIẾP TỤC BÀI HỌC ›'`, và khi gặp `403 LESSON_LOCKED_BY_PATH` thiếu nút quay lại lộ trình. | Đóng khung `centralQuestion` trên thẻ giấy dó viền vàng (`14.5px`), hiển thị danh sách `MỤC TIÊU KHÁM PHÁ`, đổi nhãn nút thành `'TIẾP TỤC BÀI HỌC ›'`, và thêm nút `'QUAY LẠI LỘ TRÌNH'` khi bị chặn bởi `LESSON_LOCKED_BY_PATH`. |
| **F-07** | Chặng 3 & 7 (`TC-PLAYER-08`, `TC-RES-07`) | `lesson_player_screen.dart` | Khi gặp lỗi `403 ATTEMPT_NOT_OWNER` / `404` trên `LessonPlayerScreen`, màn hình chỉ có nút `THỬ LẠI` mà không có lối thoát về Trang chủ; khi hoàn thành hoặc thoát bài học chưa invalidate `learningPathProvider`. | Bổ sung nút `'VỀ TRANG CHỦ'` trên màn lỗi của `LessonPlayerScreen`; gọi `ref.invalidate(learningPathProvider)` tại `_start()`, `_complete()` và `_exitNow()`. |
| **F-08** | Chặng 4 (`TC-ACT-01`, `TC-ACT-04`, `TC-ACT-07`, `TC-ACT-10`, `TC-ACT-12`, `TC-ACT-13`, `TC-ACT-14`, `TC-ACT-15`, `TC-ACT-17`) | `renderers/*.dart` | • `READ` bỏ qua `sections[]` và `callout`.<br>• `EXPLORE_MAP` không khôi phục `priorOutputs` và vẫn đánh dấu visited khi submit lỗi mạng.<br>• `MATCHING` thiếu thao tác Kéo-Thả (`Draggable`/`DragTarget`).<br>• `DRAG_ORDER`, `EVIDENCE_SELECT`, `REASONING_CONNECT`, `SoundToggleButton` có vùng chạm `< 44×44dp` và thiếu `Semantics`.<br>• `HYPOTHESIS_CHOICE` cho phép nộp khi chưa chọn bằng chứng hỗ trợ.<br>• `VERIFICATION` hiển thị mã `hypothesisId` thô thay vì nội dung giả thuyết.<br>• `CER_CHOICE` mất cờ dirty khi bỏ chọn bằng chứng. | • `ReadRenderer`: hỗ trợ `sections[]` và khung trích dẫn cổ thư `callout`.<br>• `ExploreMapRenderer`: khôi phục `discoveredMarkerIds` từ `priorOutputs`, tôn trọng `minMarkers` và chặn cập nhật giả khi `hasSubmitError == true`.<br>• `MatchingRenderer`: bổ sung `Draggable<String>` & `DragTarget<String>` song song với Tap Fallback, thu gọn thumbnail trên màn `< 380px`.<br>• Nâng toàn bộ nút điều khiển (`DRAG_ORDER` Lên/Xuống, `EVIDENCE_SELECT` chọn, `REASONING_CONNECT` xóa, `SoundToggleButton`) lên `>= 44×44dp` kèm `Semantics`.<br>• `HypothesisRenderer`: bắt buộc chọn đủ `minEvidence` khi có `visibleEvidenceIds`.<br>• `VerificationRenderer`: tra cứu văn bản giả thuyết từ `content.stages`.<br>• `CerChoiceRenderer` & `ReasoningConnectRenderer`: đồng bộ chính xác cờ dirty `onInputChanged`. |
| **F-09** | Chặng 5 & 7 (`TC-ENG-06`, `TC-RES-01..04`, `TC-VIS-01`) | `energy_management_screen.dart`, `energy_providers.dart`, `lesson_result_screen.dart` | • `EnergyManagementScreen` luôn hiển thị `'VỀ BÀN HỌC TẬP (DASHBOARD)'` kể cả khi mở từ bài học.<br>• `LessonResultScreen` tràn `RenderFlex` `13px` ở `_buildResultBadge` trên màn `360×800`, thiếu `GoldConfettiOverlay`, thiếu phân biệt `MASTERED` (`knowledgeScore >= 70%`) vs `COMPLETED` và lượt ôn tập (`replay`). | • `EnergyManagementScreen`: hiển thị `'QUAY LẠI BÀI HỌC'` khi `context.canPop() == true`.<br>• `LessonResultScreen`: bọc `FittedBox` chống tràn ngang tuyệt đối trên `360×800`, tích hợp `GoldConfettiOverlay`, hiển thị huy hiệu `THÔNG THẠO (MASTERED)` / `HOÀN THÀNH LƯỢT HỌC`, thông điệp ôn tập khi replay và loại bỏ emoji thô. |

## 2. Minh chứng Ảnh chụp Màn hình E2E (`AC-1` — `390×844` & `360×800`)

Toàn bộ 17 ảnh chụp màn hình thực tế từ Playwright Chromium nối với `dau-viet-backend` + PostgreSQL 16 được lưu tại `tasks/TASK-0029/screenshots/`:
- `stage1_dashboard_390x844.png`, `stage1_dashboard_360x800.png`
- `stage1_period_selection_390x844.png`, `stage1_period_selection_360x800.png`
- `stage1_period_journey_390x844.png`, `stage1_period_journey_360x800.png`
- `stage1_campaign_detail_390x844.png`, `stage1_campaign_detail_360x800.png`
- `stage2_lesson_entry_390x844.png`, `stage2_lesson_entry_360x800.png`
- `stage3_lesson_player_390x844.png`, `stage3_lesson_player_360x800.png`
- `stage5_energy_management_390x844.png`, `stage5_energy_management_360x800.png`
- `stage6_reload_continuity_390x844.png`
- `stage7_lesson_result_390x844.png`, `stage7_lesson_result_360x800.png`

## 3. Kết quả Kiểm chứng Tự động (`AC-3`, `AC-4`)

1. **Static Analysis & Format (`dau-viet-mobile`):**
   - `dart format --output=none --set-exit-if-changed` trên toàn bộ file trong scope -> **PASS (`0 changed`)**.
   - `flutter analyze --no-pub lib/features/learning lib/features/learning_path lib/features/dashboard lib/features/energy lib/features/meta/presentation/energy_management_screen.dart lib/core/widgets/sound_toggle_button.dart lib/core/widgets/kabi_mascot_widget.dart lib/core/widgets/mascot_speech_bubble.dart test/learning/ test/learning_path/ test/energy/` -> **PASS (`No issues found!`)**.
2. **Widget & Integration Tests (`flutter test`):**
   - `flutter test --no-pub test/learning/ test/learning_path/ test/energy/ test/dashboard/ test/kabi_mascot_widget_test.dart` -> **PASS (`358/358 tests passed`, bao gồm bộ test mới `test/learning/learning_flow_issue_29_test.dart`)**.
3. **Live Playwright E2E Audit (`390×844` & `360×800`):**
   - `python dau-viet-mobile/e2e/verify_issue_29_learning_flow_e2e.py` -> **PASS (`consoleErrorsCount: 0`, `pageErrorsCount: 0`, `overflowErrorsCount: 0`, báo cáo lưu tại `tasks/TASK-0029/e2e_audit_report.json`)**.
4. **Independent Code Review:**
   - Thực hiện qua subagent `CodeReviewer` -> **PASS (`9.8/10`, `0 blockers`)**.

## 4. Ghi chú Công cụ & Môi trường
- Chỉ mục GitNexus chưa được khởi tạo trong worktree `Dau_Viet-issue-29` (`npx gitnexus status` -> `Repository not indexed`); đã sử dụng công cụ tìm kiếm ký hiệu (`grep`/`read`) và kiểm thử diện rộng (`358` bài test + E2E Playwright) theo đúng quy định fallback trong `AGENTS.md`.

## 5. Hành động tiếp theo
- Sẵn sàng commit/push nhánh `feat/issue-29-learning-flow-ui-ux` khi người dùng xác nhận.
