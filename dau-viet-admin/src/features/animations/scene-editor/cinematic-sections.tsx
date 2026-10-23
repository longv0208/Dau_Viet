"use client";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select } from "@/components/ui/select";

import {
  AUDIO_CUES,
  EFFECT_TYPES_V2,
  EASINGS,
  TRACK_PROPERTIES,
  manifestHasV2,
  type AudioCue,
  type CameraPose,
  type Keyframe,
  type ObjectTrack,
  type SceneEffect,
} from "../animation-types";
import { Section, type SectionProps } from "./editor-sections";

/** Các section cinematic v2 — camera, tracks, effects, audio, environment.
 * Tất cả patch manifest qua onChange; khi thêm v2 key đầu tiên, bump
 * schemaVersion lên 2 (validator backend bắt buộc). */

function patchV2(
  manifest: SectionProps["manifest"],
  patch: Partial<SectionProps["manifest"]>,
  onChange: SectionProps["onChange"],
) {
  const next = { ...patch };
  if (manifest.schemaVersion < 2 && manifestHasV2({ ...manifest, ...next })) {
    next.schemaVersion = 2;
  }
  onChange(next);
}

/* ---------- helpers nhỏ ---------- */

function NumField({
  label,
  value,
  onChange,
  step = 0.05,
  min,
  max,
  disabled,
}: {
  label: string;
  value: number;
  onChange: (v: number) => void;
  step?: number;
  min?: number;
  max?: number;
  disabled?: boolean;
}) {
  return (
    <div className="flex flex-col gap-1">
      <Label>{label}</Label>
      <Input
        type="number"
        value={value}
        step={step}
        min={min}
        max={max}
        disabled={disabled}
        onChange={(e) => onChange(Number(e.target.value))}
      />
    </div>
  );
}

/* ---------- 5a. Camera ---------- */

function CameraPoseFields({
  pose,
  disabled,
  objects,
  locations,
  onChange,
}: {
  pose: CameraPose;
  disabled?: boolean;
  objects: { id: string }[];
  locations: { id: string }[];
  onChange: (p: CameraPose) => void;
}) {
  return (
    <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
      <NumField label="Tâm X" value={pose.x} min={0} max={1} disabled={disabled}
        onChange={(x) => onChange({ ...pose, x })} />
      <NumField label="Tâm Y" value={pose.y} min={0} max={1} disabled={disabled}
        onChange={(y) => onChange({ ...pose, y })} />
      <NumField label="Zoom" value={pose.zoom} min={0.5} max={3} disabled={disabled}
        onChange={(zoom) => onChange({ ...pose, zoom })} />
      <div className="flex flex-col gap-1">
        <Label>Focus</Label>
        <Select
          value={pose.focusObjectId ?? pose.focusLocationId ?? ""}
          disabled={disabled}
          onChange={(e) => {
            const v = e.target.value;
            const next: CameraPose = { ...pose };
            delete next.focusObjectId;
            delete next.focusLocationId;
            if (objects.some((o) => o.id === v)) next.focusObjectId = v;
            else if (locations.some((l) => l.id === v)) next.focusLocationId = v;
            onChange(next);
          }}
        >
          <option value="">— tự do —</option>
          {objects.map((o) => (
            <option key={o.id} value={o.id}>vật: {o.id}</option>
          ))}
          {locations.map((l) => (
            <option key={l.id} value={l.id}>địa: {l.id}</option>
          ))}
        </Select>
      </div>
    </div>
  );
}

export function CameraSection({ manifest, readOnly, onChange }: SectionProps) {
  const camera = manifest.camera;
  const objects = manifest.objects ?? [];
  const locations = manifest.map?.locations ?? [];
  const steps = manifest.steps;

  const enable = () =>
    patchV2(manifest, {
      camera: {
        initial: { x: 0.5, y: 0.5, zoom: 1 },
        steps: steps.map(() => ({
          target: { x: 0.5, y: 0.5, zoom: 1 },
        })),
      },
    }, onChange);

  if (!camera) {
    return (
      <Section title="Camera (v2)" defaultOpen={false}>
        <p className="mb-3 text-xs text-ink-muted">
          Pan/zoom điện ảnh — viewport di chuyển giữa các bước.
        </p>
        {!readOnly && (
          <Button variant="secondary" size="sm" onClick={enable}>
            + Bật camera track
          </Button>
        )}
      </Section>
    );
  }

  return (
    <Section title="Camera (v2)" defaultOpen={false}>
      <div className="flex flex-col gap-4">
        <div>
          <p className="mb-2 text-xs font-semibold text-ink">Pose khởi đầu</p>
          <CameraPoseFields
            pose={camera.initial}
            disabled={readOnly}
            objects={objects}
            locations={locations}
            onChange={(p) => patchV2(manifest, { camera: { ...camera, initial: p } }, onChange)}
          />
        </div>
        {steps.map((s, i) => (
          <div key={s.id || i} className="rounded-md border border-border p-3">
            <p className="mb-2 text-xs font-semibold text-ink">
              Bước {i + 1}: {s.title || s.id}
            </p>
            <CameraPoseFields
              pose={camera.steps[i]?.target ?? { x: 0.5, y: 0.5, zoom: 1 }}
              disabled={readOnly}
              objects={objects}
              locations={locations}
              onChange={(p) => {
                const next = [...camera.steps];
                while (next.length <= i) {
                  next.push({ target: { x: 0.5, y: 0.5, zoom: 1 } });
                }
                next[i] = { ...(next[i] ?? { target: p }), target: p };
                patchV2(manifest, { camera: { ...camera, steps: next } }, onChange);
              }}
            />
            <div className="mt-2 grid grid-cols-2 gap-2">
              <NumField
                label="Thời lượng (ms)"
                value={camera.steps[i]?.durationMs ?? 1100}
                step={100}
                min={0}
                disabled={readOnly}
                onChange={(d) => {
                  const next = [...camera.steps];
                  while (next.length <= i) next.push({ target: { x: 0.5, y: 0.5, zoom: 1 } });
                  next[i] = { ...(next[i] ?? { target: { x: 0.5, y: 0.5, zoom: 1 } }), durationMs: d };
                  patchV2(manifest, { camera: { ...camera, steps: next } }, onChange);
                }}
              />
              <div className="flex flex-col gap-1">
                <Label>Easing</Label>
                <Select
                  value={camera.steps[i]?.easing ?? "easeInOut"}
                  disabled={readOnly}
                  onChange={(e) => {
                    const next = [...camera.steps];
                    while (next.length <= i) next.push({ target: { x: 0.5, y: 0.5, zoom: 1 } });
                    next[i] = { ...(next[i] ?? { target: { x: 0.5, y: 0.5, zoom: 1 } }), easing: e.target.value };
                    patchV2(manifest, { camera: { ...camera, steps: next } }, onChange);
                  }}
                >
                  {EASINGS.map((e) => (
                    <option key={e} value={e}>{e}</option>
                  ))}
                </Select>
              </div>
            </div>
          </div>
        ))}
        {!readOnly && (
          <Button
            variant="outline"
            size="sm"
            className="self-start"
            onClick={() => patchV2(manifest, { camera: undefined }, onChange)}
          >
            Tắt camera track
          </Button>
        )}
      </div>
    </Section>
  );
}

/* ---------- 5b. Tracks ---------- */

function KeyframeValueEditor({
  track,
  kf,
  disabled,
  onChange,
}: {
  track: ObjectTrack;
  kf: Keyframe;
  disabled?: boolean;
  onChange: (v: unknown) => void;
}) {
  if (track.property === "position") {
    const v = (kf.value ?? { x: 0.5, y: 0.5 }) as { x: number; y: number };
    return (
      <div className="grid grid-cols-2 gap-2">
        <NumField label="x" value={v.x} min={0} max={1} disabled={disabled}
          onChange={(x) => onChange({ ...v, x })} />
        <NumField label="y" value={v.y} min={0} max={1} disabled={disabled}
          onChange={(y) => onChange({ ...v, y })} />
      </div>
    );
  }
  if (track.property === "visible") {
    return (
      <Select
        value={String(kf.value ?? true)}
        disabled={disabled}
        onChange={(e) => onChange(e.target.value === "true")}
      >
        <option value="true">Hiện</option>
        <option value="false">Ẩn</option>
      </Select>
    );
  }
  return (
    <NumField
      label="Giá trị"
      value={typeof kf.value === "number" ? kf.value : 0}
      disabled={disabled}
      onChange={onChange}
    />
  );
}

export function TracksSection({ manifest, readOnly, onChange }: SectionProps) {
  const tracks = manifest.tracks ?? [];
  const objects = manifest.objects ?? [];
  const update = (i: number, patch: Partial<ObjectTrack>) =>
    patchV2(manifest, {
      tracks: tracks.map((t, idx) => (idx === i ? { ...t, ...patch } : t)),
    }, onChange);

  return (
    <Section title={`Chuyển động keyframe (${tracks.length})`} defaultOpen={false}>
      <div className="flex flex-col gap-3">
        <p className="text-xs text-ink-muted">
          Mỗi track gắn một vật thể + một thuộc tính (vị trí/xoay/mờ/hiện ẩn)
          — keyframe theo mốc thời gian tMs tuyệt đối từ đầu cảnh.
        </p>
        {tracks.map((t, i) => (
          <div key={i} className="flex flex-col gap-2 rounded-md border border-border p-3">
            <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
              <div className="flex flex-col gap-1">
                <Label>Vật thể</Label>
                <Select
                  value={t.objectId}
                  disabled={readOnly}
                  onChange={(e) => update(i, { objectId: e.target.value })}
                >
                  <option value="">— chọn —</option>
                  {objects.map((o) => (
                    <option key={o.id} value={o.id}>{o.id}</option>
                  ))}
                </Select>
              </div>
              <div className="flex flex-col gap-1">
                <Label>Thuộc tính</Label>
                <Select
                  value={t.property}
                  disabled={readOnly}
                  onChange={(e) => update(i, { property: e.target.value })}
                >
                  {TRACK_PROPERTIES.map((p) => (
                    <option key={p} value={p}>{p}</option>
                  ))}
                </Select>
              </div>
              {!readOnly && (
                <Button
                  variant="outline"
                  size="sm"
                  className="self-end"
                  onClick={() =>
                    patchV2(manifest, { tracks: tracks.filter((_, x) => x !== i) }, onChange)
                  }
                >
                  Gỡ track
                </Button>
              )}
            </div>
            {(t.keyframes ?? []).map((kf, ki) => (
              <div key={ki} className="flex flex-wrap items-end gap-2 rounded border border-border/60 bg-surface-alt/40 p-2">
                <NumField
                  label="tMs"
                  value={kf.tMs}
                  step={100}
                  min={0}
                  disabled={readOnly}
                  onChange={(tMs) =>
                    update(i, {
                      keyframes: t.keyframes.map((k, x) => (x === ki ? { ...k, tMs } : k)),
                    })
                  }
                />
                <div className="min-w-32 flex-1">
                  <KeyframeValueEditor
                    track={t}
                    kf={kf}
                    disabled={readOnly}
                    onChange={(v) =>
                      update(i, {
                        keyframes: t.keyframes.map((k, x) => (x === ki ? { ...k, value: v } : k)),
                      })
                    }
                  />
                </div>
                <div className="w-28">
                  <Label>Easing</Label>
                  <Select
                    value={kf.easing ?? "easeInOut"}
                    disabled={readOnly}
                    onChange={(e) =>
                      update(i, {
                        keyframes: t.keyframes.map((k, x) =>
                          x === ki ? { ...k, easing: e.target.value } : k,
                        ),
                      })
                    }
                  >
                    {EASINGS.map((e) => (
                      <option key={e} value={e}>{e}</option>
                    ))}
                  </Select>
                </div>
                {!readOnly && (
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() =>
                      update(i, { keyframes: t.keyframes.filter((_, x) => x !== ki) })
                    }
                  >
                    Gỡ
                  </Button>
                )}
              </div>
            ))}
            {!readOnly && (
              <Button
                variant="secondary"
                size="sm"
                className="self-start"
                onClick={() =>
                  update(i, {
                    keyframes: [
                      ...(t.keyframes ?? []),
                      { tMs: 0, value: t.property === "position" ? { x: 0.5, y: 0.5 } : t.property === "visible" ? true : 1 },
                    ],
                  })
                }
              >
                + Keyframe
              </Button>
            )}
          </div>
        ))}
        {!readOnly && (
          <Button
            variant="secondary"
            size="sm"
            className="self-start"
            onClick={() =>
              patchV2(manifest, {
                tracks: [
                  ...tracks,
                  {
                    objectId: objects[0]?.id ?? "",
                    property: "position",
                    keyframes: [{ tMs: 0, value: { x: 0.5, y: 0.5 } }],
                  },
                ],
              }, onChange)
            }
          >
            + Thêm track
          </Button>
        )}
      </div>
    </Section>
  );
}

/* ---------- 5c. Effects ---------- */

export function EffectsSection({ manifest, readOnly, onChange }: SectionProps) {
  const effects = manifest.effects ?? [];
  const steps = manifest.steps;
  const objects = manifest.objects ?? [];
  const update = (i: number, patch: Partial<SceneEffect>) =>
    patchV2(manifest, {
      effects: effects.map((e, idx) => (idx === i ? { ...e, ...patch } : e)),
    }, onChange);

  return (
    <Section title={`Hiệu ứng cảnh (${effects.length})`} defaultOpen={false}>
      <div className="flex flex-col gap-3">
        <p className="text-xs text-ink-muted">
          Overlay typed (sương, glow, gợn nước, fade) — gắn bước hoặc
          ambient cả cảnh khi để trống bước.
        </p>
        {effects.map((e, i) => (
          <div key={i} className="flex flex-col gap-2 rounded-md border border-border p-3">
            <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
              <div className="flex flex-col gap-1">
                <Label>Loại</Label>
                <Select
                  value={e.type}
                  disabled={readOnly}
                  onChange={(ev) => update(i, { type: ev.target.value })}
                >
                  {EFFECT_TYPES_V2.map((t) => (
                    <option key={t} value={t}>{t}</option>
                  ))}
                </Select>
              </div>
              <div className="flex flex-col gap-1">
                <Label>Bước</Label>
                <Select
                  value={e.stepId ?? ""}
                  disabled={readOnly}
                  onChange={(ev) =>
                    update(i, { stepId: ev.target.value || undefined })
                  }
                >
                  <option value="">— ambient (cả cảnh) —</option>
                  {steps.map((s, si) => (
                    <option key={s.id || si} value={s.id}>
                      {si + 1}. {s.title || s.id}
                    </option>
                  ))}
                </Select>
              </div>
              <NumField
                label="durationMs"
                value={e.durationMs ?? 0}
                step={100}
                min={0}
                disabled={readOnly}
                onChange={(d) => update(i, { durationMs: d })}
              />
              <NumField
                label="intensity"
                value={(e.params?.intensity as number) ?? 0.5}
                min={0}
                max={1}
                disabled={readOnly}
                onChange={(v) =>
                  update(i, { params: { ...e.params, intensity: v } })
                }
              />
            </div>
            <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
              <NumField
                label="x"
                value={(e.params?.x as number) ?? 0.5}
                min={0}
                max={1}
                disabled={readOnly}
                onChange={(v) => update(i, { params: { ...e.params, x: v } })}
              />
              <NumField
                label="y"
                value={(e.params?.y as number) ?? 0.5}
                min={0}
                max={1}
                disabled={readOnly}
                onChange={(v) => update(i, { params: { ...e.params, y: v } })}
              />
              {e.type === "GLOW" && (
                <div className="flex flex-col gap-1">
                  <Label>Bám theo vật</Label>
                  <Select
                    value={(e.params?.objectId as string) ?? ""}
                    disabled={readOnly}
                    onChange={(ev) =>
                      update(i, {
                        params: { ...e.params, objectId: ev.target.value || undefined },
                      })
                    }
                  >
                    <option value="">— vị trí cố định —</option>
                    {objects.map((o) => (
                      <option key={o.id} value={o.id}>{o.id}</option>
                    ))}
                  </Select>
                </div>
              )}
              {!readOnly && (
                <Button
                  variant="outline"
                  size="sm"
                  className="self-end"
                  onClick={() =>
                    patchV2(manifest, { effects: effects.filter((_, x) => x !== i) }, onChange)
                  }
                >
                  Gỡ
                </Button>
              )}
            </div>
          </div>
        ))}
        {!readOnly && (
          <Button
            variant="secondary"
            size="sm"
            className="self-start"
            onClick={() =>
              patchV2(manifest, {
                effects: [...effects, { type: "MIST", params: { intensity: 0.4 } }],
              }, onChange)
            }
          >
            + Thêm hiệu ứng
          </Button>
        )}
      </div>
    </Section>
  );
}

/* ---------- 5d. Audio ---------- */

export function AudioSection({ manifest, readOnly, onChange }: SectionProps) {
  const cues = manifest.audio ?? [];
  const steps = manifest.steps;
  const audioAssets = (manifest.assets ?? []).filter((a) => a.role === "AUDIO");
  const update = (i: number, patch: Partial<AudioCue>) =>
    patchV2(manifest, {
      audio: cues.map((c, idx) => (idx === i ? { ...c, ...patch } : c)),
    }, onChange);

  return (
    <Section title={`Âm thanh theo bước (${cues.length})`} defaultOpen={false}>
      <div className="flex flex-col gap-3">
        <p className="text-xs text-ink-muted">
          Cue ENTER/EXIT/LOOP gắn bước — cần asset vai trò AUDIO trong
          mục Hình ảnh & tư liệu.
        </p>
        {audioAssets.length === 0 && (
          <p className="rounded-md border border-amber-300 bg-amber-50 px-3 py-2 text-xs text-amber-800">
            Chưa có asset vai trò AUDIO — thêm ở mục Hình ảnh & tư liệu trước.
          </p>
        )}
        {cues.map((c, i) => (
          <div key={i} className="grid grid-cols-2 gap-2 rounded-md border border-border p-3 sm:grid-cols-5">
            <div className="flex flex-col gap-1">
              <Label>Bước</Label>
              <Select
                value={c.stepId}
                disabled={readOnly}
                onChange={(e) => update(i, { stepId: e.target.value })}
              >
                {steps.map((s, si) => (
                  <option key={s.id || si} value={s.id}>
                    {si + 1}. {s.title || s.id}
                  </option>
                ))}
              </Select>
            </div>
            <div className="flex flex-col gap-1">
              <Label>Asset</Label>
              <Select
                value={c.assetRef}
                disabled={readOnly}
                onChange={(e) => update(i, { assetRef: e.target.value })}
              >
                <option value="">— chọn —</option>
                {audioAssets.map((a) => (
                  <option key={a.id} value={a.id}>{a.id}</option>
                ))}
              </Select>
            </div>
            <div className="flex flex-col gap-1">
              <Label>Cue</Label>
              <Select
                value={c.cue}
                disabled={readOnly}
                onChange={(e) => update(i, { cue: e.target.value })}
              >
                {AUDIO_CUES.map((k) => (
                  <option key={k} value={k}>{k}</option>
                ))}
              </Select>
            </div>
            <NumField
              label="Volume"
              value={c.volume ?? 1}
              min={0}
              max={1}
              disabled={readOnly}
              onChange={(v) => update(i, { volume: v })}
            />
            {!readOnly && (
              <Button
                variant="outline"
                size="sm"
                className="self-end"
                onClick={() =>
                  patchV2(manifest, { audio: cues.filter((_, x) => x !== i) }, onChange)
                }
              >
                Gỡ
              </Button>
            )}
          </div>
        ))}
        {!readOnly && audioAssets.length > 0 && (
          <Button
            variant="secondary"
            size="sm"
            className="self-start"
            onClick={() =>
              patchV2(manifest, {
                audio: [
                  ...cues,
                  {
                    stepId: steps[0]?.id ?? "",
                    assetRef: audioAssets[0]?.id ?? "",
                    cue: "ENTER",
                    volume: 0.8,
                  },
                ],
              }, onChange)
            }
          >
            + Thêm cue
          </Button>
        )}
      </div>
    </Section>
  );
}

/* ---------- 5e. Environment (RIVER only) ---------- */

export function EnvironmentSection({ manifest, readOnly, onChange }: SectionProps) {
  const env = manifest.environment;

  if (!env) {
    return (
      <Section title="Môi trường (v2 · RIVER)" defaultOpen={false}>
        <p className="mb-3 text-xs text-ink-muted">
          Mực nước nền + sương + glow ambient — áp xuyên suốt cảnh.
        </p>
        {!readOnly && (
          <Button
            variant="secondary"
            size="sm"
            onClick={() =>
              patchV2(manifest, { environment: { mist: 0.3 } }, onChange)
            }
          >
            + Bật môi trường
          </Button>
        )}
      </Section>
    );
  }

  return (
    <Section title="Môi trường (v2 · RIVER)" defaultOpen={false}>
      <div className="grid grid-cols-3 gap-3">
        <NumField
          label="Mực nước nền"
          value={env.waterLevel ?? 0.3}
          min={0}
          max={1}
          disabled={readOnly}
          onChange={(v) =>
            patchV2(manifest, { environment: { ...env, waterLevel: v } }, onChange)
          }
        />
        <NumField
          label="Sương (mist)"
          value={env.mist ?? 0}
          min={0}
          max={1}
          disabled={readOnly}
          onChange={(v) =>
            patchV2(manifest, { environment: { ...env, mist: v } }, onChange)
          }
        />
        <NumField
          label="Glow ambient"
          value={env.glow ?? 0}
          min={0}
          max={1}
          disabled={readOnly}
          onChange={(v) =>
            patchV2(manifest, { environment: { ...env, glow: v } }, onChange)
          }
        />
      </div>
      {!readOnly && (
        <Button
          variant="outline"
          size="sm"
          className="mt-3"
          onClick={() => patchV2(manifest, { environment: undefined }, onChange)}
        >
          Tắt môi trường
        </Button>
      )}
    </Section>
  );
}
