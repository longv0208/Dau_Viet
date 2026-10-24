---
title: "Playback + Audio Stabilization — TASK-0019 P0"
status: in_progress
priority: P0
created: 2026-10-24
baseline: 3d22399
---

# Playback + Audio Stabilization

Hoàn thiện playback state machine + audio lifecycle + deterministic cinematic timeline trên engine hiện có. Không viết lại engine; chỉ tái cấu trúc state cục bộ để xử lý root cause.

## Root cause đã xác định (audit `historical_animation_player.dart` @3d22399)

1. **FINISHED không phải trạng thái thật** — `_togglePlay` suy ra "xong" chỉ qua `_stepIndex == last`. Last-step PAUSED → Play bị `_replay()` về beat 0; STEPPED không bao giờ "finished" → PHÁT ở cuối replay ngay cả khi chưa xem xong.
2. **Replay không reset painter về initialState** — `_applyStep(0, animate:false)` chỉ áp target beat 0; `boatsObstructed/highlightStakes/showSequenceSummary/decoyProgress/counterattackProgress` của trạng thái cuối vẫn còn → "xem lại" hiển thị kết cục.
3. **`_applyStep` fire `onStepExit` ngoài `fireAudio` guard** — silent seek/navigation/skip/replay cũng đánh EXIT cue.
4. **`_replay` nhảy end-frame** — `_initialIdle=false` trước `_applyStep` → `_applyCurrent(1)` + `_emitFrameEnd` → camera/frame nhảy cuối beat 0, không phải đầu.
5. **Manual interaction = Pause** — `_setWater`/`_selectLocation`/`_revealPrediction` dùng chung "paused + controller.stop" — không phân biệt learner-giữ-giá-trị vs pause-để-tiếp-tục.
6. **Audio race: `_playOnce`/`_startLoop` không check `_paused` sau await** — pause giữa fetch/config → player vẫn `play()`; `onResume` không resume pending one-shot chưa start.

## Thiết kế

### Playback state (enum + counter, không đoán từ `controller.value`)

```
enum PlaybackStatus { idle, playing, paused, interactionHold, awaitingPrediction, finished, skipped }
```

Trạng thái chính = `_status` (single source). `controller.value` chỉ là tiến độ tween. `initialIdle` gộp vào `idle`. `tweenPaused` gộp vào `paused` với `resumeTween` flag.

Transitions (contract §2.3):
- `idle` + Play → `_startPlayback()` (applyStep animate + ENTER + timer)
- `playing` + Pause → `_status=paused`, capture `resumeTween` (controller mid-value), stop controller, pause audio + timer
- `paused` + Play → `_status=playing`, `controller.forward()` nếu resumeTween, resume audio, reschedule
- `interactionHold` (kéo nước/chạm marker/reveal) + Play → `_status=playing`, KHÔNG resume/settle tween, resume audio hợp lệ, schedule timer
- `awaitingPrediction` — `_playing=false` ở checkpoint AUTO (đã có); Play trước reveal = no-op gate (giữ `_status`, không advance); reveal → `interactionHold`-like, Play tiếp tục
- `finished` — set khi AUTO timer cuối expire hoặc learner nhấn Next qua last; Play → `_replay()` + start playback
- `skipped` — `_skip()` giữ; Replay → reset + `idle`-like seek (không auto-play trừ khi contract)
- Navigation (`_goTo`) KHÔNG đổi `_status` — paused vẫn paused, idle vẫn idle; chỉ seek step + fire ENTER khi đang playing

### Reset contract (§3)

- `_seekStepStart(index)` — painter về initialState (re-seed qua `createPainter()` → copy fields, không tạo painter mới để giữ listener), `_current = steps[index].target`, `_tweenFrom = captured()`, controller reset, `_emitFrame(0,0)`, KHÔNG audio, KHÔNG timer.
- `_applyStepEnd(index)` — settle end-state (nhảy tĩnh), `_applyCurrent(1)` + `_emitFrameEnd`.
- `_startStepPlayback(index)` — `_applyStep(animate:true, fireAudio:true)` + `_scheduleAdvance()`.
- Thay `animate=false` mơ hồ: `seekStepStart` (replay/idle-mount) vs `applyStepEnd` (skip/reduced-motion/nav-end).

### Painter reset

`_resetPainterToInitial()` — gọi `createPainter()` tạo seeded instance → copy TẤT CẢ mutable fields sang `_painter` hiện tại (waterLevel, boatProgress, boatsObstructed, highlightStakes, decoyProgress, counterattackProgress, showSequenceSummary cho river; markerVisibility, routeProgress, highlightedIds, focusedId cho map). Implement qua `copyFrom` trên từng painter (hoặc generic: `HistoricalScenePainter.restoreFrom(HistoricalScenePainter seeded)`).

### Audio (§7)

- `_fire`/`_playOnce`/`_startLoop`/`_rampVolume`: check `_disposed || _paused || gen` sau MỖI await — pause giữa fetch/config → không play.
- `onPause` đánh `_paused=true` TRƯỚC khi cancel timer → pending fetch thấy `_paused` khi resolve → hold.
- `onResume`: `_paused=false` → resume loop + one-shot; pending one-shot chưa start → play với bytes đã cache (không refetch).
- `_playOnce` chụp gen; sau `await player.stop()` + `setReleaseMode` + `setVolume` check `_disposed||_paused||gen` trước `play`.
- `onStepExit` chỉ fire EXIT cue khi `fireAudio=true` (sửa `_applyStep` — silent seek không đánh EXIT).
- `onSkip`/`dispose` giữ nguyên (bump gen, stop all).

## Tests bắt buộc (mới + fix)

Widget tests (`historical_animation_test.dart` + file mới nếu cần):
- replay reset painter fields (water 0.3, boat 0, obstructed false, summary false) — river
- replay reset markerVisibility/routeProgress/highlighted/focused — map
- replay → camera frame t=0 (cinematicFrame notifier)
- last-step paused → Play resume last step (không replay)
- last-step finished → Play replay từ đầu
- single-step scene (definition 1 step): mount/play/pause/resume/finish/replay/skip không crash, không index-out-of-range
- silent navigation paused không fire ENTER/EXIT cue
- skip → replay → play full restart
- rapid play/pause không duplicate timer
- dispose during tween/audio fetch không callback sau

Audio controller tests (`animation_audio_controller_test.dart`):
- pause trước bytes resolve → không play sau resume (đã có 1, thêm case config-pending)
- `_playOnce` pause sau `stop()` trước `play()` → không play
- `onResume` với pending one-shot chưa start → play đúng 1 lần
- Next khi paused không fire ENTER/EXIT
- silent seek không fire EXIT
- replay hủy pending ENTER cũ → ENTER mới đúng 1 lần
- double resume an toàn

## Phases

- [ ] P1 — reproduction tests (fail trên code hiện tại)
- [ ] P2 — playback state machine refactor (`_status` enum + transitions + reset contract)
- [ ] P3 — audio controller `_paused` checks + pending-resume
- [ ] P4 — silent-seek `onStepExit` gating
- [ ] P5 — painter `restoreFrom` + replay initialState
- [ ] P6 — single-step + last-step + finished semantics
- [ ] P7 — flutter analyze + flutter test + dart format
- [ ] P8 — update task.json/handoff/plan
