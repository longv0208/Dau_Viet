import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import { EmptyState } from "../empty-state";
import { PageHeader } from "../page-header";
import { StatusChip } from "../status-chip";
import {
  ChapterBadge,
  ClueTag,
  EmptyStateCard,
  PaperCard,
  RareFrame,
  SectionDivider,
  SectionEyebrow,
  StampSeal,
} from "./index";

describe("Design System v3 Atoms & Core Components", () => {
  it("renders SectionEyebrow with color variants", () => {
    render(<SectionEyebrow color="jade">DI SẢN</SectionEyebrow>);
    const el = screen.getByText("DI SẢN");
    expect(el).toHaveClass("border-jade", "shadow-pixel-sm");
  });

  it("renders ChapterBadge and StampSeal", () => {
    render(
      <>
        <ChapterBadge label="01" />
        <StampSeal label="ĐÃ DUYỆT" variant="success" />
      </>,
    );
    expect(screen.getByText("01")).toHaveClass("font-pixel", "text-chapter");
    expect(screen.getByText("ĐÃ DUYỆT")).toBeInTheDocument();
  });

  it("renders PaperCard, ClueTag, RareFrame, EmptyStateCard, and SectionDivider", () => {
    render(
      <div>
        <PaperCard usePixelShadow>Nội dung thẻ giấy</PaperCard>
        <ClueTag label="Manh mối" color="gold" />
        <RareFrame rarity="epic">Vật phẩm sử thi</RareFrame>
        <EmptyStateCard title="Trống" description="Chưa có mục nào" />
        <SectionDivider eyebrow="PHẦN 1" title="Tiêu đề phần" />
      </div>,
    );
    expect(screen.getByText("Nội dung thẻ giấy")).toHaveClass("bg-surface-alt", "shadow-pixel");
    expect(screen.getByText("Manh mối")).toBeInTheDocument();
    expect(screen.getByText("Vật phẩm sử thi")).toBeInTheDocument();
    expect(screen.getByText("Trống")).toHaveClass("font-display");
    expect(screen.getByText("Tiêu đề phần")).toHaveClass("text-chapter");
  });

  it("applies v3 tokens to PageHeader, EmptyState, and StatusChip", () => {
    render(
      <div>
        <PageHeader eyebrow="QUẢN TRỊ" title="Sự kiện lịch sử" description="Mô tả" />
        <EmptyState title="Chưa có sự kiện" />
        <StatusChip status="DRAFT" />
        <StatusChip status="PUBLISHED" />
        <StatusChip status="ARCHIVED" />
      </div>,
    );
    expect(screen.getByText("QUẢN TRỊ")).toBeInTheDocument();
    expect(screen.getByText("Chưa có sự kiện")).toHaveClass("font-display");
    expect(screen.getByText("Bản nháp")).toHaveClass("bg-gold-dark/20", "border-gold-dark");
    expect(screen.getByText("Đã xuất bản")).toHaveClass("bg-jade/15", "text-jade-dark", "border-jade");
    expect(screen.getByText("Đã lưu trữ")).toHaveClass("bg-surface-alt", "border-border");
  });
});
