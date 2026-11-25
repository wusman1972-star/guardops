-- migrations/0088_whole_run_test.sql
-- Board 11997. Twelve-step end-to-end test covering the whole chain from sign-in
-- to four lines of proof. Steps 5, 9 and 12 fail today by design — they prove
-- what is not yet built: job-to-repo join, auto shape detection, full proof chain.

CREATE OR REPLACE FUNCTION guardops.whole_run_test()
  RETURNS TABLE(step integer, what text, got text, want text, pass boolean)
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'guardops', 'pg_catalog', 'pg_temp'
AS $function$
DECLARE
  v_acct_id     bigint;
  v_cust_id     bigint;
  v_db_id       bigint;
  v_link_id     bigint;
  v_job_id      bigint;
  v_link_on_job bigint;
  v_before_pic  bigint;
  v_after_pic   bigint;
  v_pull_id     bigint;
  v_commit_id   bigint;
  v_plan_items  bigint[];
  v_claim_id    bigint;
  v_sc_count    bigint;
  v_bad_proof   bigint;
BEGIN
  BEGIN

    -- Step 1: sign the customer in
    INSERT INTO guardops.account (name, repos_allowed)
      VALUES ('whole_run_test', 1) RETURNING id INTO v_acct_id;
    INSERT INTO guardops.customer (account_id, external_id)
      VALUES (v_acct_id, 'whole_run_test') RETURNING id INTO v_cust_id;
    INSERT INTO guardops.connected_account
      (account_id, customer_id, token_secret_name, status)
      VALUES (v_acct_id, v_cust_id, 'whole_run_test-tok', 'ACTIVE');
    PERFORM guardops.act_as_house(v_cust_id);
    step := 1; what := 'sign in';
    got  := 'signed in as account ' || v_acct_id::text;
    want := 'signed in as an account';
    pass := (v_acct_id IS NOT NULL AND guardops.current_account() = v_acct_id);
    RETURN NEXT;

    -- Step 2: register a watched database
    v_db_id := guardops.watched_database_add('whole_run_test');
    step := 2; what := 'register watched database';
    got  := 'database id ' || v_db_id::text;
    want := 'a watched database id';
    pass := (v_db_id IS NOT NULL);
    RETURN NEXT;

    -- Step 3: link where the code lives
    v_link_id := guardops.repo_link_add('whole-run-test/repo', 'main');
    step := 3; what := 'repo_link_add';
    got  := 'repo link id ' || v_link_id::text;
    want := 'a repo link id';
    pass := (v_link_id IS NOT NULL);
    RETURN NEXT;

    -- Step 4: open a job
    v_job_id := guardops.job_add(v_db_id, 'whole_run_test');
    step := 4; what := 'open a job';
    got  := 'job id ' || v_job_id::text;
    want := 'a job id';
    pass := (v_job_id IS NOT NULL);
    RETURN NEXT;

    -- Step 5: the job is joined to the code — FAILS TODAY (job_add does not set repo_link_id)
    SELECT j.repo_link_id INTO v_link_on_job
      FROM guardops.job j WHERE j.id = v_job_id;
    step := 5; what := 'job carries a code link';
    got  := CASE WHEN v_link_on_job IS NULL
                 THEN 'job.repo_link_id is null'
                 ELSE 'job.repo_link_id is ' || v_link_on_job::text END;
    want := 'a code link on the job';
    pass := (v_link_on_job IS NOT NULL);
    RETURN NEXT;

    -- Step 6: photograph the database before
    v_before_pic := guardops.take_shape(v_db_id,'whole_run_test_work','CONNECTION');
    step := 6; what := 'take before picture';
    got  := 'picture id ' || v_before_pic::text;
    want := 'a before picture id';
    pass := (v_before_pic IS NOT NULL);
    RETURN NEXT;

    -- Step 7: build something new inside the watched schema (standing in for AI work)
    EXECUTE 'CREATE SCHEMA whole_run_test_work';
    EXECUTE 'CREATE TABLE whole_run_test_work.new_table (id bigint)';
    step := 7; what := 'build new object in watched schema';
    got  := 'created whole_run_test_work.new_table';
    want := 'a new object in the watched schema';
    pass := true;
    RETURN NEXT;

    -- Step 8: photograph the database after
    v_after_pic := guardops.take_shape(v_db_id,'whole_run_test_work','CONNECTION');
    step := 8; what := 'take after picture';
    got  := 'picture id ' || v_after_pic::text;
    want := 'an after picture id';
    pass := (v_after_pic IS NOT NULL);
    RETURN NEXT;

    -- Step 9: the difference was spotted — FAILS TODAY (no auto shape comparison)
    SELECT count(*) INTO v_sc_count
      FROM guardops.shape_change WHERE database_id = v_db_id;
    step := 9; what := 'shape change detected';
    got  := v_sc_count::text || ' changes detected';
    want := 'at least 1 change detected';
    pass := (v_sc_count >= 1);
    RETURN NEXT;

    -- Step 10: record the commit (pull_begin then commit_record)
    SELECT pull_id INTO v_pull_id FROM guardops.pull_begin(v_link_id);
    v_commit_id := guardops.commit_record(
      'whole-run-test/repo', 'main',
      'aaabbbccc111222333444555666777888999000a',
      'whole-run-tester', now(),
      'whole_run_test: build new_table',
      '{"new_table.sql": "-- new table"}'::jsonb,
      v_pull_id
    );
    step := 10; what := 'record commit';
    got  := 'commit id ' || v_commit_id::text;
    want := 'a commit id';
    pass := (v_commit_id IS NOT NULL AND v_commit_id > 0);
    RETURN NEXT;

    -- Step 11: file the plan and the claim, naming the built object
    v_plan_items := guardops.plan_given_add(
      v_job_id,
      ARRAY['build whole_run_test_work.new_table']
    );
    v_claim_id := guardops.claim_add(
      v_job_id,
      v_plan_items,
      ARRAY['whole_run_test_work.new_table'],
      ARRAY[]::text[]
    );
    step := 11; what := 'file plan and claim';
    got  := 'claim id ' || v_claim_id::text;
    want := 'a claim id';
    pass := (v_claim_id IS NOT NULL);
    RETURN NEXT;

    -- Step 12: the four lines carry real proof — FAILS TODAY
    -- job.repo_link_id is null so DELIVERED rows read 'no commit record';
    -- shape_change is empty so ADDED rows read 'no shape record'.
    SELECT count(*) INTO v_bad_proof
      FROM guardops.job_verdict(v_job_id)
     WHERE proof IN ('no commit record', 'no shape record');
    step := 12; what := 'four lines carry real proof';
    got  := v_bad_proof::text || ' lines missing proof';
    want := '0 lines missing proof';
    pass := (v_bad_proof = 0);
    RETURN NEXT;

    RAISE EXCEPTION 'whole_run_rollback';

  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'whole_run_rollback' THEN
      RAISE;
    END IF;
    -- Sentinel caught: subtransaction rolled back, rows still buffered
  END;
END;
$function$;

REVOKE EXECUTE ON FUNCTION guardops.whole_run_test() FROM PUBLIC;
