-- Dấu Việt | V52 | Update HISTORY_INVESTIGATION preset to Issue #35 6-stage chain
-- Idempotent: keyed UPDATE on the stable template code.
UPDATE lesson_templates
SET
    description = 'Khung bài học sáu giai đoạn (Issue #35): bối cảnh → khám phá dấu vết → giả thuyết → kiểm chứng → tái dựng → kết luận CER.',
    preset_json = '{
      "schemaVersion": 1,
      "stages": [
        {
          "id": "context",
          "type": "CONTEXT",
          "title": "Bối cảnh lịch sử",
          "required": true,
          "activities": [],
          "nextStageIds": ["discovery"]
        },
        {
          "id": "discovery",
          "type": "DISCOVERY",
          "title": "Khám phá 4 dấu vết",
          "required": true,
          "activities": [],
          "nextStageIds": ["evidence"]
        },
        {
          "id": "evidence",
          "type": "EVIDENCE",
          "title": "Thu thập bằng chứng",
          "required": true,
          "activities": [],
          "nextStageIds": ["hypothesis"]
        },
        {
          "id": "hypothesis",
          "type": "HYPOTHESIS",
          "title": "Đặt giả thuyết",
          "required": true,
          "activities": [],
          "nextStageIds": ["verification"]
        },
        {
          "id": "verification",
          "type": "VERIFICATION",
          "title": "Kiểm chứng bằng chứng",
          "required": true,
          "activities": [],
          "nextStageIds": ["reconstruction"]
        },
        {
          "id": "reconstruction",
          "type": "RECONSTRUCTION",
          "title": "Dựng lại sự kiện",
          "required": true,
          "activities": [],
          "nextStageIds": ["conclusion"]
        },
        {
          "id": "conclusion",
          "type": "CONCLUSION",
          "title": "Kết luận CER",
          "required": true,
          "activities": [],
          "nextStageIds": []
        }
      ],
      "completion": {
        "requireAllRequiredStages": true
      }
    }'::jsonb
WHERE code = 'HISTORY_INVESTIGATION';
