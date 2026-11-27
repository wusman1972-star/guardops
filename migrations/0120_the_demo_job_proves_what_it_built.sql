-- migrations/0120_the_demo_job_proves_what_it_built.sql
-- Board 12226: the built line must show how we know, like the other three do.
--
-- The 0118 demo job wrote no GO-<job>-<pos> references in its commit messages,
-- so plan_commit_link found nothing to match and the built line reads
-- "no commit linked to this item" for every delivered item.
-- Those commit records are correct (the commits really carried no reference)
-- and must not be altered.
--
-- This file stands up a fresh demo job that records commits with proper
-- GO references, calls plan_commit_link so the links are written, then marks
-- the 0118 job superseded.  No function is changed.  This file commits; it
-- does not roll back, because the demo job must be left standing.

DO $$
DECLARE
  v_acct_id        bigint;
  v_cust_id        bigint;
  v_db_id          bigint;
  v_link_id        bigint;
  v_pull_id        bigint;
  v_job_id         bigint;
  v_opened_at      timestamptz;
  v_plan_items     bigint[];
  v_links          integer;
  v_count          bigint;
  v_one            int;
  v_whole          int;
  v_wall           int;
  v_built_proof    text;
  v_notbuilt_proof text;
  v_added_proof    text;
  r                record;
BEGIN
  /* ----------------------------------------------------------------
     PART 1 — new demo account and watched schema
     Every row id in this block is captured into a local variable
     from an INSERT RETURNING or a function return value.
     ---------------------------------------------------------------- */

  -- v_acct_id, v_cust_id: INSERT RETURNING
  INSERT INTO guardops.account(name)
    VALUES ('demo2_standing_job') RETURNING id INTO v_acct_id;
  INSERT INTO guardops.customer(account_id, external_id)
    VALUES (v_acct_id, 'demo2_standing_job') RETURNING id INTO v_cust_id;
  INSERT INTO guardops.connected_account
    (account_id, customer_id, token_secret_name, status)
    VALUES (v_acct_id, v_cust_id, 'demo2-standing-job-tok', 'ACTIVE');
  PERFORM guardops.act_as_house(v_cust_id);

  -- Watched schema: one pre-existing object so the before-picture is not empty
  EXECUTE 'CREATE SCHEMA demo2_standing_job';
  EXECUTE 'CREATE TABLE demo2_standing_job.customers'
       || ' (id bigint, name text, joined_at timestamptz)';

  -- v_db_id, v_link_id: function return values
  v_db_id   := guardops.watched_database_add('Demo2 standing job database');
  v_link_id := guardops.repo_link_add('demo2/standing-job-repo', 'main');

  /* ----------------------------------------------------------------
     PART 2 — open the job and register the plan
     ---------------------------------------------------------------- */

  -- v_job_id: job_start return value
  v_job_id := guardops.job_start(
    v_db_id,
    v_link_id,
    'Demo job: each commit carries a GO reference (0120)',
    'demo2_standing_job'
  );
  SELECT j.opened_at INTO v_opened_at FROM guardops.job j WHERE j.id = v_job_id;

  -- v_plan_items: plan_given_add return value (positions 1-4)
  -- Item 3 (the index) is deliberately left unbuilt so the page has a real
  -- "what was not built" line, matching the structure of the 0118 job.
  v_plan_items := guardops.plan_given_add(v_job_id, ARRAY[
    'Add a table to record customer orders',
    'Add a table to track delivery progress',
    'Add an index on orders for fast lookup',
    'Add a summary view for the dashboard'
  ]);

  /* ----------------------------------------------------------------
     PART 3 — build schema objects
     Items 1, 2, 4 built; item 3 (the index) deliberately not built.
     One extra object (audit_log) so the page has a real "added" line.
     ---------------------------------------------------------------- */
  EXECUTE 'CREATE TABLE demo2_standing_job.orders'
       || ' (id bigint, customer_id bigint, ordered_at timestamptz)';
  EXECUTE 'CREATE TABLE demo2_standing_job.delivery_progress'
       || ' (id bigint, order_id bigint, status text)';
  EXECUTE 'CREATE VIEW demo2_standing_job.dashboard_summary'
       || ' AS SELECT customer_id, count(*) AS order_count'
       || ' FROM demo2_standing_job.orders GROUP BY customer_id';
  EXECUTE 'CREATE TABLE demo2_standing_job.audit_log'
       || ' (id bigint, event text, logged_at timestamptz)';

  /* ----------------------------------------------------------------
     PART 4 — record commits with GO-<job>-<pos> references
     committed_at = v_opened_at so each commit falls on the job
     window boundary and satisfies both plan_commit_link's range check
     (committed_at >= opened_at) and job_verdict's claim-time upper
     bound (committed_at <= MAX(claimed_at) = now() = opened_at).
     ---------------------------------------------------------------- */

  -- v_pull_id: pull_begin return value
  SELECT pull_id INTO v_pull_id FROM guardops.pull_begin(v_link_id);

  -- Commit for item 1: add orders table
  PERFORM guardops.commit_record(
    'demo2/standing-job-repo', 'main',
    'demo2sha000000000001',
    'demo builder',
    v_opened_at,
    'Add orders table GO-' || v_job_id || '-1',
    jsonb_build_object(
      'migrations/demo2_orders.sql',
      '+CREATE TABLE demo2_standing_job.orders'
      || ' (id bigint, customer_id bigint, ordered_at timestamptz)'
    ),
    v_pull_id
  );

  -- Commit for item 2: add delivery_progress table
  PERFORM guardops.commit_record(
    'demo2/standing-job-repo', 'main',
    'demo2sha000000000002',
    'demo builder',
    v_opened_at,
    'Add delivery_progress table GO-' || v_job_id || '-2',
    jsonb_build_object(
      'migrations/demo2_delivery_progress.sql',
      '+CREATE TABLE demo2_standing_job.delivery_progress'
      || ' (id bigint, order_id bigint, status text)'
    ),
    v_pull_id
  );

  -- Commit for item 4: add dashboard_summary view
  PERFORM guardops.commit_record(
    'demo2/standing-job-repo', 'main',
    'demo2sha000000000004',
    'demo builder',
    v_opened_at,
    'Add dashboard_summary view GO-' || v_job_id || '-4',
    jsonb_build_object(
      'migrations/demo2_dashboard_summary.sql',
      '+CREATE VIEW demo2_standing_job.dashboard_summary'
      || ' AS SELECT customer_id, count(*) AS order_count'
      || ' FROM demo2_standing_job.orders GROUP BY customer_id'
    ),
    v_pull_id
  );

  -- Close the pull; UNPROVEN is acceptable for this demonstration
  PERFORM guardops.pull_close(
    v_pull_id, 'FIRST',
    'demo2sha000000000004',
    'demo2sha000000000001',
    3,
    'demo-sig'
  );

  /* ----------------------------------------------------------------
     PART 5 — link commits to plan items, then close the job
     ---------------------------------------------------------------- */

  -- Scan commit_seen for GO tokens; expect 3 links (items 1, 2, 4)
  v_links := guardops.plan_commit_link(v_job_id);
  RAISE NOTICE 'plan_commit_link wrote % links (want 3, pass=%)', v_links, (v_links = 3);
  IF v_links <> 3 THEN
    RAISE EXCEPTION '0120: plan_commit_link wrote % links, want 3', v_links;
  END IF;

  -- Deliver items 1, 2, 4; claim audit_log as added; nothing deleted
  PERFORM guardops.job_finish(
    v_job_id,
    ARRAY[v_plan_items[1], v_plan_items[2], v_plan_items[4]],
    ARRAY['demo2_standing_job.audit_log'],
    ARRAY[]::text[]
  );

  /* ----------------------------------------------------------------
     PART 6 — retire the 0118 demo job
     Lookup is by account name; no literal row id is used for a row
     created outside this file.
     ---------------------------------------------------------------- */
  UPDATE guardops.job
     SET what_for  = 'SUPERSEDED BY 0120 — ' || what_for,
         closed_at = now()
    FROM guardops.account a
   WHERE guardops.job.account_id = a.id
     AND a.name = 'demo_standing_job';

  /* ================================================================
     PROOF SECTION — numbered rows, pass true/false
     ================================================================ */

  /* Proof 1: page_lines(<new job id>) returns seven rows; paste all */
  SELECT count(*) INTO v_count FROM guardops.page_lines(v_job_id);
  RAISE NOTICE 'proof_1_row_count  got=%  want=7  pass=%', v_count, (v_count = 7);
  IF v_count <> 7 THEN
    RAISE EXCEPTION '0120 proof 1 failed: page_lines returned % rows, want 7', v_count;
  END IF;
  FOR r IN SELECT * FROM guardops.page_lines(v_job_id) ORDER BY line_no LOOP
    RAISE NOTICE 'proof_1  line=%  heading="%"  body="%"  proof="%"',
      r.line_no, r.heading, r.body, r.proof;
  END LOOP;

  /* Proof 2: built line proof names real commits for each built item;
              "no commit linked to this item" appears nowhere in it    */
  SELECT r2.proof INTO v_built_proof
    FROM guardops.page_lines(v_job_id) r2
   WHERE r2.line_no = 4;
  RAISE NOTICE 'proof_2_built_line_proof  text="%"', v_built_proof;
  IF v_built_proof LIKE '%no commit linked to this item%' THEN
    RAISE EXCEPTION '0120 proof 2 failed: built line still reads "no commit linked to this item"';
  END IF;
  IF v_built_proof NOT LIKE '%demo2sha0000000000%' THEN
    RAISE EXCEPTION '0120 proof 2 failed: built line proof does not name a real commit sha';
  END IF;
  IF v_built_proof NOT LIKE '%migrations/demo2%' THEN
    RAISE EXCEPTION '0120 proof 2 failed: built line proof does not name a file';
  END IF;
  RAISE NOTICE 'proof_2_pass  bad_text_absent=true  sha_found=true  file_found=true  pass=true';

  /* Proof 3: not-built line proof = "not in any claim";
              added line proof starts with "pic " (shape record)      */
  SELECT r3.proof INTO v_notbuilt_proof
    FROM guardops.page_lines(v_job_id) r3
   WHERE r3.line_no = 5;
  SELECT r4.proof INTO v_added_proof
    FROM guardops.page_lines(v_job_id) r4
   WHERE r4.line_no = 6;
  RAISE NOTICE 'proof_3_not_built_proof  text="%"  pass=%',
    v_notbuilt_proof, (v_notbuilt_proof = 'not in any claim');
  RAISE NOTICE 'proof_3_added_proof      text="%"  pass=%',
    v_added_proof, (v_added_proof LIKE 'pic %');
  IF v_notbuilt_proof <> 'not in any claim' THEN
    RAISE EXCEPTION '0120 proof 3 failed: not-built proof="%", want "not in any claim"', v_notbuilt_proof;
  END IF;
  IF v_added_proof NOT LIKE 'pic %' THEN
    RAISE EXCEPTION '0120 proof 3 failed: added proof="%", want pic X->Y: ...', v_added_proof;
  END IF;

  /* Proof 4: existing test suites do not regress */
  SELECT count(*) INTO v_one   FROM guardops.one_run_test()   WHERE pass = true;
  SELECT count(*) INTO v_whole FROM guardops.whole_run_test() WHERE pass = true;
  SELECT count(*) INTO v_wall  FROM guardops.wall_test()      WHERE pass = true;
  RAISE NOTICE 'proof_4a one_run_test   got=%  want=8   pass=%', v_one,   (v_one   = 8);
  RAISE NOTICE 'proof_4b whole_run_test got=%  want=12  pass=%', v_whole, (v_whole = 12);
  RAISE NOTICE 'proof_4c wall_test      got=%  want=18  pass=%', v_wall,  (v_wall  = 18);
  IF v_one <> 8 OR v_whole <> 12 OR v_wall <> 18 THEN
    RAISE EXCEPTION '0120 regression: one_run=% whole_run=% wall=%', v_one, v_whole, v_wall;
  END IF;

  /* Proof 5: no row id hardcoded that this file did not create itself.
     Every id variable is sourced from an INSERT RETURNING or a function
     return; the only UPDATE touching a pre-existing row uses a name-based
     WHERE clause, not a literal id:
       v_acct_id    <- INSERT INTO guardops.account      RETURNING id
       v_cust_id    <- INSERT INTO guardops.customer     RETURNING id
       v_db_id      <- guardops.watched_database_add(...)
       v_link_id    <- guardops.repo_link_add(...)
       v_pull_id    <- guardops.pull_begin(v_link_id)
       v_job_id     <- guardops.job_start(...)
       v_plan_items <- guardops.plan_given_add(...)
     The UPDATE in PART 6 uses WHERE a.name = 'demo_standing_job'.         */
  RAISE NOTICE 'proof_5_no_hardcoded_ids  all_ids_from_inserts_or_functions  pass=true';

  RAISE NOTICE '0120 all proofs passed — job % stands committed', v_job_id;
END $$;
