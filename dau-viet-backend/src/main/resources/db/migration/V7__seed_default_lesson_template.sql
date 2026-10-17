-- Dấu Việt MVP | V7 | Default reusable lesson template seed.
-- "Điều tra sự kiện lịch sử" skeleton so admins always have a working
-- starting point. Idempotent: keyed on the stable template code.
INSERT INTO lesson_templates (
    id,
    code,
    name,
    description,
    schema_version,
    preset_json,
    enabled
)
VALUES (
    'd7a00000-0000-4000-8000-000000000001'::uuid,
    'HISTORY_INVESTIGATION',
    'Điều tra sự kiện lịch sử',
    'Khung bài học gồm bốn giai đoạn: bối cảnh, bằng chứng, tái dựng và kết luận.',
    1,
    '{
      "schemaVersion": 1,
      "stages": [
        {
          "id": "context",
          "type": "CONTEXT",
          "title": "Bối cảnh lịch sử",
          "required": true,
          "activities": [],
          "nextStageIds": ["evidence"]
        },
        {
          "id": "evidence",
          "type": "EVIDENCE",
          "title": "Điều tra bằng chứng",
          "required": true,
          "activities": [],
          "nextStageIds": ["reconstruction"]
        },
        {
          "id": "reconstruction",
          "type": "RECONSTRUCTION",
          "title": "Tái dựng diễn biến",
          "required": true,
          "activities": [],
          "nextStageIds": ["conclusion"]
        },
        {
          "id": "conclusion",
          "type": "CONCLUSION",
          "title": "Lập luận và kết luận",
          "required": true,
          "activities": [],
          "nextStageIds": []
        }
      ],
      "completion": {
        "requireAllRequiredStages": true
      }
    }'::jsonb,
    true
)
ON CONFLICT (code) DO NOTHING;
