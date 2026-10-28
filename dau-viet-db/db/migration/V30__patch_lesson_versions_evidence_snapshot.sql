-- Patch lesson_versions.snapshot_json cho các lesson V29 bị thiếu evidence[]/assets[].
-- Replicate SnapshotBuilder.embedEvidence / embedAssets ở SQL level.
-- Idempotent: chạy lại vẫn cho cùng kết quả (snapshot_json được ghi đè).
--
-- NOTE: trigger trg_lesson_versions_immutable (V3) chặn mọi UPDATE/DELETE trên
-- lesson_versions để đảm bảo snapshot bất biến. Vá dữ liệu này là một lần
-- migration có kiểm soát nên ta vô hiệu hoá trigger trong phạm vi transaction
-- Flyway rồi bật lại ngay sau đó.

ALTER TABLE lesson_versions DISABLE TRIGGER trg_lesson_versions_immutable;

WITH RECURSIVE
-- Collect evidence ids từ mọi field tham chiếu (giống SnapshotBuilder.collectEvidenceIds).
cfg_evidence AS (
  SELECT
    lv.id AS version_id,
    t.ev_id::uuid AS evidence_id
  FROM lesson_versions lv
  CROSS JOIN LATERAL (
    SELECT value #>> '{}' AS ev_id
    FROM lesson_versions lv2,
      jsonb_path_query(lv2.snapshot_json, '$.stages[*].activities[*].config.visibleEvidenceIds[*]') AS j(value)
    WHERE lv2.id = lv.id
    UNION ALL
    SELECT value #>> '{}'
    FROM lesson_versions lv2,
      jsonb_path_query(lv2.snapshot_json, '$.stages[*].activities[*].config.requiredEvidenceIds[*]') AS j(value)
    WHERE lv2.id = lv.id
    UNION ALL
    SELECT value #>> '{}'
    FROM lesson_versions lv2,
      jsonb_path_query(lv2.snapshot_json, '$.stages[*].activities[*].config.acceptedEvidenceIds[*]') AS j(value)
    WHERE lv2.id = lv.id
    UNION ALL
    SELECT value #>> '{}'
    FROM lesson_versions lv2,
      jsonb_path_query(lv2.snapshot_json, '$.stages[*].activities[*].config.visibleSourceIds[*]') AS j(value)
    WHERE lv2.id = lv.id
    UNION ALL
    SELECT value->>'id'
    FROM lesson_versions lv2,
      jsonb_path_query(lv2.snapshot_json, '$.stages[*].activities[*].config.evidenceOptions[*]') AS j(value)
    WHERE lv2.id = lv.id
    UNION ALL
    SELECT value #>> '{}'
    FROM lesson_versions lv2,
      jsonb_path_query(lv2.snapshot_json, '$.stages[*].requiredEvidenceIds[*]') AS j(value)
    WHERE lv2.id = lv.id
    UNION ALL
    SELECT value #>> '{}'
    FROM lesson_versions lv2,
      jsonb_path_query(lv2.snapshot_json, '$.stages[*].activities[*].evidenceRefs[*]') AS j(value)
    WHERE lv2.id = lv.id
  ) t
  WHERE t.ev_id IS NOT NULL AND t.ev_id <> ''
),
-- Distinct per version, preserve order first-seen
ev_per_version AS (
  SELECT DISTINCT ON (version_id, evidence_id) version_id, evidence_id
  FROM cfg_evidence
),
-- Build evidence[] jsonb theo format embedEvidence
evidence_json AS (
  SELECT
    epv.version_id,
    jsonb_agg(
      jsonb_build_object(
        'id', e.id::text,
        'title', e.title,
        'evidenceType', e.evidence_type,
        'description', e.description,
        'source', jsonb_strip_nulls(jsonb_build_object(
          'title', e.source_title,
          'author', e.source_author,
          'url', e.source_url,
          'citation', e.source_citation,
          'publishedAt', e.source_published_at::text
        )),
        'reliability', e.reliability,
        'relevance', e.relevance,
        'assetId', e.asset_id::text
      )
      ORDER BY e.id
    ) AS evidence_arr
  FROM ev_per_version epv
  JOIN evidences e ON e.id = epv.evidence_id
  GROUP BY epv.version_id
),
-- Collect asset ids từ evidence.asset_id + config.imageAssetId
cfg_asset AS (
  SELECT
    lv.id AS version_id,
    t.a_id::uuid AS asset_id
  FROM lesson_versions lv
  CROSS JOIN LATERAL (
    SELECT e.asset_id::text AS a_id
    FROM evidences e
    WHERE e.id IN (SELECT evidence_id FROM ev_per_version WHERE version_id = lv.id)
      AND e.asset_id IS NOT NULL
    UNION ALL
    SELECT value #>> '{}' AS a_id
    FROM lesson_versions lv2,
      jsonb_path_query(lv2.snapshot_json, '$.stages[*].activities[*].config.imageAssetId') AS j(value)
    WHERE lv2.id = lv.id
    UNION ALL
    SELECT (value->>'id') AS a_id
    FROM lesson_versions lv2,
      jsonb_path_query(lv2.snapshot_json, '$.stages[*].activities[*].config.backgroundAssetId') AS j(value)
    WHERE lv2.id = lv.id
  ) t
  WHERE t.a_id IS NOT NULL AND t.a_id <> ''
),
asset_per_version AS (
  SELECT DISTINCT version_id, asset_id FROM cfg_asset
),
assets_json AS (
  SELECT
    apv.version_id,
    jsonb_agg(
      jsonb_strip_nulls(jsonb_build_object(
        'id', a.id::text,
        'storageKey', a.storage_key,
        'mimeType', a.mime_type,
        'sizeBytes', a.size_bytes,
        'originalFilename', a.original_filename,
        'altText', a.alt_text
      ))
      ORDER BY a.id
    ) AS assets_arr
  FROM asset_per_version apv
  JOIN assets a ON a.id = apv.asset_id
  GROUP BY apv.version_id
)
,target_versions AS (
  SELECT lv.id AS version_id, lv.lesson_id, lv.snapshot_json, l.title
  FROM lesson_versions lv
  JOIN lessons l ON l.id = lv.lesson_id
  WHERE l.id IN (
    'd7b20000-0000-4000-8000-000000000001',
    'd7b20000-0000-4000-8000-000000000002',
    'd7b20000-0000-4000-8000-000000000003',
    '10000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000003',
    '10000000-0000-0000-0000-000000000004'
  )
)
UPDATE lesson_versions lv
SET snapshot_json =
  tv.snapshot_json
  || jsonb_build_object('evidence', COALESCE(ej.evidence_arr, '[]'::jsonb))
  || jsonb_build_object('assets',   COALESCE(aj.assets_arr,   '[]'::jsonb))
FROM target_versions tv
LEFT JOIN evidence_json ej ON ej.version_id = tv.version_id
LEFT JOIN assets_json   aj ON aj.version_id = tv.version_id
WHERE lv.id = tv.version_id
RETURNING lv.id AS version_id, tv.title,
  jsonb_array_length(COALESCE(lv.snapshot_json->'evidence','[]'::jsonb)) AS ev_cnt,
  jsonb_array_length(COALESCE(lv.snapshot_json->'assets','[]'::jsonb))   AS as_cnt;

ALTER TABLE lesson_versions ENABLE TRIGGER trg_lesson_versions_immutable;
