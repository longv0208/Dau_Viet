# Plan — Issue #43: EVIDENCE_SELECT — cơ chế trọn vẹn (dễ hiểu + có ý nghĩa học)

> Issue: https://github.com/longv0208/Dau_Viet/issues/43
> BA doc đã đọc: `Dau_Viet_BA_MVP_Learning_Framework.docx`
> Modules: `dau-viet-mobile` + `dau-viet-admin` + `dau-viet-backend` (handler output only, additive)
> Risk: **normal→high** (phần backend thêm output key là additive, nhưng đụng learning handler + grading contract → giữ gate: impact note + tests theo CODING_RULES §8)

## 0. Fact base đã xác nhận

| Fact | Nguồn |
|---|---|
| `EvidenceSelectHandler` (`SelectionHandlers.java:33-179`) emit output: `selectedEvidenceIds`, `selectedCount`, `correct`, `score`, `correctCount`, `falseCount`, `attemptCount`, `exhausted`, `budgetExhausted`, `remedial` | code đọc |
| `LEARNER_HIDDEN_KEYS` (`DraftSchema.java:66-74`) chứa `acceptedEvidenceIds`, `requiredEvidenceIds`, `expectedHypothesis`... — strip recursive trong `AbstractActivityHandler.result()` | code đọc |
| Seed V51: `graded:true`, `minRequired:2`, `maxAttempts:3`, `remedialAttempts:1`; Bạch Đằng 7 visible/4 accepted/3 distractor; 3 lesson kia 5/4/1 | migration đọc |
| `evidenceSource: es` trong VERIFICATION; `priorEvidenceSource: es` trong HYPOTHESIS_CHOICE + CER_CHOICE → `selectedEvidenceIds` được dùng lại ở 3 nơi | migration + `CerChoiceHandler`, `ReasoningHandlers` |
| Admin `evidence-select-editor.tsx` dòng 19: `const graded = true` — toggle bị khóa, không có preview | code đọc |
| `EvaluationDto.output` là `Map<String,dynamic>` mở — client đọc field tùy ý | `attempt_dtos.dart:175` |
| BA §3.3/§8.3: Evidence = "phân biệt thông tin có giá trị", output `SelectedEvidence[] + đánh giá relevance/reliability`; `distractor/core` là attribute evidence; BA KHÔNG yêu cầu exact-set | docx |

## 1. Vấn đề thật cần giải (gộp 2 chiều)

**Dễ hiểu (UX):** copy mâu thuẫn (2 ngưỡng), tap-zone đụng nhau, progress `x/y` không rõ nghĩa, learner không biết đích đến.

**Ý nghĩa học (pedagogy):** cơ chế ghép 2 intent vào 1 activity —
- `COLLECT` (thu thập — BA intent, exploration)
- `ASSESS` (đánh giá evidence literacy — implementation-invented, exact-set F1)

→ chưa ai hiểu mình đang làm gì. Và sau submit, learner **không học được gì** vì chỉ thấy `Đúng k/n`, không biết thẻ nào sai/vì sao.

## 2. Cơ chế sau sửa — learner trải nghiệm

### Mode COLLECT (`graded:false`)
```
Header: "THU THẬP DẤU VẾT — CHỌN ÍT NHẤT {minRequired}"
Sub:    "Chọn các dấu vết bạn thấy liên quan đến câu hỏi — không mất Thể lực"
[card] tap → detail sheet; [control "Chọn"] → tick
Counter: "Đã chọn x/{minRequired}"
→ submit: đủ số là xong. selectedEvidenceIds → priorOutputs.
```

### Mode ASSESS (`graded:true`)
```
Header: "CHỌN ĐÚNG CÁC DẤU VẾT LIÊN QUAN"
Sub:    "Sai mất {penalty} Thể lực · còn {left}/{budget} lượt"
[card] tap → detail sheet; [control "Chọn"] → tick
Counter: "Đã chọn x/{minRequired}"
→ submit:
   PARTIAL/INCORRECT → InlineGradingHint "Đúng k/n · còn x lượt"
                     + per-card verdict: thẻ learner ĐÃ CHỌN được đánh dấu
                       đúng (viền xanh ✓) / sai (viền đỏ mờ ✗)
                       — chỉ đánh dấu trên thẻ đã chọn, KHÔNG chỉ ra
                       thẻ accepted nào bị miss (không lộ answer key)
   COMPLETED → proceed; VERIFICATION sau đó kiểm chứng hypothesis
              bằng chính tập evidence đã chọn.
```

## 3. Thay đổi cụ thể

### 3.1 Backend — `SelectionHandlers.java` (ADDITIVE output key)

Trong `evaluateGraded` (sau khi tính `correctHits`), thêm vào `out` **trước** `result()`:

```java
// Per-card verdict on the learner's OWN selection — teaches which picks
// were relevant vs wrong. Only marks submitted ids (never reveals
// accepted ids the learner missed). `verdict` ∈ {"correct","incorrect"}.
if (!distinct.isEmpty()) {
    ObjectNode verdicts = out.putObject("selectedVerdicts");
    for (String id : distinct) {
        verdicts.put(id, correctHits.contains(id) ? "correct" : "incorrect");
    }
}
```

**Safety check:** `selectedVerdicts` không nằm trong `LEARNER_HIDDEN_KEYS` → sẽ được emit. Nó chỉ chứa ids learner **đã gửi** → không lộ `acceptedEvidenceIds` (thẻ accepted bị miss không xuất hiện trong map). Không đổi grading semantics — thuần additive output.

- `EvaluationDto` mobile: `output` là Map mở → tự động có `selectedVerdicts`, không cần sửa DTO (chỉ đọc field).
- KHÔNG thêm hidden key mới. Không đổi score/attempt/remedial logic.

### 3.2 Mobile — `evidence_select_renderer.dart`

- Đọc `graded`, `minRequired`, `maxAttempts`, `lastEvaluation` (đã có `lastEvaluation` prop).
- Mode-aware header/subtitle (như §2).
- Tap-zone split:
  - card body tap → `_showDetail` (detail sheet)
  - select control 44px → `_toggle`, label `Chọn`/`Bỏ chọn` rõ ràng
  - `maxSelect` reached → hint nhỏ
- Per-card verdict sau submit: từ `lastEvaluation.output['selectedVerdicts']` → truyền `verdict` vào `_EvidenceCard`; card render border/badge:
  - `correct` → viền jade + `✓`
  - `incorrect` → viền cinnabar mờ + `✗`
  - null (không submit/chưa submit) → như hiện tại
- `InlineGradingHint` (renderer_base): mở rộng — `score` present without `correctPositions` → "Kết quả một phần"; `exhausted`/`budgetExhausted` → "Đã hết lượt — bước này được tính hoàn thành".

### 3.3 `lesson_player_screen.dart`

- Progress chip `"x/y"` → `"Bước {x}/{y}"` — 1 dòng.

### 3.4 Admin — `evidence-select-editor.tsx`

- Mở `graded` thành toggle thật:
  - `Thu thập tự do (không chấm điểm)` → `graded:false`
  - `Đánh giá — chọn đúng đáp án` → `graded:true`
- `graded:false` → chỉ `visibleEvidenceIds` + `minRequired`; khi toggle sang false, strip `acceptedEvidenceIds`/`maxAttempts`/`remedialAttempts` khỏi config (tránh gửi key vô nghĩa — handler đọc `graded` nên vẫn an toàn nếu còn sót, nhưng sạch hơn là strip).
- `graded:true` → hiện đủ + preview tóm tắt learner-visible: "Học viên chọn đúng {n}/{m} · sai mất {penalty} Thể lực · {maxAttempts} lượt + {remedialAttempts} sửa"
- Client validate `acceptedEvidenceIds ⊆ visibleEvidenceIds` trước submit (backend vẫn check publish).

### 3.5 Docs

- `LEARNING_ENGINE_DESIGN.md` §13.1: ghi 2 mode COLLECT/ASSESS; `minRequired` là completion-gate; output `selectedVerdicts` (additive, learner-safe, chỉ trên submitted ids); `selectedEvidenceIds` nuôi `evidenceSource`/`priorEvidenceSource` của VERIFICATION + CER_CHOICE.
- §14 Open decisions: thêm BA gap `relevance`/`reliability`/`distractor`/`core` metadata trên `evidences` (chưa model — task riêng, cần migration + admin labeling).

## 4. Tests

**Mobile** (`test/learning/evidence_select_renderer_test.dart` — mới):
1. `graded:false` → eyebrow "ÍT NHẤT", sub không nhắc Thể lực, submit ≥minRequired
2. `graded:true` → eyebrow không có ngưỡng số, sub nhắc penalty/attempts
3. Card tap → detail sheet, không toggle
4. Select control → toggle + counter
5. `lastEvaluation.output.selectedVerdicts` → card hiển thị đúng/sai trên thẻ đã chọn
6. `maxSelect` → hint
7. `exhausted`/`budgetExhausted` → "hết lượt"
Update test cũ assert chuỗi `CHỌN ÍT NHẤT`/`Chạm vào thẻ để xem chi tiết`/`Đã chọn x/y`.

**Backend** (`SelectionHandlersTest` hoặc IT hiện có — mở rộng nếu có):
- Graded submit → `output.selectedVerdicts` map đúng; chỉ chứa submitted ids; `acceptedEvidenceIds` vẫn bị strip (negative test — assert `!output.has("acceptedEvidenceIds")`).
- Ungraded → không có `selectedVerdicts` (hoặc map rỗng) + `selectedEvidenceIds` vẫn emit.

**Admin** (`evidence-select-editor` test nếu có / thêm):
- Toggle `graded` off → ẩn accepted/maxAttempts/remedial, strip keys khỏi config
- `accepted ⊄ visible` → validation error trước submit

## 5. AC → check

| AC | Xử lý | Check |
|---|---|---|
| Copy khớp `minRequired`/`graded` | 3.2, 3.4 | widget test 1-2 |
| Card=detail, select=control riêng | 3.2 | widget test 3-4 |
| Graded hiện score/attempts; ungraded không dọa Thể lực | 3.2 | widget test 2 + gate |
| **Per-card verdict sau submit** (ý nghĩa học) | 3.1 + 3.2 | backend test + widget test 5 |
| Progress có label | 3.3 | widget test 7 |
| Không lộ answer key | verdict chỉ trên submitted ids | backend negative test |
| Doc cập nhật | 3.5 | diff |


### 3.4b Admin — chú thích + hướng dẫn trong editor (bắt buộc)

Không phải ai vào cũng hiểu cơ chế — editor phải tự giải thích. Trong `evidence-select-editor.tsx`, mỗi cụm field có:

- **Mode selector** (thay checkbox khóa `graded`): 2 radio card có label + mô tả 1 dòng:
  - `Thu thập bằng chứng (không chấm điểm)` — "Học viên chọn tự do các dấu vết họ thấy liên quan. Kết quả được mang sang bước Giả thuyết / Kiểm chứng — nếu thiếu bằng chứng, học viên sẽ được quay lại đây sửa sau khi đối chiếu. Không trừ Thể lực."
  - `Đánh giá bằng chứng (chấm điểm)` — "Học viên phải chọn đúng tập đáp án. Sai → trừ Thể lực và tính lượt thử. Dùng khi danh sách có dấu vết 'bẫy' (distractor) và bạn muốn kiểm tra khả năng phân biệt nguồn."
- **Field-level hint đã có, nâng cấp thành hướng dẫn đầy đủ**:
  - `Bằng chứng học viên được xem` — hint hiện tại + thêm: "Nên có ít nhất 1–3 dấu vết 'bẫy' (liên quan đến sự kiện nhưng KHÔNG trả lời câu hỏi trung tâm) nếu bạn chọn mode Đánh giá — không thì học viên chỉ cần chọn tất cả là đúng."
  - `Bằng chứng đúng (đáp án)` — "Tập con của danh sách trên — không hiển thị cho học viên. Học viên chọn đúng hết mới được điểm tối đa; chọn thiếu hoặc thừa đều bị trừ điểm theo F1."
  - `Số lần thử tối đa (có chấm)` — "Số lần học viên được nộp đáp án có chấm. Hết số này hoạt động tính là đã duyệt (exhausted) — học viên đi tiếp nhưng kết quả ghi theo lần cuối."
  - `Lượt sửa bài bổ sung (remedial)` — "Lượt sửa chỉ mở khi (a) đã hết lượt chấm VÀ (b) học viên được đưa quay lại đây từ bước sau (ví dụ Kiểm chứng báo thiếu bằng chứng). Sau khi cạn cả hai ngân sách, câu trả lời đúng cũng không đổi kết quả."
  - `Số bằng chứng tối thiểu phải chọn` — "Ngưỡng để nút GỬI được bật — KHÔNG phải đáp án đúng. Ở mode Đánh giá, chọn đúng tập đáp án mới được điểm; ngưỡng này chỉ quyết định học viên có được phép submit hay không."
- **Learner preview box** (mode ASSESS): text tóm tắt thứ học viên sẽ thấy —
  `"Học viên thấy: 'CHỌN ĐÚNG CÁC DẤU VẾT LIÊN QUAN · Sai mất {incorrectPenalty} Thể lực · còn {maxAttempts} lượt + {remedialAttempts} sửa'"` — render động theo config đang nhập.
- **Validation client-side**: `acceptedEvidenceIds ⊆ visibleEvidenceIds`; `accepted` non-empty khi `graded:true`; cảnh báo nếu `accepted.size == visible.size` (select-all = full điểm, mode Đánh giá vô nghĩa — nhưng vẫn cho publish vì backend không chặn).
## 6. Out of scope

- `evidences.relevance`/`reliability`/`role` metadata + learner self-assessment nguồn (BA §3.3) — cần migration + admin label + handler score mới → **task riêng** (ghi Open decisions)
- Đổi grading semantics (F1, remedial, budgetExhausted) — giữ nguyên
- Seed V51 instruction "đủ 4 nhóm" — authored content; renderer không còn thêm ngưỡng mâu thuẫn
- `incorrectPenalty`/`graded` đã có sẵn server-side — không đổi

## 7. Verify

- `flutter analyze` → 0 issue mới (baseline 9 `island/*` warnings)
- `flutter test` → pass + test mới
- Backend: `mvn -q test -Dtest=*EvidenceSelect*` hoặc test class hiện có + assert `selectedVerdicts` + `acceptedEvidenceIds` stripped
- Admin: `npx tsc --noEmit` + `npx vitest run`
- `git diff --check` clean
- Manual: Bach Dang EVIDENCE stage — mode ASSESS hiện đúng, tap card → sheet, select riêng, submit PARTIAL → card verdict + hint + "Bước x/6"
