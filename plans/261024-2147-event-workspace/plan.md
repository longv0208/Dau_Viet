---
title: "Event Workspace — quản lý nội dung theo sự kiện"
description: "Biến /events/[id] thành hub có tabs (Tổng quan / Bài học / Học liệu / Thông tin & địa điểm); mọi nội dung con tạo trong context sự kiện."
status: pending
priority: P1
effort: 14h
branch: main
tags: [admin, ux, event, workspace, navigation]
created: 2026-10-24
---

# Event Workspace — Plan Overview

## Mục tiêu

Thiết kế lại admin UX theo flow: **SỰ KIỆN → HỌC LIỆU CHUNG → NHIỀU BÀI HỌC → XUẤT BẢN TỪNG BÀI**. `/events/[id]` trở thành Event Workspace gồm 4 tab:

1. **Tổng quan** — thông tin nhanh, stats, lối điều hướng.
2. **Bài học** — danh sách lesson trong event, tạo mới gán sẵn eventId, link edit/preview/publish/versions.
3. **Học liệu** — Evidence + Media + Animations HTML của event.
4. **Thông tin & địa điểm** — EventForm + MapLocationsSection (form sự kiện + bản đồ).

Backend đã hỗ trợ đầy đủ `eventId` filter → **KHÔNG đổi backend, KHÔNG migration**.

## Quyết định kiến trúc

- **Routing**: tabs-in-page, `/events/[id]?tab=<slug>` — không tạo nested routes. Lý do: giữ `/events/[id]` làm hub duy nhất, deep link tới tab, giữ nguyên breadcrumb, không cần layout mới; KISS.
- **Return context**: dùng `?return=<path>` đã validate (chỉ cho phép path nội bộ bắt đầu `/events/<uuid>` hoặc `/lessons/<uuid>`, `/evidence/<uuid>`, `/animations/<uuid>`), KHÔNG redirect ra ngoài.
- **Backward compat**: giữ nguyên routes `/lessons/[id]`, `/evidence/[id]`, `/animations/[id]/edit`; chỉ bổ sung `?return=` quanh các link "Sửa" từ workspace.
- **Ordering lesson**: bỏ qua — backend chưa có `displayOrder`, không cần migration; sắp xếp bằng `updatedAt desc` (đã sẵn).

## Phases

| Phase | Tên | File | Ước lượng |
|---|---|---|---|
| 01 | Event Workspace Shell (tabs layout, stats, breadcrumb) | [phase-01-event-workspace-shell.md](./phase-01-event-workspace-shell.md) | 3h |
| 02 | Tab Bài học | [phase-02-lessons-tab.md](./phase-02-lessons-tab.md) | 2h |
| 03 | Tab Học liệu (Evidence + Media + Animations) | [phase-03-hoc-lieu-tab.md](./phase-03-hoc-lieu-tab.md) | 3h |
| 04 | Tab Thông tin & Địa điểm | [phase-04-info-tab.md](./phase-04-info-tab.md) | 1h |
| 05 | Navigation (sidebar, breadcrumbs, return-context) | [phase-05-navigation.md](./phase-05-navigation.md) | 2h |
| 06 | Empty states + guidance | [phase-06-guidance.md](./phase-06-guidance.md) | 1h |
| 07 | Vitest coverage | [phase-07-tests.md](./phase-07-tests.md) | 2h |

## Phạm vi ngoài (out of scope)

- Không đổi learning engine / renderers / WebView / PixiJS / HTML animation internals.
- Không Playwright, không backend test, không migration.
- Không xóa trang/dữ liệu cũ (routes `/lessons`, `/evidence`, `/animations` giữ nguyên).
- Assets + Templates giữ shared — không scope theo event.

## Dependencies

- Backend `eventId` filter đã sẵn trên `AdminLessonController.list`, `AdminEvidenceController.list`, `AdminAnimationSceneController.list` + `importHtml`.
- `qk` query keys đã sẵn (chỉ cần thêm `eventId` vào `animationScenes.list`).
- Tất cả components tái sử dụng: `EventForm`, `MapLocationsSection`, `LessonsTable`, `EvidenceTable`, `AssetsLibrary`, `AnimationLibrary`, `HtmlImportDropzone`.

## Success criteria

- `/events/[id]` hiển thị tabs; click tab đổi `?tab=` URL; refresh vẫn giữ tab.
- Tạo lesson/evidence/animation từ workspace tự gán eventId; redirect về đúng tab.
- Edit lesson/evidence/animation xong quay về `/events/[id]?tab=...` tương ứng.
- Sidebar gọn: Sự kiện + Bài học + Thư viện media + Hoạt họa (hoặc giữ nguyên nếu quyết định deferred).
- Vitest pass ≥85% các file mới/sửa.
