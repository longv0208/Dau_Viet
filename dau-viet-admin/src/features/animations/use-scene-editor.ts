"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import { qk } from "@/lib/query-keys";
import { ApiClientError } from "@/lib/api-error";

import { animationApi } from "./animation-api";
import type { AnimationManifest, AnimationSceneDetail } from "./animation-types";

/** Parse draftJson an toàn — hỏng/empty → null (caller seed manifest). */
export function parseDraft(detail: AnimationSceneDetail | undefined): AnimationManifest | null {
  if (!detail?.draftJson) return null;
  try {
    const parsed = JSON.parse(detail.draftJson) as AnimationManifest;
    return parsed && typeof parsed === "object" ? parsed : null;
  } catch {
    return null;
  }
}

/**
 * State trung tâm của Scene Editor: giữ manifest cục bộ + lưu tay qua
 * PATCH (đồng title/draftJson/expectedRowVersion trong một request).
 * KHÔNG auto-save: soạn cảnh là việc có chủ đích — bấm "Lưu nháp" rõ
 * ràng tránh ghi đè nhầm khi 2 tab cùng mở (optimistic lock báo 409).
 */
export function useSceneEditor(sceneId: string) {
  const qc = useQueryClient();
  const scene = useQuery({
    queryKey: qk.animationScenes.detail(sceneId),
    queryFn: () => animationApi.getScene(sceneId),
  });

  const [manifest, setManifest] = useState<AnimationManifest | null>(null);
  const [title, setTitle] = useState("");
  const [eventId, setEventId] = useState<string | null>(null);
  const [dirty, setDirty] = useState(false);
  const loadedFor = useRef<string | null>(null);

  // Seed local state một lần khi scene load xong — sau đó user sửa local,
  // không để refetch ghi đè phần đang gõ.
  useEffect(() => {
    if (!scene.data || loadedFor.current === scene.data.id) return;
    loadedFor.current = scene.data.id;
    setTitle(scene.data.title);
    setEventId(scene.data.eventId);
    setManifest(parseDraft(scene.data));
  }, [scene.data]);

  const updateManifest = useCallback((patch: Partial<AnimationManifest>) => {
    setManifest((m) => (m ? { ...m, ...patch } : m));
    setDirty(true);
  }, []);

  const save = useMutation({
    mutationFn: () => {
      if (!scene.data || !manifest) throw new Error("Chưa tải xong cảnh.");
      return animationApi.updateScene(sceneId, {
        title,
        eventId: eventId ?? undefined,
        clearEvent: eventId === null,
        draftJson: JSON.stringify(manifest),
        expectedRowVersion: scene.data.rowVersion,
      });
    },
    onSuccess: (fresh) => {
      setDirty(false);
      qc.setQueryData(qk.animationScenes.detail(sceneId), fresh);
    },
  });

  const conflict = save.error instanceof ApiClientError && save.error.status === 409;

  const versions = useQuery({
    queryKey: qk.animationScenes.versions(sceneId),
    queryFn: () => animationApi.listVersions(sceneId),
  });

  const rendererCode = manifest?.rendererCode ?? "";
  const readOnly = scene.data?.status === "ARCHIVED";

  return useMemo(
    () => ({
      scene: scene.data,
      loading: scene.isPending,
      error: scene.error,
      manifest,
      setManifest: updateManifest,
      replaceManifest: (m: AnimationManifest) => {
        setManifest(m);
        setDirty(true);
      },
      title,
      setTitle: (t: string) => {
        setTitle(t);
        setDirty(true);
      },
      eventId,
      setEventId: (id: string | null) => {
        setEventId(id);
        setDirty(true);
      },
      dirty,
      readOnly,
      save,
      conflict,
      versions: versions.data ?? [],
      rendererCode,
      refetch: scene.refetch,
    }),
    [scene, manifest, updateManifest, title, eventId, dirty, readOnly, save, conflict, versions.data, rendererCode],
  );
}
