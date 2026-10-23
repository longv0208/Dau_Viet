---
title: "Fix & Harden Data-driven Historical Animation Engine"
status: in_progress
priority: P0
created: 2026-10-24
---

# Fix & Harden Animation Engine

Audit commit 82765d3. Vertical slice: Admin create/configure/preview/publish scene → lesson builder pin version → Flutter render manifest+assets.

## Constraints
- No commit/push. No Playwright. No independent summary report.
- No core-architecture rewrite. Preserve Bạch Đằng 938 / Hai Bà Trưng 40 / Lý Thái Tổ 1010 + legacy animationKey.
- Backend authoritative; no client-side completion/reward. No eventId hard-code.
- Prior work in `plans/2026-10-23-animation-engine/` (all 4 phases done, reviewer fixes applied).

## TODO checklist

### P0
- [x] P0-2 create-scene DTO: `@NotBlank` on UUID templateId → `@NotNull`; sweep all new DTOs for wrong-type annotations; MockMvc/IT tests (valid create, null templateId, missing template, disabled template, bad draftJson)
- [x] P0-3.1 DTO contract: `SceneSummaryResponse` add `currentVersionId` (+`currentVersionNo`,`rowVersion`,`updatedAt`,`rendererCode` if used); sync `animation-types.ts`, `AnimationMapper`, controllers; audit SceneResponse/SceneVersionSummary drift
- [x] P0-3.2 pagination: picker `size=200` vs backend max 100 → implement search/pagination server-side support, fetch selected scene by id
- [x] P0-3.3 error handling: picker shows real error + retry, not "Chưa có animation"
- [x] P0-3.4 published-scene selection E2E: list published, select, pin currentVersionId, playbackMode, save draft, reopen keeps choice, publish lesson; FE + BE tests
- [x] P0-4 asset rendering: publish giữ `{id, assetId, role}` + meta trong snapshot `assets[]`; Flutter `ManifestAssetLayers` (background dưới painter + objects theo position/layer, fetch 1 lần qua `fetchLearningAssetBytes` có auth, fallback icon, không fetch khi chưa auth); admin `scene-preview.tsx` hiển thị ảnh nền + object parity; AssetsSection chỉ cho chọn BACKGROUND/OBJECT (còn lại disable "chưa hỗ trợ")
- [x] P0-5 timeline executable: durationMs/easing whitelist/playbackMode AUTO-STEPPED-INTERACTIVE/canvas.aspectRatio truyền từ manifest → `HistoricalAnimationDefinition` → player (auto-advance chỉ AUTO, per-step curve, aspectRatio từ manifest); widget tests 27/27

### P1
- [x] P1-6 renderer version compat: `rendererVersion < 1` → INVALID_VALUE; `> template.rendererVersion` → UNSUPPORTED_VERSION; <= template chấp nhận; schemaVersion 99 → UNSUPPORTED_SCHEMA; +4 negative tests (29/29)
- [x] P1-7 preview↔flutter parity: admin `scene-preview.tsx` RIVER_TIDE waterSurfaceY/stake/boat formulas khớp `RiverScenePainter`; JOURNEY_MAP partial-draw + markers/focus/tap; hiển thị assets/objects cùng contract
- [x] P1-8 lesson preview integration: `text-renderers.tsx` READ preview parse `config.animationManifest` envelope `{manifest, sceneVersionId, versionNo, rendererCode, rendererVersion}` → `<ScenePreview>` trực tiếp; legacy animationKey giữ; không fetch unpublished
- [x] P1-9 harden manifest validation: rendererVersion/schemaVersion, sourceReferences required, disclaimer, backgroundAssetId ACTIVE, asset refs, numeric bounds (water/boat/marker 0..1), marker/route ids exist, effects/interactions whitelist, types, size bounds, missing deps; path/code/message errors; no break of old published versions
- [~] P1-10 backend ITs — Docker daemon OFF → toàn bộ Testcontainers ITs blocked; MockMvc + unit tests (225) cover phạm vi code mới. Ghi blocked thật.
- [x] P1-11 admin usability: DataTable error+retry, search q + phân trang server, `đang phát hành v{n}` + cột Phiên bản, beforeunload khi dirty + banner "Lưu nháp trước khi xuất bản", disable *.isPending mọi action, archive confirm + duplicate/archive error alert, role không hỗ trợ disable, preview ghi nhãn "nội dung đang soạn (chưa lưu/đã lưu) ≠ phiên bản đã phát hành"

## Evidence so far (from prior phase)
- Backend unit 225 + validator 29/29 (1 err = DauVietApplicationTests needs Docker)
- Admin tsc clean, vitest 144/144
- Mobile 278/278

## Blockers
- Docker Desktop daemon OFF → all Testcontainers ITs (P1-10) cannot run; unit/MockMvc tests proceed.
