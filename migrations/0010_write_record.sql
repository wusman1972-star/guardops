-- migrations/0010_write_record.sql

-- 10. write_record
CREATE TABLE guardops.write_record (
    account_id   bigint      NOT NULL DEFAULT 1,
    id           bigint      GENERATED ALWAYS AS IDENTITY,
    database_id  bigint      NOT NULL,
    their_id     bigint      NOT NULL,
    seen_at      timestamptz NOT NULL,
    table_name   text        NOT NULL,
    operation    text        NOT NULL,
    rows_touched bigint      NOT NULL,
    CONSTRAINT write_record_pkey                     PRIMARY KEY (id),
    CONSTRAINT write_record_database_id_their_id_key UNIQUE (database_id, their_id)
);

CREATE INDEX write_record_by_time
    ON guardops.write_record USING btree (database_id, seen_at DESC);
