import { ForbiddenState } from "@/components/forbidden-state";

/** 403 route — reachable via router.push or a direct hit. */
export default function ForbiddenPage() {
  return <ForbiddenState />;
}
