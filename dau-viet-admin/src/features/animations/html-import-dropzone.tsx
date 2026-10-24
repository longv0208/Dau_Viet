"use client";

import { useCallback, useRef, useState } from "react";

import { Button } from "@/components/ui/button";

const MAX_BYTES = 15 * 1024 * 1024;

/**
 * Khu vực kéo-thả / chọn file .html self-contained. Kiểm tra phía client:
 * đuôi .html/.htm + ≤15MB — kiểm tra an toàn thật nằm ở backend
 * (HtmlDocumentValidator). Gọi onFile khi file hợp lệ.
 */
export function HtmlImportDropzone({
  onFile,
  disabled,
}: {
  onFile: (file: File) => void;
  disabled?: boolean;
}) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [dragOver, setDragOver] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const accept = useCallback(
    (file: File | undefined) => {
      if (!file) return;
      if (!/\.html?$/i.test(file.name)) {
        setError("Chỉ chấp nhận tệp .html — không phải ZIP hay thư mục.");
        return;
      }
      if (file.size > MAX_BYTES) {
        setError(
          `Tệp vượt ${MAX_BYTES / (1024 * 1024)} MB — hãy nén media trong file hoặc tách nội dung.`,
        );
        return;
      }
      setError(null);
      onFile(file);
    },
    [onFile],
  );

  return (
    <div className="flex flex-col gap-2">
      <div
        role="button"
        tabIndex={0}
        aria-disabled={disabled}
        onDragOver={(e) => {
          e.preventDefault();
          if (!disabled) setDragOver(true);
        }}
        onDragLeave={() => setDragOver(false)}
        onDrop={(e) => {
          e.preventDefault();
          setDragOver(false);
          if (!disabled) accept(e.dataTransfer.files?.[0]);
        }}
        onClick={() => !disabled && inputRef.current?.click()}
        onKeyDown={(e) => {
          if (!disabled && (e.key === "Enter" || e.key === " ")) {
            e.preventDefault();
            inputRef.current?.click();
          }
        }}
        className={`flex min-h-[140px] cursor-pointer flex-col items-center justify-center gap-2 rounded-lg border-2 border-dashed px-4 py-6 text-center transition-colors ${
          dragOver
            ? "border-primary bg-primary/5"
            : "border-border bg-surface-alt hover:border-primary/60"
        } ${disabled ? "cursor-not-allowed opacity-60" : ""}`}
      >
        <p className="text-sm font-medium text-ink">
          Kéo thả tệp .html vào đây
        </p>
        <p className="text-xs text-ink-muted">
          Một tệp HTML tự chứa (CSS/JS/media nhúng sẵn), tối đa 15 MB — không
          tải tài nguyên từ Internet.
        </p>
        <Button type="button" variant="outline" size="sm" disabled={disabled}>
          Chọn tệp…
        </Button>
        <input
          ref={inputRef}
          type="file"
          accept=".html,.htm,text/html"
          className="hidden"
          disabled={disabled}
          onChange={(e) => {
            accept(e.target.files?.[0]);
            e.target.value = "";
          }}
        />
      </div>
      {error && (
        <p role="alert" className="text-xs text-error">
          {error}
        </p>
      )}
    </div>
  );
}
