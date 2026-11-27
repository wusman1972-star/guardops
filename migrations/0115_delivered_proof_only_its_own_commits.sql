-- migrations/0115_delivered_proof_only_its_own_commits.sql
-- Board 12207: DELIVERED proof cites only THIS item's commits.
-- Removes the job-window fallback; items with no link read
-- 'no commit linked to this item'.  commit_object is LEFT-JOINed
-- so a linked commit with no file rows still shows its sha.
-- Only the DELIVERED proof expression in job_verdict changes.
-- one_run_test fixture updated to earn the proof honestly.

CREATE OR REPLACE FUNCTION guardops.job_verdict(p_job_id bigint)
 RETURNS TABLE(kind text, what text, proof text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_account_id    bigint;
  v_db_id         bigint;
  v_repo_link_id  bigint;
  v_opened_at     timestamptz;
  v_delivered_ids bigint[];
  v_added_objs    text[];
  v_deleted_objs  text[];
  v_before_pic    bigint;
  v_after_pic     bigint;
BEGIN
  SELECT j.account_id, j.watched_database_id, j.repo_link_id, j.opened_at,
         j.before_picture_id, j.after_picture_id
    INTO v_account_id, v_db_id, v_repo_link_id, v_opened_at,
         v_before_pic, v_after_pic
    FROM guardops.job j
   WHERE j.id         = p_job_id
     AND j.account_id = guardops.current_account();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'job % does not exist or does not belong to this account', p_job_id;
  END IF;

  SELECT array_agg(DISTINCT d ORDER BY d) FILTER (WHERE d IS NOT NULL)
    INTO v_delivered_ids
    FROM guardops.claim c
    CROSS JOIN LATERAL unnest(COALESCE(c.delivered_item_ids, ARRAY[]::bigint[])) AS d
   WHERE c.job_id     = p_job_id
     AND c.account_id = v_account_id;

  SELECT array_agg(DISTINCT a ORDER BY a) FILTER (WHERE a IS NOT NULL)
    INTO v_added_objs
    FROM guardops.claim c
    CROSS JOIN LATERAL unnest(COALESCE(c.added, ARRAY[]::text[])) AS a
   WHERE c.job_id     = p_job_id
     AND c.account_id = v_account_id;

  SELECT array_agg(DISTINCT del ORDER BY del) FILTER (WHERE del IS NOT NULL)
    INTO v_deleted_objs
    FROM guardops.claim c
    CROSS JOIN LATERAL unnest(COALESCE(c.deleted, ARRAY[]::text[])) AS del
   WHERE c.job_id     = p_job_id
     AND c.account_id = v_account_id;

  RETURN QUERY
  SELECT
    'DELIVERED'::text,
    pg.item_text,
    CASE
      WHEN NOT EXISTS (
        SELECT 1 FROM guardops.plan_commit pc_ex
        WHERE  pc_ex.plan_given_id = pg.id
          AND  pc_ex.account_id    = v_account_id
      ) THEN 'no commit linked to this item'
      ELSE 'this item''s commits: ' || (
        SELECT string_agg(
                 CASE WHEN co2.file_key IS NOT NULL
                      THEN cs2.sha || ' -> ' || co2.file_key
                      ELSE cs2.sha
                 END,
                 '; ' ORDER BY cs2.committed_at, cs2.sha, COALESCE(co2.file_key, '')
               )
          FROM guardops.plan_commit pc2
          JOIN guardops.commit_seen cs2
               ON  cs2.id          = pc2.commit_seen_id
               AND cs2.account_id  = v_account_id
               AND cs2.committed_at >= v_opened_at
               AND cs2.committed_at <= COALESCE(
                     (SELECT MAX(c2.claimed_at)
                        FROM guardops.claim c2
                       WHERE c2.job_id     = p_job_id
                         AND c2.account_id = v_account_id),
                     now()
                   )
          LEFT JOIN guardops.commit_object co2
               ON  co2.commit_seen_id = cs2.id
               AND co2.account_id     = v_account_id
         WHERE pc2.plan_given_id = pg.id
           AND pc2.account_id    = v_account_id
      )
    END
  FROM guardops.plan_given pg
  WHERE pg.job_id     = p_job_id
    AND pg.account_id = v_account_id
    AND pg.id = ANY(COALESCE(v_delivered_ids, ARRAY[]::bigint[]));

  RETURN QUERY
  SELECT
    'MISSING'::text,
    pg.item_text,
    'not in any claim'::text
  FROM guardops.plan_given pg
  WHERE pg.job_id     = p_job_id
    AND pg.account_id = v_account_id
    AND NOT (pg.id = ANY(COALESCE(v_delivered_ids, ARRAY[]::bigint[])));

  RETURN QUERY
  SELECT
    'ADDED'::text,
    obj.name,
    COALESCE(
      (SELECT 'pic ' || sc.prev_picture_id::text
              || '->' || sc.picture_id::text
              || ': ' || sc.schema_name || '.' || sc.object_name
         FROM guardops.shape_change sc
        WHERE sc.picture_id      = v_after_pic
          AND sc.prev_picture_id = v_before_pic
          AND sc.change_kind     = 'APPEARED'
          AND sc.schema_name || '.' || split_part(sc.object_name, '(', 1) = obj.name
        LIMIT 1),
      'no shape record'
    )
  FROM unnest(COALESCE(v_added_objs, ARRAY[]::text[])) AS obj(name);

  RETURN QUERY
  SELECT
    'DELETED'::text,
    obj.name,
    COALESCE(
      (SELECT 'pic ' || sc.prev_picture_id::text
              || '->' || sc.picture_id::text
              || ': ' || sc.schema_name || '.' || sc.object_name
         FROM guardops.shape_change sc
        WHERE sc.picture_id      = v_after_pic
          AND sc.prev_picture_id = v_before_pic
          AND sc.change_kind     = 'GONE'
          AND sc.schema_name || '.' || split_part(sc.object_name, '(', 1) = obj.name
        LIMIT 1),
      'no shape record'
    )
  FROM unnest(COALESCE(v_deleted_objs, ARRAY[]::text[])) AS obj(name);

  RETURN QUERY
  SELECT
    ('CLAIM ' || upper(cvg.claim_kind))::text,
    cvg.claim_value::text,
    (cvg.verdict || ' - ' || cvg.detail)::text
  FROM guardops.claim c
  CROSS JOIN LATERAL guardops.claim_vs_git(c.id) AS cvg
  WHERE c.job_id     = p_job_id
    AND c.account_id = v_account_id
  ORDER BY c.id;

END;
$function$;

CREATE OR REPLACE FUNCTION guardops.one_run_test()
 RETURNS TABLE(step integer, what text, got text, want text, pass boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'guardops', 'pg_catalog', 'pg_temp'
AS $function$
DECLARE
  v_acct_id        bigint;
  v_cust_id        bigint;
  v_db_id          bigint;
  v_link_id        bigint;
  v_pull_id        bigint;
  v_job_id         bigint;
  v_plan_items     bigint[];
  v_before_pic     bigint;
  v_after_pic      bigint;
  v_claim_id       bigint;
  v_opened_at      timestamptz;
  v_delivered      int;
  v_missing        int;
  v_added          int;
  v_deleted        int;
  v_cs_cites_id    bigint;
  v_added_proof    text;
  v_deleted_proof  text;
  v_deliv_proof    text;
BEGIN
  BEGIN

    INSERT INTO guardops.account (name)
      VALUES ('one_run_test') RETURNING id INTO v_acct_id;
    INSERT INTO guardops.customer (account_id, external_id)
      VALUES (v_acct_id, 'one_run_test') RETURNING id INTO v_cust_id;
    INSERT INTO guardops.connected_account
      (account_id, customer_id, token_secret_name, status)
      VALUES (v_acct_id, v_cust_id, 'one_run_test-tok', 'ACTIVE');
    PERFORM guardops.act_as_house(v_cust_id);

    EXECUTE 'CREATE FUNCTION guardops.fn_deleted_obj() RETURNS int LANGUAGE sql AS $q$ SELECT 1 $q$';

    IF NOT EXISTS (
      SELECT 1 FROM information_schema.routines
      WHERE routine_schema = 'guardops' AND routine_name = 'watched_database_add'
    ) THEN
      step := 1; what := 'watched_database_add'; got := NULL;
      want := 'door must exist'; pass := false;
      RETURN NEXT;
      RAISE EXCEPTION 'one_run_rollback';
    END IF;
    v_db_id := guardops.watched_database_add('one_run_test');

    IF NOT EXISTS (
      SELECT 1 FROM information_schema.routines
      WHERE routine_schema = 'guardops' AND routine_name = 'job_add'
    ) THEN
      step := 2; what := 'job_add'; got := NULL;
      want := 'door must exist'; pass := false;
      RETURN NEXT;
      RAISE EXCEPTION 'one_run_rollback';
    END IF;
    INSERT INTO guardops.repo_link (account_id, repo, branch, linked_by, active)
    VALUES (guardops.current_account(), 'one-run-test/repo', 'main', 'TEST', false)
    RETURNING id INTO v_link_id;

    INSERT INTO guardops.repo_pull (account_id, repo_link_id)
    VALUES (guardops.current_account(), v_link_id)
    RETURNING id INTO v_pull_id;

    v_job_id := guardops.job_start(v_db_id, v_link_id,
                                   'one_run_test: deliberate wrong claim', 'guardops');
    SELECT before_picture_id INTO v_before_pic FROM guardops.job WHERE id = v_job_id;
    SELECT opened_at INTO v_opened_at FROM guardops.job WHERE id = v_job_id;

    IF NOT EXISTS (
      SELECT 1 FROM information_schema.routines
      WHERE routine_schema = 'guardops' AND routine_name = 'plan_given_add'
    ) THEN
      step := 3; what := 'plan_given_add'; got := NULL;
      want := 'door must exist'; pass := false;
      RETURN NEXT;
      RAISE EXCEPTION 'one_run_rollback';
    END IF;
    v_plan_items := guardops.plan_given_add(
      v_job_id,
      ARRAY['add function alpha', 'add function beta', 'add function gamma']
    );

    EXECUTE 'CREATE FUNCTION guardops.fn_surprise_added() RETURNS int LANGUAGE sql AS $q$ SELECT 2 $q$';
    EXECUTE 'DROP FUNCTION guardops.fn_deleted_obj()';

    IF NOT EXISTS (
      SELECT 1 FROM information_schema.routines
      WHERE routine_schema = 'guardops' AND routine_name = 'claim_add'
    ) THEN
      step := 5; what := 'claim_add'; got := NULL;
      want := 'door must exist'; pass := false;
      RETURN NEXT;
      RAISE EXCEPTION 'one_run_rollback';
    END IF;
    PERFORM guardops.job_finish(
      v_job_id,
      v_plan_items[1:2],
      ARRAY['guardops.fn_surprise_added'],
      ARRAY['guardops.fn_deleted_obj']
    );
    SELECT after_picture_id INTO v_after_pic FROM guardops.job WHERE id = v_job_id;
    SELECT id INTO v_claim_id FROM guardops.claim WHERE job_id = v_job_id ORDER BY id DESC LIMIT 1;

    PERFORM guardops.commit_record(
      'test/one_run_test_repo', 'main',
      'aaabbbccc111222333444555666777888999000aaab',
      'one-run-tester', now(),
      'deliberate wrong commit for one_run_test',
      '["alpha.sql","beta.sql","surprise.sql"]'::jsonb,
      NULL
    );

    INSERT INTO guardops.commit_seen
      (account_id, repo_link_id, repo, sha,
       committed_at, message, files, first_pull_id)
    VALUES
      (guardops.current_account(), v_link_id, 'one-run-test/repo',
       'bbbb0000000000000000000000000000000000000001',
       v_opened_at - interval '1 hour',
       'before-window commit', '{"before.sql":"-- before"}'::jsonb,
       v_pull_id);

    IF NOT EXISTS (
      SELECT 1 FROM information_schema.routines
      WHERE routine_schema = 'guardops' AND routine_name = 'job_verdict'
    ) THEN
      step := 8; what := 'job_verdict'; got := NULL;
      want := 'door must exist'; pass := false;
      RETURN NEXT;
      RAISE EXCEPTION 'one_run_rollback';
    END IF;

    SELECT count(*) INTO v_delivered FROM guardops.job_verdict(v_job_id) WHERE kind = 'DELIVERED';
    SELECT count(*) INTO v_missing   FROM guardops.job_verdict(v_job_id) WHERE kind = 'MISSING';
    SELECT count(*) INTO v_added     FROM guardops.job_verdict(v_job_id) WHERE kind = 'ADDED';
    SELECT count(*) INTO v_deleted   FROM guardops.job_verdict(v_job_id) WHERE kind = 'DELETED';

    SELECT proof INTO v_added_proof   FROM guardops.job_verdict(v_job_id) WHERE kind = 'ADDED'     LIMIT 1;
    SELECT proof INTO v_deleted_proof FROM guardops.job_verdict(v_job_id) WHERE kind = 'DELETED'   LIMIT 1;
    SELECT proof INTO v_deliv_proof   FROM guardops.job_verdict(v_job_id) WHERE kind = 'DELIVERED' LIMIT 1;

    step := 9; what := 'delivered'; got := v_delivered::text; want := '2';
    pass := (v_delivered = 2); RETURN NEXT;

    step := 9; what := 'missing';   got := v_missing::text;   want := '1';
    pass := (v_missing   = 1); RETURN NEXT;

    step := 9; what := 'added';     got := v_added::text;     want := '1';
    pass := (v_added     = 1); RETURN NEXT;

    step := 9; what := 'deleted';   got := v_deleted::text;   want := '1';
    pass := (v_deleted   = 1); RETURN NEXT;

    step := 9; what := 'added_proof'; got := v_added_proof;
    want := 'not null, not "no shape record"';
    pass := (v_added_proof IS NOT NULL AND v_added_proof NOT LIKE '%no shape record%'); RETURN NEXT;

    step := 9; what := 'deleted_proof'; got := v_deleted_proof;
    want := 'not null, not "no shape record"';
    pass := (v_deleted_proof IS NOT NULL AND v_deleted_proof NOT LIKE '%no shape record%'); RETURN NEXT;

    step := 9; what := 'delivered_proof_scoped'; got := v_deliv_proof;
    want := 'no commit linked to this item';
    pass := (v_deliv_proof = 'no commit linked to this item'); RETURN NEXT;

    INSERT INTO guardops.commit_seen
      (account_id, repo_link_id, repo, sha,
       committed_at, message, files, first_pull_id)
    VALUES
      (guardops.current_account(), v_link_id, 'one-run-test/repo',
       'cccc0000000000000000000000000000000000000002',
       v_opened_at,
       'in-window commit GO-' || v_job_id || '-1', '{"change.sql":"-- in window"}'::jsonb,
       v_pull_id)
    RETURNING id INTO v_cs_cites_id;

    INSERT INTO guardops.commit_object
      (account_id, commit_seen_id, repo_link_id, committed_at, file_key, is_delete)
    VALUES
      (guardops.current_account(), v_cs_cites_id, v_link_id, v_opened_at, 'change.sql', false);

    PERFORM guardops.plan_commit_link(v_job_id);

    SELECT jv.proof INTO v_deliv_proof
      FROM guardops.job_verdict(v_job_id) AS jv
     WHERE jv.kind = 'DELIVERED'
       AND jv.what = 'add function alpha';

    step := 9; what := 'delivered_proof_cites'; got := v_deliv_proof;
    want := 'this item''s commits';
    pass := (v_deliv_proof LIKE 'this item''s commits:%'); RETURN NEXT;

    RAISE EXCEPTION 'one_run_rollback';

  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'one_run_rollback' THEN
      RAISE;
    END IF;
  END;
END;
$function$;

-- Proof items 1-5 — subtransaction that rolls back
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
  v_sha_a      text := '0115aaaa000000000000000000000000000000000001';
  v_sha_b      text := '0115bbbb000000000000000000000000000000000002';
  v_sha_c      text := '0115cccc000000000000000000000000000000000003';
  v_sha_late   text := '0115dddd000000000000000000000000000000000004';
  v_all_pass   boolean := true;
  v_count      int;
BEGIN
  BEGIN
    INSERT INTO guardops.account(name) VALUES('0115_proof') RETURNING id INTO v_acct_id;
    INSERT INTO guardops.customer(account_id, external_id)
      VALUES(v_acct_id, '0115_proof') RETURNING id INTO v_cust_id;
    INSERT INTO guardops.connected_account
      (account_id, customer_id, token_secret_name, status)
      VALUES(v_acct_id, v_cust_id, '0115-proof-tok', 'ACTIVE');
    PERFORM guardops.act_as_house(v_cust_id);

    EXECUTE 'CREATE FUNCTION guardops.fn_0115_proof_del() RETURNS int LANGUAGE sql AS $q$ SELECT 1 $q$';

    v_db_id := guardops.watched_database_add('0115_proof_db');

    INSERT INTO guardops.repo_link
      (account_id, repo, branch, linked_by, active)
    VALUES
      (guardops.current_account(), '0115-proof/repo', 'main', 'TEST', false)
    RETURNING id INTO v_link_id;

    INSERT INTO guardops.repo_pull
      (account_id, repo_link_id)
    VALUES
      (guardops.current_account(), v_link_id)
    RETURNING id INTO v_pull_id;

    v_job_id := guardops.job_start(v_db_id, v_link_id, '0115_proof', 'guardops');
    SELECT opened_at INTO v_opened_at FROM guardops.job WHERE id = v_job_id;

    v_plan_items := guardops.plan_given_add(
      v_job_id,
      ARRAY['item alpha', 'item beta', 'item gamma']
    );

    EXECUTE 'CREATE FUNCTION guardops.fn_0115_proof_add() RETURNS int LANGUAGE sql AS $q$ SELECT 2 $q$';
    EXECUTE 'DROP FUNCTION guardops.fn_0115_proof_del()';

    PERFORM guardops.job_finish(
      v_job_id,
      v_plan_items[1:2],
      ARRAY['guardops.fn_0115_proof_add'],
      ARRAY['guardops.fn_0115_proof_del']
    );

    -- sha_a: item alpha (position 1), in-window, has file rows
    INSERT INTO guardops.commit_seen
      (account_id, repo_link_id, repo, sha, committed_at, message, files, first_pull_id)
    VALUES
      (guardops.current_account(), v_link_id, '0115-proof/repo',
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
      (guardops.current_account(), v_link_id, '0115-proof/repo',
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
      (guardops.current_account(), v_link_id, '0115-proof/repo',
       v_sha_c, v_opened_at, 'extra GO-' || v_job_id || '-1', '{}', v_pull_id)
    RETURNING id INTO v_cs_c;
    -- deliberately no commit_object rows for sha_c

    -- sha_late: item alpha (position 1), committed AFTER the last claim
    INSERT INTO guardops.commit_seen
      (account_id, repo_link_id, repo, sha, committed_at, message, files, first_pull_id)
    VALUES
      (guardops.current_account(), v_link_id, '0115-proof/repo',
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

    -- 1. Item alpha cites its sha; item beta cites its sha; neither says "no commit linked"
    RAISE NOTICE '1a item_alpha  got="%"  starts=%  has_sha_a=%  pass=%',
      v_p1,
      (v_p1 LIKE 'this item''s commits:%'),
      (v_p1 LIKE '%' || v_sha_a || '%'),
      (v_p1 LIKE 'this item''s commits:%' AND v_p1 LIKE '%' || v_sha_a || '%');
    v_all_pass := v_all_pass
      AND (v_p1 LIKE 'this item''s commits:%' AND v_p1 LIKE '%' || v_sha_a || '%');

    RAISE NOTICE '1b item_beta  got="%"  starts=%  has_sha_b=%  pass=%',
      v_p2,
      (v_p2 LIKE 'this item''s commits:%'),
      (v_p2 LIKE '%' || v_sha_b || '%'),
      (v_p2 LIKE 'this item''s commits:%' AND v_p2 LIKE '%' || v_sha_b || '%');
    v_all_pass := v_all_pass
      AND (v_p2 LIKE 'this item''s commits:%' AND v_p2 LIKE '%' || v_sha_b || '%');

    -- 2. Item alpha proof does NOT contain sha_b (sha_b belongs only to item beta)
    RAISE NOTICE '2 alpha_no_sha_b  has_sha_b=%  pass=%',
      (v_p1 LIKE '%' || v_sha_b || '%'),
      NOT (v_p1 LIKE '%' || v_sha_b || '%');
    v_all_pass := v_all_pass AND NOT (v_p1 LIKE '%' || v_sha_b || '%');

    -- 3. sha_c (no file rows) still appears in item alpha proof as sha alone
    RAISE NOTICE '3 no_file_sha_shows  has_sha_c=%  pass=%',
      (v_p1 LIKE '%' || v_sha_c || '%'),
      (v_p1 LIKE '%' || v_sha_c || '%');
    v_all_pass := v_all_pass AND (v_p1 LIKE '%' || v_sha_c || '%');

    -- 4. sha_late (committed after last claim) is not cited
    RAISE NOTICE '4 late_not_cited  has_sha_late=%  pass=%',
      (v_p1 LIKE '%' || v_sha_late || '%'),
      NOT (v_p1 LIKE '%' || v_sha_late || '%');
    v_all_pass := v_all_pass AND NOT (v_p1 LIKE '%' || v_sha_late || '%');

    -- 5. MISSING, ADDED, DELETED still present
    SELECT count(*) INTO v_count FROM guardops.job_verdict(v_job_id) WHERE kind = 'MISSING';
    RAISE NOTICE '5a missing  got=%  want=1  pass=%', v_count, (v_count = 1);
    v_all_pass := v_all_pass AND (v_count = 1);

    SELECT count(*) INTO v_count FROM guardops.job_verdict(v_job_id) WHERE kind = 'ADDED';
    RAISE NOTICE '5b added  got=%  want=1  pass=%', v_count, (v_count = 1);
    v_all_pass := v_all_pass AND (v_count = 1);

    SELECT count(*) INTO v_count FROM guardops.job_verdict(v_job_id) WHERE kind = 'DELETED';
    RAISE NOTICE '5c deleted  got=%  want=1  pass=%', v_count, (v_count = 1);
    v_all_pass := v_all_pass AND (v_count = 1);

    IF NOT v_all_pass THEN
      RAISE EXCEPTION '0115 proof failed — see NOTICE lines above';
    END IF;

    RAISE EXCEPTION '0115_proof_rollback';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> '0115_proof_rollback' THEN RAISE; END IF;
  END;
END $$;

-- 6. Existing test suites must not move
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
    RAISE EXCEPTION '0115 regression: one_run=% whole_run=% wall=%', v_one, v_whole, v_wall;
  END IF;
END $$;
