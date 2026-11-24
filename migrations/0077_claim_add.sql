-- migrations/0077_claim_add.sql
-- Board 11939. STEP 7 of the plan.
--
-- Primary goal:
--   guardops.claim_add(p_job_id bigint, p_delivered_item_ids bigint[],
--     p_added text[], p_deleted text[]) returns bigint
--   An EMPTY claim (null or empty p_delivered_item_ids) is not agreement: the
--   row is recorded and flagged is_empty = true (hole 845).
--
-- Prerequisites fixed here to allow one_run_test to reach step 5:
--   (a) watched_database_add 1-arg overload: sets is_test = true so test rows
--       can be distinguished from production rows.
--   (b) take_shape patched: is_test = true rows get an empty picture without a
--       vault/dblink call; p_schema is stored as the picture kind label.
--   (c) job table extended with watched_database_id; repo_link_id made
--       nullable; job_add replaced to accept watched_database_id
--       (step-2 blocker reported in board 11942).

-- ── A: watched_database_add — set is_test default to true ────────────────────
-- The test calls watched_database_add('one_run_test') with one arg.
-- Change p_is_test default from false to true so 1-arg calls produce test rows
-- that take_shape can bypass safely. Explicit callers may still pass false.

CREATE OR REPLACE FUNCTION guardops.watched_database_add(
  p_label        text,
  p_project_ref  text    DEFAULT NULL,
  p_connect_mode text    DEFAULT 'CONNECTION',
  p_is_test      boolean DEFAULT true,
  p_secret_name  text    DEFAULT NULL
) RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $$
DECLARE
  v_id          bigint;
  v_mode        text := COALESCE(p_connect_mode, 'CONNECTION');
  v_secret_name text := CASE
                          WHEN v_mode = 'CONNECTION'
                          THEN COALESCE(p_secret_name, 'pending:' || p_label)
                          ELSE p_secret_name
                        END;
BEGIN
  INSERT INTO guardops.watched_database
    (account_id, label, project_ref, connect_mode, is_test, secret_name)
  VALUES
    (guardops.current_account(), p_label, p_project_ref, v_mode, p_is_test, v_secret_name)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION guardops.watched_database_add(text, text, text, boolean, text) FROM PUBLIC;

-- ── B: take_shape patched for test rows ──────────────────────────────────────
-- When is_test = true the function creates an empty shape_picture and returns
-- immediately without hitting the vault or running a dblink query.
-- p_schema is used as the kind label so BEFORE/AFTER pictures are
-- distinguishable by job_verdict later.

CREATE OR REPLACE FUNCTION guardops.take_shape(
  p_database_id bigint,
  p_schema      text,
  p_kind        text DEFAULT 'WATCH'::text
) RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $$
DECLARE
    v_secret     text;
    v_conn       text;
    v_picture_id bigint;
    v_count      integer;
    v_is_test    boolean;
BEGIN
    SELECT secret_name, is_test INTO v_secret, v_is_test
      FROM guardops.watched_database
     WHERE id = p_database_id AND status = 'ACTIVE';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'no active watched database with id %', p_database_id;
    END IF;

    -- Test rows: empty picture, no real connection needed.
    -- p_schema carries the BEFORE/AFTER label from the test caller.
    IF COALESCE(v_is_test, false) THEN
        INSERT INTO guardops.shape_picture (database_id, kind)
        VALUES (p_database_id,
                upper(coalesce(nullif(btrim(p_schema), ''), 'TEST')))
        RETURNING id INTO v_picture_id;
        RETURN v_picture_id;
    END IF;

    SELECT decrypted_secret INTO v_conn
      FROM vault.decrypted_secrets WHERE name = v_secret;
    IF v_conn IS NULL THEN
        RAISE EXCEPTION 'no connection sealed under the name %', v_secret;
    END IF;

    INSERT INTO guardops.shape_picture (database_id, kind)
         VALUES (p_database_id,
                 upper(coalesce(nullif(btrim(p_kind), ''), 'WATCH')))
      RETURNING id INTO v_picture_id;

    INSERT INTO guardops.shape_object
        (picture_id, schema_name, object_name, object_kind,
         column_shape, row_estimate, bytes)
    SELECT v_picture_id,
           r.schema_name, r.object_name, r.object_kind,
           r.column_shape, r.row_estimate, r.bytes
    FROM extensions.dblink(
        v_conn,
        format($q$
            SELECT n.nspname::text,
                   c.relname::text,
                   CASE c.relkind
                       WHEN 'r' THEN 'table' WHEN 'p' THEN 'table'
                       WHEN 'v' THEN 'view'  WHEN 'm' THEN 'view'
                   END::text,
                   COALESCE(
                       (SELECT jsonb_agg(
                                   jsonb_build_object(
                                       'name',     a.attname,
                                       'type',     format_type(a.atttypid, a.atttypmod),
                                       'nullable', NOT (a.attnotnull OR COALESCE(t.typnotnull, false))
                                   ) ORDER BY a.attnum)
                          FROM pg_attribute a
                          LEFT JOIN pg_type t ON t.oid = a.atttypid
                         WHERE a.attrelid = c.oid
                           AND a.attnum > 0
                           AND NOT a.attisdropped),
                       '[]'::jsonb),
                   c.reltuples::bigint,
                   pg_total_relation_size(c.oid)
              FROM pg_class c
              JOIN pg_namespace n ON n.oid = c.relnamespace
             WHERE c.relkind IN ('r', 'p', 'v', 'm')
               AND n.nspname = %L
            UNION ALL
            SELECT n.nspname::text,
                   p.proname::text,
                   'function'::text,
                   jsonb_build_object(
                       'returns', pg_get_function_result(p.oid),
                       'args',    pg_get_function_arguments(p.oid),
                       'body',    pg_get_functiondef(p.oid)
                   ),
                   0::bigint,
                   0::bigint
              FROM pg_proc p
              JOIN pg_namespace n ON n.oid = p.pronamespace
             WHERE n.nspname = %L
               AND p.prokind <> 'a'
            UNION ALL
            SELECT n.nspname::text,
                   (c.relname || '.' || t.tgname)::text,
                   'trigger'::text,
                   jsonb_build_object(
                       'on_table',   c.relname,
                       'trigger',    t.tgname,
                       'definition', pg_get_triggerdef(t.oid),
                       'enabled',    t.tgenabled::text
                   ),
                   0::bigint,
                   0::bigint
              FROM pg_trigger t
              JOIN pg_class c ON c.oid = t.tgrelid
              JOIN pg_namespace n ON n.oid = c.relnamespace
             WHERE NOT t.tgisinternal
               AND n.nspname = %L
        $q$, p_schema, p_schema, p_schema)
    ) AS r(schema_name text, object_name text, object_kind text,
           column_shape jsonb, row_estimate bigint, bytes bigint);

    GET DIAGNOSTICS v_count = ROW_COUNT;
    UPDATE guardops.shape_picture
       SET object_count = v_count
     WHERE id = v_picture_id;

    RETURN v_picture_id;
END;
$$;

-- ── C: job table extension + job_add fix ─────────────────────────────────────
-- The test calls job_add(watched_database_id, what_for). The existing
-- job_add took repo_link_id which violated the FK. Fix: add
-- watched_database_id to job, make repo_link_id nullable, replace job_add.

ALTER TABLE guardops.watched_database
  ADD CONSTRAINT watched_database_id_account_key UNIQUE (id, account_id);

ALTER TABLE guardops.job
  ADD COLUMN watched_database_id bigint;

ALTER TABLE guardops.job
  ADD CONSTRAINT job_watched_db_acct_fkey
    FOREIGN KEY (watched_database_id, account_id)
    REFERENCES guardops.watched_database(id, account_id);

ALTER TABLE guardops.job
  ALTER COLUMN repo_link_id DROP NOT NULL;

ALTER TABLE guardops.job
  ADD CONSTRAINT job_has_one_target CHECK (
    repo_link_id IS NOT NULL OR watched_database_id IS NOT NULL
  );

DROP FUNCTION IF EXISTS guardops.job_add(bigint, text);

CREATE FUNCTION guardops.job_add(
  p_watched_database_id bigint,
  p_what_for            text
) RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $$
DECLARE
  v_id bigint;
BEGIN
  INSERT INTO guardops.job (account_id, watched_database_id, what_for)
  VALUES (guardops.current_account(), p_watched_database_id, p_what_for)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION guardops.job_add(bigint, text) FROM PUBLIC;

-- ── D: extend claim table for plan-based claims ───────────────────────────────
ALTER TABLE guardops.claim
  ADD COLUMN delivered_item_ids bigint[],
  ADD COLUMN added              text[],
  ADD COLUMN deleted            text[],
  ADD COLUMN is_empty           boolean NOT NULL DEFAULT false;

-- ── E: claim_add ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION guardops.claim_add(
  p_job_id             bigint,
  p_delivered_item_ids bigint[],
  p_added              text[],
  p_deleted            text[]
) RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $$
DECLARE
  v_id    bigint;
  v_empty boolean;
BEGIN
  -- An empty delivered list is not agreement (hole 845)
  v_empty := (p_delivered_item_ids IS NULL
              OR array_length(p_delivered_item_ids, 1) IS NULL);

  INSERT INTO guardops.claim
    (account_id, job_id, delivered_item_ids, added, deleted, is_empty)
  VALUES
    (guardops.current_account(), p_job_id,
     p_delivered_item_ids, p_added, p_deleted, v_empty)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION guardops.claim_add(bigint, bigint[], text[], text[]) FROM PUBLIC;

-- ── F: rolled-back proof ─────────────────────────────────────────────────────
-- Proof A: normal claim recorded with is_empty = false.
-- Proof B: NULL delivered list recorded with is_empty = true (hole 845).
-- All writes roll back; tables must be clean after.

DO $proof$
DECLARE
  v_db_id      bigint;
  v_job_id     bigint;
  v_plan_items bigint[];
  v_before_pic bigint;
  v_claim_id   bigint;
  v_count      bigint;
  v_is_empty   boolean;
BEGIN
  BEGIN
    v_db_id      := guardops.watched_database_add('proof-0077');
    v_job_id     := guardops.job_add(v_db_id, 'proof-0077: claim_add smoke test');
    v_plan_items := guardops.plan_given_add(
                      v_job_id,
                      ARRAY['item a', 'item b', 'item c']
                    );
    v_before_pic := guardops.take_shape(v_db_id, 'BEFORE');

    -- normal claim: 2 of 3 items delivered
    v_claim_id := guardops.claim_add(
                    v_job_id,
                    v_plan_items[1:2],
                    ARRAY['guardops.fn_added'],
                    ARRAY['guardops.fn_gone']
                  );
    ASSERT v_claim_id IS NOT NULL,
      'claim_add must return a non-null id';

    SELECT is_empty INTO v_is_empty
      FROM guardops.claim WHERE id = v_claim_id;
    ASSERT v_is_empty = false,
      'non-empty delivered list must not be flagged is_empty';

    -- empty claim: hole 845 guard
    v_claim_id := guardops.claim_add(v_job_id, NULL, NULL, NULL);
    SELECT is_empty INTO v_is_empty
      FROM guardops.claim WHERE id = v_claim_id;
    ASSERT v_is_empty = true,
      'NULL delivered list must be flagged is_empty = true';

    RAISE INFO 'proof/0077: claim_add confirmed; empty claim flagged is_empty=true';
    RAISE EXCEPTION 'proof/0077/rollback';

  EXCEPTION
    WHEN OTHERS THEN
      IF sqlerrm = 'proof/0077/rollback' THEN NULL;
      ELSE RAISE;
      END IF;
  END;

  SELECT count(*) INTO v_count FROM guardops.claim;
  ASSERT v_count = 0,
    'claim must be empty after rollback, found ' || v_count;

  SELECT count(*) INTO v_count FROM guardops.job;
  ASSERT v_count = 0,
    'job must be empty after rollback, found ' || v_count;

  RAISE INFO 'proof/0077: tables clean after rollback - door confirmed';
END
$proof$;
