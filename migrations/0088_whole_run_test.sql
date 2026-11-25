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
  v_acct_id bigint; v_cust_id bigint; v_db_id bigint; v_link_id bigint;
  v_job_id bigint; v_link_on_job bigint; v_before_pic bigint; v_after_pic bigint;
  v_pull_id bigint; v_commit_id bigint; v_plan_items bigint[]; v_claim_id bigint;
  v_sc_count bigint; v_bad_proof bigint;
BEGIN
  BEGIN
    INSERT INTO guardops.account (name, repos_allowed) VALUES ('whole_run_test', 1) RETURNING id INTO v_acct_id;
    INSERT INTO guardops.customer (account_id, external_id) VALUES (v_acct_id, 'whole_run_test') RETURNING id INTO v_cust_id;
    INSERT INTO guardops.connected_account (account_id, customer_id, token_secret_name, status)
      VALUES (v_acct_id, v_cust_id, 'whole_run_test-tok', 'ACTIVE');
    PERFORM guardops.act_as_house(v_cust_id);
    step := 1; what := 'Sign the customer in';
    got := 'signed in'; want := 'signed in';
    pass := (guardops.current_account() = v_acct_id); RETURN NEXT;

    v_db_id := guardops.watched_database_add('whole_run_test','wholeruntestrefaaaaa','CONNECTION',true,'whole_run_test-sec');
    step := 2; what := 'Register the customer database';
    got := 'database registered'; want := 'a watched database';
    pass := (v_db_id IS NOT NULL); RETURN NEXT;

    v_link_id := guardops.repo_link_add('whole-run-test/repo','main');
    step := 3; what := 'Link where the code lives';
    got := 'code link made'; want := 'a code link';
    pass := (v_link_id IS NOT NULL); RETURN NEXT;

    v_job_id := guardops.job_add(v_db_id,'whole_run_test');
    step := 4; what := 'Open a job';
    got := 'job opened'; want := 'a job';
    pass := (v_job_id IS NOT NULL); RETURN NEXT;

    SELECT j.repo_link_id INTO v_link_on_job FROM guardops.job j WHERE j.id = v_job_id;
    step := 5; what := 'Join the job to the code';
    got := CASE WHEN v_link_on_job IS NULL THEN 'the job has no code link and nothing can give it one'
                ELSE 'the job carries its code link' END;
    want := 'the job knows where its code lives';
    pass := (v_link_on_job IS NOT NULL); RETURN NEXT;

    v_before_pic := guardops.take_shape(v_db_id,'whole_run_test_work','CONNECTION');
    step := 6; what := 'Photograph the database before';
    got := 'picture taken'; want := 'a before picture';
    pass := (v_before_pic IS NOT NULL); RETURN NEXT;

    EXECUTE 'CREATE SCHEMA whole_run_test_work';
    EXECUTE 'CREATE TABLE whole_run_test_work.new_table (id bigint)';
    step := 7; what := 'Build something new';
    got := 'a new table was built'; want := 'something new to find';
    pass := true; RETURN NEXT;

    v_after_pic := guardops.take_shape(v_db_id,'whole_run_test_work','CONNECTION');
    step := 8; what := 'Photograph the database after';
    got := 'picture taken'; want := 'an after picture';
    pass := (v_after_pic IS NOT NULL); RETURN NEXT;

    SELECT count(*) INTO v_sc_count FROM guardops.shape_change WHERE database_id = v_db_id;
    step := 9; what := 'Spot what changed';
    got := CASE WHEN v_sc_count = 0 THEN 'two pictures taken and nothing compared them'
                ELSE v_sc_count::text || ' differences found' END;
    want := 'the new table found by comparing the pictures';
    pass := (v_sc_count >= 1); RETURN NEXT;

    SELECT pull_id INTO v_pull_id FROM guardops.pull_begin(v_link_id);
    v_commit_id := guardops.commit_record('whole-run-test/repo','main',
      'aaabbbccc111222333444555666777888999000a','whole-run-tester', now(),
      'whole_run_test', '{"new_table.sql": "-- new table"}'::jsonb, v_pull_id);
    step := 10; what := 'Record the commit';
    got := 'commit recorded'; want := 'the commit on record';
    pass := (v_commit_id IS NOT NULL); RETURN NEXT;

    v_plan_items := guardops.plan_given_add(v_job_id, ARRAY['build whole_run_test_work.new_table']);
    v_claim_id := guardops.claim_add(v_job_id, v_plan_items,
      ARRAY['whole_run_test_work.new_table'], ARRAY[]::text[]);
    step := 11; what := 'File what the AI claims';
    got := 'claim filed'; want := 'a claim to check';
    pass := (v_claim_id IS NOT NULL); RETURN NEXT;

    SELECT count(*) INTO v_bad_proof FROM guardops.job_verdict(v_job_id)
      WHERE proof IN ('no commit record','no shape record');
    step := 12; what := 'Four lines with real proof';
    got := CASE WHEN v_bad_proof = 0 THEN 'every line carries proof'
                ELSE v_bad_proof::text || ' lines came back with no proof at all' END;
    want := 'every line carries proof';
    pass := (v_bad_proof = 0); RETURN NEXT;

    RAISE EXCEPTION 'whole_run_rollback';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'whole_run_rollback' THEN RAISE; END IF;
  END;
END;
$function$;

REVOKE EXECUTE ON FUNCTION guardops.whole_run_test() FROM PUBLIC;
