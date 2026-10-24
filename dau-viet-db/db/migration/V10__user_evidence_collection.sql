-- Dấu Việt MVP | V10 | TASK-0022 Collection: per-learner dedup + pinned snapshot.
-- user_evidence (V4) chỉ có UNIQUE(learner_attempt_id, evidence_id) — học lại
-- bài (attempt mới) hoặc republish (version mới) tạo row trùng evidence cho
-- cùng learner. UNIQUE(user_id, evidence_id) làm backstop: upsert
-- ON CONFLICT DO NOTHING giữ collection idempotent ở tầng DB.
-- snapshot_json giữ bản embedded evidence (immutable) của pinned
-- lesson_version tại thời điểm collect — admin edit/archive evidence gốc
-- không viết lại nội dung learner đã sưu tầm. evidence_type tách cột để
-- filter list không phải quét jsonb path.
ALTER TABLE user_evidence
    ADD COLUMN snapshot_json JSONB,
    ADD COLUMN evidence_type VARCHAR(48),
    ADD COLUMN event_id UUID REFERENCES historical_events(id);
ALTER TABLE user_evidence
    ADD CONSTRAINT chk_user_evidence_snapshot
        CHECK (snapshot_json IS NULL OR jsonb_typeof(snapshot_json) = 'object');
CREATE UNIQUE INDEX ux_user_evidence_user_evidence
    ON user_evidence(user_id, evidence_id);
CREATE INDEX idx_user_evidence_user_event
    ON user_evidence(user_id, event_id);
