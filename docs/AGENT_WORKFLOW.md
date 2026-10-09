# Quy trình AI agent

## Mục đích và nguồn chuẩn

Dành cho người phát triển và coding agent. [AGENTS](../AGENTS.md) là entry point; sáu tài liệu sản phẩm hiện hữu giữ nội dung nghiệp vụ. `tasks/<id>/task.json` lưu trạng thái thực thi; `brief.md` giải thích yêu cầu; `plans/` lưu thiết kế. Không duy trì hai bản trạng thái độc lập.

## Intake

Tạo task từ [template](../.harness/templates/task.md), điền goal, scope, modules, AC và next action. Dùng [schema](../.harness/schemas/task.schema.json). Mỗi AC có `id` và `text`; không ghi hoàn thành nếu chưa có artifact kiểm chứng.

| Risk | Áp dụng | Hồ sơ |
|---|---|---|
| tiny | Docs/copy không đổi hành vi | Brief, kiểm tra liên quan, review |
| normal | Chức năng giới hạn, contract đã chốt | Brief, plan, AC/test mapping |
| high-risk | Auth, ownership, DB/migration, version, reward/idempotency, public API | Plan, impact note, negative/concurrency tests phù hợp, ADR khi đổi quyết định |

Chọn mức cao nhất bị ảnh hưởng. Bản thân high-risk không tạo một vòng xin phép mới cho việc đã được người dùng cho phép.

## Thực thi

1. Planner khảo sát yêu cầu, source và dependencies; chọn scope và TODO.
2. Agent đọc tài liệu theo context map, kiểm tra working tree, ghi impact note.
3. Implementer sửa trong scope được giao; không ghi đè thay đổi của agent khác.
4. Tester chạy build/tests áp dụng, giữ exit code, logs và fingerprint.
5. Reviewer độc lập đối chiếu diff, plan, AC và kết quả test.
6. Docs-manager cập nhật tài liệu khi hành vi thay đổi; viết handoff và next action.
7. Runner chỉ finish khi evidence hiện tại đủ, review không còn blocker và AC có coverage.

Alias `planner-researcher` có thể ánh xạ sang role `planner` kèm research; ghi đúng role đã dùng. Nếu không có công cụ delegation, báo hạn chế thay vì tự nhận đã có review độc lập.

## Role mapping và orchestration

Vai trò contract dùng trong task/handoff là tên logic; tên agent cụ thể trong Claude Code có thể khác. Ánh xạ mặc định:

| Role (contract) | Agent thực tế | Trách nhiệm |
|---|---|---|
| planner | `planner` hoặc `planner-researcher` | Plan, research, chia phase |
| implementer | `fullstack-developer` hoặc `claude` | Sửa code trong scope |
| tester | `tester` | Chạy test, validate gate |
| reviewer | `code-reviewer` | Review độc lập sau implementation |
| docs-manager | `docs-manager` | Cập nhật docs khi behavior đổi |
| debugger | `debugger` | Điều tra bug/CI/server issues |

**Mặc định sequential**: planner → implementer → tester → reviewer → docs-manager. Mỗi bước đợi bước trước xong; output của bước trước là input của bước sau.

**Parallel chỉ khi**: (a) các agent ghi vào file disjoint (file ownership không overlap), (b) không có data dependency giữa chúng, (c) merge plan đã xác định trước. Ví dụ hợp lệ: `tester` chạy test trong khi `docs-manager` viết docs — đọc cùng code, ghi file khác nhau. Ví dụ không hợp lệ: hai implementer cùng sửa `FooService.java`.

Một writer mỗi file mỗi thời điểm. Reviewer độc lập — người/agent review không phải người/agent viết code đang review.

## Trạng thái

`draft → ready → implementing → verifying → reviewing → done`.

`blocked` phải có `blockedReason`, `nextAction`, `resumeFrom`. Khi yêu cầu/source/gate đổi, evidence cũ là stale; quay lại bước phù hợp để kiểm chứng. Một writer mỗi task; runner tương lai chịu trách nhiệm lock và atomic writes.

## Module và gate

[Config](../.harness/config.json) đăng ký backend/admin/mobile ban đầu là `uninitialized`. Mỗi module có `path`, `status`, `manifests`, `gates`. Gate command dùng `id`, `executable`, `args`, `cwd`, `timeoutSeconds`; không shell string hay `Invoke-Expression`.

- Docs-only: schema, liên kết, whitespace/scope và review; app build là N/A có lý do.
- Module trống: không tự tuyên bố app test pass. Feature cần module chưa bootstrap phải blocked.
- Có source/manifest mới nhưng registry chưa active: blocked để hoàn tất bootstrap registration.
- Module active: dùng wrapper/lock/scripts có thật; thiếu tool/test/script là failed hoặc blocked.
- Harness/config: cần tests cho runner, state, routing, fingerprint và smoke.

Bootstrap chỉ active sau khi có manifest/wrapper/lock thích hợp và smoke test được xác minh. Không hạ module active về uninitialized để bỏ test.

## GitNexus và kiểm chứng

GitNexus hỗ trợ impact, không quyết định done. Pin phiên bản đã smoke test, ghi snapshot của index; không dùng cache tồn tại làm bằng chứng index mới. Không tự chạy setup sửa cấu hình global. Kiểm tra diff sau indexing để tránh ghi đè AGENTS/skills.

Nếu graph thiếu hoặc stale: ghi lý do, tìm kiếm source/contract, truy references thủ công và mở rộng kiểm tra. Graph không chứng minh đầy đủ Spring DI, reflection hoặc liên kết HTTP giữa các module.

Evidence cần command/args/cwd, tool versions, thời gian, exit code, logs/digest, HEAD hoặc null, fingerprint đầu vào và hash gate config. Đổi source trong lúc chạy làm evidence stale. N/A khác passed. Logs mất hoặc fingerprint sai thì không đủ điều kiện finish.

Mỗi AC cần map đến test hoặc manual check có người/agent thực hiện và artifact cụ thể. Runner không thể tự chứng minh toàn bộ nghiệp vụ qua exit code. Tối đa ba vòng sửa cùng lỗi rồi ghi blocked với root cause và next action; tiếp tục khi có cách giải quyết mới.

## Bàn giao và an toàn dữ liệu

Handoff ghi kết quả, checks thực chạy, các hạn chế, file liên quan và hành động kế tiếp. Phiên mới đọc task/handoff, kiểm tra working tree và freshness trước tiếp tục. Không auto commit/push. Raw logs/cache không đưa vào Git; evidence summaries chỉ lưu sau khi rà secrets. Không log token hoặc dữ liệu learner riêng tư.

Các cơ chế runner, resume, GitNexus và CI thuộc Phase 2–3. Entrypoint `scripts/harness/harness.ps1` (subcommands `doctor`, `start`, `verify`, `status`, `resume`, `finish`) đã được cài đặt; test cục bộ `tests/harness/run-tests.ps1` pass 38/38 dưới Windows PowerShell 5.1. Gate `harness-self-test` hiện `failed` trên máy dev vì `pwsh` (PowerShell 7) chưa được cài — cần PowerShell 7 trước khi CI xanh. Tài liệu này quy định contract; các con số trên phản ánh chạy thật, không phải kỳ vọng.
