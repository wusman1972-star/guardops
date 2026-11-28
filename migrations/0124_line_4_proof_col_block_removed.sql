-- migrations/0124_line_4_proof_col_block_removed.sql
-- Board 12249. Line 4 was appending the wrong object's columns from claim.added.
-- v_built_col_proof read unrequested objects (line 6's input) and appended their
-- column before/after block to line 4 (delivered items). That is the one mistake
-- this product must never make.
-- Fix: delete v_built_col_proof and everything that feeds it. Line 4 proof returns
-- to the changed code lines alone — the +CREATE text already built from plan_commit
-- and commit_object. Nothing is appended to it.
-- Leave line 6, line 7, and the one-argument overload exactly as 0123 left them.

-- ========================================================================
-- PREFLIGHT — refuse if 0123 did not land or 0124 already fired.
-- ========================================================================
DO $preflight$
BEGIN
  IF coalesce(md5((SELECT prosrc FROM pg_catalog.pg_proc
     WHERE oid = to_regprocedure('guardops.page_lines(bigint, bigint)'))), '')
     NOT IN ('7d4e468ac049b074d84cb41dbca5b10f',
              'e8cf2094105e8cca6904bb3524d5af74',
              'd4d96e464aaddb66f677733e29fefc0f') THEN
    RAISE EXCEPTION '0124 REFUSED: page_lines(bigint,bigint) is not the 0123 or prior-0124 body (not landed, or already fixed).';
  END IF;
  IF coalesce(md5((SELECT prosrc FROM pg_catalog.pg_proc
     WHERE oid = to_regprocedure('guardops.page_lines(bigint)'))), '')
     NOT IN ('a5462bb5f7ece5a4b976f788668791a1') THEN
    RAISE EXCEPTION '0124 REFUSED: page_lines(bigint) is not the 0123 body (not landed, or already modified).';
  END IF;
END $preflight$;

-- ========================================================================
-- TWO-ARGUMENT OVERLOAD — replace whole body, leave signature unchanged.
-- v_built_col_proof removed: line 4 proof ends at the last +CREATE line.
-- ========================================================================
CREATE OR REPLACE FUNCTION guardops.page_lines(p_customer bigint, p_job_id bigint)
 RETURNS TABLE(line_no integer, heading text, body text, proof text, detail text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_account         bigint;
  v_job_wfor        text;
  v_opened_str      text;
  v_db_label        text;
  v_plan_body       text;
  v_opened_at       timestamptz;
  v_before_pic      bigint;
  v_after_pic       bigint;
  v_built_body      text;
  v_built_proof     text;
  v_built_detail    text;
  v_unbuilt_body    text;
  v_unbuilt_proof   text;
  v_added_body      text;
  v_added_proof     text;
  v_added_detail    text;
  v_deleted_body    text;
  v_deleted_proof   text;
  v_deleted_detail  text;
  v_delivered_names text[];
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
         coalesce(nullif(btrim(wd.label), ''), wd.project_ref, 'unknown database'),
         j.opened_at,
         j.before_picture_id,
         j.after_picture_id
    INTO v_job_wfor, v_opened_str, v_db_label,
         v_opened_at, v_before_pic, v_after_pic
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

  -- Body from job_verdict; old proof becomes new detail.
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
    v_built_body,   v_built_detail,
    v_unbuilt_body, v_unbuilt_proof,
    v_added_body,   v_added_detail,
    v_deleted_body, v_deleted_detail
  FROM guardops.job_verdict(p_job_id) AS jv;

  -- Delivered-names set: in AFTER picture, absent from BEFORE, not in claim.added.
  -- An object belongs here only if the picture says it arrived this job AND it was
  -- not flagged as an unrequested addition. This is what line 4 is allowed to claim.
  SELECT array_agg(DISTINCT so.schema_name || '.' || split_part(so.object_name, '(', 1))
    INTO v_delivered_names
    FROM guardops.shape_object so
   WHERE so.picture_id = v_after_pic
     AND so.account_id = v_account
     AND NOT EXISTS (
       SELECT 1 FROM guardops.shape_object sb
        WHERE sb.picture_id  = v_before_pic
          AND sb.account_id  = v_account
          AND sb.schema_name = so.schema_name
          AND sb.object_name = so.object_name
     )
     AND so.schema_name || '.' || split_part(so.object_name, '(', 1) NOT IN (
       SELECT a
         FROM guardops.claim c
        CROSS JOIN LATERAL unnest(COALESCE(c.added, ARRAY[]::text[])) AS a
        WHERE c.job_id     = p_job_id
          AND c.account_id = v_account
     );

  -- Proof for DELIVERED: actual changed lines from commit_object.
  SELECT string_agg(
    coalesce(
      (SELECT string_agg(co.obj_lines, E'\n' ORDER BY cs.committed_at, co.file_key)
         FROM guardops.plan_commit pc
         JOIN guardops.commit_seen cs
              ON  cs.id           = pc.commit_seen_id
              AND cs.account_id   = v_account
              AND cs.committed_at >= v_opened_at
              AND cs.committed_at <= COALESCE(
                    (SELECT MAX(c2.claimed_at)
                       FROM guardops.claim c2
                      WHERE c2.job_id     = p_job_id
                        AND c2.account_id = v_account),
                    now())
         JOIN guardops.commit_object co
              ON  co.commit_seen_id = cs.id
              AND co.account_id     = v_account
              AND co.obj_lines IS NOT NULL
              AND lower(replace(
                    COALESCE(
                      (regexp_match(
                        co.obj_lines,
                        '(?i)(?:^|[\r\n])[+\- ]*(?:create(?:\s+or\s+replace)?(?:\s+(?:temp(?:orary)?))?(?:\s+unlogged)?\s+(?:(?:materialized\s+)?view|table|function|type|sequence|trigger)|alter\s+(?:table|view|type))\s+(?:if\s+not\s+exists\s+)?((?:"[^"]*"|[A-Za-z_]\w*)\.(?:"[^"]*"|[A-Za-z_]\w*))'
                      ))[1],
                      ''
                    ),
                    '"', ''
                  )) = ANY(
                    SELECT lower(dn.name)
                      FROM unnest(COALESCE(v_delivered_names, ARRAY[]::text[])) AS dn(name)
                  )
        WHERE pc.plan_given_id = pg.id
          AND pc.account_id    = v_account),
      'nothing to prove'
    ),
    E'\n' ORDER BY pg.item_text
  ) INTO v_built_proof
  FROM guardops.plan_given pg
  WHERE pg.job_id     = p_job_id
    AND pg.account_id = guardops.current_account()
    AND pg.id = ANY(
      SELECT d
        FROM guardops.claim c
       CROSS JOIN LATERAL unnest(COALESCE(c.delivered_item_ids, ARRAY[]::bigint[])) AS d
       WHERE c.job_id     = p_job_id
         AND c.account_id = v_account
    );

  -- Proof for ADDED: before and after columns side by side.
  -- Before half: columns from before picture if the object existed, else "did not exist".
  -- After half:  columns from after picture.
  SELECT string_agg(
    combined.proof_text,
    E'\n' ORDER BY obj.name
  ) INTO v_added_proof
  FROM unnest(
    COALESCE(
      (SELECT array_agg(DISTINCT a ORDER BY a) FILTER (WHERE a IS NOT NULL)
         FROM guardops.claim c
        CROSS JOIN LATERAL unnest(COALESCE(c.added, ARRAY[]::text[])) AS a
        WHERE c.job_id     = p_job_id
          AND c.account_id = v_account),
      ARRAY[]::text[]
    )
  ) AS obj(name)
  CROSS JOIN LATERAL (
    SELECT
      CASE
        WHEN b_cols.cols IS NOT NULL
          THEN 'Before:' || E'\n' || b_cols.cols
        ELSE 'Before: did not exist'
      END || E'\n' || 'After:' || E'\n' || coalesce(a_cols.cols, 'no column record')
    AS proof_text
    FROM
      (SELECT string_agg(e.name || ' ' || e.type, E'\n') AS cols
         FROM (SELECT so.column_shape
                 FROM guardops.shape_object so
                WHERE so.picture_id  = v_before_pic
                  AND so.account_id  = v_account
                  AND so.schema_name || '.' || split_part(so.object_name, '(', 1) = obj.name
                LIMIT 1) one_row,
              LATERAL jsonb_to_recordset(one_row.column_shape) AS e(name text, type text)
      ) b_cols,
      (SELECT string_agg(e.name || ' ' || e.type, E'\n') AS cols
         FROM (SELECT so.column_shape
                 FROM guardops.shape_object so
                WHERE so.picture_id  = v_after_pic
                  AND so.account_id  = v_account
                  AND so.schema_name || '.' || split_part(so.object_name, '(', 1) = obj.name
                LIMIT 1) one_row,
              LATERAL jsonb_to_recordset(one_row.column_shape) AS e(name text, type text)
      ) a_cols
  ) combined;

  -- Proof for DELETED: before columns then "After: gone".
  SELECT string_agg(
    combined.proof_text,
    E'\n' ORDER BY obj.name
  ) INTO v_deleted_proof
  FROM unnest(
    COALESCE(
      (SELECT array_agg(DISTINCT del ORDER BY del) FILTER (WHERE del IS NOT NULL)
         FROM guardops.claim c
        CROSS JOIN LATERAL unnest(COALESCE(c.deleted, ARRAY[]::text[])) AS del
        WHERE c.job_id     = p_job_id
          AND c.account_id = v_account),
      ARRAY[]::text[]
    )
  ) AS obj(name)
  CROSS JOIN LATERAL (
    SELECT
      'Before:' || E'\n' || coalesce(b_cols.cols, 'no column record') || E'\n' || 'After: gone'
    AS proof_text
    FROM
      (SELECT string_agg(e.name || ' ' || e.type, E'\n') AS cols
         FROM (SELECT so.column_shape
                 FROM guardops.shape_object so
                WHERE so.picture_id  = v_before_pic
                  AND so.account_id  = v_account
                  AND so.schema_name || '.' || split_part(so.object_name, '(', 1) = obj.name
                LIMIT 1) one_row,
              LATERAL jsonb_to_recordset(one_row.column_shape) AS e(name text, type text)
      ) b_cols
  ) combined;

  line_no := 1; heading := 'What went in';
  body    := 'Job: ' || coalesce(v_job_wfor, 'untitled')
          || '. Database: ' || coalesce(v_db_label, 'unknown database')
          || '. Opened: ' || coalesce(v_opened_str, 'unknown') || '.';
  proof   := 'nothing to prove';
  detail  := '';
  RETURN NEXT;

  line_no := 2; heading := 'What was planned';
  body    := coalesce(nullif(btrim(coalesce(v_plan_body, '')), ''), 'Nothing was planned.');
  proof   := 'nothing to prove';
  detail  := '';
  RETURN NEXT;

  line_no := 3; heading := 'You asked for it - started, not finished';
  body    := 'Nothing was held.';
  proof   := 'nothing to prove';
  detail  := '';
  RETURN NEXT;

  line_no := 4; heading := 'You asked for it - it is there';
  body    := coalesce(nullif(v_built_body, ''), 'Nothing was built.');
  proof   := coalesce(nullif(btrim(coalesce(v_built_proof, '')), ''), 'nothing to prove');
  detail  := coalesce(v_built_detail, '');
  RETURN NEXT;

  line_no := 5; heading := 'You asked for it - it is not there';
  body    := coalesce(nullif(v_unbuilt_body,  ''), 'Nothing was left unbuilt.');
  proof   := coalesce(nullif(v_unbuilt_proof, ''), 'nothing to prove');
  detail  := '';
  RETURN NEXT;

  line_no := 6; heading := 'It is there - you never asked for it';
  body    := coalesce(nullif(v_added_body,  ''), 'Nothing was added.');
  proof   := coalesce(nullif(v_added_proof, ''), 'nothing to prove');
  detail  := coalesce(v_added_detail, '');
  RETURN NEXT;

  line_no := 7; heading := 'It was there - now it is gone';
  body    := coalesce(nullif(v_deleted_body,  ''), 'Nothing was deleted.');
  proof   := coalesce(nullif(v_deleted_proof, ''), 'nothing to prove');
  detail  := coalesce(v_deleted_detail, '');
  RETURN NEXT;
END;
$function$;

-- ========================================================================
-- EXECUTE LOCKDOWN — both overloads: postgres and service_role only.
-- ========================================================================
REVOKE ALL ON FUNCTION guardops.page_lines(bigint, bigint) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION guardops.page_lines(bigint, bigint) TO postgres, service_role;
REVOKE ALL ON FUNCTION guardops.page_lines(bigint) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION guardops.page_lines(bigint) TO postgres, service_role;

-- ========================================================================
-- PROOF — rolls back all fixture data; function replacement stands.
-- Four checks: fixture test, grants, security, suites.
-- ========================================================================
DO $$
DECLARE
  v_proof_4     text;
  v_proof_6     text;
  v_acct        bigint;
  v_cust        bigint;
  v_db          bigint;
  v_link        bigint;
  v_pull_id     bigint;
  v_cs          bigint;
  v_job         bigint;
  v_plans       bigint[];
  v_one_fail    bigint;  v_one_total    bigint;
  v_whole_fail  bigint;  v_whole_total  bigint;
  v_wall_fail   bigint;  v_wall_total   bigint;
BEGIN
  BEGIN

    -- check 2: fixture — one commit touching two .sql files; only the planned object
    --          must appear on line 4. Line 4 must have +CREATE for the planned obj,
    --          no col block, and must NOT carry the unrequested obj. Line 6 must
    --          have both Before: and After: for the added object.
    INSERT INTO guardops.account (name) VALUES ('0124_proof') RETURNING id INTO v_acct;
    INSERT INTO guardops.customer (account_id, external_id)
      VALUES (v_acct, '0124_proof') RETURNING id INTO v_cust;
    INSERT INTO guardops.connected_account
      (account_id, customer_id, token_secret_name, status)
      VALUES (v_acct, v_cust, '0124_proof_tok', 'ACTIVE');
    PERFORM guardops.act_as_house(v_cust);

    v_db   := guardops.watched_database_add('0124_proof_db');
    v_link := guardops.repo_link_add('0124-proof/repo', 'main');

    v_job   := guardops.job_start(v_db, v_link, '0124 proof job', 'guardops');
    v_plans := guardops.plan_given_add(v_job, ARRAY['add planned table']);

    -- Create both tables AFTER job_start so neither appears in the before picture.
    EXECUTE 'CREATE TABLE guardops.invoice (inv_id bigint, inv_val text)';
    EXECUTE 'CREATE TABLE guardops.invoice_audit (aud_id bigint, aud_val text)';

    SELECT pl.pull_id INTO v_pull_id FROM guardops.pull_begin(v_link) AS pl;
    v_cs := guardops.commit_record(
      '0124-proof/repo', 'main',
      '0124a00000000000000000000000000000000000',
      'tester', now(),
      'GO-' || v_job::text || '-1 fixture',
      jsonb_build_object(
        'migrations/0124_proof.sql',
        '+CREATE TABLE guardops.invoice (inv_id bigint, inv_val text)',
        'migrations/0124_proof_added.sql',
        '+CREATE TABLE guardops.invoice_audit (aud_id bigint, aud_val text)'
      ),
      v_pull_id
    );
    PERFORM guardops.plan_commit_link(v_job);

    PERFORM guardops.job_finish(
      v_job,
      v_plans,
      ARRAY['guardops.invoice_audit'],
      ARRAY[]::text[]
    );

    SELECT proof INTO v_proof_4 FROM guardops.page_lines(v_cust, v_job) WHERE line_no = 4;
    SELECT proof INTO v_proof_6 FROM guardops.page_lines(v_cust, v_job) WHERE line_no = 6;
    RAISE NOTICE '0124 fixture line_4="%"', v_proof_4;
    RAISE NOTICE '0124 fixture line_6="%"', v_proof_6;

    IF v_proof_4 NOT LIKE '%+CREATE%' THEN
      RAISE EXCEPTION '0124 fixture: line 4 must have obj_lines (+CREATE), got [%]', v_proof_4;
    END IF;
    IF v_proof_4 LIKE '%Before:%' THEN
      RAISE EXCEPTION '0124 fixture: line 4 must NOT have col block (Before:), got [%]', v_proof_4;
    END IF;
    IF v_proof_4 NOT LIKE '%guardops.invoice%' THEN
      RAISE EXCEPTION '0124 fixture: line 4 must show planned obj (guardops.invoice), got [%]', v_proof_4;
    END IF;
    IF v_proof_4 LIKE '%invoice_audit%' THEN
      RAISE EXCEPTION '0124 fixture: line 4 must NOT show unrequested obj (invoice_audit), got [%]', v_proof_4;
    END IF;
    RAISE NOTICE '0124 fixture line_4 pass=true';

    IF v_proof_6 NOT LIKE '%Before: did not exist%' THEN
      RAISE EXCEPTION '0124 fixture: line 6 must have "Before: did not exist", got [%]', v_proof_6;
    END IF;
    IF v_proof_6 NOT LIKE '%After:%' THEN
      RAISE EXCEPTION '0124 fixture: line 6 must have "After:", got [%]', v_proof_6;
    END IF;
    IF v_proof_6 NOT LIKE '%aud_id%' THEN
      RAISE EXCEPTION '0124 fixture: line 6 must list added table columns (aud_id), got [%]', v_proof_6;
    END IF;
    RAISE NOTICE '0124 fixture line_6 pass=true';

    -- check 3: grants — anon/authenticated blocked, postgres/service_role have EXECUTE.
    IF has_function_privilege('anon', 'guardops.page_lines(bigint, bigint)', 'EXECUTE') THEN
      RAISE EXCEPTION '0124 grant: anon must not have EXECUTE on page_lines(bigint,bigint)';
    END IF;
    IF has_function_privilege('authenticated', 'guardops.page_lines(bigint, bigint)', 'EXECUTE') THEN
      RAISE EXCEPTION '0124 grant: authenticated must not have EXECUTE on page_lines(bigint,bigint)';
    END IF;
    IF NOT has_function_privilege('postgres', 'guardops.page_lines(bigint, bigint)', 'EXECUTE') THEN
      RAISE EXCEPTION '0124 grant: postgres must have EXECUTE on page_lines(bigint,bigint)';
    END IF;
    IF NOT has_function_privilege('service_role', 'guardops.page_lines(bigint, bigint)', 'EXECUTE') THEN
      RAISE EXCEPTION '0124 grant: service_role must have EXECUTE on page_lines(bigint,bigint)';
    END IF;
    IF has_function_privilege('anon', 'guardops.page_lines(bigint)', 'EXECUTE') THEN
      RAISE EXCEPTION '0124 grant: anon must not have EXECUTE on page_lines(bigint)';
    END IF;
    IF has_function_privilege('authenticated', 'guardops.page_lines(bigint)', 'EXECUTE') THEN
      RAISE EXCEPTION '0124 grant: authenticated must not have EXECUTE on page_lines(bigint)';
    END IF;
    IF NOT has_function_privilege('postgres', 'guardops.page_lines(bigint)', 'EXECUTE') THEN
      RAISE EXCEPTION '0124 grant: postgres must have EXECUTE on page_lines(bigint)';
    END IF;
    IF NOT has_function_privilege('service_role', 'guardops.page_lines(bigint)', 'EXECUTE') THEN
      RAISE EXCEPTION '0124 grant: service_role must have EXECUTE on page_lines(bigint)';
    END IF;
    RAISE NOTICE '0124 grant_check pass=true';

    -- check 4: SECURITY DEFINER and SET search_path TO '' on both overloads.
    IF NOT (SELECT prosecdef FROM pg_catalog.pg_proc
             WHERE oid = to_regprocedure('guardops.page_lines(bigint, bigint)')) THEN
      RAISE EXCEPTION '0124 security: page_lines(bigint,bigint) must be SECURITY DEFINER';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM unnest(
        (SELECT proconfig FROM pg_catalog.pg_proc
          WHERE oid = to_regprocedure('guardops.page_lines(bigint, bigint)'))) AS c
        WHERE c LIKE 'search_path=%') THEN
      RAISE EXCEPTION '0124 security: page_lines(bigint,bigint) must have SET search_path';
    END IF;
    IF NOT (SELECT prosecdef FROM pg_catalog.pg_proc
             WHERE oid = to_regprocedure('guardops.page_lines(bigint)')) THEN
      RAISE EXCEPTION '0124 security: page_lines(bigint) must be SECURITY DEFINER';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM unnest(
        (SELECT proconfig FROM pg_catalog.pg_proc
          WHERE oid = to_regprocedure('guardops.page_lines(bigint)'))) AS c
        WHERE c LIKE 'search_path=%') THEN
      RAISE EXCEPTION '0124 security: page_lines(bigint) must have SET search_path';
    END IF;
    RAISE NOTICE '0124 security_check pass=true';

    -- check 5: test suites must not regress.
    SELECT count(*) FILTER (WHERE pass IS NOT TRUE), count(*)
      INTO v_one_fail,   v_one_total   FROM guardops.one_run_test();
    SELECT count(*) FILTER (WHERE pass IS NOT TRUE), count(*)
      INTO v_whole_fail, v_whole_total FROM guardops.whole_run_test();
    SELECT count(*) FILTER (WHERE pass IS NOT TRUE), count(*)
      INTO v_wall_fail,  v_wall_total  FROM guardops.wall_test();

    RAISE NOTICE 'suites one_run_test   total=% fail=%  pass=%',
      v_one_total,   v_one_fail,   (v_one_total = 8   AND v_one_fail   = 0);
    RAISE NOTICE 'suites whole_run_test total=% fail=%  pass=%',
      v_whole_total, v_whole_fail, (v_whole_total = 12 AND v_whole_fail = 0);
    RAISE NOTICE 'suites wall_test      total=% fail=%  pass=%',
      v_wall_total,  v_wall_fail,  (v_wall_total = 18  AND v_wall_fail  = 0);

    IF v_one_total   <> 8  OR v_one_fail   <> 0
    OR v_whole_total <> 12 OR v_whole_fail <> 0
    OR v_wall_total  <> 18 OR v_wall_fail  <> 0 THEN
      RAISE EXCEPTION '0124 regression: one=%/% whole=%/% wall=%/%',
        v_one_total, v_one_fail, v_whole_total, v_whole_fail,
        v_wall_total, v_wall_fail;
    END IF;

    RAISE NOTICE '0124 all proofs passed — fixture rolled back, function replacement stands';
    RAISE EXCEPTION '0124_proof_rollback';

  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> '0124_proof_rollback' THEN RAISE; END IF;
  END;
END;
$$;
