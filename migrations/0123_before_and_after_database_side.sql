-- migrations/0123_before_and_after_database_side.sql
-- Board 12247. page_lines shows before/after side by side on lines 4, 6, and 7.
-- Line 6 proof: Before: (cols or "did not exist") / After: cols
-- Line 7 proof: Before: cols / After: gone
-- Line 4 proof: obj_lines then col before/after for claimed objects in either picture

-- ========================================================================
-- TWO-ARGUMENT OVERLOAD — replace whole body, leave signature unchanged.
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
  v_built_col_proof text;
  v_built_detail    text;
  v_unbuilt_body    text;
  v_unbuilt_proof   text;
  v_added_body      text;
  v_added_proof     text;
  v_added_detail    text;
  v_deleted_body    text;
  v_deleted_proof   text;
  v_deleted_detail  text;
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

  -- Column before/after for claimed objects that exist in either picture (appended to line 4).
  -- Only objects from claim.added that have a shape_object record in before or after picture.
  SELECT string_agg(
    combined.proof_text,
    E'\n' ORDER BY obj.name
  ) INTO v_built_col_proof
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
  JOIN LATERAL (
    SELECT 1 FROM guardops.shape_object so
     WHERE so.account_id = v_account
       AND so.schema_name || '.' || split_part(so.object_name, '(', 1) = obj.name
       AND so.picture_id IN (v_before_pic, v_after_pic)
     LIMIT 1
  ) exists_check ON TRUE
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
  proof   := coalesce(nullif(
    trim(both E'\n' from (
      coalesce(v_built_proof, '') ||
      CASE WHEN v_built_col_proof IS NOT NULL THEN E'\n' || v_built_col_proof ELSE '' END
    )),
    ''
  ), 'nothing to prove');
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
-- ONE-ARGUMENT WRAPPER — unchanged; passes all columns through.
-- ========================================================================
CREATE OR REPLACE FUNCTION guardops.page_lines(p_job_id bigint)
 RETURNS TABLE(line_no integer, heading text, body text, proof text, detail text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_account_id  bigint;
  v_customer_id bigint;
BEGIN
  SELECT j.account_id INTO v_account_id
    FROM guardops.job j
   WHERE j.id = p_job_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'job % was not found', p_job_id;
  END IF;

  SELECT c.id INTO v_customer_id
    FROM guardops.customer c
   WHERE c.account_id = v_account_id
   ORDER BY c.id
   LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'account % has no customer yet', v_account_id;
  END IF;

  PERFORM guardops.act_as_house(v_customer_id);
  RETURN QUERY SELECT * FROM guardops.page_lines(v_customer_id, p_job_id);
END;
$function$;

-- ========================================================================
-- EXECUTE LOCKDOWN — both overloads: postgres and service_role only.
-- Board 12240 held for exactly this.
-- ========================================================================
REVOKE ALL ON FUNCTION guardops.page_lines(bigint, bigint) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION guardops.page_lines(bigint, bigint) TO postgres, service_role;
REVOKE ALL ON FUNCTION guardops.page_lines(bigint) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION guardops.page_lines(bigint) TO postgres, service_role;

-- ========================================================================
-- PROOF — rolls back all fixture data; function replacements stand.
-- Three checks as required by board 12247.
-- ========================================================================
DO $$
DECLARE
  v_acct        bigint;
  v_cust        bigint;
  v_db          bigint;
  v_link        bigint;
  v_pull_id     bigint;
  v_cs          bigint;
  v_job_a       bigint;
  v_plans_a     bigint[];
  v_job_b       bigint;
  v_plans_b     bigint[];
  v_job_c       bigint;
  v_plans_c     bigint[];
  v_proof_4a    text;
  v_proof_6a    text;
  v_proof_6b    text;
  v_proof_7c    text;
  v_one_fail    bigint;  v_one_total    bigint;
  v_whole_fail  bigint;  v_whole_total  bigint;
  v_wall_fail   bigint;  v_wall_total   bigint;
BEGIN
  BEGIN

    INSERT INTO guardops.account (name) VALUES ('0123_proof') RETURNING id INTO v_acct;
    INSERT INTO guardops.customer (account_id, external_id)
      VALUES (v_acct, '0123_proof') RETURNING id INTO v_cust;
    INSERT INTO guardops.connected_account
      (account_id, customer_id, token_secret_name, status)
      VALUES (v_acct, v_cust, '0123_proof_tok', 'ACTIVE');
    PERFORM guardops.act_as_house(v_cust);

    v_db   := guardops.watched_database_add('0123_proof_db');
    v_link := guardops.repo_link_add('0123-proof/repo', 'main');

    -- ----------------------------------------------------------------
    -- Job A: table created after job_start (not in before picture).
    --        Proof 1: line 6 shows "Before: did not exist" / "After:" / columns.
    --        Proof 1: line 4 has col block appended after obj_lines.
    -- ----------------------------------------------------------------
    v_job_a   := guardops.job_start(v_db, v_link, '0123 proof job A', 'guardops');
    v_plans_a := guardops.plan_given_add(v_job_a, ARRAY['add items table A']);

    SELECT pl.pull_id INTO v_pull_id FROM guardops.pull_begin(v_link) AS pl;
    v_cs := guardops.commit_record(
      '0123-proof/repo', 'main',
      '0123a00000000000000000000000000000000000',
      'tester', now(),
      'GO-' || v_job_a::text || '-1 fixture',
      jsonb_build_object(
        'migrations/0123_proof_a.sql',
        '+CREATE TABLE guardops.tbl_0123_proof_a (item_id bigint, item_label text)'
      ),
      v_pull_id
    );
    PERFORM guardops.plan_commit_link(v_job_a);

    EXECUTE 'CREATE TABLE guardops.tbl_0123_proof_a (item_id bigint, item_label text)';

    PERFORM guardops.job_finish(
      v_job_a,
      v_plans_a,
      ARRAY['guardops.tbl_0123_proof_a'],
      ARRAY[]::text[]
    );

    SELECT proof INTO v_proof_6a
      FROM guardops.page_lines(v_cust, v_job_a) WHERE line_no = 6;
    RAISE NOTICE 'proof_a1 line_6 proof="%"', v_proof_6a;
    IF v_proof_6a NOT LIKE '%Before: did not exist%' THEN
      RAISE EXCEPTION '0123 proof_a1: line 6 must have "Before: did not exist", got [%]', v_proof_6a;
    END IF;
    IF v_proof_6a NOT LIKE '%After:%' THEN
      RAISE EXCEPTION '0123 proof_a1: line 6 must have "After:", got [%]', v_proof_6a;
    END IF;
    IF v_proof_6a NOT LIKE '%item_id%' THEN
      RAISE EXCEPTION '0123 proof_a1: line 6 after half must list columns, got [%]', v_proof_6a;
    END IF;
    RAISE NOTICE 'proof_a1 pass=true';

    SELECT proof INTO v_proof_4a
      FROM guardops.page_lines(v_cust, v_job_a) WHERE line_no = 4;
    RAISE NOTICE 'proof_a2 line_4 proof="%"', v_proof_4a;
    IF v_proof_4a NOT LIKE '%+CREATE%' THEN
      RAISE EXCEPTION '0123 proof_a2: line 4 must have obj_lines, got [%]', v_proof_4a;
    END IF;
    IF v_proof_4a NOT LIKE '%Before: did not exist%' THEN
      RAISE EXCEPTION '0123 proof_a2: line 4 must have col block appended, got [%]', v_proof_4a;
    END IF;
    RAISE NOTICE 'proof_a2 pass=true';

    -- ----------------------------------------------------------------
    -- Job B: table created before job_start (exists in both pictures).
    --        Proof 3: line 6 shows before columns, not "did not exist".
    -- ----------------------------------------------------------------
    EXECUTE 'CREATE TABLE guardops.tbl_0123_proof_b (col_x bigint, col_y text)';

    v_job_b   := guardops.job_start(v_db, v_link, '0123 proof job B', 'guardops');
    v_plans_b := guardops.plan_given_add(v_job_b, ARRAY['test object in both pictures']);

    PERFORM guardops.job_finish(
      v_job_b,
      v_plans_b,
      ARRAY['guardops.tbl_0123_proof_b'],
      ARRAY[]::text[]
    );

    SELECT proof INTO v_proof_6b
      FROM guardops.page_lines(v_cust, v_job_b) WHERE line_no = 6;
    RAISE NOTICE 'proof_b line_6 proof="%"', v_proof_6b;
    IF v_proof_6b LIKE '%Before: did not exist%' THEN
      RAISE EXCEPTION '0123 proof_b: object in both pictures must not say "did not exist", got [%]', v_proof_6b;
    END IF;
    IF v_proof_6b NOT LIKE '%Before:%' THEN
      RAISE EXCEPTION '0123 proof_b: line 6 must have "Before:", got [%]', v_proof_6b;
    END IF;
    IF v_proof_6b NOT LIKE '%col_x%' THEN
      RAISE EXCEPTION '0123 proof_b: before half must show before columns, got [%]', v_proof_6b;
    END IF;
    RAISE NOTICE 'proof_b pass=true';

    -- ----------------------------------------------------------------
    -- Job C: table created before job_start then dropped.
    --        Proof 2 (line 7): before columns / "After: gone".
    -- ----------------------------------------------------------------
    EXECUTE 'CREATE TABLE guardops.tbl_0123_proof_c (col_p bigint, col_q text)';

    v_job_c   := guardops.job_start(v_db, v_link, '0123 proof job C', 'guardops');
    v_plans_c := guardops.plan_given_add(v_job_c, ARRAY['remove proof table C']);

    EXECUTE 'DROP TABLE guardops.tbl_0123_proof_c';

    PERFORM guardops.job_finish(
      v_job_c,
      v_plans_c,
      ARRAY[]::text[],
      ARRAY['guardops.tbl_0123_proof_c']
    );

    SELECT proof INTO v_proof_7c
      FROM guardops.page_lines(v_cust, v_job_c) WHERE line_no = 7;
    RAISE NOTICE 'proof_c line_7 proof="%"', v_proof_7c;
    IF v_proof_7c NOT LIKE '%Before:%' THEN
      RAISE EXCEPTION '0123 proof_c: line 7 must have "Before:", got [%]', v_proof_7c;
    END IF;
    IF v_proof_7c NOT LIKE '%col_p%' THEN
      RAISE EXCEPTION '0123 proof_c: before half must list before columns, got [%]', v_proof_7c;
    END IF;
    IF v_proof_7c NOT LIKE '%After: gone%' THEN
      RAISE EXCEPTION '0123 proof_c: line 7 must have "After: gone", got [%]', v_proof_7c;
    END IF;
    RAISE NOTICE 'proof_c pass=true';

    -- ----------------------------------------------------------------
    -- Grant check: anon and authenticated must NOT have EXECUTE;
    --              service_role must have EXECUTE on both overloads.
    -- ----------------------------------------------------------------
    IF has_function_privilege('anon', 'guardops.page_lines(bigint, bigint)', 'EXECUTE') THEN
      RAISE EXCEPTION '0123 grant: anon must not have EXECUTE on page_lines(bigint,bigint)';
    END IF;
    IF has_function_privilege('authenticated', 'guardops.page_lines(bigint, bigint)', 'EXECUTE') THEN
      RAISE EXCEPTION '0123 grant: authenticated must not have EXECUTE on page_lines(bigint,bigint)';
    END IF;
    IF NOT has_function_privilege('service_role', 'guardops.page_lines(bigint, bigint)', 'EXECUTE') THEN
      RAISE EXCEPTION '0123 grant: service_role must have EXECUTE on page_lines(bigint,bigint)';
    END IF;
    IF has_function_privilege('anon', 'guardops.page_lines(bigint)', 'EXECUTE') THEN
      RAISE EXCEPTION '0123 grant: anon must not have EXECUTE on page_lines(bigint)';
    END IF;
    IF has_function_privilege('authenticated', 'guardops.page_lines(bigint)', 'EXECUTE') THEN
      RAISE EXCEPTION '0123 grant: authenticated must not have EXECUTE on page_lines(bigint)';
    END IF;
    IF NOT has_function_privilege('service_role', 'guardops.page_lines(bigint)', 'EXECUTE') THEN
      RAISE EXCEPTION '0123 grant: service_role must have EXECUTE on page_lines(bigint)';
    END IF;
    RAISE NOTICE 'grant_check pass=true';

    -- ----------------------------------------------------------------
    -- Test suites must not regress.
    -- ----------------------------------------------------------------
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
      RAISE EXCEPTION '0123 regression: one=%/% whole=%/% wall=%/%',
        v_one_total, v_one_fail, v_whole_total, v_whole_fail,
        v_wall_total, v_wall_fail;
    END IF;

    RAISE NOTICE '0123 all proofs passed — fixture rolled back, function replacements stand';
    RAISE EXCEPTION '0123_proof_rollback';

  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> '0123_proof_rollback' THEN RAISE; END IF;
  END;
END;
$$;
