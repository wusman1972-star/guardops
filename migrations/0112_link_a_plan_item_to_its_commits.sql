-- migrations/0112_link_a_plan_item_to_its_commits.sql
-- Board 12200, hole 838: link plan items to commits via GO-<job_id>-<position> token.

-- 1. Table
CREATE TABLE guardops.plan_commit (
    account_id      bigint      NOT NULL,
    id              bigserial   PRIMARY KEY,
    plan_given_id   bigint      NOT NULL,
    commit_seen_id  bigint      NOT NULL,
    how_found       text        NOT NULL,
    found_at        timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT plan_commit_how_found_check
        CHECK (how_found = 'MESSAGE_REF'),
    CONSTRAINT plan_commit_unique
        UNIQUE (account_id, plan_given_id, commit_seen_id),
    CONSTRAINT plan_commit_plan_given_id_fkey
        FOREIGN KEY (plan_given_id) REFERENCES guardops.plan_given (id) ON DELETE CASCADE,
    CONSTRAINT plan_commit_commit_seen_id_fkey
        FOREIGN KEY (commit_seen_id) REFERENCES guardops.commit_seen (id) ON DELETE CASCADE
);

ALTER TABLE guardops.plan_commit ENABLE ROW LEVEL SECURITY;

CREATE POLICY own_account_only ON guardops.plan_commit
    AS PERMISSIVE FOR ALL TO PUBLIC
    USING  (account_id = guardops.current_account_or_null())
    WITH CHECK (account_id = guardops.current_account_or_null());

-- 2. Door
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
  v_acct_id    bigint;
  v_cust_id    bigint;
  v_link_id    bigint;
  v_pull_id    bigint;
  v_job_id     bigint;
  v_opened_at  timestamptz;
  v_plan_items bigint[];
  v_cs1_id     bigint;
  v_cs2_id     bigint;
  v_cs3_id     bigint;
  v_cs4_id     bigint;
  v_pg_row     guardops.plan_commit%ROWTYPE;
  v_count1     integer;
  v_count2     integer;
  v_rc         integer;
  v_all_pass   boolean := true;
BEGIN
  INSERT INTO guardops.account(name) VALUES('0112_proof') RETURNING id INTO v_acct_id;
  INSERT INTO guardops.customer(account_id, external_id)
    VALUES(v_acct_id, '0112_proof') RETURNING id INTO v_cust_id;
  INSERT INTO guardops.connected_account(account_id, customer_id, token_secret_name, status)
    VALUES(v_acct_id, v_cust_id, '0112-proof-tok', 'ACTIVE');
  PERFORM guardops.act_as_house(v_cust_id);

  INSERT INTO guardops.repo_link(account_id, repo, branch, linked_by, active)
    VALUES(guardops.current_account(), '0112-proof/repo', 'main', 'TEST', false)
    RETURNING id INTO v_link_id;

  INSERT INTO guardops.repo_pull(account_id, repo_link_id)
    VALUES(guardops.current_account(), v_link_id)
    RETURNING id INTO v_pull_id;

  INSERT INTO guardops.job(account_id, repo_link_id, what_for, opened_by)
    VALUES(guardops.current_account(), v_link_id, '0112-proof', SESSION_USER)
    RETURNING id, opened_at INTO v_job_id, v_opened_at;

  v_plan_items := guardops.plan_given_add(v_job_id, ARRAY['item one', 'item two']);

  -- commit 1: token for position 1 in this job
  INSERT INTO guardops.commit_seen
    (account_id, repo_link_id, repo, sha, committed_at, message, files, first_pull_id)
  VALUES
    (guardops.current_account(), v_link_id, '0112-proof/repo',
     '0112-proof-sha-1', v_opened_at,
     'implement item one GO-' || v_job_id || '-1',
     '{}', v_pull_id)
  RETURNING id INTO v_cs1_id;

  -- commit 2: no token at all
  INSERT INTO guardops.commit_seen
    (account_id, repo_link_id, repo, sha, committed_at, message, files, first_pull_id)
  VALUES
    (guardops.current_account(), v_link_id, '0112-proof/repo',
     '0112-proof-sha-2', v_opened_at,
     'just a cleanup commit',
     '{}', v_pull_id)
  RETURNING id INTO v_cs2_id;

  -- commit 3: token for a different job number
  INSERT INTO guardops.commit_seen
    (account_id, repo_link_id, repo, sha, committed_at, message, files, first_pull_id)
  VALUES
    (guardops.current_account(), v_link_id, '0112-proof/repo',
     '0112-proof-sha-3', v_opened_at,
     'cross-job GO-99999999-1',
     '{}', v_pull_id)
  RETURNING id INTO v_cs3_id;

  -- commit 4: token for position 999 which has no plan item
  INSERT INTO guardops.commit_seen
    (account_id, repo_link_id, repo, sha, committed_at, message, files, first_pull_id)
  VALUES
    (guardops.current_account(), v_link_id, '0112-proof/repo',
     '0112-proof-sha-4', v_opened_at,
     'bad pos GO-' || v_job_id || '-999',
     '{}', v_pull_id)
  RETURNING id INTO v_cs4_id;

  PERFORM guardops.plan_commit_link(v_job_id);

  -- 1. commit with token → exactly one plan_commit row pointing at that item
  SELECT * INTO v_pg_row FROM guardops.plan_commit
   WHERE plan_given_id = v_plan_items[1] AND commit_seen_id = v_cs1_id;
  RAISE NOTICE '1 token-links-item  got_id=% how_found=% pass=%',
    v_pg_row.id, v_pg_row.how_found,
    (v_pg_row.id IS NOT NULL AND v_pg_row.how_found = 'MESSAGE_REF');
  v_all_pass := v_all_pass AND (v_pg_row.id IS NOT NULL AND v_pg_row.how_found = 'MESSAGE_REF');

  -- 2. commit with no token → no row
  SELECT count(*) INTO v_rc FROM guardops.plan_commit WHERE commit_seen_id = v_cs2_id;
  RAISE NOTICE '2 no-token-no-row  got=% want=0 pass=%', v_rc, (v_rc = 0);
  v_all_pass := v_all_pass AND (v_rc = 0);

  -- 3. idempotent: second call does not add rows; show count both times
  SELECT count(*) INTO v_count1 FROM guardops.plan_commit WHERE plan_given_id = ANY(v_plan_items);
  PERFORM guardops.plan_commit_link(v_job_id);
  SELECT count(*) INTO v_count2 FROM guardops.plan_commit WHERE plan_given_id = ANY(v_plan_items);
  RAISE NOTICE '3 idempotent  first=% second=% pass=%', v_count1, v_count2, (v_count1 = v_count2 AND v_count1 = 1);
  v_all_pass := v_all_pass AND (v_count1 = v_count2 AND v_count1 = 1);

  -- 4. token with different job number → zero rows
  SELECT count(*) INTO v_rc FROM guardops.plan_commit WHERE commit_seen_id = v_cs3_id;
  RAISE NOTICE '4 wrong-job-no-row  got=% want=0 pass=%', v_rc, (v_rc = 0);
  v_all_pass := v_all_pass AND (v_rc = 0);

  -- 5. token with position that has no plan item → no row, no error
  SELECT count(*) INTO v_rc FROM guardops.plan_commit WHERE commit_seen_id = v_cs4_id;
  RAISE NOTICE '5 bad-pos-no-row  got=% want=0 pass=%', v_rc, (v_rc = 0);
  v_all_pass := v_all_pass AND (v_rc = 0);

  IF NOT v_all_pass THEN
    RAISE EXCEPTION '0112 proof failed — see NOTICE lines above';
  END IF;

  RAISE EXCEPTION '0112_proof_rollback';
EXCEPTION WHEN OTHERS THEN
  IF SQLERRM <> '0112_proof_rollback' THEN RAISE; END IF;
END $$;

-- 6. Existing sheets must not move
DO $$
DECLARE
  v_one   int;
  v_whole int;
  v_wall  int;
BEGIN
  SELECT count(*) INTO v_one   FROM guardops.one_run_test()   WHERE pass = true;
  SELECT count(*) INTO v_whole FROM guardops.whole_run_test() WHERE pass = true;
  SELECT count(*) INTO v_wall  FROM guardops.wall_test()      WHERE pass = true;

  RAISE NOTICE '6a one_run_test   got=% want=8  pass=%', v_one,   (v_one   = 8);
  RAISE NOTICE '6b whole_run_test got=% want=12 pass=%', v_whole, (v_whole = 12);
  RAISE NOTICE '6c wall_test      got=% want=18 pass=%', v_wall,  (v_wall  = 18);

  IF v_one <> 8 OR v_whole <> 12 OR v_wall <> 18 THEN
    RAISE EXCEPTION '0112 regression: one_run=% whole_run=% wall=%', v_one, v_whole, v_wall;
  END IF;
END $$;
