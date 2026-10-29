# TASK-0029 — [UI/UX & QA] Đánh giá chi tiết và bộ Test Case toàn diện cho Luồng Học Tập Lịch Sử (Issue #29)

- **GitHub Issue:** https://github.com/longv0208/Dau_Viet/issues/29
- **Branch:** `feat/issue-29-learning-flow-ui-ux`
- **Worktree:** `E:/Telegram Desktop/Dau viet/Dau_Viet-issue-29`
- **Master Plan:** `plans/261028-issue-29-learning-flow-ui-ux/plan.md`

## 1. Mục tiêu
Rà soát, đánh giá toàn diện UI/UX và thực thi **68 kịch bản kiểm thử chi tiết (Test Cases)** xuyên suốt 7 chặng của **Luồng Học Tập Lịch Sử** trên `dau-viet-mobile` nối với `dau-viet-backend` + PostgreSQL thật:
1. **Chặng 1:** Điểm vào & Khám phá Lộ trình (`/dashboard`, `/journey`, `/journey/:periodCode`, `/campaign/:eventId`, `/saban/:eventId`).
2. **Chặng 2:** Khởi tạo / Tiếp tục Bài học (`LessonEntryScreen`).
3. **Chặng 3:** Khung Trình phát Bài học (`LessonPlayerScreen` Shell: Top Bar, Progress, Mascot Kabi, Audio, `PopScope` Exit Guard).
4. **Chặng 4:** 12+ Loại Hoạt động Học tập (`READ`, `VIEW_IMAGE`, `EXPLORE_MAP`, `MULTIPLE_CHOICE`, `EVIDENCE_SELECT`, `MATCHING`, `DRAG_ORDER`, `REASONING_CONNECT`, `HYPOTHESIS_CHOICE`, `VERIFICATION`, `CER_CHOICE`, `CER`, `REFLECTION_PROMPT`, `UnsupportedRenderer`).
5. **Chặng 5:** Cơ chế Chấm điểm, Phản hồi Server (`_feedbackCard`), Giới hạn Lượt thử (`maxAttempts` / `exhausted`) & Vòng lặp Thể lực (`Energy` + Viện Thái Y `/energy`).
6. **Chặng 6:** Tính Liên tục Phiên học (`Resume`, `page.reload()`, `Version Pinning`).
7. **Chặng 7:** Màn Kết quả (`LessonResultScreen`), Phần thưởng, Chuỗi ngày học (`Streak`), Mở khóa Dấu/Hồ sơ/Vật phẩm & Banner Địa điểm Di tích (`UnlockedLocationBanner`).

## 2. Tiêu chí Nghiệm thu (Acceptance Criteria)
- **AC-1:** Báo cáo đánh giá UI/UX chi tiết toàn bộ 7 chặng trên `360×800` và `390×844` kèm ảnh chụp màn hình minh chứng.
- **AC-2:** Sửa triệt để các lỗi UI/UX phát hiện trên các màn hình và renderer của luồng học tập theo chuẩn `UI/UX Pro Max` & `DauVietColors`.
- **AC-3:** Vượt qua bộ Widget/Integration Test (`flutter test`) và E2E Playwright (`390×844` & `360×800`) bao phủ 8 nhóm kịch bản (`TC-NAV`, `TC-PLAYER`, `TC-ACT`, `TC-FB`, `TC-ENG`, `TC-RES`, `TC-ERR`, `TC-VIS`).
- **AC-4:** `flutter analyze` đạt `0 issues`; chạy thực tế luồng học đạt `0` lỗi `console.error` / `FlutterError` / `RenderFlex overflowed`.
