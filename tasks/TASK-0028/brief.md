# TASK-0028: Issue #35 — Chuỗi 4 giai đoạn chấm tự động

## Goal
Chuẩn hóa chuỗi Khám phá 4 Dấu Vết → Đặt giả thuyết → Kiểm chứng → Dựng lại sự kiện → Kết luận CER trên backend + admin + mobile; 100% activity chấm tự động server-side; không lộ đáp án.

## AC
Xem task.json AC-1..AC-5 (mirror issue #35).

## Plan
plans/261029-issue-35-4-stage-flow/plan.md

## Verification mapping
| AC | Check | Expected | Evidence |
|---|---|---|---|
| AC-1 | `mvn test` handler tests + LearningFlow2IT | all green | test log |
| AC-2 | unit test DraftSchema + admin validator tests | combos allowed | test log |
| AC-3 | ScoredHandlersTest PARTIAL/exhausted branches | pass | test log |
| AC-4 | HiddenKeyLeakIT draft đủ 5 loại activity | pass | test log |
| AC-5 | V51 migration + lesson content IT + flutter test | pass | test log |

## Handoff
Cập nhật cuối task.
