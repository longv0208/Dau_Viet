import { z } from "zod";

export const evidenceFormSchema = z.object({
  eventId: z.string().min(1, "Vui lòng chọn sự kiện"),
  title: z.string().min(1, "Vui lòng nhập tiêu đề").max(255),
  evidenceType: z.string().min(1, "Vui lòng chọn loại bằng chứng").max(48),
  description: z.string().optional().or(z.literal("")),
  sourceTitle: z.string().min(1, "Bắt buộc để chứng thực").max(255),
  sourceAuthor: z.string().max(255).optional().or(z.literal("")),
  sourceUrl: z.string().optional().or(z.literal("")),
  sourceCitation: z.string().optional().or(z.literal("")),
  sourcePublishedAt: z.string().optional().or(z.literal("")),
  reliability: z.string().optional().or(z.literal("")),
  relevance: z.string().optional().or(z.literal("")),
});

export type EvidenceFormValues = z.infer<typeof evidenceFormSchema>;
