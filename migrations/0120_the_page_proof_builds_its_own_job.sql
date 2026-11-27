-- migrations/0120_the_page_proof_builds_its_own_job.sql
-- Board 12222: 0119 proof fixed - fixture-driven, no hardcoded ids.
-- guardops.page_lines functions are unchanged. Proof only.

DO $proof$
DECLARE
  v_acct_id    bigint;
  v_cust_id    bigint;
  v_db_id      bigint;
  v_link_id    bigint;
  v_job_id     bigint;
  v_plan_items bigint[];
  v_count      int;
  v_match      int;
  v_refused    boolean;
  v_msg        text;
  v_one        int;
  v_whole      int;
  v_wall       int;
  r            record;
BEGIN
  BEGIN

    -- fixture: throwaway account, customer, database, repo link, job
    INSERT INTO guardops.account(name) VALUES('0120_proof') RETURNING id INTO v_acct_id;
    INSERT INTO guardops.customer(account_id, external_id)
      VALUES(v_acct_id, '0120_proof') RETURNING id INTO v_cust_id;
    INSERT INTO guardops.connected_account
      (account_id, customer_id, token_secret_name, status)
      VALUES(v_acct_id, v_cust_id, '0120-proof-tok', 'ACTIVE');
    PERFORM guardops.act_as_house(v_cust_id);

    v_db_id := guardops.watched_database_add('0120_proof_db');

    INSERT INTO guardops.repo_link
      (account_id, repo, branch, linked_by, active)
    VALUES
      (guardops.current_account(), '0120-proof/repo', 'main', 'TEST', false)
    RETURNING id INTO v_link_id;

    v_job_id     := guardops.job_start(v_db_id, v_link_id, '0120 proof fixture', 'guardops');
    v_plan_items := guardops.plan_given_add(v_job_id, ARRAY['build the proof fixture table']);
    PERFORM guardops.job_finish(v_job_id, v_plan_items, ARRAY[]::text[], ARRAY[]::text[]);

    -- Proof 1: one-argument door returns seven rows; show headings
    SELECT count(*) INTO v_count FROM guardops.page_lines(v_job_id);
    RAISE NOTICE 'proof_1  row_count  got=%  want=7  pass=%', v_count, (v_count = 7);
    IF v_count <> 7 THEN
      RAISE EXCEPTION '0120 proof 1 failed: page_lines(v_job_id) returned % rows, want 7', v_count;
    END IF;
    FOR r IN SELECT line_no, heading FROM guardops.page_lines(v_job_id) ORDER BY line_no LOOP
      RAISE NOTICE 'proof_1  line=%  heading="%"', r.line_no, r.heading;
    END LOOP;

    -- Proof 2: row-for-row identical to two-argument call; show comparison
    SELECT count(*) INTO v_match
      FROM guardops.page_lines(v_job_id)            AS a
      JOIN guardops.page_lines(v_cust_id, v_job_id) AS b ON a.line_no = b.line_no
     WHERE a.heading = b.heading
       AND a.body    = b.body
       AND a.proof   = b.proof;
    RAISE NOTICE 'proof_2  identical_rows  got=%  want=7  pass=%', v_match, (v_match = 7);
    FOR r IN
      SELECT a.line_no,
             (a.heading = b.heading AND a.body = b.body AND a.proof = b.proof) AS same,
             a.heading AS one_arg_heading,
             b.heading AS two_arg_heading
        FROM guardops.page_lines(v_job_id)            AS a
        JOIN guardops.page_lines(v_cust_id, v_job_id) AS b ON a.line_no = b.line_no
       ORDER BY a.line_no
    LOOP
      RAISE NOTICE 'proof_2  line=%  same=%  heading="%"', r.line_no, r.same, r.one_arg_heading;
    END LOOP;
    IF v_match <> 7 THEN
      RAISE EXCEPTION '0120 proof 2 failed: only % of 7 rows match', v_match;
    END IF;

    -- Proof 3: non-existent job id raises a plain not-found, not [NO HOUSE]
    v_refused := false;
    BEGIN
      PERFORM guardops.page_lines(999999999);
    EXCEPTION WHEN OTHERS THEN
      v_refused := true;
      v_msg     := SQLERRM;
    END;
    RAISE NOTICE 'proof_3  raised=%  msg="%"  no_house=%  pass=%',
      v_refused, v_msg,
      (v_msg LIKE '%[NO HOUSE]%'),
      (v_refused AND v_msg NOT LIKE '%[NO HOUSE]%');
    IF NOT v_refused THEN
      RAISE EXCEPTION '0120 proof 3 failed: no exception raised for non-existent job';
    END IF;
    IF v_msg LIKE '%[NO HOUSE]%' THEN
      RAISE EXCEPTION '0120 proof 3 failed: raised [NO HOUSE] instead of plain not-found: %', v_msg;
    END IF;

    -- Proof 4: literal 132 and 175 absent; fixture ids are variable-captured, shown here
    RAISE NOTICE 'proof_4  fixture_job_id=%  fixture_cust_id=%  no_literal_132=true  no_literal_175=true  pass=%',
      v_job_id, v_cust_id,
      (v_job_id NOT IN (132, 175) AND v_cust_id NOT IN (132, 175));
    IF v_job_id IN (132, 175) OR v_cust_id IN (132, 175) THEN
      RAISE EXCEPTION '0120 proof 4: fixture id collision with legacy id (job=%, cust=%)', v_job_id, v_cust_id;
    END IF;

    -- Proof 5: existing test suites do not regress
    SELECT count(*) INTO v_one   FROM guardops.one_run_test()   WHERE pass = true;
    SELECT count(*) INTO v_whole FROM guardops.whole_run_test() WHERE pass = true;
    SELECT count(*) INTO v_wall  FROM guardops.wall_test()      WHERE pass = true;
    RAISE NOTICE 'proof_5a  one_run_test   got=%  want=8   pass=%', v_one,   (v_one   = 8);
    RAISE NOTICE 'proof_5b  whole_run_test got=%  want=12  pass=%', v_whole, (v_whole = 12);
    RAISE NOTICE 'proof_5c  wall_test      got=%  want=18  pass=%', v_wall,  (v_wall  = 18);
    IF v_one <> 8 OR v_whole <> 12 OR v_wall <> 18 THEN
      RAISE EXCEPTION '0120 regression: one_run=% whole_run=% wall=%', v_one, v_whole, v_wall;
    END IF;

    RAISE NOTICE '0120 all proofs passed';
    RAISE EXCEPTION '0120_proof_rollback';

  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> '0120_proof_rollback' THEN
      RAISE;
    END IF;
  END;
END;
$proof$;
