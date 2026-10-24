import type { Activity } from "../builder/draft-model";
import {
  CerActivityView,
  CerChoiceActivityView,
  VerificationActivityView,
} from "./renderers/assessment-renderers";
import {
  HypothesisChoiceActivityView,
  MultipleChoiceActivityView,
} from "./renderers/choice-renderers";
import {
  DragOrderActivityView,
  EvidenceSelectActivityView,
  MatchingActivityView,
  ReasoningConnectActivityView,
} from "./renderers/interaction-renderers";
import {
  ReadActivityView,
  ReflectionPromptActivityView,
  ViewImageActivityView,
} from "./renderers/text-renderers";
import type { EmbeddedAsset, EmbeddedEvidence } from "./renderers/types";
import { UnsupportedActivity } from "./unsupported-activity";

const ACTIVITY_LABELS: Record<string, string> = {
  READ: "Đọc tư liệu",
  VIEW_IMAGE: "Quan sát hình ảnh",
  MULTIPLE_CHOICE: "Trắc nghiệm",
  EXPLORE_MAP: "Khám phá bản đồ",
  EVIDENCE_SELECT: "Chọn bằng chứng",
  MATCHING: "Ghép nối",
  REASONING_CONNECT: "Nối suy luận",
  HYPOTHESIS_CHOICE: "Chọn giả thuyết",
  DRAG_ORDER: "Sắp xếp thứ tự",
  VERIFICATION: "Kiểm chứng",
  CER: "Luận điểm – Bằng chứng – Lập luận",
  CER_CHOICE: "Kết luận có dẫn chứng (chọn)",
  REFLECTION_PROMPT: "Suy ngẫm",
};

export function activityLabel(type: string): string {
  return ACTIVITY_LABELS[type] ?? "—";
}

/**
 * Dispatches to the per-type preview renderer. The activity comes from the
 * POST /preview projection — validation/evidenceRefs/requiredEvidenceIds and
 * every LEARNER_HIDDEN_KEYS leaf have already been stripped server-side, so
 * renderers simply read `config` fields and never see answer keys.
 * `evidence`/`assets` carry the denormalized documents embedded in the
 * lesson content so renderers can resolve ids to titles/sources.
 */
export function ActivityRenderer({
  activity,
  evidence,
  assets,
}: {
  activity: Activity;
  evidence?: EmbeddedEvidence[];
  assets?: EmbeddedAsset[];
}) {
  const props = { activity, evidence, assets };
  switch (activity.type) {
    case "READ":
      return <ReadActivityView {...props} />;
    case "VIEW_IMAGE":
      return <ViewImageActivityView {...props} />;
    case "MULTIPLE_CHOICE":
      return <MultipleChoiceActivityView {...props} />;
    case "EVIDENCE_SELECT":
      return <EvidenceSelectActivityView {...props} />;
    case "MATCHING":
      return <MatchingActivityView {...props} />;
    case "REASONING_CONNECT":
      return <ReasoningConnectActivityView {...props} />;
    case "HYPOTHESIS_CHOICE":
      return <HypothesisChoiceActivityView {...props} />;
    case "DRAG_ORDER":
      return <DragOrderActivityView {...props} />;
    case "VERIFICATION":
      return <VerificationActivityView {...props} />;
    case "CER":
      return <CerActivityView {...props} />;
    case "CER_CHOICE":
      return <CerChoiceActivityView {...props} />;
    case "REFLECTION_PROMPT":
      return <ReflectionPromptActivityView {...props} />;
    default:
      return <UnsupportedActivity activity={activity} />;
  }
}
