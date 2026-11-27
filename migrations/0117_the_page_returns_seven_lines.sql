-- migrations/0117_the_page_returns_seven_lines.sql
-- Board 12211: build guardops.page_lines - seven plain-English lines for a job.

CREATE OR REPLACE FUNCTION guardops.page_lines(
  p_customer bigint,
  p_job_id   bigint
)
RETURNS TABLE(line_no int, heading text, body text, proof text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_account       bigint;
  v_job_wfor      text;
  v_opened_str    text;
  v_db_label      text;
  v_plan_body     text;
  v_built_body    text;
  v_built_proof   text;
  v_unbuilt_body  text;
  v_unbuilt_proof text;
  v_added_body    text;
  v_added_proof   text;
  v_deleted_body  text;
  v_deleted_proof text;
BEGIN
  PERFORM guardops.act_as_house(p_customer);

  SELECT c.account_id INTO v_account
    FROM guardops.customer c
   WHERE c.id = p_customer;

  IF v_account IS DISTINCT FROM guardops.current_account() THEN
    RAISE EXCEPTION
      '[NOT YOURS] customer % does not belong to the signed-in account', p_customer;
  END IF;

  SELECT j.what_for,
         to_char(j.opened_at AT TIME ZONE 'Asia/Karachi', 'DD Mon YYYY HH12:MI AM'),
         coalesce(nullif(btrim(wd.label), ''), wd.project_ref, 'unknown database')
    INTO v_job_wfor, v_opened_str, v_db_label
    FROM guardops.job j
    LEFT JOIN guardops.watched_database wd ON wd.id = j.watched_database_id
   WHERE j.id         = p_job_id
     AND j.account_id = guardops.current_account();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'job % does not exist or does not belong to this account', p_job_id;
  END IF;

  SELECT string_agg(pg.item_text, E'\n' ORDER BY pg.position, pg.id)
    INTO v_plan_body
    FROM guardops.plan_given pg
   WHERE pg.job_id     = p_job_id
     AND pg.account_id = guardops.current_account();

  SELECT
    string_agg(jv.what,  E'\n' ORDER BY jv.what) FILTER (WHERE jv.kind = 'DELIVERED'),
    string_agg(jv.proof, E'\n' ORDER BY jv.what) FILTER (WHERE jv.kind = 'DELIVERED'),
    string_agg(jv.what,  E'\n' ORDER BY jv.what) FILTER (WHERE jv.kind = 'MISSING'),
    string_agg(jv.proof, E'\n' ORDER BY jv.what) FILTER (WHERE jv.kind = 'MISSING'),
    string_agg(jv.what,  E'\n' ORDER BY jv.what) FILTER (WHERE jv.kind = 'ADDED'),
    string_agg(jv.proof, E'\n' ORDER BY jv.what) FILTER (WHERE jv.kind = 'ADDED'),
    string_agg(jv.what,  E'\n' ORDER BY jv.what) FILTER (WHERE jv.kind = 'DELETED'),
    string_agg(jv.proof, E'\n' ORDER BY jv.what) FILTER (WHERE jv.kind = 'DELETED')
  INTO
    v_built_body,   v_built_proof,
    v_unbuilt_body, v_unbuilt_proof,
    v_added_body,   v_added_proof,
    v_deleted_body, v_deleted_proof
  FROM guardops.job_verdict(p_job_id) AS jv;

  line_no := 1; heading := 'What went in';
  body    := 'Job: ' || coalesce(v_job_wfor, 'untitled')
          || '. Database: ' || coalesce(v_db_label, 'unknown database')
          || '. Opened: ' || coalesce(v_opened_str, 'unknown') || '.';
  proof   := 'nothing to prove';
  RETURN NEXT;

  line_no := 2; heading := 'What was planned';
  body    := coalesce(nullif(btrim(coalesce(v_plan_body, '')), ''), 'Nothing was planned.');
  proof   := 'nothing to prove';
  RETURN NEXT;

  line_no := 3; heading := 'What was held';
  body    := 'Nothing was held.';
  proof   := 'nothing to prove';
  RETURN NEXT;

  line_no := 4; heading := 'What was built';
  body    := coalesce(nullif(v_built_body,  ''), 'Nothing was built.');
  proof   := coalesce(nullif(v_built_proof, ''), 'nothing to prove');
  RETURN NEXT;

  line_no := 5; heading := 'What was not built';
  body    := coalesce(nullif(v_unbuilt_body,  ''), 'Nothing was left unbuilt.');
  proof   := coalesce(nullif(v_unbuilt_proof, ''), 'nothing to prove');
  RETURN NEXT;

  line_no := 6; heading := 'What was added';
  body    := coalesce(nullif(v_added_body,  ''), 'Nothing was added.');
  proof   := coalesce(nullif(v_added_proof, ''), 'nothing to prove');
  RETURN NEXT;

  line_no := 7; heading := 'What was deleted';
  body    := coalesce(nullif(v_deleted_body,  ''), 'Nothing was deleted.');
  proof   := coalesce(nullif(v_deleted_proof, ''), 'nothing to prove');
  RETURN NEXT;
END;
$$;

REVOKE EXECUTE ON FUNCTION guardops.page_lines(bigint, bigint) FROM public, anon, authenticated;
GRANT  EXECUTE ON FUNCTION guardops.page_lines(bigint, bigint) TO service_role;

DO $$
DECLARE
  v_acct_id    bigint;
  v_cust_id    bigint;
  v_db_id      bigint;
  v_link_id    bigint;
  v_pull_id    bigint;
  v_job_id     bigint;
  v_plan_items bigint[];
  v_rows       int;
  r            record;
  v_acct2      bigint;
  v_cust2      bigint;
  v_db2        bigint;
  v_link2      bigint;
  v_job2       bigint;
  v_plan2      bigint[];
  v_one        int;
  v_whole      int;
  v_wall       int;
BEGIN
  BEGIN

    -- fixture A: job with delivered, missing, added, deleted
    INSERT INTO guardops.account(name) VALUES('0117_proof_A') RETURNING id INTO v_acct_id;
    INSERT INTO guardops.customer(account_id, external_id)
      VALUES(v_acct_id, '0117_proof_A') RETURNING id INTO v_cust_id;
    INSERT INTO guardops.connected_account
      (account_id, customer_id, token_secret_name, status)
      VALUES(v_acct_id, v_cust_id, '0117-proof-A-tok', 'ACTIVE');
    PERFORM guardops.act_as_house(v_cust_id);

    EXECUTE 'CREATE FUNCTION guardops.fn_0117_proof_del() RETURNS int LANGUAGE sql AS $q$ SELECT 1 $q$';

    v_db_id := guardops.watched_database_add('0117_proof_A_db');

    INSERT INTO guardops.repo_link
      (account_id, repo, branch, linked_by, active)
    VALUES
      (guardops.current_account(), '0117-proof-A/repo', 'main', 'TEST', false)
    RETURNING id INTO v_link_id;

    INSERT INTO guardops.repo_pull(account_id, repo_link_id)
      VALUES(guardops.current_account(), v_link_id)
    RETURNING id INTO v_pull_id;

    v_job_id := guardops.job_start(v_db_id, v_link_id, '0117 proof fixture A', 'guardops');

    v_plan_items := guardops.plan_given_add(
      v_job_id,
      ARRAY['build report table', 'add index on report', 'wire the export hook']
    );

    EXECUTE 'CREATE FUNCTION guardops.fn_0117_proof_add() RETURNS int LANGUAGE sql AS $q$ SELECT 2 $q$';
    EXECUTE 'DROP FUNCTION guardops.fn_0117_proof_del()';

    PERFORM guardops.job_finish(
      v_job_id,
      v_plan_items[1:2],
      ARRAY['guardops.fn_0117_proof_add'],
      ARRAY['guardops.fn_0117_proof_del']
    );

    -- proof 1: exactly seven rows, line_no 1-7, all headings present
    SELECT count(*) INTO v_rows FROM guardops.page_lines(v_cust_id, v_job_id);
    RAISE NOTICE '1_row_count  got=%  want=7  pass=%', v_rows, (v_rows = 7);
    IF v_rows IS DISTINCT FROM 7 THEN
      RAISE EXCEPTION '0117 proof 1 failed: row count is %, want 7', v_rows;
    END IF;

    SELECT count(*) INTO v_rows
      FROM guardops.page_lines(v_cust_id, v_job_id)
     WHERE line_no BETWEEN 1 AND 7;
    RAISE NOTICE '1_lines_1_to_7  got=%  want=7  pass=%', v_rows, (v_rows = 7);
    IF v_rows IS DISTINCT FROM 7 THEN
      RAISE EXCEPTION '0117 proof 1 failed: line_no 1-7 count is %', v_rows;
    END IF;

    SELECT count(*) INTO v_rows
      FROM guardops.page_lines(v_cust_id, v_job_id)
     WHERE heading IN (
       'What went in', 'What was planned', 'What was held',
       'What was built', 'What was not built', 'What was added', 'What was deleted'
     );
    RAISE NOTICE '1_headings  got=%  want=7  pass=%', v_rows, (v_rows = 7);
    IF v_rows IS DISTINCT FROM 7 THEN
      RAISE EXCEPTION '0117 proof 1 failed: heading match count is %', v_rows;
    END IF;

    -- proof 2: print body and proof; no blank values on any line
    FOR r IN SELECT * FROM guardops.page_lines(v_cust_id, v_job_id) ORDER BY line_no LOOP
      RAISE NOTICE '2  line_no=%  heading="%"  body="%"  proof="%"',
        r.line_no, r.heading, r.body, r.proof;
    END LOOP;

    SELECT count(*) INTO v_rows
      FROM guardops.page_lines(v_cust_id, v_job_id)
     WHERE body  IS NULL OR btrim(body)  = ''
        OR proof IS NULL OR btrim(proof) = '';
    RAISE NOTICE '2_no_blank  got=%  want=0  pass=%', v_rows, (v_rows = 0);
    IF v_rows IS DISTINCT FROM 0 THEN
      RAISE EXCEPTION '0117 proof 2 failed: % lines have blank body or proof', v_rows;
    END IF;

    -- proof 3: clean job - nothing missing, nothing added, nothing deleted
    INSERT INTO guardops.account(name) VALUES('0117_proof_B') RETURNING id INTO v_acct2;
    INSERT INTO guardops.customer(account_id, external_id)
      VALUES(v_acct2, '0117_proof_B') RETURNING id INTO v_cust2;
    INSERT INTO guardops.connected_account
      (account_id, customer_id, token_secret_name, status)
      VALUES(v_acct2, v_cust2, '0117-proof-B-tok', 'ACTIVE');
    PERFORM guardops.act_as_house(v_cust2);

    v_db2 := guardops.watched_database_add('0117_proof_B_db');

    INSERT INTO guardops.repo_link
      (account_id, repo, branch, linked_by, active)
    VALUES
      (guardops.current_account(), '0117-proof-B/repo', 'main', 'TEST', false)
    RETURNING id INTO v_link2;

    v_job2 := guardops.job_start(v_db2, v_link2, '0117 proof fixture B', 'guardops');

    v_plan2 := guardops.plan_given_add(v_job2, ARRAY['build the main view']);

    PERFORM guardops.job_finish(v_job2, v_plan2, ARRAY[]::text[], ARRAY[]::text[]);

    SELECT count(*) INTO v_rows FROM guardops.page_lines(v_cust2, v_job2);
    RAISE NOTICE '3_row_count  got=%  want=7  pass=%', v_rows, (v_rows = 7);
    IF v_rows IS DISTINCT FROM 7 THEN
      RAISE EXCEPTION '0117 proof 3 failed: clean job returned % rows', v_rows;
    END IF;

    FOR r IN
      SELECT * FROM guardops.page_lines(v_cust2, v_job2)
       WHERE line_no IN (5, 6, 7)
       ORDER BY line_no
    LOOP
      RAISE NOTICE '3  line_no=%  heading="%"  body="%"', r.line_no, r.heading, r.body;
    END LOOP;

    SELECT count(*) INTO v_rows
      FROM guardops.page_lines(v_cust2, v_job2)
     WHERE line_no IN (5, 6, 7)
       AND (body IS NULL OR btrim(body) = '');
    RAISE NOTICE '3_clean_lines_not_blank  got=%  want=0  pass=%', v_rows, (v_rows = 0);
    IF v_rows IS DISTINCT FROM 0 THEN
      RAISE EXCEPTION '0117 proof 3 failed: clean job has blank body on lines 5/6/7';
    END IF;

    -- proof 4: existing test suites do not regress
    SELECT count(*) INTO v_one   FROM guardops.one_run_test()   WHERE pass = true;
    SELECT count(*) INTO v_whole FROM guardops.whole_run_test() WHERE pass = true;
    SELECT count(*) INTO v_wall  FROM guardops.wall_test()      WHERE pass = true;

    RAISE NOTICE '4a one_run_test   got=%  want=8   pass=%', v_one,   (v_one   = 8);
    RAISE NOTICE '4b whole_run_test got=%  want=12  pass=%', v_whole, (v_whole = 12);
    RAISE NOTICE '4c wall_test      got=%  want=18  pass=%', v_wall,  (v_wall  = 18);

    IF v_one <> 8 OR v_whole <> 12 OR v_wall <> 18 THEN
      RAISE EXCEPTION '0117 regression: one_run=% whole_run=% wall=%', v_one, v_whole, v_wall;
    END IF;

    RAISE EXCEPTION '0117_proof_rollback';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> '0117_proof_rollback' THEN RAISE; END IF;
  END;
END $$;
