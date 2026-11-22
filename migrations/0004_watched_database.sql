-- migrations/0004_watched_database.sql

-- 4. watched_database
CREATE TABLE guardops.watched_database (
    account_id           bigint      NOT NULL DEFAULT guardops.current_account(),
    id                   bigint      NOT NULL DEFAULT nextval('guardops.watched_database_id_seq'),
    label                text        NOT NULL,
    secret_name          text,
    status               text        NOT NULL DEFAULT 'ACTIVE',
    created_by           text        NOT NULL DEFAULT SESSION_USER,
    created_at           timestamptz NOT NULL DEFAULT now(),
    updated_at           timestamptz NOT NULL DEFAULT now(),
    connect_mode         text        NOT NULL DEFAULT 'CONNECTION',
    project_ref          text,
    connected_account_id bigint,
    is_test              boolean     NOT NULL DEFAULT false,
    CONSTRAINT watched_database_pkey             PRIMARY KEY (id),
    CONSTRAINT watched_database_signin_known     FOREIGN KEY (connected_account_id) REFERENCES guardops.connected_account (id),
    CONSTRAINT watched_database_mode_known       CHECK (connect_mode = ANY (ARRAY['CONNECTION'::text, 'SIGNED'::text])),
    CONSTRAINT watched_database_one_way_in       CHECK (
        ((connect_mode = 'CONNECTION'::text) AND (secret_name IS NOT NULL))
        OR ((connect_mode = 'SIGNED'::text) AND (project_ref IS NOT NULL) AND (connected_account_id IS NOT NULL))
    ),
    CONSTRAINT watched_database_project_ref_shape CHECK ((project_ref IS NULL) OR (project_ref ~ '^[a-z0-9]{20}$'::text))
);
