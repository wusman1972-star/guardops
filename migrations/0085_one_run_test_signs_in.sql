-- migrations/0085_one_run_test_signs_in.sql
-- Board 11982. Gives one_run_test its own identity so current_account() does not
-- raise. Creates a temporary account/customer/connected_account, calls
-- act_as_house, then carries on exactly as 0084 did. The whole subtransaction
-- still rolls back, so no trace is left.

CREATE OR REPLACE FUNCTION guardops.one_run_test()
  RETURNS TABLE(step integer, what text, got text, want text, pass boolean)
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'guardops', 'pg_catalog', 'pg_temp'
AS $function$
DECLARE
  v_acct_id        bigint;
  v_cust_id        bigint;
  v_db_id          bigint;
  v_link_id        bigint;
  v_pull_id        bigint;
  v_job_id         bigint;
  v_plan_items     bigint[];
  v_before_pic     bigint;
  v_after_pic      bigint;
  v_claim_id       bigint;
  v_opened_at      timestamptz;
  v_delivered      int;
  v_missing        int;
  v_added          int;
  v_deleted        int;
  v_cs_cites_id    bigint;
  v_added_proof    text;
  v_deleted_proof  text;
  v_deliv_proof    text;
BEGIN
  BEGIN

    INSERT INTO guardops.account (name)
      VALUES ('one_run_test') RETURNING id INTO v_acct_id;
    INSERT INTO guardops.customer (account_id, external_id)
      VALUES (v_acct_id, 'one_run_test') RETURNING id INTO v_cust_id;
    INSERT INTO guardops.connected_account
      (account_id, customer_id, token_secret_name, status)
      VALUES (v_acct_id, v_cust_id, 'one_run_test-tok', 'ACTIVE');
    PERFORM guardops.act_as_house(v_cust_id);

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
    -- Wire a test repo_link and repo_pull FIRST: job_add's argument is a
    -- repo_link_id, and the job row's foreign key is checked on insert, so the
    -- link has to exist before the job (hole 864). Both rows roll back with the
    -- subtransaction; no trace is left.
    INSERT INTO guardops.repo_link (account_id, repo, branch, linked_by, active)
    VALUES (guardops.current_account(), 'one-run-test/repo', 'main', 'TEST', false)
    RETURNING id INTO v_link_id;

    INSERT INTO guardops.repo_pull (account_id, repo_link_id)
    VALUES (guardops.current_account(), v_link_id)
    RETURNING id INTO v_pull_id;

    v_job_id := guardops.job_add(v_link_id, 'one_run_test: deliberate wrong claim');
    SELECT opened_at INTO v_opened_at FROM guardops.job WHERE id = v_job_id;

    -- Step 3: file a plan of THREE items
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

    -- Step 6: record the commits (NULL pull_id is a deliberate no-op in GuardOps)
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

    -- Build shape_change rows so the ADDED and DELETED lines carry real proof text.
    -- Rows roll back with the subtransaction.
    INSERT INTO guardops.shape_change
      (account_id, database_id, picture_id, prev_picture_id,
       change_kind, schema_name, object_name, object_kind, noticed_at, noticed_by)
    VALUES
      (guardops.current_account(), v_db_id, v_after_pic, v_before_pic,
       'APPEARED', 'guardops', 'fn_surprise_added', 'function', now(), 'one_run_test'),
      (guardops.current_account(), v_db_id, v_after_pic, v_before_pic,
       'GONE',     'guardops', 'fn_deleted_obj',    'function', now(), 'one_run_test');

    -- Insert a commit BEFORE job.opened_at to prove the scoping fix: it must not be cited.
    INSERT INTO guardops.commit_seen
      (account_id, repo_link_id, repo, sha,
       committed_at, message, files, first_pull_id)
    VALUES
      (guardops.current_account(), v_link_id, 'one-run-test/repo',
       'bbbb0000000000000000000000000000000000000001',
       v_opened_at - interval '1 hour',
       'before-window commit', '{"before.sql":"-- before"}'::jsonb,
       v_pull_id);

    -- Step 8: call the reader
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

    -- Collect proof texts before the in-window commit is inserted.
    SELECT proof INTO v_added_proof
      FROM guardops.job_verdict(v_job_id) WHERE kind = 'ADDED' LIMIT 1;
    SELECT proof INTO v_deleted_proof
      FROM guardops.job_verdict(v_job_id) WHERE kind = 'DELETED' LIMIT 1;
    -- Only the before-window commit exists here: DELIVERED must read 'no commit record'.
    SELECT proof INTO v_deliv_proof
      FROM guardops.job_verdict(v_job_id) WHERE kind = 'DELIVERED' LIMIT 1;

    -- Step 9: existing four count assertions (kept identical)
    step := 9; what := 'delivered'; got := v_delivered::text; want := '2';
    pass := (v_delivered = 2); RETURN NEXT;

    step := 9; what := 'missing';   got := v_missing::text;   want := '1';
    pass := (v_missing   = 1); RETURN NEXT;

    step := 9; what := 'added';     got := v_added::text;     want := '1';
    pass := (v_added     = 1); RETURN NEXT;

    step := 9; what := 'deleted';   got := v_deleted::text;   want := '1';
    pass := (v_deleted   = 1); RETURN NEXT;

    -- Four new proof assertions
    step := 9; what := 'added_proof'; got := v_added_proof;
    want := 'not null, not "no shape record"';
    pass := (v_added_proof IS NOT NULL
             AND v_added_proof NOT LIKE '%no shape record%'); RETURN NEXT;

    step := 9; what := 'deleted_proof'; got := v_deleted_proof;
    want := 'not null, not "no shape record"';
    pass := (v_deleted_proof IS NOT NULL
             AND v_deleted_proof NOT LIKE '%no shape record%'); RETURN NEXT;

    step := 9; what := 'delivered_proof_scoped'; got := v_deliv_proof;
    want := 'no commit record';
    pass := (v_deliv_proof = 'no commit record'); RETURN NEXT;

    -- Insert the in-window commit (committed_at = v_opened_at = now()).
    -- Also insert a commit_object row so job_verdict produces a sha->file citation.
    INSERT INTO guardops.commit_seen
      (account_id, repo_link_id, repo, sha,
       committed_at, message, files, first_pull_id)
    VALUES
      (guardops.current_account(), v_link_id, 'one-run-test/repo',
       'cccc0000000000000000000000000000000000000002',
       v_opened_at,
       'in-window commit', '{"change.sql":"-- in window"}'::jsonb,
       v_pull_id)
    RETURNING id INTO v_cs_cites_id;

    INSERT INTO guardops.commit_object
      (account_id, commit_seen_id, repo_link_id, committed_at, file_key, is_delete)
    VALUES
      (guardops.current_account(), v_cs_cites_id, v_link_id, v_opened_at, 'change.sql', false);

    -- Re-read DELIVERED proof: now the in-window commit must be cited.
    SELECT proof INTO v_deliv_proof
      FROM guardops.job_verdict(v_job_id) WHERE kind = 'DELIVERED' LIMIT 1;

    step := 9; what := 'delivered_proof_cites'; got := v_deliv_proof;
    want := 'not "no commit record"';
    pass := (v_deliv_proof IS NOT NULL
             AND v_deliv_proof <> 'no commit record'); RETURN NEXT;

    -- Always raise so the subtransaction rolls back — no trace left
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
