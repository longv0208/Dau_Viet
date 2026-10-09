# Giai đoạn 2: Workflow, GitNexus và verification

Priority P2 · Pending · 20h · Phụ thuộc: giai đoạn 1.

## Mục tiêu

Thực hiện bước 4–6: biến workflow thành entrypoint chạy được, kết nối code intelligence khi có code, thực thi gate thống nhất local/CI. [Contract](harness-contract.md), [nghiên cứu](research/source-check.md).

## File dự kiến

Tạo `scripts/harness/harness.ps1`, `scripts/harness/modules/{State,Runner,Fingerprint,GitNexus}.psm1`, `.harness/schemas/evidence.schema.json`, `tests/harness/`, `.github/workflows/harness.yml`; cập nhật config/AGENTS/workflow/README. Đường dẫn tương đối với `C:/Users/Admin/Desktop/4user/DauViet/`. Không sửa ứng dụng trống thành skeleton trong phase này; bootstrap ứng dụng là task riêng.

## TODO thực hiện

- [ ] H1. Doctor kiểm tra Git/unborn HEAD, PowerShell, config schema; check Java/Node/Flutter chỉ theo applicable module; phân biệt installed, configured và usable.
- [ ] H2. Implement task state validation, dependency checks, atomic writes/lock và dry-run preview selected gates.
- [ ] H3. Implement runner bằng executable + argument array + cwd allowlist; capture exit/log/duration, timeout/cancel, nonzero propagation và redact.
- [ ] H4. Fingerprint trước/sau theo contract; test tracked, staged, deleted, renamed, untracked, unborn HEAD và filenames có spaces/Unicode.
- [ ] H5. Scope selector deterministic từ config và changed paths. Rename/delete dùng cả old/new path; shared contracts/harness/config hoặc không chắc scope chạy broader suite. GitNexus chỉ bổ sung, không được cắt gate bắt buộc.
- [ ] H6. GitNexus version/license/runtime review; pin version đã thử. Kiểm tra `--help`, generated side effects; fixture Java/TS/Dart kiểm tra query/context/call-reference và fallback khi parser không chạy.
- [ ] H7. Tạo MCP project adapter tối thiểu; kiểm tra tool schema/live connection. Giữ rg fallback khi thiếu GitNexus/Serena; không hard dependency vào tên MCP không tồn tại.
- [ ] H8. Module gate config theo contract. Backend đề xuất wrapper `test`/`verify` sau bootstrap; admin script names phải lấy từ package.json; Flutter platform checks đúng OS. CI không install mọi stack khi module chưa active.
- [ ] H9. CI chạy runner cùng config, least-privilege read-only token, timeouts, logs/artifacts. PR nội bộ/untrusted không truy cập production secrets; không tự publish/deploy.
- [ ] H10. Tester chạy matrix bên dưới; implementer sửa fail; reviewer kiểm tra runner và guard không bị bypass. Docs-manager cập nhật commands đã thực sự chạy được.

## Test matrix bắt buộc

| Tình huống | Kết quả mong đợi |
|---|---|
| Repo docs-only/unborn HEAD | Doctor chạy, fingerprint hợp lệ, app gates N/A rõ lý do |
| Feature nhắm module trống | Blocked do thiếu bootstrap dependency |
| Manifest xuất hiện dưới uninitialized | Không bypass gate; cần đăng ký bootstrap |
| Active module thiếu wrapper/script/runtime | Blocked/failed, không N/A |
| Build/test nonzero, zero required tests, timeout | Verification không pass |
| Edit code giữa hoặc sau test | Evidence stale; finish bị chặn |
| Edit chỉ run log/status | Không làm stale vô hạn |
| GitNexus lỗi/stale/không có tool | Impact note fallback; không báo graph verified |
| Config/gate/lock/AC thay đổi | Evidence invalidated |
| CI và local cùng revision/config | Chọn cùng logical gates; khác OS được giải thích |
| Thiếu authorization regression cho auth task | AC coverage chưa đủ, không finish |

## Acceptance

Harness unit/fixture tests pass; tests thực sự đánh vào failure modes của runner. Một dry-run docs task chạy được local; CI chỉ coi thành công sau actual run nếu có remote/access. Nếu chưa có remote thì ghi CI chưa được xác nhận, không tuyên bố xanh.

Test gates module sẽ kích hoạt trong bootstrap task khi source tồn tại. Chưa có ứng dụng thì không công bố JUnit/Flutter/admin build đã pass. Có thể dùng fixtures để kiểm tra adapters nhưng phải đánh dấu fixture, không gắn kết quả vào ứng dụng thật.

## Rủi ro và recovery

GitNexus native dependency Windows: fixture smoke rồi pin; lỗi dùng fallback. Runner exit handling PowerShell: assert explicit exit code bằng test. Package hooks hoặc generated agent files: chạy phạm vi fixture trước và review diff. CI integration test DB dùng container tạm với data giả, không production DB.

Next: giai đoạn 3 diễn tập resume và multi-agent với evidence thật.
