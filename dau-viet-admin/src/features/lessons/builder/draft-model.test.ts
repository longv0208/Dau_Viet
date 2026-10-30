import { describe, expect, it } from "vitest";

import {
  ACTIVITY_TYPES,
  allIds,
  defaultFeedbackForActivity,
  parseDraft,
  serializeDraft,
} from "./draft-model";
import { validateDraftLocally } from "./draft-local-validator";

describe("parseDraft", () => {
  it("parses empty/missing draft to empty stages with schemaVersion=1", () => {
    for (const raw of ["{}", "", null, undefined, "  "]) {
      const d = parseDraft(raw);
      expect(d.stages).toEqual([]);
      expect(d.schemaVersion).toBe(1);
    }
  });

  it("throws DraftParseError on non-object JSON", () => {
    expect(() => parseDraft("[1,2]")).toThrowError(/JSON object/);
    expect(() => parseDraft("123")).toThrowError(/JSON object/);
    expect(() => parseDraft("{bad")).toThrowError(/JSON hợp lệ/);
  });

  it("round-trips unknown top-level + stage + activity keys", () => {
    const src = JSON.stringify({
      schemaVersion: 1,
      objectives: ["obj"],
      futureField: { nested: true },
      stages: [
        {
          id: "s1",
          type: "CONTEXT",
          title: "T",
          unknownStageKey: 42,
          activities: [
            {
              id: "a1",
              type: "READ",
              config: { text: "x", futureCfg: [1] },
              weird: "kept",
            },
          ],
        },
      ],
    });
    const d = parseDraft(src);
    const out = JSON.parse(serializeDraft(d));
    expect(out.futureField).toEqual({ nested: true });
    expect(out.stages[0].unknownStageKey).toBe(42);
    expect(out.stages[0].activities[0].weird).toBe("kept");
    expect(out.stages[0].activities[0].config.futureCfg).toEqual([1]);
  });

  it("defaults missing stage.activities to []", () => {
    const d = parseDraft(JSON.stringify({ stages: [{ id: "s", type: "CONTEXT" }] }));
    expect(d.stages[0]!.activities).toEqual([]);
  });

  it("normalizes stages and activities to required=true and pre-populates default feedback", () => {
    const d = parseDraft(
      JSON.stringify({
        stages: [
          {
            id: "s1",
            type: "EVIDENCE",
            required: false,
            activities: [
              {
                id: "a1",
                type: "EVIDENCE_SELECT",
                required: false,
                config: {
                  visibleEvidenceIds: ["e1"],
                  acceptedEvidenceIds: ["e1"],
                },
              },
              {
                id: "a2",
                type: "MULTIPLE_CHOICE",
                feedback: { COMPLETED: "Tùy chỉnh của quản trị viên" },
                config: {
                  question: "Câu hỏi?",
                  options: [
                    { id: "o1", label: "A" },
                    { id: "o2", label: "B" },
                  ],
                  correctOptionIds: ["o1"],
                },
              },
            ],
          },
        ],
        completion: { requireAllRequiredStages: false },
      }),
    );
    expect(d.stages[0]!.required).toBe(true);
    expect(d.completion?.requireAllRequiredStages).toBe(true);
    const evAct = d.stages[0]!.activities[0]!;
    expect(evAct.required).toBe(true);
    expect(evAct.config?.graded).toBe(true);
    expect(evAct.feedback).toMatchObject({
      COMPLETED: expect.any(String),
      PARTIAL: expect.any(String),
      INCORRECT: expect.any(String),
      EXHAUSTED: expect.any(String),
    });
    const mcAct = d.stages[0]!.activities[1]!;
    expect(mcAct.required).toBe(true);
    expect(mcAct.feedback?.COMPLETED).toBe("Tùy chỉnh của quản trị viên");
    expect(mcAct.feedback?.INCORRECT).toBeTruthy();
    expect(mcAct.feedback?.EXHAUSTED).toBeTruthy();
    expect(validateDraftLocally(d)).toEqual([]);
  });

  it("provides valid defaultFeedbackForActivity for every ActivityType", () => {
    for (const type of ACTIVITY_TYPES) {
      const fb = defaultFeedbackForActivity(type);
      expect(fb.COMPLETED?.trim().length).toBeGreaterThan(0);
      expect(fb.INCORRECT?.trim().length).toBeGreaterThan(0);
    }
    const verFb = defaultFeedbackForActivity("VERIFICATION");
    expect(Object.keys(verFb)).toEqual(
      expect.arrayContaining([
        "COMPLETED",
        "INCORRECT",
        "PARTIAL",
        "SUPPORTED",
        "CONTRADICTED",
        "EXHAUSTED",
      ]),
    );
  });
});

describe("allIds", () => {
  it("collects stage + activity ids", () => {
    const d = parseDraft(
      JSON.stringify({
        stages: [{ id: "s1", type: "CONTEXT", activities: [{ id: "a1" }, { id: "a2" }] }],
      }),
    );
    expect(allIds(d).sort()).toEqual(["a1", "a2", "s1"]);
  });
});
