# TASK-0016 — Evidence & Asset Library + Activity Configuration

Plan tổng quan. Nguồn sự thật contract: backend code tại `dau-viet-backend` (đã đọc trực tiếp, không suy đoán từ docs).

## Trạng thái các phase

| Phase | Nội dung | Trạng thái |
|---|---|---|
| 01 | Backend: AdminAssetController upload/list/get/serve + AssetService + local storage | pending |
| 02 | Admin: lib/dto + api wrappers cho evidence & asset | pending |
| 03 | `/evidence` — Evidence Library (list/search/filter/create/edit/approve) | pending |
| 04 | `/assets` — Asset Library thật (list/upload/preview/replace coming-soon page) | pending |
| 05 | EvidencePicker + AssetPicker dialog (dùng chung) | pending |
| 06 | Builder integration: EVIDENCE_SELECT + CER requiredEvidenceIds + VIEW_IMAGE | pending |
| 07 | FeedbackPanel reusable (feedback.{outcome} object) | pending |
| 08 | Editors mới: HYPOTHESIS_CHOICE, VERIFICATION, REASONING_CONNECT (+READ nâng cấp) | pending |
| 09 | MSW handlers + e2e stub mở rộng; unit tests | pending |
| 10 | Playwright journey: evidence create → attach → feedback → save → reload | pending |
| 11 | Gates + báo cáo tiếng Việt + task.json | pending |

## Contract backend đã xác minh (không suy đoán)

### Evidence — CÓ SẴN, không cần backend mới
- `POST /api/v1/admin/evidences` → 201 `EvidenceResponse`
- `GET /api/v1/admin/evidences?eventId&status&q&page&size&sort`
- `GET /api/v1/admin/evidences/{id}`; `PATCH /{id}` (EvidencePatchRequest — field null-clear, absent-keep)
- `POST /{id}/approve` (DRAFT→APPROVED), `POST /{id}/archive` (từ chối khi published snapshot tham chiếu)
- Upsert: `eventId*` `title*≤255` `evidenceType*≤48` `description` `sourceTitle*≤255` `sourceAuthor` `sourceUrl` `sourceCitation` `sourcePublishedAt (LocalDate)` `reliability ∈ HIGH|MEDIUM|LOW|UNASSESSED` `relevance` `assetId`
- `evidenceType` VARCHAR tự do — client định nghĩa tập hợp VN (VĂN_BẢN/HIỆN_VẬT/HÌNH_ẢNH/BẢN_ĐỒ/LỜI_KỂ...) gửi chuỗi thô.
- status ∈ DRAFT|APPROVED|ARCHIVED.

### Asset — THIẾU endpoint, entity có sẵn
- Table `assets(id, storage_key unique, original_filename, mime_type, size_bytes, checksum_sha256 CHAR(64), state UPLOADING|ACTIVE|RETIRED|FAILED, alt_text, created_at, created_by, retired_at)` — V3 migration.
- `Asset` entity + `AssetRepository` + `AssetNotFoundException` đã có. Chưa có controller/service/storage.
- `evidences.asset_id` FK → assets.
- Cần slice nhỏ: `POST /api/v1/admin/assets` (multipart upload), `GET /api/v1/admin/assets` (list), `GET /api/v1/admin/assets/{id}`, `GET /api/v1/assets/{id}/content` (serve bytes — learner-safe path), local-dev lưu `data/assets/` (disk), checksum sha256, validate mime PNG/JPEG/WebP + max size (10MB dev). State=ACTIVE ngay khi lưu xong.
- Serve path phải là URL ổn định đi qua admin proxy — KHÔNG blob URL, KHÔNG đường dẫn filesystem lộ ra ngoài.

### Activity feedback — object tự do
- `activity.feedback` là JSON object; handler `feedbackFor(activity, outcomeKey)` trả `outcomeKey` nếu `feedback[outcomeKey]` tồn tại → feedbackCode.
- Outcome keys: `COMPLETED, INCORRECT, IN_PROGRESS, SUPPORTED, PARTIAL, CONTRADICTED`.
- FeedbackPanel emit `{COMPLETED?: string, INCORRECT?: string, PARTIAL?: string, ...}` — key rỗng → xoá, không emit object rỗng.
- Hint: backend KHÔNG có trường hint riêng trong schema — không thêm key bịa (ACTIVITY_KEYS fixed). Ghi nhận gap trong report.

### Config schemas (per type)
- EVIDENCE_SELECT `{visibleEvidenceIds[]≥1, minRequired?}`
- VERIFICATION `{visibleSourceIds[]?, requiredEvidenceIds[]?}` — refs checked PUBLISH
- HYPOTHESIS_CHOICE `{hypotheses[]≥2 unique ids}` (item shape như options: id+label)
- REASONING_CONNECT `{nodes[]≥2 unique ids, allowedRelations[]≥1}`
- EXPLORE_MAP `{markers[]≥1 unique ids}` — marker shape không rõ → giữ UnsupportedEditor với ghi chú
- CER `{rubric.criteria[]≥1, requiredEvidenceIds[]≥1}` + claimPrompt?
- VIEW_IMAGE `{imageAssetId*}` + caption? (không validate caption — optional)
- READ `{text?≤20000}`
- LEARNER_HIDDEN_KEYS bị strip: correctOptionIds/multiCorrect/correctPairs/expectedOrder/requiredEvidenceIds/expectedHypothesis/answerKey/answer/key/expected.

## Quyết định kiến trúc

- Backend slice Asset: tối thiểu theo pattern có sẵn (controller/service/repository/migration-free vì bảng đã có). Local disk storage `data/assets/{id}.{ext}`, path trong `application.yml` `dauviet.assets.dir` default `data/assets`. Serve qua `GET /api/v1/assets/{id}/content` trả bytes + content-type — cần permitAll cho learner? → kiểm tra SecurityConfig; nếu phức tạp thì serve qua admin-auth trước, ghi note cho TASK-0017.
- Pickers: một `EvidencePickerDialog` + `AssetPickerDialog` dùng chung cho mọi editor (tránh lặp). Render trong builder page, controlled bởi state.
- Editors mới tái dùng `ActivityCommonFields` + pattern Option/Pair/Item spread-preserve đã có.
- `/assets` page: thay coming-soon bằng library thật (list + upload + preview). `/evidence` page mới.

## Phạm vi KHÔNG làm

- EXPLORE_MAP editor (shape markers không có contract rõ → UnsupportedEditor + ghi chú).
- Hint/attempts-limit fields không có trong backend schema → không emit key bịa; báo cáo gap.
- S3/cloud, publish workflow, version history UI, Flutter renderer.

## Rủi ro

- Asset serve auth: nếu learner path chưa sẵn → serve admin-only trước, ghi blocker.
- `evidenceType` free-text: client chuẩn hoá qua select cố định, vẫn cho nhập tự do? → chọn select cố định tập VN + "Khác".
- 200 LOC/file: pickers + editors mới chia file nhỏ ngay từ đầu.
