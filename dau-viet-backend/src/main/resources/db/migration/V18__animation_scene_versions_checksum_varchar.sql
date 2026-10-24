-- Dấu Việt | V18 | Align animation_scene_versions.manifest_checksum type.
-- V14 created the column as CHAR(64); the JPA entity maps String +
-- length=64 → Hibernate `ddl-auto: validate` expects VARCHAR(64) and
-- Postgres reports bpchar ≠ varchar at startup. CHAR and VARCHAR share
-- semantics for a fixed 64-char hex SHA-256; ALTER TYPE is a metadata
-- change (no rewrite of existing rows beyond the catalog) and keeps
-- every published checksum intact — values are already exactly 64 hex
-- characters (no trailing-space padding to strip, but TRIM is applied
-- defensively for any legacy row that might have been space-padded).
ALTER TABLE animation_scene_versions
  ALTER COLUMN manifest_checksum TYPE VARCHAR(64)
  USING TRIM(manifest_checksum);
