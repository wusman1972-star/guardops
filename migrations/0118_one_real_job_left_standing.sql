-- migrations/0118_one_real_job_left_standing.sql
-- Board 12214: run one real committed job so the page has something to show.
--
-- Creates a demonstration account with its own watched schema, runs the full
-- chain through the existing doors, and commits everything.  No function is
-- changed.  The DO block carries its own four-point proof before it exits.

DO $$
DECLARE
  v_acct_id    bigint;
  v_cust_id    bigint;
  v_db_id      bigint;
  v_link_id    bigint;
  v_job_id     bigint;
  v_plan_items bigint[];
  v_count      bigint;
  v_one        int;
  v_whole      int;
  v_wall       int;
  r            record;
BEGIN
  -- Demonstration account - name makes it impossible to confuse with a customer
  INSERT INTO guardops.account(name)
    VALUES('demo_standing_job') RETURNING id INTO v_acct_id;
  INSERT INTO guardops.customer(account_id, external_id)
    VALUES(v_acct_id, 'demo_standing_job') RETURNING id INTO v_cust_id;
  INSERT INTO guardops.connected_account
    (account_id, customer_id, token_secret_name, status)
    VALUES(v_acct_id, v_cust_id, 'demo-standing-job-tok', 'ACTIVE');
  PERFORM guardops.act_as_house(v_cust_id);

  -- Dedicated schema with one pre-existing object so the before-picture is not empty
  EXECUTE 'CREATE SCHEMA demo_standing_job';
  EXECUTE 'CREATE TABLE demo_standing_job.customers (id bigint, name text, joined_at timestamptz)';

  -- Register the watched database (is_test=true so take_shape reads pg_catalog locally)
  v_db_id   := guardops.watched_database_add('Demo standing job database');
  v_link_id := guardops.repo_link_add('demo/standing-job-repo', 'main');

  -- Open the job and take the before-picture
  v_job_id := guardops.job_start(
    v_db_id,
    v_link_id,
    'First completed job for the product demonstration',
    'demo_standing_job'
  );

  -- Four plan items worded as a founder would word them.
  -- Item 3 (the index) is deliberately left unbuilt so the page has a real
  -- "what was not built" line.
  v_plan_items := guardops.plan_given_add(v_job_id, ARRAY[
    'Add a table to record customer orders',
    'Add a table to track delivery progress',
    'Add an index on orders for fast lookup',
    'Add a summary view for the dashboard'
  ]);

  -- Build items 1, 2, and 4
  EXECUTE 'CREATE TABLE demo_standing_job.orders (id bigint, customer_id bigint, ordered_at timestamptz)';
  EXECUTE 'CREATE TABLE demo_standing_job.delivery_progress (id bigint, order_id bigint, status text)';
  EXECUTE 'CREATE VIEW demo_standing_job.dashboard_summary AS SELECT customer_id, count(*) AS order_count FROM demo_standing_job.orders GROUP BY customer_id';

  -- One object nobody planned, so the page has a real "what was added" line
  EXECUTE 'CREATE TABLE demo_standing_job.audit_log (id bigint, event text, logged_at timestamptz)';

  -- Close the job: deliver items 1, 2, 4; claim audit_log as added; nothing deleted
  PERFORM guardops.job_finish(
    v_job_id,
    ARRAY[v_plan_items[1], v_plan_items[2], v_plan_items[4]],
    ARRAY['demo_standing_job.audit_log'],
    ARRAY[]::text[]
  );

  -- Proof 1: job is standing in the database
  SELECT count(*) INTO v_count FROM guardops.job WHERE id = v_job_id;
  RAISE NOTICE 'proof_1_job_standing  job_id=%  count=%  pass=%', v_job_id, v_count, (v_count = 1);
  IF v_count <> 1 THEN
    RAISE EXCEPTION '0118 proof 1 failed: job % not found', v_job_id;
  END IF;

  -- Proof 2: page_lines returns exactly seven rows; print each one
  SELECT count(*) INTO v_count FROM guardops.page_lines(v_cust_id, v_job_id);
  RAISE NOTICE 'proof_2_row_count  got=%  want=7  pass=%', v_count, (v_count = 7);
  IF v_count <> 7 THEN
    RAISE EXCEPTION '0118 proof 2 failed: page_lines returned % rows, want 7', v_count;
  END IF;

  FOR r IN SELECT * FROM guardops.page_lines(v_cust_id, v_job_id) ORDER BY line_no LOOP
    RAISE NOTICE 'proof_2  line=%  heading="%"  body="%"', r.line_no, r.heading, r.body;
  END LOOP;

  -- Proof 3: built, not-built, and added lines each name real items
  SELECT count(*) INTO v_count
    FROM guardops.page_lines(v_cust_id, v_job_id)
   WHERE line_no IN (4, 5, 6)
     AND body IN ('Nothing was built.', 'Nothing was left unbuilt.', 'Nothing was added.');
  RAISE NOTICE 'proof_3_real_items  empty_lines=%  want=0  pass=%', v_count, (v_count = 0);
  IF v_count <> 0 THEN
    RAISE EXCEPTION '0118 proof 3 failed: % of lines 4/5/6 still read nothing', v_count;
  END IF;

  -- Proof 4: existing test suites do not regress
  SELECT count(*) INTO v_one   FROM guardops.one_run_test()   WHERE pass = true;
  SELECT count(*) INTO v_whole FROM guardops.whole_run_test() WHERE pass = true;
  SELECT count(*) INTO v_wall  FROM guardops.wall_test()      WHERE pass = true;
  RAISE NOTICE 'proof_4a one_run_test   got=%  want=8   pass=%', v_one,   (v_one   = 8);
  RAISE NOTICE 'proof_4b whole_run_test got=%  want=12  pass=%', v_whole, (v_whole = 12);
  RAISE NOTICE 'proof_4c wall_test      got=%  want=18  pass=%', v_wall,  (v_wall  = 18);
  IF v_one <> 8 OR v_whole <> 12 OR v_wall <> 18 THEN
    RAISE EXCEPTION '0118 regression: one_run=% whole_run=% wall=%', v_one, v_whole, v_wall;
  END IF;

  RAISE NOTICE '0118 all proofs passed - job % stands committed', v_job_id;
END $$;
