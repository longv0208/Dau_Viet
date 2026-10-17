-- Dấu Việt MVP | V7 | Default lesson template seed.
-- Inserts the "Điều tra sự kiện lịch sử" skeleton so admins always have a
-- working starting point. Idempotent: keyed on the stable template code.
INSERT INTO lesson_templates (id, code, name, description, schema_version, preset_json, enabled)
SELECT
    gen_random_uuid(),
    'dieu-tra-su-kien-lich-su',
    'Điều tra sự kiện lịch sử',
    'Khung 4 giai đoạn: bối cảnh, điều tra bằng chứng, tái dựng diễn biến, lập luận kết luận.',
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
      ]
    }'::jsonb,
    TRUE
WHERE NOT EXISTS (
    SELECT 1 FROM lesson_templates WHERE code = 'dieu-tra-su-kien-lich-su'
);
