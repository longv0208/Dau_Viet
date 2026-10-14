# Dấu Việt

Ứng dụng học lịch sử Việt Nam qua hoạt động khám phá và lập luận dựa trên bằng chứng.

## Hiện trạng

- `dau-viet-backend`: **active** — Spring Boot 3.4 / Java 21 / PostgreSQL + Flyway modular monolith; `GET /api/v1/events` và `GET /api/v1/events/{id}` đã chạy với dev seed Bạch Đằng 938. Chạy local theo [backend runbook](docs/backend-runbook.md).
- `dau-viet-mobile`: active — Flutter demo với mock data (chưa nối backend; delta contract ở [backend-flutter-contract-notes](docs/backend-flutter-contract-notes.md)).
- `dau-viet-admin`: chưa khởi tạo.

Kiến trúc dự kiến: Spring Boot + PostgreSQL, Next.js Admin và Flutter (xem [tech stack](docs/TECH_STACK.md)).

## Bắt đầu

Đọc [AGENTS.md](AGENTS.md), [quy trình agent](docs/AGENT_WORKFLOW.md) và [task pilot](tasks/TASK-0001/brief.md). Trạng thái thực thi chuẩn nằm trong `tasks/*/task.json`; [tiến độ](docs/PROGRESS.md) chỉ là bản tổng hợp.

| Tài liệu sản phẩm | Nội dung |
|---|---|
| [Project overview](docs/PROJECT_OVERVIEW.md) | Mục tiêu, phạm vi MVP |
| [Tech stack](docs/TECH_STACK.md) | Kiến trúc và công nghệ dự kiến |
| [Coding rules](docs/CODING_RULES.md) | Quy tắc code và invariants |
| [API specification](docs/API_SPEC.md) | Hợp đồng API dự thảo |
| [Database design](docs/DATABASE_DESIGN.md) | Dữ liệu, transaction, version |
| [Learning engine](docs/LEARNING_ENGINE_DESIGN.md) | Runtime và hoạt động học |

## Harness theo từng phase

- Phase 1: context map, quy tắc, schema/config và task mẫu.
- Phase 2: runner PowerShell 7, kiểm chứng, GitNexus adapter và CI.
- Phase 3: resume, handoff, bằng chứng còn hợp lệ và cải tiến quy trình.

Xem [kế hoạch](plans/2026-10-09-no-issue-vibe-coding-harness/plan.md) và [quyết định](docs/DECISIONS.md).

Lệnh runner đã được kiểm chứng trên máy dev (Windows PowerShell 5.1):

```powershell
powershell -NoProfile -File scripts/harness/harness.ps1 doctor
powershell -NoProfile -File scripts/harness/harness.ps1 status
powershell -NoProfile -File tests/harness/run-tests.ps1
```

`verify`/`start`/`resume`/`finish` cần `pwsh` (PowerShell 7) cho gate `harness-self-test`; các gate khác chạy được trên 5.1. Không suy ra runner đã hoạt động chỉ từ thiết kế — trạng thái chi tiết ở `tasks/TASK-0002/task.json`.
