# Phase 05 — EVIDENCE_SELECT polish

## Overview

- Priority: P1
- Status: pending
- Goal: richer evidence cards (title/desc/source/author/thumbnail/
  selection), tap-to-detail, clear selected state, respect
  `visibleEvidenceIds` + `minRequired`.

## File

Modify: `lib/features/learning/presentation/renderers/evidence_select_renderer.dart`

Optional small helper: extract `String? evidenceSourceText(Map)` into
`renderer_base.dart` (shared with `_SourceTile` in verification renderer
and Phase 01 view_image source line).

## Contract preserved

- `{'selectedEvidenceIds': List<String>}`.
- Iterate ONLY `config.visibleEvidenceIds` — never `requiredEvidenceIds`.
- `minRequired` numeric config — default 1.
- Evidence fields read from `content.evidenceById(id)`:
  existing/allowed keys — `id`, `title`, `description`, `source` (Map
  with `title`/`author`, or raw String), `author`, `thumbnailAssetId`,
  `year`. Read all with `as String?` defensive casts — never invent
  fields; if missing skip.

## Changes

1. Replace `_EvidenceTile` with richer card (same file):
   - `ParchmentCard` instead of raw Container — keep border/ink language.
   - `onTap` → toggles selection.
   - Selected state: border `cinnabarRed` 1.6w, background
     `cinnabarRed.withValues(alpha:0.08)`, trailing `Icons.check_circle`
     in `cinnabarRed`. Use `AnimatedContainer`-style fade on the
     check-icon (`AnimatedOpacity`, 150ms).
   - Leading: checkbox icon column (existing `check_circle /
     radio_button_off`) + thumbnail (if `thumbnailAssetId` →
     `LearningAssetImage(assetId: thumbId, height: 56, width: 56, fit:
     cover)` — extend `LearningAssetImage` to accept `width` parameter).
   - Body Column: title (`labelMedium` bold) → desc (`bodySmall`, max 3
     lines ellipsis) → `Nguồn: {source}` italic 11px (existing logic) →
     `Tác giả: {author}` if `e['author']` exists and is not already
     inside `source`.
   - `trailing`: chevron `Icons.info_outline` → opens detail sheet
     (below).
2. Tap-to-detail: `IconButton` on the info icon calls
   `showModalBottomSheet` with the same evidence map — title, full
   description, `sourceText`, `author`, `year`. Use
   `showDragHandle: true`, `backgroundColor:
   DauVietColors.parchmentSurface`. Keep inside the same file as a
   `_EvidenceDetailSheet` private widget. Reuse
   `evidenceSourceText` helper.
3. Selection counter: above list, change SectionLabel to dynamic:
   `'CHỌN ÍT NHẤT $minRequired BẰNG CHỨNG — ĐÃ CHỌN ${_selected.length}/$minRequired'`.
   Or keep label and add a right-aligned counter `Text` in the same
   row using `Row(mainAxisAlignment: spaceBetween)`. Pick the simpler:
   SectionLabel stays static + new `Text('Đã chọn ${_selected.length}/
   $minRequired tối thiểu')` aligned end in `bodySmall` — clear progress.
4. Disable during submit: tiles `enabled: !widget.submitting` (exists);
   also dim via `opacity: 0.6` on the card.
5. Haptics: `HapticFeedback.selectionClick()` on tile tap.
6. Missing evidence entries (id present in `visibleEvidenceIds` but
   `evidenceById` returns null) — keep current fallback to `fallbackId`
   as title; still selectable (server authoritative).
7. `onInputChanged` already wired — keep.

## Todo

- [ ] Add `width` param to `LearningAssetImage`.
- [ ] Extract `evidenceSourceText` into `renderer_base.dart`.
- [ ] Rebuild `_EvidenceTile` with card layout + thumbnail + author +
      info chevron.
- [ ] `_EvidenceDetailSheet` modal.
- [ ] Counter text under SectionLabel.
- [ ] AnimatedOpacity on check + dim on submit + haptic.

## Risks

- Modal sheet + submitting: when sheet is open and submit fires, sheet
  stays open — acceptable (read-only); no auto-dismiss needed.
- `LearningAssetImage` FutureBuilder refetches each rebuild — the
  Phase 01 `static Map` cache fixes this.
