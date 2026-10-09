---
title: "Hệ thống Vibe Coding với GitNexus và harness cho Dấu Việt"
description: "Thiết lập context, task, code intelligence, verification và resume có bằng chứng cho ba module Dấu Việt."
status: pending
priority: P2
effort: 40h
branch: master
tags: [infra, docs, backend, frontend]
created: 2026-10-09
---

# Kế hoạch Vibe Coding cho Dấu Việt

## Kết quả mong muốn

Một developer đưa yêu cầu tự nhiên; agent chuyển thành task có acceptance criteria, đọc context và code liên quan, lập kế hoạch, triển khai, kiểm thử, review và lưu handoff. Phiên sau tiếp tục từ trạng thái đã xác minh. GitNexus hỗ trợ hiểu code; harness điều phối quy trình và kiểm tra bằng chứng.

Đây là **kế hoạch**, chưa cài công cụ hoặc tạo implementation. ULP có Harness CLI riêng bằng Rust; kế hoạch này đề xuất harness nhẹ của Dấu Việt, không tuyên bố tương thích CLI ULP. [Nghiên cứu nguồn](research/source-check.md).

## Hiện trạng đã kiểm tra

- Git branch `master` chưa có commit (`HEAD=null`); ba thư mục `dau-viet-backend/`, `dau-viet-admin/`, `dau-viet-mobile/` hiện trống.
- Có sáu tài liệu trong `docs/`, chưa có README/AGENTS trên đĩa. `docs/` đang untracked; không tự stage/commit.
- Stack trong `TECH_STACK.md`: Java 21/Spring Boot 3.x/Maven/PostgreSQL, Next.js/TypeScript, Flutter/Dart. Phiên bản cụ thể chưa được pin và kiểm thử.
- `docs/development-rules.md` không tồn tại; dùng `docs/CODING_RULES.md` và chỉ dẫn AGENTS do user cung cấp làm baseline.
- Chọn Claude Code làm agent chính ban đầu theo phiên hiện tại; adapter agent khác chỉ là lớp chỉ dẫn mỏng.

## Thiết kế chốt cho kế hoạch

| Thành phần | Quyết định |
|---|---|
| Context | Tái dùng docs hiện có; AGENTS ngắn đóng vai trò bản đồ |
| Task | Một JSON trạng thái chuẩn + brief/plan Markdown; PROGRESS sinh từ task |
| Harness | PowerShell 7 + JSON, chạy local và CI; không xây agent platform/web dashboard |
| Code intelligence | GitNexus khi có source hỗ trợ; tìm kiếm trực tiếp và contract review là fallback |
| Verification | Gate deterministic, bằng chứng gắn commit và fingerprint workspace; lỗi/mất tool không được tính pass |
| Multi-agent | Planner → implementer → tester → reviewer → docs-manager; tuần tự mặc định |
| Git | Khi tạo nhánh trong Claude Code dùng `<scope>` phù hợp host; user yêu cầu tên cụ thể được ưu tiên. Commit/push/merge chỉ khi user yêu cầu |

## Ba giai đoạn và tám bước

| Giai đoạn | Bước | Kết quả | Phụ thuộc | Effort |
|---|---|---|---|---|
| [1. Nền tảng](phase-01-context-and-tasks.md) | 1 agent, 2 context, 3 task | Context map, task schema/template, policy bootstrap | Không | 8h |
| [2. Workflow có kiểm chứng](phase-02-harness-and-gitnexus.md) | 4 workflow, 5 GitNexus, 6 verification | Harness local, adapters, gates, CI | Giai đoạn 1 | 20h |
| [3. Resume và cải tiến](phase-03-resume-and-improvement.md) | 7 trạng thái, 8 feedback | Resume an toàn, điều phối agent, pilot và runbook | Giai đoạn 2 | 12h |

Ước lượng lập kế hoạch 32–52h, mốc tham chiếu 40h cho một developer với AI; chưa bao gồm xây chức năng Dấu Việt hoặc bootstrap toàn bộ ba ứng dụng. Cần hiệu chỉnh sau pilot. Dừng sau giai đoạn 1 vẫn sử dụng được quy trình thủ công.

## Definition of Done toàn hệ thống

- [ ] Task có scope, constraints, acceptance, dependency và evidence; chuyển trạng thái không vượt gate.
- [ ] Dự án trống hiển thị `not_applicable` có lý do, không giả vờ đã build/test.
- [ ] Sau bootstrap từng module, gate tương ứng trở thành bắt buộc; không có test là lỗi của task feature.
- [ ] Sửa code sau khi test/review làm evidence stale; phiên mới không được tái dùng pass cũ.
- [ ] GitNexus lỗi/stale hoặc không hỗ trợ ngôn ngữ vẫn có fallback có báo cáo; không mất khả năng làm task.
- [ ] Local và CI dùng cùng gate config; full applicable suite khi không xác định chắc phạm vi.
- [ ] Tester/reviewer/docs báo cáo độc lập, failure quay lại implementer; không tự commit/push.
- [ ] Pilot docs-only, fixture harness và một bootstrap task được diễn tập; fresh session resume đúng next action.

## Tài liệu thực thi

- [Contract harness và trạng thái](harness-contract.md).
- Nguồn nghiệp vụ: [overview](../../docs/PROJECT_OVERVIEW.md), [architecture](../../docs/TECH_STACK.md), [rules](../../docs/CODING_RULES.md), [API](../../docs/API_SPEC.md), [database](../../docs/DATABASE_DESIGN.md), [engine](../../docs/LEARNING_ENGINE_DESIGN.md).
- Folder kế hoạch được chỉ định cho task này; `no-issue` nghĩa là chưa có issue ID, không tạo GitHub issue tự động.

## Câu hỏi còn mở

1. Khi bắt đầu bootstrap, chọn module đầu tiên: mặc định backend để xác lập contract; việc xây tính năng là task riêng.
2. Nếu muốn port nguyên CLI Rust của ULP: cần scope riêng để review source, license và compatibility; không cần cho MVP này.
