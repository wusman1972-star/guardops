-- migrations/0072_one_run_test.sql
-- Board 11903. Writes the one-run end-to-end test function.
-- Board 11923 fix: added pg_temp last in search_path (prevents temp-schema
-- type shadowing on SECURITY DEFINER); added REVOKE EXECUTE FROM PUBLIC.

CREATE OR REPLACE FUNCTION guardops.one_run_test()
  RETURNS TABLE(step integer, what text, got text, want text, pass boolean)
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'guardops', 'pg_catalog', 'pg_temp'
AS $function$
DECLARE
  v_db_id       bigint;
  v_job_id      bigint;
  v_plan_items  bigint[];
  v_before_pic  bigint;
  v_after_pic   bigint;
  v_claim_id    bigint;
  v_delivered   int;
  v_missing     int;
  v_added       int;
  v_deleted     int;
BEGIN
  -- The inner block is an implicit subtransaction.
  -- Every exit path raises 'one_run_rollback'; the handler catches it, which
  -- rolls back all DB writes.  RETURN NEXT rows buffered before the raise
  -- survive in the tuple store and are returned to the caller.
  BEGIN

    -- Step 1: register a database to watch
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.routines
      WHERE routine_schema = 'guardops' AND routine_name = 'watched_database_add'
    ) THEN
      step := 1; what := 'watched_database_add'; got := NULL;
      want := 'door must exist'; pass := false;
      RETURN NEXT;
      RAISE EXCEPTION 'one_run_rollback';
    END IF;
    v_db_id := guardops.watched_database_add('one_run_test');

    -- Step 2: open a job
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.routines
      WHERE routine_schema = 'guardops' AND routine_name = 'job_add'
    ) THEN
      step := 2; what := 'job_add'; got := NULL;
      want := 'door must exist'; pass := false;
      RETURN NEXT;
      RAISE EXCEPTION 'one_run_rollback';
    END IF;
    v_job_id := guardops.job_add(v_db_id, 'one_run_test: deliberate wrong claim');

    -- Step 3: file a plan of THREE items
    -- plan_given_add(job_id, items text[]) returns bigint[] of item ids in position order
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.routines
      WHERE routine_schema = 'guardops' AND routine_name = 'plan_given_add'
    ) THEN
      step := 3; what := 'plan_given_add'; got := NULL;
      want := 'door must exist'; pass := false;
      RETURN NEXT;
      RAISE EXCEPTION 'one_run_rollback';
    END IF;
    v_plan_items := guardops.plan_given_add(
      v_job_id,
      ARRAY['add function alpha', 'add function beta', 'add function gamma']
    );

    -- Step 4: take a before picture (door exists: take_shape)
    v_before_pic := guardops.take_shape(v_db_id, 'BEFORE');

    -- Step 5: record a claim (wrong on purpose)
    -- 2 of 3 items delivered, item 3 never touched,
    -- 1 object added nobody asked for, 1 object deleted
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.routines
      WHERE routine_schema = 'guardops' AND routine_name = 'claim_add'
    ) THEN
      step := 5; what := 'claim_add'; got := NULL;
      want := 'door must exist'; pass := false;
      RETURN NEXT;
      RAISE EXCEPTION 'one_run_rollback';
    END IF;
    v_claim_id := guardops.claim_add(
      v_job_id,
      v_plan_items[1:2],
      ARRAY['guardops.fn_surprise_added'],
      ARRAY['guardops.fn_deleted_obj']
    );

    -- Step 6: record the commits (door exists: commit_record)
    PERFORM guardops.commit_record(
      'test/one_run_test_repo', 'main',
      'aaabbbccc111222333444555666777888999000aaab',
      'one-run-tester', now(),
      'deliberate wrong commit for one_run_test',
      '["alpha.sql","beta.sql","surprise.sql"]'::jsonb,
      NULL
    );

    -- Step 7: take an after picture (door exists: take_shape)
    v_after_pic := guardops.take_shape(v_db_id, 'AFTER');

    -- Step 8: call the reader
    -- job_verdict(job_id) returns TABLE(kind text, what text, proof text)
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.routines
      WHERE routine_schema = 'guardops' AND routine_name = 'job_verdict'
    ) THEN
      step := 8; what := 'job_verdict'; got := NULL;
      want := 'door must exist'; pass := false;
      RETURN NEXT;
      RAISE EXCEPTION 'one_run_rollback';
    END IF;

    SELECT count(*) INTO v_delivered
      FROM guardops.job_verdict(v_job_id) WHERE kind = 'DELIVERED';
    SELECT count(*) INTO v_missing
      FROM guardops.job_verdict(v_job_id) WHERE kind = 'MISSING';
    SELECT count(*) INTO v_added
      FROM guardops.job_verdict(v_job_id) WHERE kind = 'ADDED';
    SELECT count(*) INTO v_deleted
      FROM guardops.job_verdict(v_job_id) WHERE kind = 'DELETED';

    -- Step 9: assert
    step := 9; what := 'delivered'; got := v_delivered::text; want := '2';
    pass := (v_delivered = 2); RETURN NEXT;

    step := 9; what := 'missing';   got := v_missing::text;   want := '1';
    pass := (v_missing   = 1); RETURN NEXT;

    step := 9; what := 'added';     got := v_added::text;     want := '1';
    pass := (v_added     = 1); RETURN NEXT;

    step := 9; what := 'deleted';   got := v_deleted::text;   want := '1';
    pass := (v_deleted   = 1); RETURN NEXT;

    -- Always raise so the subtransaction rolls back - no trace left
    RAISE EXCEPTION 'one_run_rollback';

  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'one_run_rollback' THEN
      RAISE;
    END IF;
    -- Sentinel caught: subtransaction rolled back, rows still in buffer
  END;
END;
$function$;

REVOKE EXECUTE ON FUNCTION guardops.one_run_test() FROM PUBLIC;
