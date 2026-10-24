# Phase 06 — Empty States & Guidance

## Context links
- [phase-01-event-workspace-shell.md](./phase-01-event-workspace-shell.md)
- [phase-02-lessons-tab.md](./phase-02-lessons-tab.md)
- [phase-03-hoc-lieu-tab.md](./phase-03-hoc-lieu-tab.md)
- `src/components/empty-state.tsx`

## Overview
- **Priority**: P2
- **Status**: pending
- **Effort**: 1h
- Tin nhắn rỗng + hướng dẫn bước tiếp theo trong từng tab của Event Workspace — giúp admin biết đang ở đâu trong quy trình.

## Key insights
- Workflow: Sự kiện → Học liệu → Bài học → Xuất bản từng bài. Admin mới vào event rỗng cần biết bước đầu tiên là gì.
- `EmptyState` component đã có sẵn (title + description + optional action slot — verify props).
- Cần tin nhắn khác nhau cho: event vừa tạo (chưa gì) / có học liệu nhưng chưa có bài học / có bài học nhưng chưa xuất bản.

## Requirements
- **Tab Tổng quan** khi event có 0 bài học + 0 bằng chứng + 0 hoạt họa:
  - "Bắt đầu bằng việc thêm học liệu (bằng chứng, media, hoạt họa) → soạn bài học → xuất bản" + 3 CTA link tới các tab tương ứng.
- **Tab Bài học** khi 0 lesson:
  - "Chưa có bài học nào cho sự kiện này" + description gợi ý "Tạo bài học đầu tiên — có thể dùng mẫu bài học có sẵn hoặc soạn mới" + CTA "Tạo bài học" → `/lessons/new?event={id}`.
- **Tab Học liệu** khi 0 evidence + 0 animations:
  - Mỗi section có empty state riêng.
  - Evidence: "Bằng chứng giúp nội dung bài học có cơ sở lịch sử — thêm bằng chứng đầu tiên" + CTA.
  - Animations: "Hoạt họa HTML là các tệp tự chứa, tối đa 15MB — kéo thả để tải lên" + dropzone.
- **Tab Thông tin**: không cần empty state (form + locations luôn hiển thị).
- Quick guidance text trong Overview tab hiển thị checklist trạng thái:
  - "[x] Đã có bằng chứng (5)" / "[ ] Chưa có bài học — tạo ngay" → checklist theo số liệu stats.

## Architecture
- `EmptyState` reuse — check props (`title`, `description`, `action?`).
- `EventOverviewTab` — logic conditional render: `if (lessonsCount === 0 && evidencesCount === 0 && scenesCount === 0)` → hero empty; else stats + checklist.
- `EventLessonsTab` — khi `LessonsTable` empty → override `emptyTitle`/`emptyDescription` (đã hỗ trợ trong `DataTable`) + CTA button.
- `EventAssetsTab` — sections truyền `emptyTitle`/`emptyDescription` cụ thể cho `EvidenceTable`, `AnimationLibrary`.

## Related code files

**Modify**
- `src/features/events/workspace/event-overview-tab.tsx` — thêm checklist + hero empty state.
- `src/features/events/workspace/event-lessons-tab.tsx` — empty props + CTA.
- `src/features/events/workspace/event-assets-tab.tsx` — empty props per section.
- `src/features/lessons/lessons-table.tsx` — đã có `emptyTitle`/`emptyDescription` props? (check `DataTable` component — nếu chưa thì thêm optional props).

**Create**
- `src/features/events/workspace/workspace-checklist.tsx` — checklist điều kiện (có bằng chứng chưa, có bài học chưa, đã xuất bản chưa).

**Delete**
- (none)

## Implementation steps
1. Verify `DataTable` + `EmptyState` props — nếu `EmptyState` không có `action` slot → thêm `action?: ReactNode` prop (không break existing).
2. Tạo `WorkspaceChecklist({ event, stats })` — render list các mục tiêu với check/uncheck icon + link tới tab tương ứng:
   - "Thêm ít nhất 1 bằng chứng" → `/events/{id}?tab=hoc-lieu`
   - "Tạo ít nhất 1 bài học" → `/events/{id}?tab=lessons`
   - "Đăng ít nhất 1 địa điểm trên bản đồ" → `/events/{id}?tab=info`
   - "Xuất bản sự kiện" → action button (gọi publish endpoint hiện có)
3. `EventOverviewTab`: khi stats total = 0 → hero `EmptyState` với 3 CTAs; ngược lại → stats cards + `WorkspaceChecklist`.
4. `EventLessonsTab`: truyền `emptyTitle="Chưa có bài học nào"` + `emptyDescription` + action button.
5. `EventAssetsTab`: tương tự cho từng section.

## Todo list
- [ ] `EmptyState` check/extend `action` slot
- [ ] `WorkspaceChecklist` component
- [ ] `EventOverviewTab` conditional hero/checklist
- [ ] `EventLessonsTab` + `EventAssetsTab` empty props
- [ ] Manual verify all empty states

## Success criteria
- Event mới tạo → Overview tab hiển thị hero empty + checklist 4 mục.
- Tab Bài học rỗng → message + CTA rõ ràng.
- Tab Học liệu → mỗi section có empty state riêng, không lẫn nhau.
- Checklist item click → navigate đúng tab.

## Risk assessment
- **R-01**: `EmptyState` không có action slot → cần modify; check hiện tại nó dùng ở đâu (evidence-table empty) → backward compat.
- **R-02**: Checklist "Đã xuất bản sự kiện" gọi API publish → cần handle success/error inline. Reuse `EventPublishButton`.
- **R-03**: Checklist yêu cầu `mapLocations` count — query `qk.mapLocations.list(eventId)` đã sẵn → reuse.

## Security considerations
- Checklist chỉ render links nội bộ — không cần sanitize.
- Publish button có sẵn optimistic locking + permissions — giữ nguyên.

## Next steps
- Phase 07 — vitest coverage cho checklist + empty states.
