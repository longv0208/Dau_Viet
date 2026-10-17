import type { Activity } from "../builder/draft-model";
import {
  CerActivityView,
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
  REFLECTION_PROMPT: "Suy ngẫm",
};

export function activityLabel(type: string): string {
  return ACTIVITY_LABELS[type] ?? type;
}

/**
 * Dispatches to the per-type preview renderer. The activity comes from the
 * POST /preview projection — validation/evidenceRefs/requiredEvidenceIds and
 * every LEARNER_HIDDEN_KEYS leaf have already been stripped server-side, so
 * renderers simply read `config` fields and never see answer keys.
 */
export function ActivityRenderer({ activity }: { activity: Activity }) {
  switch (activity.type) {
    case "READ":
      return <ReadActivityView activity={activity} />;
    case "VIEW_IMAGE":
      return <ViewImageActivityView activity={activity} />;
    case "MULTIPLE_CHOICE":
      return <MultipleChoiceActivityView activity={activity} />;
    case "EVIDENCE_SELECT":
      return <EvidenceSelectActivityView activity={activity} />;
    case "MATCHING":
      return <MatchingActivityView activity={activity} />;
    case "REASONING_CONNECT":
      return <ReasoningConnectActivityView activity={activity} />;
    case "HYPOTHESIS_CHOICE":
      return <HypothesisChoiceActivityView activity={activity} />;
    case "DRAG_ORDER":
      return <DragOrderActivityView activity={activity} />;
    case "VERIFICATION":
      return <VerificationActivityView activity={activity} />;
    case "CER":
      return <CerActivityView activity={activity} />;
    case "REFLECTION_PROMPT":
      return <ReflectionPromptActivityView activity={activity} />;
    default:
      return <UnsupportedActivity activity={activity} />;
  }
}
