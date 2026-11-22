-- migrations/0001_account.sql
CREATE SCHEMA guardops;

-- Sequences used as column defaults (not identity columns)
CREATE SEQUENCE guardops.commit_seen_id_seq;
CREATE SEQUENCE guardops.connected_account_id_seq;
CREATE SEQUENCE guardops.repo_link_id_seq;
CREATE SEQUENCE guardops.shape_picture_id_seq;
CREATE SEQUENCE guardops.watched_database_id_seq;

-- Stub so DEFAULT guardops.current_account() compiles.
-- The real implementation is deployed separately.
CREATE FUNCTION guardops.current_account()
    RETURNS bigint LANGUAGE sql STABLE
    AS $$ SELECT 1::bigint $$;

-- 1. account
CREATE TABLE guardops.account (
    id            bigint      GENERATED ALWAYS AS IDENTITY,
    name          text        NOT NULL,
    created_at    timestamptz NOT NULL DEFAULT now(),
    repos_allowed integer     NOT NULL DEFAULT 1,
    CONSTRAINT account_pkey                PRIMARY KEY (id),
    CONSTRAINT account_name_nonblank       CHECK (length(btrim(name)) > 0),
    CONSTRAINT account_repos_allowed_check CHECK (repos_allowed >= 1)
);
