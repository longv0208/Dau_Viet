CREATE TABLE historical_events (
    id              UUID PRIMARY KEY,
    slug            VARCHAR(150) NOT NULL,
    title           VARCHAR(255) NOT NULL,
    era             VARCHAR(100),
    period          VARCHAR(100),
    start_year      INTEGER,
    summary         TEXT NOT NULL,
    description     TEXT,
    location        VARCHAR(255),
    cover_asset_key VARCHAR(512),
    tags            TEXT[] NOT NULL DEFAULT '{}',
    status          VARCHAR(24) NOT NULL DEFAULT 'DRAFT',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_historical_events_status CHECK (status IN ('DRAFT','PUBLISHED','ARCHIVED'))
);

CREATE UNIQUE INDEX ux_historical_events_slug       ON historical_events(slug);
CREATE INDEX idx_historical_events_status           ON historical_events(status);
CREATE INDEX idx_historical_events_start_year       ON historical_events(start_year);
CREATE INDEX idx_historical_events_published_year   ON historical_events(start_year) WHERE status = 'PUBLISHED';
