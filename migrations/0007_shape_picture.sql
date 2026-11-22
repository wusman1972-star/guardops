-- migrations/0007_shape_picture.sql

-- 7. shape_picture
CREATE TABLE guardops.shape_picture (
    account_id   bigint      NOT NULL DEFAULT guardops.current_account(),
    id           bigint      NOT NULL DEFAULT nextval('guardops.shape_picture_id_seq'),
    database_id  bigint      NOT NULL,
    taken_at     timestamptz NOT NULL DEFAULT now(),
    taken_by     text        NOT NULL DEFAULT SESSION_USER,
    object_count integer     NOT NULL DEFAULT 0,
    source       text        NOT NULL DEFAULT 'CONNECTION',
    state        text        NOT NULL DEFAULT 'DONE',
    request_id   bigint,
    failed_why   text,
    judged_at    timestamptz,
    kind         text,
    CONSTRAINT shape_picture_pkey             PRIMARY KEY (id),
    CONSTRAINT shape_picture_database_id_fkey FOREIGN KEY (database_id) REFERENCES guardops.watched_database (id),
    CONSTRAINT shape_picture_source_known     CHECK (source = ANY (ARRAY['CONNECTION'::text, 'SIGNED'::text])),
    CONSTRAINT shape_picture_state_known      CHECK (state = ANY (ARRAY['PENDING'::text, 'DONE'::text, 'FAILED'::text]))
);
