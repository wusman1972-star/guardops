-- migrations/0113_a_junk_reference_cannot_kill_the_linking_run.sql
-- Board 12202: overflow-safe token filter in plan_commit_link.
-- A GO-<job>-<pos> token is accepted only when its digit strings, stripped of
-- leading zeros, are <=18 chars (bigint-safe) and <=9 chars (integer-safe).
-- Oversized tokens are silently skipped; valid tokens in the same message still link.

CREATE OR REPLACE FUNCTION guardops.plan_commit_link(p_job_id bigint)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_acct_id      bigint;
  v_repo_link_id bigint;
  v_opened_at    timestamptz;
  v_closed_at    timestamptz;
  v_added        integer := 0;
  v_rows         integer;
  v_pg_id        bigint;
  r              record;
  v_job_num      bigint;
  v_pos          integer;
BEGIN
  v_acct_id := guardops.current_account();

  SELECT j.repo_link_id, j.opened_at, j.closed_at
    INTO v_repo_link_id, v_opened_at, v_closed_at
    FROM guardops.job j
   WHERE j.id         = p_job_id
     AND j.account_id = v_acct_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'job % not found or does not belong to this account', p_job_id;
  END IF;

  FOR r IN
    SELECT cs.id AS commit_seen_id, cs.message
      FROM guardops.commit_seen cs
     WHERE cs.account_id   = v_acct_id
       AND cs.repo_link_id = v_repo_link_id
       AND cs.committed_at >= v_opened_at
       AND (v_closed_at IS NULL OR cs.committed_at <= v_closed_at)
  LOOP
    FOR v_job_num, v_pos IN
      SELECT m[1]::bigint, m[2]::integer
        FROM regexp_matches(r.message, 'GO-(\d+)-(\d+)', 'ig') AS t(m)
       WHERE length(ltrim(m[1], '0')) <= 18
         AND length(ltrim(m[2], '0')) <= 9
    LOOP
      CONTINUE WHEN v_job_num <> p_job_id;

      SELECT pg.id INTO v_pg_id
        FROM guardops.plan_given pg
       WHERE pg.job_id     = p_job_id
         AND pg.position   = v_pos
         AND pg.account_id = v_acct_id;

      CONTINUE WHEN NOT FOUND;

      INSERT INTO guardops.plan_commit
        (account_id, plan_given_id, commit_seen_id, how_found)
      VALUES
        (v_acct_id, v_pg_id, r.commit_seen_id, 'MESSAGE_REF')
      ON CONFLICT (account_id, plan_given_id, commit_seen_id) DO NOTHING;

      GET DIAGNOSTICS v_rows = ROW_COUNT;
      v_added := v_added + v_rows;
    END LOOP;
  END LOOP;

  RETURN v_added;
END;
$function$;

-- PROOF: numbered rows, pass true/false, inside a transaction that rolls back
DO $$
DECLARE
  v_acct_id        bigint;
  v_cust_id        bigint;
  v_link_id        bigint;
  v_pull_id        bigint;
  v_job_id         bigint;
  v_opened_at      timestamptz;
  v_plan_items     bigint[];
  v_cs_ovj_id      bigint;   -- overflow job + valid token
  v_cs_ovp_id      bigint;   -- overflow pos + valid token
  v_cs_ovo_id      bigint;   -- overflow only
  v_cs_valid_id    bigint;   -- valid token (0112 proof 1)
  v_cs_notok_id    bigint;   -- no token (0112 proof 2)
  v_cs_wrongjob_id bigint;   -- wrong job (0112 proof 4)
  v_cs_badpos_id   bigint;   -- bad position (0112 proof 5)
  v_row            guardops.plan_commit%ROWTYPE;
  v_count1         integer;
  v_count2         integer;
  v_rc             integer;
  v_all_pass       boolean := true;
BEGIN
  INSERT INTO guardops.account(name) VALUES('0113_proof') RETURNING id INTO v_acct_id;
  INSERT INTO guardops.customer(account_id, external_id)
    VALUES(v_acct_id, '0113_proof') RETURNING id INTO v_cust_id;
  INSERT INTO guardops.connected_account(account_id, customer_id, token_secret_name, status)
    VALUES(v_acct_id, v_cust_id, '0113-proof-tok', 'ACTIVE');
  PERFORM guardops.act_as_house(v_cust_id);

  INSERT INTO guardops.repo_link(account_id, repo, branch, linked_by, active)
    VALUES(guardops.current_account(), '0113-proof/repo', 'main', 'TEST', false)
    RETURNING id INTO v_link_id;

  INSERT INTO guardops.repo_pull(account_id, repo_link_id)
    VALUES(guardops.current_account(), v_link_id)
    RETURNING id INTO v_pull_id;

  INSERT INTO guardops.job(account_id, repo_link_id, what_for, opened_by)
    VALUES(guardops.current_account(), v_link_id, '0113-proof', SESSION_USER)
    RETURNING id, opened_at INTO v_job_id, v_opened_at;

  v_plan_items := guardops.plan_given_add(v_job_id, ARRAY['item one', 'item two']);

  -- commit A: overflow job token + valid token for position 1
  INSERT INTO guardops.commit_seen
    (account_id, repo_link_id, repo, sha, committed_at, message, files, first_pull_id)
  VALUES
    (guardops.current_account(), v_link_id, '0113-proof/repo',
     '0113-proof-sha-A', v_opened_at,
     'feat GO-9223372036854775808-1 GO-' || v_job_id || '-1',
     '{}', v_pull_id)
  RETURNING id INTO v_cs_ovj_id;

  -- commit B: overflow pos token + valid token for position 1
  INSERT INTO guardops.commit_seen
    (account_id, repo_link_id, repo, sha, committed_at, message, files, first_pull_id)
  VALUES
    (guardops.current_account(), v_link_id, '0113-proof/repo',
     '0113-proof-sha-B', v_opened_at,
     'feat GO-1-2147483648 GO-' || v_job_id || '-1',
     '{}', v_pull_id)
  RETURNING id INTO v_cs_ovp_id;

  -- commit C: oversized token only
  INSERT INTO guardops.commit_seen
    (account_id, repo_link_id, repo, sha, committed_at, message, files, first_pull_id)
  VALUES
    (guardops.current_account(), v_link_id, '0113-proof/repo',
     '0113-proof-sha-C', v_opened_at,
     'feat GO-9223372036854775808-1',
     '{}', v_pull_id)
  RETURNING id INTO v_cs_ovo_id;

  -- commit D: valid token for position 1 (0112 proof 1)
  INSERT INTO guardops.commit_seen
    (account_id, repo_link_id, repo, sha, committed_at, message, files, first_pull_id)
  VALUES
    (guardops.current_account(), v_link_id, '0113-proof/repo',
     '0113-proof-sha-D', v_opened_at,
     'implement item one GO-' || v_job_id || '-1',
     '{}', v_pull_id)
  RETURNING id INTO v_cs_valid_id;

  -- commit E: no token (0112 proof 2)
  INSERT INTO guardops.commit_seen
    (account_id, repo_link_id, repo, sha, committed_at, message, files, first_pull_id)
  VALUES
    (guardops.current_account(), v_link_id, '0113-proof/repo',
     '0113-proof-sha-E', v_opened_at,
     'just a cleanup commit',
     '{}', v_pull_id)
  RETURNING id INTO v_cs_notok_id;

  -- commit F: wrong job (0112 proof 4)
  INSERT INTO guardops.commit_seen
    (account_id, repo_link_id, repo, sha, committed_at, message, files, first_pull_id)
  VALUES
    (guardops.current_account(), v_link_id, '0113-proof/repo',
     '0113-proof-sha-F', v_opened_at,
     'cross-job GO-99999999-1',
     '{}', v_pull_id)
  RETURNING id INTO v_cs_wrongjob_id;

  -- commit G: bad position (0112 proof 5)
  INSERT INTO guardops.commit_seen
    (account_id, repo_link_id, repo, sha, committed_at, message, files, first_pull_id)
  VALUES
    (guardops.current_account(), v_link_id, '0113-proof/repo',
     '0113-proof-sha-G', v_opened_at,
     'bad pos GO-' || v_job_id || '-999',
     '{}', v_pull_id)
  RETURNING id INTO v_cs_badpos_id;

  PERFORM guardops.plan_commit_link(v_job_id);

  -- 1. overflow job + valid: no raise (we reached here), valid token linked; show row
  SELECT * INTO v_row FROM guardops.plan_commit
   WHERE commit_seen_id = v_cs_ovj_id AND plan_given_id = v_plan_items[1];
  RAISE NOTICE '1 overflow-job+valid  row_id=% how_found=% pass=%',
    v_row.id, v_row.how_found,
    (v_row.id IS NOT NULL AND v_row.how_found = 'MESSAGE_REF');
  v_all_pass := v_all_pass AND (v_row.id IS NOT NULL AND v_row.how_found = 'MESSAGE_REF');

  -- 2. overflow pos + valid: no raise, valid token still linked; show row
  SELECT * INTO v_row FROM guardops.plan_commit
   WHERE commit_seen_id = v_cs_ovp_id AND plan_given_id = v_plan_items[1];
  RAISE NOTICE '2 overflow-pos+valid  row_id=% how_found=% pass=%',
    v_row.id, v_row.how_found,
    (v_row.id IS NOT NULL AND v_row.how_found = 'MESSAGE_REF');
  v_all_pass := v_all_pass AND (v_row.id IS NOT NULL AND v_row.how_found = 'MESSAGE_REF');

  -- 3. oversized token only: nothing linked, no raise
  SELECT count(*) INTO v_rc FROM guardops.plan_commit WHERE commit_seen_id = v_cs_ovo_id;
  RAISE NOTICE '3 oversized-only  got=% want=0 pass=%', v_rc, (v_rc = 0);
  v_all_pass := v_all_pass AND (v_rc = 0);

  -- 4a. token links item (0112 proof 1)
  SELECT * INTO v_row FROM guardops.plan_commit
   WHERE plan_given_id = v_plan_items[1] AND commit_seen_id = v_cs_valid_id;
  RAISE NOTICE '4a token-links-item  got_id=% how_found=% pass=%',
    v_row.id, v_row.how_found,
    (v_row.id IS NOT NULL AND v_row.how_found = 'MESSAGE_REF');
  v_all_pass := v_all_pass AND (v_row.id IS NOT NULL AND v_row.how_found = 'MESSAGE_REF');

  -- 4b. no token no row (0112 proof 2)
  SELECT count(*) INTO v_rc FROM guardops.plan_commit WHERE commit_seen_id = v_cs_notok_id;
  RAISE NOTICE '4b no-token-no-row  got=% want=0 pass=%', v_rc, (v_rc = 0);
  v_all_pass := v_all_pass AND (v_rc = 0);

  -- 4c. idempotent: second call does not add rows (0112 proof 3)
  SELECT count(*) INTO v_count1 FROM guardops.plan_commit WHERE plan_given_id = ANY(v_plan_items);
  PERFORM guardops.plan_commit_link(v_job_id);
  SELECT count(*) INTO v_count2 FROM guardops.plan_commit WHERE plan_given_id = ANY(v_plan_items);
  RAISE NOTICE '4c idempotent  first=% second=% pass=%', v_count1, v_count2, (v_count1 = v_count2);
  v_all_pass := v_all_pass AND (v_count1 = v_count2);

  -- 4d. wrong job no row (0112 proof 4)
  SELECT count(*) INTO v_rc FROM guardops.plan_commit WHERE commit_seen_id = v_cs_wrongjob_id;
  RAISE NOTICE '4d wrong-job-no-row  got=% want=0 pass=%', v_rc, (v_rc = 0);
  v_all_pass := v_all_pass AND (v_rc = 0);

  -- 4e. bad position no row (0112 proof 5)
  SELECT count(*) INTO v_rc FROM guardops.plan_commit WHERE commit_seen_id = v_cs_badpos_id;
  RAISE NOTICE '4e bad-pos-no-row  got=% want=0 pass=%', v_rc, (v_rc = 0);
  v_all_pass := v_all_pass AND (v_rc = 0);

  IF NOT v_all_pass THEN
    RAISE EXCEPTION '0113 proof failed — see NOTICE lines above';
  END IF;

  RAISE EXCEPTION '0113_proof_rollback';
EXCEPTION WHEN OTHERS THEN
  IF SQLERRM <> '0113_proof_rollback' THEN RAISE; END IF;
END $$;

-- 5. Existing sheets must not move
DO $$
DECLARE
  v_one   int;
  v_whole int;
  v_wall  int;
BEGIN
  SELECT count(*) INTO v_one   FROM guardops.one_run_test()   WHERE pass = true;
  SELECT count(*) INTO v_whole FROM guardops.whole_run_test() WHERE pass = true;
  SELECT count(*) INTO v_wall  FROM guardops.wall_test()      WHERE pass = true;

  RAISE NOTICE '5a one_run_test   got=% want=8  pass=%', v_one,   (v_one   = 8);
  RAISE NOTICE '5b whole_run_test got=% want=12 pass=%', v_whole, (v_whole = 12);
  RAISE NOTICE '5c wall_test      got=% want=18 pass=%', v_wall,  (v_wall  = 18);

  IF v_one <> 8 OR v_whole <> 12 OR v_wall <> 18 THEN
    RAISE EXCEPTION '0113 regression: one_run=% whole_run=% wall=%', v_one, v_whole, v_wall;
  END IF;
END $$;
