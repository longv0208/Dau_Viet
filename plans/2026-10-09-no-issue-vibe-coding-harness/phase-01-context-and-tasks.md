# Giai đoạn 1: Context và task

Priority P2 · Pending · 8h · Phụ thuộc: không.

## Mục tiêu và phạm vi

Thực hiện bước 1–3. Biến repo tài liệu hiện tại thành nơi agent mới hiểu quy tắc, scope và next action mà không phải đọc toàn bộ repo. Không đổi stack hoặc viết chức năng sản phẩm.

## Tài liệu liên quan

[Kế hoạch](plan.md), [contract](harness-contract.md), `docs/PROJECT_OVERVIEW.md`, `docs/TECH_STACK.md`, `docs/CODING_RULES.md`.

## File dự kiến tạo/sửa

Các đường dẫn dưới đây tương đối với `C:/Users/Admin/Desktop/4user/DauViet/`; chưa tạo trong lượt lập kế hoạch.

| File | Thao tác | Nội dung |
|---|---|---|
| `AGENTS.md` | Tạo | Context map, workflow, roles, done gates, fallback |
| `README.md` | Tạo | Entry point, hiện trạng bootstrap, setup/harness commands sau khi tồn tại |
| `docs/AGENT_WORKFLOW.md` | Tạo | Quy trình, phân loại task, recovery, cách đưa yêu cầu |
| `docs/DECISIONS.md` | Tạo | ADR gọn cho harness, task source of truth, adapter policy |
| `docs/PROGRESS.md` | Tạo | View sinh từ task state, không chỉnh status thủ công |
| `.harness/config.json` | Tạo | Module registry, profile bootstrap, gate definitions |
| `.harness/schemas/task.schema.json` | Tạo | Schema task có version |
| `.harness/templates/task.md` | Tạo | Brief: goal, AC, constraints, scope, tests |
| `tasks/TASK-xxxx/task.json`, `brief.md` | Tạo mẫu | Một task docs-only có acceptance kiểm chứng được |
| `.gitignore` | Tạo/cập nhật | GitNexus cache, run logs/local state; không loại task records |

Không tạo PROJECT.md/ARCHITECTURE.md/CONVENTIONS.md trùng nội dung sáu docs hiện hữu. CLAUDE.md hoặc adapter Cursor chỉ thêm khi thực sự dùng, dẫn về AGENTS.

## TODO thực hiện

- [ ] F1. Kiểm kê files/tracked state/tool versions, ghi rõ planned versus installed; không làm mất docs đang untracked.
- [ ] F2. AGENTS context routing: task DB đọc DATABASE_DESIGN; runtime đọc LEARNING_ENGINE; contract đọc API_SPEC; mọi task đọc overview/stack/rules.
- [ ] F3. Chuyển các invariant sang checklist: immutable version, attempt pinning, ownership, idempotency, private answers, no event-specific logic.
- [ ] F4. Định nghĩa small/docs task chỉ cần brief; task API/DB/auth/architecture phải có plan, risk và tests. Quyết định thay kiến trúc xin user chốt; lựa chọn thực thi thông thường tự xử lý.
- [ ] F5. Task schema chứa id, type, status, goal/AC refs, modules, paths, dependencies, base commit, workspace fingerprint, role reports, evidence, next action.
- [ ] F6. Khởi tạo module registry `uninitialized`; chỉ chuyển `active` qua bootstrap task đã có manifest/wrapper/lock và smoke test được xác minh.
- [ ] F7. Viết role mapping theo user: `planner-researcher` → planner có research; tester, code-reviewer, docs-manager. Tool không hỗ trợ alias thì ghi role thực tế, không giả lập delegation.
- [ ] F8. Ghi ADR và README entry point; kiểm tra internal links và schema examples.

## Acceptance và kiểm chứng

- Agent mới đọc AGENTS + docs liên quan, nêu đúng ba module, backend authoritative và hiện trạng chưa có source.
- Task mẫu có AC cụ thể, không tự invent function requirements; JSON hợp lệ và không có secrets.
- Context vừa đủ: AGENTS mục tiêu dưới 150 dòng; chi tiết thuộc docs, không copy lại toàn bộ.
- `PROGRESS.md` là view; trạng thái duy nhất nằm trong task JSON. Không dựng song song `tasks/` và `plans/` cùng quản lý status: plans chứa thiết kế, tasks quản lý thực thi.

## Rủi ro và xử lý

- Docs lệch nhau: ưu tiên source map, ghi conflict vào task trước thay đổi lớn.
- Bootstrap che lỗi: config uninitialized không đủ để bypass; runner phải phát hiện manifest/source xuất hiện và yêu cầu đăng ký gate.
- Scope phình: chưa thêm hosted service, database task, GUI hoặc multi-agent daemon.

## Bàn giao

Giai đoạn 2 nhận task/config contracts đã rõ. Giai đoạn 1 có thể dùng bằng lệnh và checklist thủ công trước khi harness tồn tại.
