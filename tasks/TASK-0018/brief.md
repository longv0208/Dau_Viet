# TASK-0018 — Dấu Việt Flutter Mobile: Real Learning Experience

Brief đầy đủ do user paste trong phiên làm việc (2026-10-17). Tóm tắt trọng tâm:

## Mục tiêu sản phẩm

Một hành trình học end-to-end nối backend thật:

Login → Discover Historical Event → Select Published Lesson → Start/Resume Attempt → Learn Through Stages → Submit Answers → Receive Feedback → Complete Lesson → View Result.

Kịch bản đại diện: Event "Trận Bạch Đằng năm 938", Lesson "Bí mật chiến thắng Bạch Đằng" — dữ liệu phải lấy từ backend, KHÔNG hard-code UUID/title/content/stage order/activity ids. Learner phải hoàn thành được nội dung do Admin Web publish mà không sửa Flutter source.

## Điểm chính

- Backend learner APIs đã có: lesson discovery, attempt lifecycle, auth, learner media — inspect DTO thật, không đoán.
- Server authoritative: cursor stage/activity, grading, transitions, completion, version pinning, Idempotency-Key, error envelope.
- Tái dùng UI mock hiện có (6 màn learning + theme + mascot + widgets) convert sang data-driven; giữ USE_MOCK=true làm demo rõ ràng; lỗi API không fallback mock.
- Auth email/password thật + secure storage + refresh + restore; Guest = mock only; Google/EduID đánh dấu unavailable, không fake.
- Renderer registry theo ActivityType; ưu tiên READ, VIEW_IMAGE, MULTIPLE_CHOICE, EVIDENCE_SELECT, MATCHING, DRAG_ORDER, CER, REFLECTION_PROMPT; unsupported → trạng thái rõ ràng, không fake-complete.
- Idempotent submission (reuse key khi retry cùng answer); giữ answer khi network fail; feedback tiếng Việt.
- Version pinning: render theo pinned lessonVersionId; chỉ thêm backend endpoint read-only tối thiểu nếu contract thiệt sự thiếu + regression test.
- Progress qua /me/progress + /me/attempts (completedRequired/totalRequired); complete + result thật; không fabricate reward.
- Tests: unit + widget + integration khi backend chạy được; phân biệt rõ stub vs real-backend verify; không emulator thì report limitation.
- Không redesign app, không architecture framework, không reward engine, không OAuth mới.
- DoD quan trọng nhất: lesson publish trên Admin Web chơi được thật trên Flutter không hard-code, không client-side fake grading.
- KHÔNG tự động push/merge. Báo cáo cuối bằng tiếng Việt.

## Constraints môi trường đã biết

- Windows, PowerShell (Bash tool hay lỗi ENAMETOOLONG trên đường dẫn dài).
- Docker không khả dụng → Postgres/Testcontainers IT không chạy được local; ghi rõ trong report.
- Backend unit tests: `./mvnw.cmd test "-Dtest=*Test"` từ `dau-viet-backend/`.
- Flutter toolchain: kiểm tra `flutter --version` trước khi hứa gates.
