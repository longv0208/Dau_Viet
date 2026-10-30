# Plan: Issue #45 — E2E Flows (Admin to Learner) & UI/UX + Pedagogical Audit

## 1. Context & Findings from Initial Audit

### Flow 1–3 (Admin Web `dau-viet-admin` & Backend `dau-viet-backend`)
1. **Pagination Selection Bug on `/map-locations` (`map-locations-page.tsx`):**
   - `selectedLocation` is looked up only in the current 8-item page (`locations.find(l => l.id === selectedId)`). When creating a new location (or navigating via `?highlight=<id>`) in a database with $\ge 8$ locations where the new row sorts onto another page, `selectedLocation` becomes `null`, causing `LocationDetailEditor` to treat it as `isNew = true` and disable Tabs 2 (`Sự kiện`), 3 (`Mở khóa`), and 4 (`Media`).
   - **Fix:** Fetch individual location details (`GET /api/v1/admin/map-locations/${selectedId}`) or cache the newly created location when `selectedId` is not present in the current page slice.
2. **Dual Map Location Views Out of Sync (`AdminMapLocationService.java`, `map-locations-section.tsx`):**
   - Standalone locations linked to an event via `map_location_events` (`PUT /admin/map-locations/{id}/events`) do not appear in `/events/[id]?tab=info` (`GET /admin/events/{eventId}/map-locations`), which only queries `map_locations.event_id = :eventId`.
   - **Fix:** Sync `map_locations.event_id` with the `PRIMARY` (or first linked) event in `AdminMapLocationService.replaceEvents`, include `map_location_events` in `MapLocationRepository` event lookup, and add a direct navigation banner/button in `MapLocationsSection` (`/events/[id]?tab=info`) to open `/map-locations` for full V2 configuration (`PUBLIC_PREVIEW`/`UNLOCKED_ONLY` media & `ANY`/`ALL` unlock rules).
3. **Misleading `ANY (0 bài)` Default on New Standalone Map Location (`map-locations-page.tsx`):**
   - New locations initialize `unlockRuleMode` to `"ANY"` with `0` lessons, showing a lock badge `ANY (0 bài)` in Admin even though Backend treats 0 lessons as `NONE` (unlocked).
   - **Fix:** Default `unlockRuleMode` to `"NONE"` until lessons are selected, display `"Mở sẵn (0 bài)"` when `unlockLessons.length === 0`, and warn in Tab 3 if `ANY`/`ALL` is chosen without selecting any lesson.
4. **Publish Dependency Guidance & Policy Publish Validation UX (`event-overview-tab.tsx`, `policy-editor.tsx`, `policy-publish-dialog.tsx`):**
   - Backend requires Historical Event to be `PUBLISHED` before Lessons, Map Locations, or Event Completion Policies can be published.
   - `PolicyPublishDialog` does not render `validation?.errors` or disable its confirm button when `validation?.valid === false`. `PolicyEditor` enables "Kiểm tra" before a new policy draft is saved (resulting in a silent no-op).
   - **Fix:** Update the 4-step workflow guide in `EventOverviewTab` and `PublishReadinessCard` to highlight publishing the Event shell before publishing Lessons/Policies; render `validation.errors` and guard the confirm button in `PolicyPublishDialog`; disable "Kiểm tra" until the draft policy is saved.
5. **Evidence Creation Return Context & 4 Trace Groups Guidance (`use-evidence-submit.ts`, `evidence-editor-page.tsx`, `evidence-basic-fields.tsx`):**
   - Creating an evidence from `/events/[id]?tab=hoc-lieu` drops `?return=...` on redirect to `/evidence/[id]`.
   - **Fix:** Preserve `?return=...` in `useEvidenceSubmit`, add a prominent "Quay lại Sự kiện" action on `EvidenceEditorPage` (especially after clicking `Phê duyệt`), and display a helper mapping `evidenceType` to the 4 Learner Investigation Trace Groups (*Hiện vật, Địa hình/Bản đồ, Nhân vật/Lời kể, Cổ thư/Văn bản*).
6. **Lesson Wizard & Builder Authoring Ergonomics (`lesson-wizard.tsx`, `use-builder.ts`, `draft-local-validator.ts`, `evidence-ref-picker.tsx`, `dossier-picker-dialog.tsx`, `event-panel.tsx`):**
   - Redirect `LessonWizard` to `/lessons/${res.id}/builder` (with return context) or offer immediate builder navigation so authors go straight into stage/activity editing.
   - Default `required: true` and prefill sensible default Vietnamese feedback messages in `makeActivity` (`use-builder.ts`) so upstream `EVIDENCE_SELECT` activities automatically appear in downstream `VERIFICATION`/`CER_CHOICE` dropdowns and authors aren't blocked by hidden empty feedback fields when saving drafts.
   - Allow saving work-in-progress drafts in `BuilderPage` even when publish-only feedback strings are incomplete, while keeping strict validation for "Kiểm tra" / Publish; align `validateCerChoice` with backend rules ($\ge 2$ claims/reasonings, non-empty `combo.evidenceIds`).
   - Add link to `/dossiers` in `DossierPickerDialog` when no published dossiers exist, and clarify `NO_PUBLISHED_LESSON` in ` learning-path` `EventPanel` to `"Chưa gắn bài học vào lộ trình"`.

### Flow 4 (Mobile/Web Learner `dau-viet-mobile` & Backend `dau-viet-backend`)
1. **Dashboard CTAs Navigating to `/map` Instead of `/journey` (`learner_dashboard_screen.dart`):**
   - Update "Bài học hôm nay", "Xem tất cả →", "Xem hành trình →", "Bài học (Khám phá lịch sử)", and Quest 1 CTAs on `LearnerDashboardScreen` to navigate to `/journey` (or `/journey/${target.period!.code}`).
2. **Result Screen & Unlocked Location Banner Navigation (`unlocked_location_banner.dart`, `lesson_result_screen.dart`):**
   - Update `UnlockedLocationBanner` "Xem địa điểm" to navigate to `/map?locationId=$locId` so the learner lands on the Heritage Map (`/map`) with `LocationProfileSheet` automatically opened for the unlocked location.
   - Update `LessonResultScreen` "TIẾP TỤC HỌC" to navigate back to `/campaign/$eventId` (when resolved from attempt/lesson metadata) or `/journey` so the learner immediately sees Lesson A completed and Lesson B unlocked (`Sẵn sàng học`), and add a button to view `/collection` when evidences were collected.
3. **Real-Time Provider Invalidation & Direct Lesson Tap (`lesson_player_screen.dart`, `period_journey_screen.dart`):**
   - In `LessonPlayerScreen._complete()`, invalidate `mapLocationDetailProvider`, `eventProgressProvider` (whole family), `collectionListProvider`, `collectionTypesProvider`, `collectionDetailProvider`, `dossierListProvider`, and `dossierDetailProvider` alongside `learningPathProvider`.
   - Pass `onLessonTap` to `HistoricalEventCard` in `PeriodJourneyScreen` so tapping an unlocked lesson row opens `/learning/lesson/${lesson.lessonId}`, and display both event and lesson progress counts (`$completedEvents/$requiredEvents sự kiện • $completedLessons/$requiredLessons bài học`) in `_buildPeriodHeaderCard`.
4. **Pedagogical Continuity & 4-Stage Activity Fixes (`LearnerProjectionService.java`, `ReasoningHandlers.java`, `evidence_select_renderer.dart`, `hypothesis_renderer.dart`, `verification_renderer.dart`, `cer_choice_renderer.dart`, `cer_renderer.dart`, `activity_renderer.dart`, `attempt_dtos.dart`, `lesson_player_screen.dart`):**
   - **Evidence Continuity:** Fall back to scanning `priorOutputs` for `selectedEvidenceIds` in `HypothesisRenderer`, `VerificationRenderer`, `CerChoiceRenderer`, `CerRenderer`, and backend `VerificationHandler.evidenceGiven()` whenever `priorEvidenceSource` / `evidenceSource` is not explicitly set.
   - **Graded `EVIDENCE_SELECT` Clarity:** Project `expectedCount` (size of `acceptedEvidenceIds` when `graded == true`) in `LearnerProjectionService` so `EvidenceSelectRenderer` displays the exact required count (e.g. `Chọn đủ 3 dấu vết`) instead of turning green prematurely at `minRequired = 1`; map `correctCount` in `EvaluationDto` for `InlineGradingHint`.
   - **`VERIFICATION` Interactivity & Anti-Soft-Lock:** Pass `lastEvaluation` to `VerificationRenderer` in `ActivityRenderer`, require choosing a verdict (`SUPPORTED` / `PARTIAL` / `CONTRADICTED`) before submitting, and prevent infinite in-place soft-locks in `VerificationHandler` when no revise target (`onPartial`/`onContradicted`) is configured.
   - **`StepProgressBar` Accuracy:** Bind `StepProgressBar` in `LessonPlayerScreen` to `cur.progress.totalRequired` and `cur.progress.completedRequired` instead of hardcoded `6`.

## 2. Execution Phases
- **Phase 1:** Backend & Admin Web fixes (Flows 1–3 bugs & UX enhancements).
- **Phase 2:** Mobile Learner fixes (Flow 4 navigation, state invalidation, 4-stage pedagogical continuity & renderers).
- **Phase 3:** Live End-to-End Execution of Flows 1, 2, 3, and 4 against local Backend + Postgres + Admin + Mobile Web, plus unit/widget/integration tests and independent code review.
- **Phase 4 (Remaining Bugs Remediation):** See [`phase-04-remaining-bugs-remediation-plan.md`](./phase-04-remaining-bugs-remediation-plan.md) for the detailed plan covering the 6 remaining bugs discovered during E2E & full-suite verification (persisting unlocked locations/dossiers in `GET /attempts/{id}/result`, `UnlockedLocationsCard` loading state + MSW handler, `UNLOCKED_ONLY` media badge in `LocationProfileSheet`, 12 TypeScript errors in `dau-viet-admin`, 9 `flutter analyze` warnings + Web GIS guard in `dau-viet-mobile`, and Learning Path audit warning jump-links).
