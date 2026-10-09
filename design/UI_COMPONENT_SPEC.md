# DẤU VIỆT — UI COMPONENT SPEC v2.0

**Status:** Proposed | **Mobile:** Flutter | **Admin:** Next.js | **Style:** Modern UI + Vietnamese Historical Illustration  
Tài liệu định nghĩa component library và interaction contract, **không** thay thế Figma pixel-perfect hoặc API spec.

## 1. Nguyên tắc thiết kế component

1. **UI native và accessible:** text, answer, score, marker, interaction luôn là widget/DOM thay vì chữ nhúng vào tranh.
2. **Data-driven:** stage là bước tư duy; activity là thao tác; screen là renderer. Không dùng tên sự kiện để chọn component.
3. **Visual hierarchy:** illustration là hero/background; phần học ưu tiên readability.
4. **States đầy đủ:** default, loading, empty, locked, active, selected, correct/incorrect, disabled, error, success, offline/retry khi thích hợp.
5. **Mobile first:** tap alternative cho drag/drop; responsive, screen reader và reduced motion.

## 2. Design tokens (đề xuất, cần phê duyệt)

- Color: dùng semantic tokens từ `ART_DIRECTION.md`, không hard-code HEX trong từng component.
- Spacing: `space.1=4`, `space.2=8`, `space.3=12`, `space.4=16`, `space.6=24`, `space.8=32` logical px.
- Radius: `sm=8`, `md=12`, `lg=16`, `xl=24`.
- Type scale mobile: caption 12–13, label 14, body 16, title 20–24, hero 28–32 (sp đề xuất).
- Focus ring visible; pointer/keyboard support trong Admin; button tap area ≥ 44×44.

## 3. Component inventory — Flutter Mobile

| ID | Component | Trách nhiệm | States / notes |
|---|---|---|---|
| M-C01 | `AppScaffold` | safe area, backgrounds, shell | load/error/keyboard |
| M-C02 | `BrandTopBar` | logo, back, notifications/profile | compact/expanded |
| M-C03 | `MainBottomNav` | Home, Explore, Progress, Island, Profile | active/disabled; route config |
| M-C04 | `PrimaryActionButton` | CTA primary red | loading/disabled/pressed |
| M-C05 | `SecondaryActionButton` | CTA secondary | enabled/disabled |
| M-C06 | `EventHeroCard` | event image/title/year/question | locked/available/in-progress/completed |
| M-C07 | `EraTimelineItem` | time-period card, dates | selected/current/locked |
| M-C08 | `HistoricalMapCanvas` | render 2D map + overlays | pan/zoom/loading |
| M-C09 | `MapEventMarker` | unlock states and navigation | locked/available/completed |
| M-C10 | `FourTraceCard` | Bối cảnh/Nhân vật/Diễn biến/Ý nghĩa | same geometry; progress |
| M-C11 | `EvidenceCard` | evidence title/media/source/citation | collected/available/selected |
| M-C12 | `ActivityShell` | instruction, progress, timer optional, submit | stage/activity labels |
| M-C13 | `ChoiceOption` | MCQ option | unselected/selected/correct/incorrect |
| M-C14 | `MatchingBoard` | connect evidence pairs | tap-pair fallback |
| M-C15 | `DragOrderList` | sequence reconstruction | drag/tap up/down fallback |
| M-C16 | `EvidenceSelector` | select evidence | required count / hint |
| M-C17 | `ReasoningConnector` | evidence → inference links | selection and explanation |
| M-C18 | `HypothesisChoice` | hypothesis options | revision allowed |
| M-C19 | `VerificationFeedback` | supported/partial/contradicted | revise CTA |
| M-C20 | `CERComposer` | Claim/Evidence/Reasoning conclusion | autosave; validation |
| M-C21 | `ReflectionPrompt` | 1 thought prompt | optional/skip as configured |
| M-C22 | `StoryScene` | illustrated explanatory narrative | captions/skip |
| M-C23 | `RewardSummary` | lesson result/EXP/collection | once-only display, backend award |
| M-C24 | `IslandScene` | illustrated 2.5D island | optional post-MVP |
| M-C25 | `InventoryItemCard` | decorate item | owned/placed/locked |
| M-C26 | `ShopItemCard` | item price and metadata | purchasable/insufficient funds |
| M-C27 | `EnergyIndicator` | show energy | optional post-MVP |
| M-C28 | `StatusView` | unified empty/error/offline/skeleton | retry/accessible |

### 3.1 Component contract mẫu — ActivityShell

```dart
class ActivityShell extends StatelessWidget {
  const ActivityShell({
    super.key,
    required this.title,
    required this.instructions,
    required this.content,
    required this.onSubmit,
    this.submitting = false,
    this.canSubmit = true,
  });

  final String title;
  final String instructions;
  final Widget content;
  final VoidCallback onSubmit;
  final bool submitting;
  final bool canSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      Text(instructions),
      Expanded(child: content),
      ElevatedButton(
        onPressed: canSubmit && !submitting ? onSubmit : null,
        child: Text(submitting ? 'Đang gửi...' : 'Kiểm tra kết quả'),
      ),
    ]);
  }
}
```

Contract thật cần bổ sung `Semantics`, scrolling, safe area và lỗi API theo `CODING_RULES.md`.

### 3.2 Activity renderer contract

Input nhận từ backend: `activityId`, `type`, `publicConfig`, `currentAnswer?`, `completionState`, `attemptId`. Output: `submission` gửi API. **Không nhận correct answers / internal validation rules từ learner API.** Backend là nguồn xác nhận kết quả và chuyển stage.

```text
ActivityRenderer(type, publicConfig)
  ├─ MULTIPLE_CHOICE -> ChoiceActivity
  ├─ EVIDENCE_SELECT -> EvidenceSelectActivity
  ├─ MATCHING -> MatchingActivity
  ├─ DRAG_ORDER -> OrderActivity
  ├─ REASONING_CONNECT -> ReasoningActivity
  ├─ HYPOTHESIS_CHOICE -> HypothesisActivity
  ├─ VERIFICATION -> VerificationView
  └─ CER -> ConclusionActivity
```

## 4. Component inventory — Next.js Admin

| ID | Component | Chức năng |
|---|---|---|
| A-C01 | `AdminShell` | sidebar/header/content shell |
| A-C02 | `PageHeader` | title, breadcrumb, primary action |
| A-C03 | `DataTable` | events, lessons, assets; search/filter/sort |
| A-C04 | `StatusChip` | draft/ready/published/archived |
| A-C05 | `EventEditorForm` | metadata/event/era/source |
| A-C06 | `LessonMetadataForm` | question/objectives/template/level |
| A-C07 | `TemplatePicker` | template + stage presets |
| A-C08 | `StageOutline` | stage order/required/enable |
| A-C09 | `ActivityTypePicker` | renderer-supported activities |
| A-C10 | `ActivityConfigEditor` | typed form from activity schema |
| A-C11 | `EvidenceSourceEditor` | source, citation, reliability |
| A-C12 | `AssetLibraryPicker` | search, tags, license, alt |
| A-C13 | `RuleEditor` | validation, retry, feedback, transitions |
| A-C14 | `PublishChecklist` | all constraints, broken references |
| A-C15 | `LearnerPreviewFrame` | preview screen & full journey |
| A-C16 | `VersionHistory` | immutable publish snapshots |
| A-C17 | `UnsavedChangesGuard` | confirm navigation/discard |
| A-C18 | `UploadDropzone` | type/size/license checks |
| A-C19 | `ReviewComments` | reviewer notes (optional phase) |
| A-C20 | `InlineErrorSummary` | validation summary navigates to fields |

## 5. Màn hình → components chính

| Luồng | Mobile | Admin tương ứng |
|---|---|---|
| Chọn thời kỳ / Event | `EraTimelineItem`, `EventHeroCard`, `HistoricalMapCanvas` | `EventEditorForm` |
| Event intro / 4 Dấu | `EventHeroCard`, `FourTraceCard` | `LessonMetadataForm`, `StageOutline` |
| Quiz / Matching / Drag | `ActivityShell`, `ChoiceOption`, `MatchingBoard`, `DragOrderList` | `ActivityConfigEditor`, `RuleEditor` |
| Evidence → Reasoning | `EvidenceCard`, `ReasoningConnector` | `EvidenceSourceEditor` |
| Verification → CER | `VerificationFeedback`, `CERComposer` | `RuleEditor`, `LearnerPreviewFrame` |
| Story / Reward | `StoryScene`, `RewardSummary` | `AssetLibraryPicker`, publish settings |
| Island / Shop | `IslandScene`, `ShopItemCard` | future catalog management, outside core builder |

## 6. Hành vi thống nhất

- **Submit:** disable CTA trong khi submit; idempotency key; show result từ server; không cộng EXP client-side.
- **Autosave:** draft answer lưu local nếu cho phép; câu trả lời submitted phải persist backend.
- **Review:** answer sai hiển thị giải thích, không chỉ màu đỏ; hypothesis có revise loop.
- **Accessibility:** có spoken labels cho marker/ảnh; drag có tap alternative; không chỉ màu biểu thị đúng/sai.
- **Responsive:** Mobile hỗ trợ small viewport + text scaling; Admin breakpoints đề xuất 768/1024/1440 và hỗ trợ desktop chính.
- **No asset dependency:** loading/error có fallback; app vẫn thao tác được khi illustration lỗi tải.

## 7. Definition of Done mỗi component

- [ ] API/data contract + event callbacks rõ.
- [ ] Có semantic/accessibility spec.
- [ ] Có tất cả states và empty/loading/error.
- [ ] Theme token (không hard-code style rải rác).
- [ ] Widget/component tests và golden/visual regression theo rủi ro.
- [ ] Không chứa historical event logic cố định.
- [ ] Nội dung tiếng Việt dài không overflow; thử text scaling.
- [ ] Asset có fallback, alt/caption và nguồn.
