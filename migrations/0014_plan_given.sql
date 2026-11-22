-- migrations/0014_plan_given.sql

-- 14. plan_given
CREATE TABLE guardops.plan_given (
    account_id    bigint      NOT NULL DEFAULT guardops.current_account(),
    id            bigint      GENERATED ALWAYS AS IDENTITY,
    item_text     text        NOT NULL,
    position      integer     NOT NULL,
    plan_version  integer     NOT NULL,
    plan_digest   text        NOT NULL,
    created_by    text        NOT NULL DEFAULT SESSION_USER,
    created_at    timestamptz NOT NULL DEFAULT now(),
    job_id        bigint,
    CONSTRAINT plan_given_pkey                     PRIMARY KEY (id),
    CONSTRAINT plan_given_account_id_fkey          FOREIGN KEY (account_id) REFERENCES guardops.account (id),
    CONSTRAINT plan_given_position_positive        CHECK (position >= 1),
    CONSTRAINT plan_given_plan_version_positive    CHECK (plan_version >= 1),
    CONSTRAINT plan_given_item_text_nonblank       CHECK (length(btrim(item_text)) > 0),
    CONSTRAINT plan_given_plan_digest_nonblank     CHECK (length(btrim(plan_digest)) > 0)
);

CREATE INDEX plan_given_by_version
    ON guardops.plan_given USING btree (account_id, plan_version, position);

-- Append-only gate: refuses UPDATE and DELETE.
CREATE FUNCTION guardops.plan_given_no_mutation()
    RETURNS trigger LANGUAGE plpgsql AS
$$
BEGIN
    RAISE EXCEPTION 'plan_given rows are append-only; UPDATE and DELETE are not permitted';
END;
$$;

CREATE TRIGGER plan_given_no_update
    BEFORE UPDATE ON guardops.plan_given
    FOR EACH ROW EXECUTE FUNCTION guardops.plan_given_no_mutation();

CREATE TRIGGER plan_given_no_delete
    BEFORE DELETE ON guardops.plan_given
    FOR EACH ROW EXECUTE FUNCTION guardops.plan_given_no_mutation();
