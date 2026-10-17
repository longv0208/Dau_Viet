# TASK-0015 — Báo cáo sửa lỗi sản phẩm sau review

- Ngày: 2026-10-17
- Phạm vi: `dau-viet-admin/src/features/lessons/builder/**` — 4 ưu tiên từ brief
- Kết quả: hoàn thành, toàn bộ gate xanh

## 1. Lỗi đã sửa

### P1 — Mất thay đổi khi sửa trong lúc đang lưu

- Trước: PUT thành công → `markSaved` tắt `dirty` vô điều kiện. Nếu người dùng gõ tiếp trong lúc request đang chạy, edit mới bị đánh dấu "đã lưu" dù chưa hề gửi lên server → mất dữ liệu âm thầm.
- Sửa: `BuilderState` thêm `revision` (tăng +1 ở mọi mutation của draft) và `savedRevision`. `mutationFn` capture `revision` lúc bấm Lưu; `markSaved(rowVersion, revision)` chỉ tắt `dirty` khi `revision === state.revision` — nếu đã có edit mới hơn, `dirty` vẫn giữ, unsaved-changes guard và nút Lưu tiếp tục hoạt động.
- File: `use-builder.ts` (state + 10 case mutation + `markSaved`), `builder-page.tsx` (capture revision trong mutationFn).
- Test: `use-builder.test.ts` "markSaved keeps dirty when edits happened during a pending save"; `builder-page.test.tsx` test mới giả PUT chậm qua MSW — sửa giữa chừng → "Chưa lưu" vẫn hiển thị, không có chip "Đã lưu", nút Lưu còn bật.

### P2 — Nhãn `v{rowVersion}` gây nhầm với LessonVersion

- Trước: thanh trạng thái hiển thị `v3`, `v4`... — dễ hiểu nhầm là phiên bản đã xuất bản, thực chất là optimistic-lock rowVersion của dòng DB.
- Sửa: bỏ hẳn nhãn version; chỉ còn `{lesson.title}` + chip trạng thái (DRAFT/PUBLISHED) + chip "Chưa lưu"/"Đã lưu HH:mm:ss" — người dùng nhìn thời điểm lưu thay vì con số kỹ thuật.
- File: `builder-page.tsx`.

### P3 — Validation inline cho MULTIPLE_CHOICE / MATCHING / DRAG_ORDER

- MC: thêm cảnh báo "Có đáp án chưa nhập nội dung — điền đủ hoặc xoá bớt"; làm rõ thông điệp câu hỏi trống ("học viên sẽ không biết cần trả lời gì"), thiếu đáp án đúng ("hệ thống sẽ không chấm được câu này"), <2 đáp án.
- MATCHING: thêm cảnh báo cặp thiếu một vế; làm rõ điều kiện ≥2 cặp.
- DRAG_ORDER: thêm cảnh báo bước trống nội dung; làm rõ điều kiện ≥2 bước.
- Nguyên tắc giữ nguyên: chỉ là hint `role=alert` inline — KHÔNG chặn save; draft dở vẫn lưu được (SAVE-level), publish readiness do backend `/validate` quyết.

### P4 — Duplicate stage: unique id + remap tham chiếu nội bộ

- Trước: bản sao giữ nguyên `nextStageIds` của stage gốc — nếu gốc tự trỏ vào chính nó (self-loop) hoặc có tham chiếu nội bộ, bản sao trỏ về stage GỐC thay vì về chính nó.
- Sửa: `duplicateStage` giờ dùng `idMap` (stage cũ→mới + activity cũ→mới), remap `nextStageIds` của bản sao: tham chiếu nội bộ trỏ về id mới, tham chiếu ngoài draft giữ nguyên. Id sinh qua `genSlugId` với `taken` array tích luỹ — unique toàn draft. Stage gốc không bị đụng.
- Test: `use-builder.test.ts` "duplicateStage remaps internal nextStageIds and leaves the original untouched" — self-loop `s2→[s2,s3]` thành `[copyId,s3]`, toàn bộ id unique, stage gốc nguyên vẹn.

## 2. Ảnh hưởng tới trải nghiệm Content Admin

- Gõ nhanh trong lúc lưu không còn rủi ro mất chữ — hệ thống nhận biết "có thay đổi chưa gửi" và giữ nút Lưu.
- Không còn con số `v#` gây hiểu nhầm đây là phiên bản xuất bản; trạng thái bản nháp đọc được bằng ngôn ngữ tự nhiên.
- Lỗi soạn thảo phổ biến (quên đáp án đúng, cặp/bước trống) hiện cảnh báo ngay khi gõ, không phải đợi tới khi publish bị từ chối — nhưng vẫn lưu nháp được để làm tiếp sau.
- Nhân bản giai đoạn có rẽ nhánh nội bộ không còn tạo bản sao trỏ sai về stage gốc.

## 3. Kết quả test thực tế

| Gate | Kết quả |
|---|---|
| `tsc --noEmit` | Sạch, 0 lỗi |
| `next lint` | 0 warning/error |
| `vitest run` | 62/62 pass (14 files; builder: 26 test — use-builder 10, builder-page 8, draft-model 5, MC editor 3) |
| `next build` | Thành công |
| `playwright tests/e2e/builder.spec.ts` | 3/3 pass (stub có kiểm soát) |

## 4. Giới hạn còn lại

- Revision chỉ chống mất edit trong CÙNG một tab/phiên; hai admin sửa đồng thời vẫn xử lý qua 409 conflict + reload (không merge).
- Race "save-đè-save": nếu bấm Lưu hai lần cực nhanh, request sau ghi đè — hiện nút Lưu disabled trong lúc `isPending` nên xác suất thấp, chưa có queue.
- Validation inline vẫn là hint — chưa có tổng hợp "n lỗi trước publish" phía client (chờ backend `/validate`).
- MATCHING: id vế phải của cặp mới không bảo đảm khác vế trái tuyệt đối (xác suất ~0, đã ghi nhận ở review P3).
- Không mở rộng sang TASK-0016 (evidence/asset picker, các editor loại còn lại) đúng giới hạn brief.
