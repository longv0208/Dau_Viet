CREATE TABLE user_learning_path_enrollments (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    path_code VARCHAR(64) NOT NULL,
    path_version_id UUID NOT NULL REFERENCES learning_path_versions(id),
    enrolled_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, path_code)
);

CREATE INDEX idx_user_learning_path_enrollments_version
    ON user_learning_path_enrollments(path_version_id);
