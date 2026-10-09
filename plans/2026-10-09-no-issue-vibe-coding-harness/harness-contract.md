# Contract harness đề xuất

Tất cả file, subcommand và schema dưới đây là thiết kế cần triển khai, không phải công cụ đã tồn tại. [Nghiên cứu nguồn](research/source-check.md).

## Kiến trúc tối thiểu

User → agent intake → task brief/plan → implementer → runner deterministic → tester/reviewer → docs → handoff. Agent đọc/viết code; runner quản lý task state, chạy command đã định nghĩa và kiểm tra evidence. GitNexus cung cấp code graph; không quyết định done.

Harness local không ngăn agent chạy shell ngoài script. AGENTS là hướng dẫn; runner là kiểm tra deterministic khi được gọi. Bắt buộc trước merge chỉ được enforce bằng CI required checks/protected branch sau khi cấu hình được cho phép; không mặc định repo đã có protection.

Entrypoint dự kiến: `scripts/harness/harness.ps1`. Actions: `doctor`, `start`, `verify`, `status`, `resume`, `finish`. Cú pháp dự kiến: `pwsh -File scripts/harness/harness.ps1 verify -Task TASK-0001`. PowerShell 7 dùng local và CI; module adapters là dữ liệu executable/arguments/workingDirectory, không shell string tùy ý và không `Invoke-Expression`. Hỗ trợ Windows trước; smoke test Linux khi bật CI Linux.

## State và evidence

Risk lane là policy đề xuất riêng của Dấu Việt:

| Lane | Khi áp dụng | Hồ sơ tối thiểu |
|---|---|---|
| tiny | Copy/docs hoặc thay đổi cục bộ không đổi hành vi, schema, quyền | Task brief ngắn, checks liên quan, review |
| normal | Chức năng giới hạn trong một module, contract đã được chốt | Brief, plan, AC và test mapping |
| high-risk | Auth/ownership, migration/xóa dữ liệu, publish/version, idempotency/reward, thay đổi public contract hoặc yêu cầu kiểm thử | Plan chi tiết, impact note, negative/concurrency tests phù hợp, ADR nếu đổi quyết định |

Lane lấy mức cao nhất của yếu tố ảnh hưởng; task không tự hạ lane để bỏ gate. Quyết định sản phẩm/kiến trúc chưa rõ cần user chốt; lane high-risk không tự tạo thêm vòng xin phép cho công việc đã được user cho phép.

Task state: `draft → ready → implementing → verifying → reviewing → done`; `blocked` giữ reason/nextAction/resumeFrom; evidence stale quay về `implementing` hoặc `verifying`, không giữ done hợp lệ. Docs/handoff là required evidence trước finish, không cần thêm state riêng.

`task.json` là nguồn chuẩn: `schemaVersion`, `id`, `type`, `risk`, `status`, `modules`, `scope`, `acceptanceCriteria`, `dependencies`, `planPath`, `owner`, `nextAction`, `evidenceRefs`, `reviewRefs`. Writes atomic bằng temp + rename; một writer mỗi task, lock có recovery rõ, không xóa lock đang hoạt động theo timeout mù.

Evidence record gồm `taskId`, `runId`, `gateId`, `scope`, `command/args/cwd`, `toolVersions`, `startedAt/finishedAt`, `exitCode`, `status`, `reason`, `logPath/digest`, `headSha|null`, `inputFingerprint`, `gateConfigHash`. Reviewer/tester report chứa cùng fingerprint và kết luận độc lập; lời agent nói “pass” không thay exit code.

Gate status: `passed`, `failed`, `not_applicable`, `blocked`, `stale`. Command thiếu, timeout, crash, không có required tests → failed/blocked. `not_applicable` chỉ hợp lệ do policy + task scope, có reason; không là pass.

Fingerprint conservative cho MVP: HEAD hoặc null + sorted relative paths/content SHA-256 của tracked input, staged blob state và untracked nonignored inputs + config/lock/schema/task requirements. Dùng enumeration Git hỗ trợ unborn repo; không gọi `git diff HEAD` khi chưa có HEAD. Bao gồm trạng thái xóa và đổi tên. Hash nguồn trước và sau gate; có edit giữa run → stale.

Loại khỏi fingerprint output tự sinh (`.git/`, `.gitnexus/`, build outputs, run logs, generated PROGRESS, task status/evidence metadata), nhưng không loại brief/AC/plan/config ảnh hưởng yêu cầu. Danh sách exclusions được review để không giấu source. Gate config/lock/tool version đổi phải verify lại. Có thể hash toàn repo source ở MVP để tránh tối ưu scope sai; chỉ tối ưu khi đo chi phí.

Raw logs/cache local ignored, evidence summary có thể track sau redact. CI artifacts lưu log digest/link/runId; nếu log tham chiếu đã mất thì evidence không còn đủ để finish/resume. Không đưa env dump, token hoặc private learner payload vào logs.

## Gate routing

| Profile | Gate |
|---|---|
| Docs-only | Task schema, links, diff whitespace/scope, review tài liệu; app build not_applicable theo scope |
| Module uninitialized | Manifest/source scan, doctor và bootstrap policy; app tests not_applicable với reason |
| Backend active | Maven wrapper compile/test/verify theo task; integration DB nếu DB/transaction/security đổi |
| Admin active | Lock-based install, defined typecheck/lint/test/build scripts; không đoán package script tồn tại |
| Mobile active | Flutter analyze/test, build target smoke nếu thay build/platform; không yêu cầu iOS build trên Windows |
| Shared API/schema/unknown impact | Tất cả active consumer modules liên quan; contract compatibility và full relevant suites |
| Harness/config | Unit tests runner/fingerprint/routing/state + smoke local/CI |

Module active thiếu manifest/tool/script/test → fail, không tự quay lại uninitialized. Module khai báo uninitialized nhưng có source/manifest mới → blocked yêu cầu bootstrap registration. Task feature nhắm module trống → blocked dependency bootstrap, không “done” nhờ toàn N/A.

`finish` kiểm tra AC coverage, all applicable gates passed, fingerprint hiện tại khớp, independent review không còn blocker, docs/handoff đủ. CLI không thể chứng minh mọi AC nghiệp vụ chỉ qua exit code; mỗi AC phải map test hoặc manual check có người/agent thực hiện và artifact cụ thể. Không auto commit/push.

Một vòng sửa gate tự động tối đa ba lần rồi ghi blocked với root-cause/evidence/next action; không tự xóa tests, giảm gate hay sửa expected output để qua. Tiếp tục khi có cách giải quyết mới hoặc yêu cầu từ user.

## GitNexus và fallback

Pin version đã smoke test, ghi version vào doctor. Tool schema được discover tại runtime. Theo upstream, sử dụng `query`, `context`, `impact`, `detect_changes` nếu available; không coi prompt `detect_impact` là tool. Java/TypeScript/Dart có trong README nhưng parser/native binary phải thử trên máy đích.

Trước index, inspect `analyze --help` của bản pin và flags `--skip-agents-md --skip-skills`; index có thể sinh AGENTS/CLAUDE/skills/hooks, cần kiểm tra generated diff và chặn overwrite. Tránh chạy `setup` sửa global config mặc định; thêm MCP adapter theo project sau khi inspect config. Không gọi flag chưa có trong bản pin.

Index snapshot ghi HEAD + dirty/untracked fingerprint + version/config. Sau edit quan trọng reindex hoặc đánh dấu stale; sự tồn tại `.gitnexus/` không chứng minh server chạy. Index rỗng trên repo chưa có code là expected, không phải bằng chứng hiểu runtime.

Graph không bảo đảm Spring DI/reflection, HTTP giữa Flutter/Next.js và Java, generated code hoặc runtime config. Dùng API_SPEC/schema + targeted search/references để bổ sung. Fallback: rg/files/symbol tools thực sự có → call paths thủ công → impact note → broaden tests khi không chắc. Báo rõ GitNexus unavailable/stale và coverage; không ngầm giả graph đầy đủ.

## Đối chiếu ULP

ULP mô tả Rust CLI, task intake theo risk và evidence/trace/friction. Dấu Việt lấy ý tưởng intake, evidence và cải tiến, chưa lấy SQLite, toàn bộ CLI hay taxonomy lớn. PowerShell/JSON giảm dependency và dễ review cho repo đang trống. Port Rust chỉ hợp lý khi xuất hiện nhu cầu nhiều writer/concurrency hoặc báo cáo vượt khả năng file; phải đánh giá license/source trước. Nguồn: [ULP Harness](https://github.com/dikhamchua/ulp/blob/main/docs/HARNESS.md), [Feature Intake](https://github.com/dikhamchua/ulp/blob/main/docs/FEATURE_INTAKE.md), [GitNexus](https://github.com/abhigyanpatwari/GitNexus).
