"use client";

import { useEffect, useState } from "react";

import { fetchAssetBlob } from "./asset-api";

/**
 * Load an authenticated asset's bytes through the BFF proxy (attaches the
 * in-memory Bearer token + single-flight refresh on 401), then expose a
 * temporary `blob:` object URL for <img>. Revoked on unmount / contentUrl
 * change — never leaks object URLs, never puts tokens in URLs.
 */
export function useAssetObjectUrl(contentUrl: string | null | undefined): {
  src: string | null;
  loading: boolean;
  error: boolean;
} {
  const [state, setState] = useState<{ src: string | null; loading: boolean; error: boolean }>({
    src: null,
    loading: Boolean(contentUrl),
    error: false,
  });

  useEffect(() => {
    if (!contentUrl) {
      setState({ src: null, loading: false, error: false });
      return;
    }
    let cancelled = false;
    let objectUrl: string | null = null;
    setState({ src: null, loading: true, error: false });

    fetchAssetBlob(contentUrl)
      .then((blob) => {
        if (cancelled) return;
        objectUrl = URL.createObjectURL(blob);
        setState({ src: objectUrl, loading: false, error: false });
      })
      .catch(() => {
        if (!cancelled) setState({ src: null, loading: false, error: true });
      });

    return () => {
      cancelled = true;
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [contentUrl]);

  return state;
}
