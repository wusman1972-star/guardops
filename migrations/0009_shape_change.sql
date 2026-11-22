-- migrations/0009_shape_change.sql

-- 9. shape_change
CREATE TABLE guardops.shape_change (
    account_id      bigint      NOT NULL DEFAULT guardops.current_account(),
    id              bigint      GENERATED ALWAYS AS IDENTITY,
    database_id     bigint      NOT NULL,
    picture_id      bigint      NOT NULL,
    prev_picture_id bigint      NOT NULL,
    change_kind     text        NOT NULL,
    schema_name     text        NOT NULL,
    object_name     text        NOT NULL,
    object_kind     text,
    noticed_at      timestamptz NOT NULL DEFAULT now(),
    noticed_by      text        NOT NULL DEFAULT SESSION_USER,
    CONSTRAINT shape_change_pkey    PRIMARY KEY (id),
    CONSTRAINT shape_change_once    UNIQUE (picture_id, change_kind, schema_name, object_name),
    CONSTRAINT shape_change_kind_ck CHECK (change_kind = ANY (ARRAY['APPEARED'::text, 'GONE'::text, 'COLUMNS'::text]))
);

CREATE INDEX shape_change_database_idx
    ON guardops.shape_change USING btree (database_id);

CREATE INDEX shape_change_picture_idx
    ON guardops.shape_change USING btree (picture_id);
