CREATE TABLE IF NOT EXISTS cf_sessions (
    cookie_id   TEXT PRIMARY KEY,
    role        TEXT,
    user_name   TEXT,
    user_id     TEXT,
    user_email  TEXT,
    created_at  TIMESTAMP DEFAULT NOW()
);