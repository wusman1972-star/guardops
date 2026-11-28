-- migrations/0121_every_line_says_whose_idea_it_was.sql
-- Board 12235. Only the five heading texts for lines 3-7 change.
-- Lines 1 and 2 keep their wording. Nothing else is altered.

CREATE OR REPLACE FUNCTION guardops.page_lines(p_customer bigint, p_job_id bigint)
 RETURNS TABLE(line_no integer, heading text, body text, proof text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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

  line_no := 3; heading := 'You asked for it - started, not finished';
  body    := 'Nothing was held.';
  proof   := 'nothing to prove';
  RETURN NEXT;

  line_no := 4; heading := 'You asked for it - it is there';
  body    := coalesce(nullif(v_built_body,  ''), 'Nothing was built.');
  proof   := coalesce(nullif(v_built_proof, ''), 'nothing to prove');
  RETURN NEXT;

  line_no := 5; heading := 'You asked for it - it is not there';
  body    := coalesce(nullif(v_unbuilt_body,  ''), 'Nothing was left unbuilt.');
  proof   := coalesce(nullif(v_unbuilt_proof, ''), 'nothing to prove');
  RETURN NEXT;

  line_no := 6; heading := 'It is there - you never asked for it';
  body    := coalesce(nullif(v_added_body,  ''), 'Nothing was added.');
  proof   := coalesce(nullif(v_added_proof, ''), 'nothing to prove');
  RETURN NEXT;

  line_no := 7; heading := 'It was there - now it is gone';
  body    := coalesce(nullif(v_deleted_body,  ''), 'Nothing was deleted.');
  proof   := coalesce(nullif(v_deleted_proof, ''), 'nothing to prove');
  RETURN NEXT;
END;
$function$;

-- ========================================================================
-- PROOF — rolls back all fixture data; function replacement stands.
-- CR lesson applied: count total and failed rows, not only passing rows.
-- ========================================================================
DO $$
DECLARE
  v_acct        bigint;
  v_cust        bigint;
  v_db          bigint;
  v_link        bigint;
  v_job         bigint;
  v_plans       bigint[];
  v_n           int;
  v_one_fail    bigint;  v_one_total    bigint;
  v_whole_fail  bigint;  v_whole_total  bigint;
  v_wall_fail   bigint;  v_wall_total   bigint;
  r             record;
  v_body        text;
  v_proof       text;
  v_headings    text[] := ARRAY[
    'What went in',
    'What was planned',
    'You asked for it - started, not finished',
    'You asked for it - it is there',
    'You asked for it - it is not there',
    'It is there - you never asked for it',
    'It was there - now it is gone'
  ];
BEGIN
  BEGIN

    -- Pre-existing object: in before-picture, dropped during job, appears in line 7.
    EXECUTE 'CREATE FUNCTION guardops.fn_0121_pre_existing()'
         || ' RETURNS int LANGUAGE sql AS $q$ SELECT 1 $q$';

    INSERT INTO guardops.account (name) VALUES ('0121_proof') RETURNING id INTO v_acct;
    INSERT INTO guardops.customer (account_id, external_id)
      VALUES (v_acct, '0121_proof') RETURNING id INTO v_cust;
    INSERT INTO guardops.connected_account
      (account_id, customer_id, token_secret_name, status)
      VALUES (v_acct, v_cust, '0121_proof_tok', 'ACTIVE');
    PERFORM guardops.act_as_house(v_cust);

    v_db   := guardops.watched_database_add('0121_proof_db');
    v_link := guardops.repo_link_add('0121-proof/repo', 'main');
    -- job_start takes before-picture of 'guardops'; fn_0121_pre_existing is in it.
    v_job  := guardops.job_start(v_db, v_link, '0121 proof job', 'guardops');

    -- Two plan items: alpha delivered (line 4), beta missing (line 5).
    v_plans := guardops.plan_given_add(v_job, ARRAY['item alpha', 'item beta']);

    -- Create added object (not in before-picture); drop pre-existing one.
    EXECUTE 'CREATE FUNCTION guardops.fn_0121_added()'
         || ' RETURNS int LANGUAGE sql AS $q$ SELECT 2 $q$';
    EXECUTE 'DROP FUNCTION guardops.fn_0121_pre_existing()';

    -- Deliver alpha only; claim added and deleted objects explicitly.
    PERFORM guardops.job_finish(
      v_job,
      ARRAY[v_plans[1]],
      ARRAY['guardops.fn_0121_added'],
      ARRAY['guardops.fn_0121_pre_existing']
    );

    -- Proof 1: seven headings, exact text, in order. Print them.
    v_n := 0;
    FOR r IN SELECT * FROM guardops.page_lines(v_cust, v_job) ORDER BY line_no LOOP
      v_n := v_n + 1;
      RAISE NOTICE 'proof_1  row=%  heading="%"  want="%"  pass=%',
        v_n, r.heading, v_headings[v_n], (r.heading = v_headings[v_n]);
      IF r.heading IS DISTINCT FROM v_headings[v_n] THEN
        RAISE EXCEPTION '0121 proof 1 row % heading: got [%] want [%]',
          v_n, r.heading, v_headings[v_n];
      END IF;
    END LOOP;
    IF v_n <> 7 THEN
      RAISE EXCEPTION '0121 proof 1: expected 7 rows, got %', v_n;
    END IF;

    -- Proof 2: body and proof of all seven, then spot-checks confirm logic intact.
    FOR r IN SELECT * FROM guardops.page_lines(v_cust, v_job) ORDER BY line_no LOOP
      RAISE NOTICE 'proof_2  row=%  body="%"  proof="%"', r.line_no, r.body, r.proof;
    END LOOP;

    SELECT body, proof INTO v_body, v_proof
      FROM guardops.page_lines(v_cust, v_job) WHERE line_no = 1;
    IF v_body IS NULL OR v_body NOT LIKE '%0121 proof job%' THEN
      RAISE EXCEPTION '0121 proof 2 line 1 body NULL or wrong: got [%]', v_body;
    END IF;
    RAISE NOTICE 'proof_2  line=1  body_has_job_title  pass=true';

    SELECT body, proof INTO v_body, v_proof
      FROM guardops.page_lines(v_cust, v_job) WHERE line_no = 3;
    IF v_body IS DISTINCT FROM 'Nothing was held.' THEN
      RAISE EXCEPTION '0121 proof 2 line 3 body: got [%] want [Nothing was held.]', v_body;
    END IF;
    IF v_proof IS DISTINCT FROM 'nothing to prove' THEN
      RAISE EXCEPTION '0121 proof 2 line 3 proof: got [%] want [nothing to prove]', v_proof;
    END IF;
    RAISE NOTICE 'proof_2  line=3  body="%"  proof="%"  pass=true', v_body, v_proof;

    SELECT body, proof INTO v_body, v_proof
      FROM guardops.page_lines(v_cust, v_job) WHERE line_no = 4;
    IF v_body IS NULL OR v_body NOT LIKE '%item alpha%' THEN
      RAISE EXCEPTION '0121 proof 2 line 4 body NULL or wrong: got [%]', v_body;
    END IF;
    RAISE NOTICE 'proof_2  line=4  body_has_item_alpha  pass=true';

    SELECT body, proof INTO v_body, v_proof
      FROM guardops.page_lines(v_cust, v_job) WHERE line_no = 5;
    IF v_body IS NULL OR v_body NOT LIKE '%item beta%' THEN
      RAISE EXCEPTION '0121 proof 2 line 5 body NULL or wrong: got [%]', v_body;
    END IF;
    RAISE NOTICE 'proof_2  line=5  body_has_item_beta  pass=true';

    SELECT body, proof INTO v_body, v_proof
      FROM guardops.page_lines(v_cust, v_job) WHERE line_no = 6;
    IF v_body IS NULL OR v_body NOT LIKE '%fn_0121_added%' THEN
      RAISE EXCEPTION '0121 proof 2 line 6 body NULL or wrong: got [%]', v_body;
    END IF;
    RAISE NOTICE 'proof_2  line=6  body_has_fn_0121_added  pass=true';

    SELECT body, proof INTO v_body, v_proof
      FROM guardops.page_lines(v_cust, v_job) WHERE line_no = 7;
    IF v_body IS NULL OR v_body NOT LIKE '%fn_0121_pre_existing%' THEN
      RAISE EXCEPTION '0121 proof 2 line 7 body NULL or wrong: got [%]', v_body;
    END IF;
    RAISE NOTICE 'proof_2  line=7  body_has_fn_0121_pre_existing  pass=true';

    -- Proof 3: test suites do not regress.
    -- Count both total rows and rows where pass IS NOT TRUE from one call each.
    SELECT count(*) FILTER (WHERE pass IS NOT TRUE), count(*)
      INTO v_one_fail, v_one_total   FROM guardops.one_run_test();
    SELECT count(*) FILTER (WHERE pass IS NOT TRUE), count(*)
      INTO v_whole_fail, v_whole_total FROM guardops.whole_run_test();
    SELECT count(*) FILTER (WHERE pass IS NOT TRUE), count(*)
      INTO v_wall_fail, v_wall_total   FROM guardops.wall_test();

    RAISE NOTICE 'proof_3a one_run_test   total=%  fail=%  want=8/0   pass=%',
      v_one_total,   v_one_fail,   (v_one_total = 8   AND v_one_fail   = 0);
    RAISE NOTICE 'proof_3b whole_run_test total=%  fail=%  want=12/0  pass=%',
      v_whole_total, v_whole_fail, (v_whole_total = 12 AND v_whole_fail = 0);
    RAISE NOTICE 'proof_3c wall_test      total=%  fail=%  want=18/0  pass=%',
      v_wall_total,  v_wall_fail,  (v_wall_total = 18  AND v_wall_fail  = 0);

    IF v_one_total   <> 8  OR v_one_fail   <> 0
    OR v_whole_total <> 12 OR v_whole_fail <> 0
    OR v_wall_total  <> 18 OR v_wall_fail  <> 0 THEN
      RAISE EXCEPTION '0121 regression: one=%/% whole=%/% wall=%/%',
        v_one_total, v_one_fail, v_whole_total, v_whole_fail,
        v_wall_total, v_wall_fail;
    END IF;

    RAISE NOTICE '0121 all proofs passed — fixture rolled back, function replacement stands';
    RAISE EXCEPTION '0121_proof_rollback';

  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> '0121_proof_rollback' THEN RAISE; END IF;
  END;
END;
$$;
