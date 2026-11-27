-- migrations/0116_a_proof_block_cannot_pass_itself.sql
-- Board 12209: a migration's own proof block must not pass itself.
-- No function changes.  This file re-runs the 0115 proof block with
-- every pass gate reading IS NOT TRUE (never IF NOT <flag>), every
-- individual check coalesced to false on NULL, and a link assertion
-- added before the late-commit cutoff check.

DO $$
DECLARE
  v_acct_id    bigint;
  v_cust_id    bigint;
  v_db_id      bigint;
  v_link_id    bigint;
  v_pull_id    bigint;
  v_job_id     bigint;
  v_opened_at  timestamptz;
  v_plan_items bigint[];
  v_cs_a       bigint;
  v_cs_b       bigint;
  v_cs_c       bigint;
  v_cs_late    bigint;
  v_p1         text;
  v_p2         text;
  v_sha_a      text := '0116aaaa000000000000000000000000000000000001';
  v_sha_b      text := '0116bbbb000000000000000000000000000000000002';
  v_sha_c      text := '0116cccc000000000000000000000000000000000003';
  v_sha_late   text := '0116dddd000000000000000000000000000000000004';
  v_all_pass   boolean := true;
  v_count      int;
  v_one        int;
  v_whole      int;
  v_wall       int;
BEGIN
  BEGIN

    -- item 0: NULL gate refuses NULL -----------------------------------------
    -- Set v_all_pass to NULL deliberately.  IS NOT TRUE evaluates to true for
    -- NULL, so the gate fires.  NOT NULL evaluates to NULL, so the old gate
    -- silently skips the failure branch.
    v_all_pass := NULL;
    RAISE NOTICE '0 null_gate_refuses_null  flag=%  IS_NOT_TRUE=%  pass=%',
      v_all_pass,
      (v_all_pass IS NOT TRUE),
      (v_all_pass IS NOT TRUE);
    -- IS NOT TRUE = t → gate fires → NULL cannot reach a pass.  Reset.
    v_all_pass := true;

    -- fixture -----------------------------------------------------------------
    INSERT INTO guardops.account(name) VALUES('0116_proof') RETURNING id INTO v_acct_id;
    INSERT INTO guardops.customer(account_id, external_id)
      VALUES(v_acct_id, '0116_proof') RETURNING id INTO v_cust_id;
    INSERT INTO guardops.connected_account
      (account_id, customer_id, token_secret_name, status)
      VALUES(v_acct_id, v_cust_id, '0116-proof-tok', 'ACTIVE');
    PERFORM guardops.act_as_house(v_cust_id);

    EXECUTE 'CREATE FUNCTION guardops.fn_0116_proof_del() RETURNS int LANGUAGE sql AS $q$ SELECT 1 $q$';

    v_db_id := guardops.watched_database_add('0116_proof_db');

    INSERT INTO guardops.repo_link
      (account_id, repo, branch, linked_by, active)
    VALUES
      (guardops.current_account(), '0116-proof/repo', 'main', 'TEST', false)
    RETURNING id INTO v_link_id;

    INSERT INTO guardops.repo_pull
      (account_id, repo_link_id)
    VALUES
      (guardops.current_account(), v_link_id)
    RETURNING id INTO v_pull_id;

    v_job_id := guardops.job_start(v_db_id, v_link_id, '0116_proof', 'guardops');
    SELECT opened_at INTO v_opened_at FROM guardops.job WHERE id = v_job_id;

    v_plan_items := guardops.plan_given_add(
      v_job_id,
      ARRAY['item alpha', 'item beta', 'item gamma']
    );

    EXECUTE 'CREATE FUNCTION guardops.fn_0116_proof_add() RETURNS int LANGUAGE sql AS $q$ SELECT 2 $q$';
    EXECUTE 'DROP FUNCTION guardops.fn_0116_proof_del()';

    PERFORM guardops.job_finish(
      v_job_id,
      v_plan_items[1:2],
      ARRAY['guardops.fn_0116_proof_add'],
      ARRAY['guardops.fn_0116_proof_del']
    );

    -- sha_a: item alpha (position 1), in-window, has file rows
    INSERT INTO guardops.commit_seen
      (account_id, repo_link_id, repo, sha, committed_at, message, files, first_pull_id)
    VALUES
      (guardops.current_account(), v_link_id, '0116-proof/repo',
       v_sha_a, v_opened_at, 'alpha GO-' || v_job_id || '-1', '{}', v_pull_id)
    RETURNING id INTO v_cs_a;
    INSERT INTO guardops.commit_object
      (account_id, commit_seen_id, repo_link_id, committed_at, file_key, is_delete)
    VALUES
      (guardops.current_account(), v_cs_a, v_link_id, v_opened_at, 'alpha.sql', false);

    -- sha_b: item beta (position 2), in-window, has file rows
    INSERT INTO guardops.commit_seen
      (account_id, repo_link_id, repo, sha, committed_at, message, files, first_pull_id)
    VALUES
      (guardops.current_account(), v_link_id, '0116-proof/repo',
       v_sha_b, v_opened_at, 'beta GO-' || v_job_id || '-2', '{}', v_pull_id)
    RETURNING id INTO v_cs_b;
    INSERT INTO guardops.commit_object
      (account_id, commit_seen_id, repo_link_id, committed_at, file_key, is_delete)
    VALUES
      (guardops.current_account(), v_cs_b, v_link_id, v_opened_at, 'beta.sql', false);

    -- sha_c: item alpha (position 1), in-window, NO file rows
    INSERT INTO guardops.commit_seen
      (account_id, repo_link_id, repo, sha, committed_at, message, files, first_pull_id)
    VALUES
      (guardops.current_account(), v_link_id, '0116-proof/repo',
       v_sha_c, v_opened_at, 'extra GO-' || v_job_id || '-1', '{}', v_pull_id)
    RETURNING id INTO v_cs_c;
    -- deliberately no commit_object rows for sha_c

    -- sha_late: item alpha (position 1), committed AFTER the last claim
    INSERT INTO guardops.commit_seen
      (account_id, repo_link_id, repo, sha, committed_at, message, files, first_pull_id)
    VALUES
      (guardops.current_account(), v_link_id, '0116-proof/repo',
       v_sha_late, v_opened_at + interval '1 hour',
       'late GO-' || v_job_id || '-1', '{}', v_pull_id)
    RETURNING id INTO v_cs_late;
    INSERT INTO guardops.commit_object
      (account_id, commit_seen_id, repo_link_id, committed_at, file_key, is_delete)
    VALUES
      (guardops.current_account(), v_cs_late, v_link_id,
       v_opened_at + interval '1 hour', 'late.sql', false);

    PERFORM guardops.plan_commit_link(v_job_id);

    SELECT proof INTO v_p1
      FROM guardops.job_verdict(v_job_id)
     WHERE kind = 'DELIVERED' AND what = 'item alpha';
    SELECT proof INTO v_p2
      FROM guardops.job_verdict(v_job_id)
     WHERE kind = 'DELIVERED' AND what = 'item beta';

    -- 1a. Item alpha cites its sha; starts with "this item's commits:"
    RAISE NOTICE '1a item_alpha  got="%"  starts=%  has_sha_a=%  pass=%',
      v_p1,
      COALESCE(v_p1 LIKE 'this item''s commits:%', false),
      COALESCE(v_p1 LIKE '%' || v_sha_a || '%', false),
      COALESCE(v_p1 LIKE 'this item''s commits:%' AND v_p1 LIKE '%' || v_sha_a || '%', false);
    v_all_pass := v_all_pass
      AND COALESCE(v_p1 LIKE 'this item''s commits:%' AND v_p1 LIKE '%' || v_sha_a || '%', false);

    -- 1b. Item beta cites its sha; starts with "this item's commits:"
    RAISE NOTICE '1b item_beta  got="%"  starts=%  has_sha_b=%  pass=%',
      v_p2,
      COALESCE(v_p2 LIKE 'this item''s commits:%', false),
      COALESCE(v_p2 LIKE '%' || v_sha_b || '%', false),
      COALESCE(v_p2 LIKE 'this item''s commits:%' AND v_p2 LIKE '%' || v_sha_b || '%', false);
    v_all_pass := v_all_pass
      AND COALESCE(v_p2 LIKE 'this item''s commits:%' AND v_p2 LIKE '%' || v_sha_b || '%', false);

    -- 2. Item alpha proof does NOT contain sha_b
    RAISE NOTICE '2 alpha_no_sha_b  has_sha_b=%  pass=%',
      COALESCE(v_p1 LIKE '%' || v_sha_b || '%', false),
      COALESCE(NOT (v_p1 LIKE '%' || v_sha_b || '%'), false);
    v_all_pass := v_all_pass
      AND COALESCE(NOT (v_p1 LIKE '%' || v_sha_b || '%'), false);

    -- 3. sha_c (no file rows) still appears in item alpha proof as sha alone
    RAISE NOTICE '3 no_file_sha_shows  has_sha_c=%  pass=%',
      COALESCE(v_p1 LIKE '%' || v_sha_c || '%', false),
      COALESCE(v_p1 LIKE '%' || v_sha_c || '%', false);
    v_all_pass := v_all_pass
      AND COALESCE(v_p1 LIKE '%' || v_sha_c || '%', false);

    -- 4-pre. Assert the fixture actually linked sha_late to item alpha.
    --        Without this, check 4 trivially passes when the link is absent.
    SELECT count(*) INTO v_count
      FROM guardops.plan_commit
     WHERE plan_given_id  = v_plan_items[1]
       AND commit_seen_id = v_cs_late
       AND account_id     = guardops.current_account();
    RAISE NOTICE '4pre late_link_exists  got=%  want=1  pass=%',
      v_count, COALESCE(v_count = 1, false);
    IF v_count <> 1 THEN
      RAISE EXCEPTION '0116 proof aborted: fixture did not link sha_late to item alpha (got %)', v_count;
    END IF;

    -- 4. sha_late (committed after last claim) is NOT cited in Alpha proof
    RAISE NOTICE '4 late_not_cited  has_sha_late=%  pass=%',
      COALESCE(v_p1 LIKE '%' || v_sha_late || '%', false),
      COALESCE(NOT (v_p1 LIKE '%' || v_sha_late || '%'), false);
    v_all_pass := v_all_pass
      AND COALESCE(NOT (v_p1 LIKE '%' || v_sha_late || '%'), false);

    -- 5a. MISSING count
    SELECT count(*) INTO v_count FROM guardops.job_verdict(v_job_id) WHERE kind = 'MISSING';
    RAISE NOTICE '5a missing  got=%  want=1  pass=%', v_count, COALESCE(v_count = 1, false);
    v_all_pass := v_all_pass AND COALESCE(v_count = 1, false);

    -- 5b. ADDED count
    SELECT count(*) INTO v_count FROM guardops.job_verdict(v_job_id) WHERE kind = 'ADDED';
    RAISE NOTICE '5b added  got=%  want=1  pass=%', v_count, COALESCE(v_count = 1, false);
    v_all_pass := v_all_pass AND COALESCE(v_count = 1, false);

    -- 5c. DELETED count
    SELECT count(*) INTO v_count FROM guardops.job_verdict(v_job_id) WHERE kind = 'DELETED';
    RAISE NOTICE '5c deleted  got=%  want=1  pass=%', v_count, COALESCE(v_count = 1, false);
    v_all_pass := v_all_pass AND COALESCE(v_count = 1, false);

    -- Fixed gate: IS NOT TRUE catches NULL; never IF NOT <flag>
    IF v_all_pass IS NOT TRUE THEN
      RAISE EXCEPTION '0116 proof failed — see NOTICE lines above';
    END IF;

    -- 6. Existing test suites must not regress.
    SELECT count(*) INTO v_one   FROM guardops.one_run_test()   WHERE pass = true;
    SELECT count(*) INTO v_whole FROM guardops.whole_run_test() WHERE pass = true;
    SELECT count(*) INTO v_wall  FROM guardops.wall_test()      WHERE pass = true;

    RAISE NOTICE '6a one_run_test   got=% want=8  pass=%', v_one,   (v_one   = 8);
    RAISE NOTICE '6b whole_run_test got=% want=12 pass=%', v_whole, (v_whole = 12);
    RAISE NOTICE '6c wall_test      got=% want=18 pass=%', v_wall,  (v_wall  = 18);

    IF v_one <> 8 OR v_whole <> 12 OR v_wall <> 18 THEN
      RAISE EXCEPTION '0116 regression: one_run=% whole_run=% wall=%', v_one, v_whole, v_wall;
    END IF;

    RAISE EXCEPTION '0116_proof_rollback';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> '0116_proof_rollback' THEN RAISE; END IF;
  END;
END $$;
