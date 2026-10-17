import type { Activity } from "../../builder/draft-model";

/** Props every preview renderer receives — activity is the projection node. */
export interface PreviewActivityProps {
  activity: Activity;
}
