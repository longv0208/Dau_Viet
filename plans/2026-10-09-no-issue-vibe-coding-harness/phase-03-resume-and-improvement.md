# Giai đoạn 3: Resume, phối hợp agent và cải tiến

Priority P2 · Pending · 12h · Phụ thuộc: giai đoạn 2.

## Mục tiêu

Thực hiện bước 7–8. Phiên mới biết việc tiếp theo, bằng chứng nào còn hợp lệ và khi nào phải kiểm tra lại. [Contract](harness-contract.md).

## File dự kiến

Tạo `.harness/templates/handoff.md`, `.harness/templates/role-report.md`, `docs/HARNESS_RUNBOOK.md`; thêm resume/finish/progress rendering trong `scripts/harness/`; cập nhật tests, AGENTS, workflow, DECISIONS. Task artifacts nằm `tasks/<id>/`; raw runs nằm `.harness/runs/` ignored. Tất cả đường dẫn tương đối với `C:/Users/Admin/Desktop/4user/DauViet/`.

## TODO thực hiện

- [ ] R1. `resume` kiểm tra task/dependencies, branch/worktree identity, HEAD/fingerprint/gate config và evidence còn tồn tại; trả next action, stale reasons, impacted gates.
- [ ] R2. Handoff gồm intent, files, assumptions, invariants, completed/pending AC, verification refs, unresolved blockers và một next command cụ thể. Không copy transcript hoặc secrets.
- [ ] R3. `finish` chỉ cho done khi gates, review, AC mapping và docs report hợp lệ; raw evidence không sửa được thành pass qua text report.
- [ ] R4. Tạo PROGRESS view từ task JSON; dependency cycle/missing task là lỗi. Không đọc PROGRESS như source of truth.
- [ ] R5. Planner-researcher lập plan; implementer ownership rõ; tester độc lập chạy tests; code-reviewer so với plan; docs-manager cập nhật docs khi hành vi/contract đổi hoặc ghi N/A với reason. Mapping role thực tế được ghi lại.
- [ ] R6. Mặc định tuần tự; chỉ parallel khi file ownership độc lập. Khi cần worktree, state/evidence gắn đúng worktree; parent hợp nhất thay đổi rồi chạy integration checks lại. Không tin tests từ workspace trước merge.
- [ ] R7. Friction note chỉ tạo khi có incident: symptom, root cause, fix, prevention, proof. Lỗi lặp → test/guard trước, rule ngắn sau; không auto thêm hàng chục rules mỗi task.
- [ ] R8. Pilot docs-only + harness fixtures + bootstrap module đầu tiên được user chọn; application bootstrap là task riêng, không kéo toàn bộ MVP vào scope harness.
- [ ] R9. Mở fresh session, resume pilot; cố tình làm stale evidence và mất log, xác nhận finish bị chặn; simulate agent thiếu/crash, báo incomplete role thay vì giả report.
- [ ] R10. Đo pilot: thời gian tìm context, số stale pass bị chặn, lệnh verification tái chạy được và số rule hữu ích. Chỉ thêm tự động hóa khi có friction đo được.

## Ví dụ dùng hằng ngày: publish lesson version

Yêu cầu: “Admin publish lesson; learner đang học giữ nguyên version cũ.” Planner phân loại high-risk vì auth/transaction/versioning, đọc CODING_RULES + DATABASE_DESIGN + API_SPEC + LEARNING_ENGINE, tạo task với AC:

1. Chỉ role Admin publish; learner bị forbidden.
2. Published snapshot immutable; edit draft rồi publish tạo version mới.
3. Attempt hiện hữu vẫn pin version cũ; payload không lộ private answer keys.
4. Invalid activity config/evidence refs bị chặn trước publish.

Agent query/context/impact với GitNexus khi usable; bổ sung HTTP/schema mapping thủ công. Implementer sửa scope đã chốt. Tester chạy domain/integration/authorization và API consumer tests liên quan. Reviewer kiểm tra transaction/version invariant và diff. Docs-manager cập nhật contract. Harness finish đối chiếu AC và fingerprint; báo sẵn sàng commit, chờ user yêu cầu Git action. Nếu backend chưa bootstrap, task blocked vào bootstrap dependency thay vì tạo “pass” rỗng.

## Acceptance và diễn tập

- Fresh agent đọc task/handoff, xác định đúng trạng thái mà không cần lịch sử chat.
- Fix sau review làm review và affected test evidence stale; reviewer kiểm tra lại diff mới.
- Task done có AC → evidence mapping; docs-only và feature task không dùng chung N/A để bypass.
- Rollback harness: ngừng entrypoint, dùng checklist thủ công với cùng task/docs; không mất source/task data. Không tự rollback code người dùng.
- Runbook có setup, update pin, recover lock, resume, reindex/fallback, CI triage và quyền commit/push.

## Phụ thuộc và câu hỏi còn mở

- Nếu agent runtime không hỗ trợ subagents, phải báo hạn chế và ghi role chưa hoàn tất; không claim independent review. Có thể chuyển runtime hoặc người review theo thỏa thuận.
- Bootstrap backend là lựa chọn mặc định đề xuất; actual build evidence chỉ có sau task bootstrap được thực hiện.
