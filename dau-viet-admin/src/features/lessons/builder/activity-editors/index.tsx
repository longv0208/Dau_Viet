import type { ComponentType } from "react";

import type { ActivityType } from "../draft-model";
import { CerEditor } from "./cer-editor";
import { CerChoiceEditor } from "./cer-choice-editor";
import { DragOrderEditor } from "./drag-order-editor";
import { EvidenceSelectEditor } from "./evidence-select-editor";
import { HypothesisChoiceEditor } from "./hypothesis-choice-editor";
import { MatchingEditor } from "./matching-editor";
import { MultipleChoiceEditor } from "./multiple-choice-editor";
import { ReadEditor } from "./read-editor";
import { ReasoningConnectEditor } from "./reasoning-connect-editor";
import { ReflectionPromptEditor } from "./reflection-prompt-editor";
import type { EditorProps } from "./shared-fields";
import { UnsupportedEditor } from "./unsupported-editor";
import { VerificationEditor } from "./verification-editor";
import { ViewImageEditor } from "./view-image-editor";

/**
 * Registry loại hoạt động → trình soạn. Loại chưa hỗ trợ dùng
 * UnsupportedEditor — không bao giờ âm thầm ghi cấu hình sai.
 */
const EDITORS: Partial<Record<ActivityType, ComponentType<EditorProps>>> = {
  READ: ReadEditor,
  VIEW_IMAGE: ViewImageEditor,
  MULTIPLE_CHOICE: MultipleChoiceEditor,
  EVIDENCE_SELECT: EvidenceSelectEditor,
  MATCHING: MatchingEditor,
  DRAG_ORDER: DragOrderEditor,
  CER: CerEditor,
  CER_CHOICE: CerChoiceEditor,
  REFLECTION_PROMPT: ReflectionPromptEditor,
  HYPOTHESIS_CHOICE: HypothesisChoiceEditor,
  VERIFICATION: VerificationEditor,
  REASONING_CONNECT: ReasoningConnectEditor,
};

export function ActivityEditor(props: EditorProps) {
  const Editor = EDITORS[props.activity.type] ?? UnsupportedEditor;
  return <Editor {...props} />;
}
