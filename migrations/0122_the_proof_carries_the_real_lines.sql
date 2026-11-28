-- migrations/0122_the_proof_carries_the_real_lines.sql
-- Board 12236. page_lines gains a fifth column: detail.
-- proof: human-readable content (obj_lines / column names).
-- detail: machine-shaped references (sha, file path, picture ids).

-- ========================================================================
-- DROP BOTH OVERLOADS FIRST (return type changes; OR REPLACE is refused).
-- ========================================================================
DROP FUNCTION IF EXISTS guardops.page_lines(bigint, bigint);
DROP FUNCTION IF EXISTS guardops.page_lines(bigint);

-- ========================================================================
-- TWO-ARGUMENT OVERLOAD
-- ========================================================================
CREATE OR REPLACE FUNCTION guardops.page_lines(p_customer bigint, p_job_id bigint)
 RETURNS TABLE(line_no integer, heading text, body text, proof text, detail text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_account        bigint;
  v_job_wfor       text;
  v_opened_str     text;
  v_db_label       text;
  v_plan_body      text;
  v_opened_at      timestamptz;
  v_before_pic     bigint;
  v_after_pic      bigint;
  v_built_body     text;
  v_built_proof    text;
  v_built_detail   text;
  v_unbuilt_body   text;
  v_unbuilt_proof  text;
  v_added_body     text;
  v_added_proof    text;
  v_added_detail   text;
  v_deleted_body   text;
  v_deleted_proof  text;
  v_deleted_detail text;
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

  -- New proof for DELIVERED: actual changed lines from commit_object.
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

  -- New proof for ADDED: column names and types from shape_object (after picture).
  SELECT string_agg(
    coalesce(
      (SELECT string_agg(e.name || ' ' || e.type, E'\n')
         FROM (SELECT so.column_shape
                 FROM guardops.shape_object so
                WHERE so.picture_id  = v_after_pic
                  AND so.account_id  = v_account
                  AND so.schema_name || '.' || split_part(so.object_name, '(', 1) = obj.name
                LIMIT 1) one_row,
              LATERAL jsonb_to_recordset(one_row.column_shape) AS e(name text, type text)),
      'no column record'
    ),
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
  ) AS obj(name);

  -- New proof for DELETED: column names and types from shape_object (before picture).
  SELECT string_agg(
    coalesce(
      (SELECT string_agg(e.name || ' ' || e.type, E'\n')
         FROM (SELECT so.column_shape
                 FROM guardops.shape_object so
                WHERE so.picture_id  = v_before_pic
                  AND so.account_id  = v_account
                  AND so.schema_name || '.' || split_part(so.object_name, '(', 1) = obj.name
                LIMIT 1) one_row,
              LATERAL jsonb_to_recordset(one_row.column_shape) AS e(name text, type text)),
      'no column record'
    ),
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
  ) AS obj(name);

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
  body    := coalesce(nullif(v_built_body,   ''), 'Nothing was built.');
  proof   := coalesce(nullif(v_built_proof,  ''), 'nothing to prove');
  detail  := coalesce(v_built_detail, '');
  RETURN NEXT;

  line_no := 5; heading := 'You asked for it - it is not there';
  body    := coalesce(nullif(v_unbuilt_body,  ''), 'Nothing was left unbuilt.');
  proof   := coalesce(nullif(v_unbuilt_proof, ''), 'nothing to prove');
  detail  := '';
  RETURN NEXT;

  line_no := 6; heading := 'It is there - you never asked for it';
  body    := coalesce(nullif(v_added_body,   ''), 'Nothing was added.');
  proof   := coalesce(nullif(v_added_proof,  ''), 'nothing to prove');
  detail  := coalesce(v_added_detail, '');
  RETURN NEXT;

  line_no := 7; heading := 'It was there - now it is gone';
  body    := coalesce(nullif(v_deleted_body,   ''), 'Nothing was deleted.');
  proof   := coalesce(nullif(v_deleted_proof,  ''), 'nothing to prove');
  detail  := coalesce(v_deleted_detail, '');
  RETURN NEXT;
END;
$function$;

-- ========================================================================
-- ONE-ARGUMENT WRAPPER — passes new column through unchanged.
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

REVOKE EXECUTE ON FUNCTION guardops.page_lines(bigint, bigint) FROM public, anon, authenticated;
GRANT  EXECUTE ON FUNCTION guardops.page_lines(bigint, bigint) TO service_role;
REVOKE EXECUTE ON FUNCTION guardops.page_lines(bigint) FROM public, anon, authenticated;
GRANT  EXECUTE ON FUNCTION guardops.page_lines(bigint) TO service_role;

-- ========================================================================
-- PROOF — rolls back all fixture data; function replacements stand.
-- Five numbered checks as required by board 12236.
-- ========================================================================
DO $$
DECLARE
  v_acct        bigint;
  v_cust        bigint;
  v_db          bigint;
  v_link        bigint;
  v_job         bigint;
  v_plans       bigint[];
  v_pull_id     bigint;
  v_cs          bigint;
  v_proof       text;
  v_detail      text;
  r             record;
  v_one_fail    bigint;  v_one_total    bigint;
  v_whole_fail  bigint;  v_whole_total  bigint;
  v_wall_fail   bigint;  v_wall_total   bigint;
BEGIN
  BEGIN

    INSERT INTO guardops.account (name) VALUES ('0122_proof') RETURNING id INTO v_acct;
    INSERT INTO guardops.customer (account_id, external_id)
      VALUES (v_acct, '0122_proof') RETURNING id INTO v_cust;
    INSERT INTO guardops.connected_account
      (account_id, customer_id, token_secret_name, status)
      VALUES (v_acct, v_cust, '0122_proof_tok', 'ACTIVE');
    PERFORM guardops.act_as_house(v_cust);

    v_db   := guardops.watched_database_add('0122_proof_db');
    v_link := guardops.repo_link_add('0122-proof/repo', 'main');

    -- Before-picture: tbl_0122_proof does not yet exist.
    v_job := guardops.job_start(v_db, v_link, '0122 proof job', 'guardops');

    v_plans := guardops.plan_given_add(
      v_job,
      ARRAY['add items table', 'add missing feature']
    );

    -- Open a pull so commit_record can record the commit.
    SELECT pl.pull_id INTO v_pull_id FROM guardops.pull_begin(v_link) AS pl;

    -- Record a commit referencing plan position 1 ('add items table').
    -- sha: 40 hex chars. files: one SQL migration with a +CREATE line.
    v_cs := guardops.commit_record(
      '0122-proof/repo',
      'main',
      '0122000000000000000000000000000000000000',
      'tester',
      now(),
      'GO-' || v_job::text || '-1 fixture',
      jsonb_build_object(
        'migrations/0122_proof.sql',
        '+CREATE TABLE guardops.tbl_0122_proof (item_id bigint, item_label text)'
      ),
      v_pull_id
    );

    -- Link plan_given position 1 to the commit via message reference.
    PERFORM guardops.plan_commit_link(v_job);

    -- Create the table AFTER job_start so it appears only in the after-picture.
    EXECUTE 'CREATE TABLE guardops.tbl_0122_proof (item_id bigint, item_label text)';

    -- Close the job: deliver plan[1], claim the new table as added.
    PERFORM guardops.job_finish(
      v_job,
      ARRAY[v_plans[1]],
      ARRAY['guardops.tbl_0122_proof'],
      ARRAY[]::text[]
    );

    -- ----------------------------------------------------------------
    -- Proof 1: built item with linked commit — proof has real changed
    --          lines and no sha.
    -- ----------------------------------------------------------------
    SELECT proof, detail
      INTO v_proof, v_detail
      FROM guardops.page_lines(v_cust, v_job)
     WHERE line_no = 4;

    RAISE NOTICE 'proof_1  line=4  proof="%"', v_proof;

    IF v_proof IS NULL OR v_proof NOT LIKE '%+CREATE%' THEN
      RAISE EXCEPTION
        '0122 proof 1: line 4 proof must contain obj_lines, got [%]', v_proof;
    END IF;
    IF v_proof ~ '[0-9a-f]{40}' THEN
      RAISE EXCEPTION
        '0122 proof 1: line 4 proof must not contain a sha, got [%]', v_proof;
    END IF;
    RAISE NOTICE 'proof_1  no_sha=%  pass=true', (v_proof !~ '[0-9a-f]{40}');

    -- ----------------------------------------------------------------
    -- Proof 2: added object — proof names columns and types.
    -- ----------------------------------------------------------------
    SELECT proof, detail
      INTO v_proof, v_detail
      FROM guardops.page_lines(v_cust, v_job)
     WHERE line_no = 6;

    RAISE NOTICE 'proof_2  line=6  proof="%"', v_proof;

    IF v_proof IS NULL
       OR v_proof NOT LIKE '%item_id%'
       OR v_proof NOT LIKE '%bigint%' THEN
      RAISE EXCEPTION
        '0122 proof 2: line 6 proof must name columns, got [%]', v_proof;
    END IF;
    RAISE NOTICE 'proof_2  has_columns=true  pass=true';

    -- ----------------------------------------------------------------
    -- Proof 3: detail carries sha (line 4) and picture ids (line 6).
    -- ----------------------------------------------------------------
    SELECT detail INTO v_detail
      FROM guardops.page_lines(v_cust, v_job)
     WHERE line_no = 4;
    RAISE NOTICE 'proof_3a  line=4  detail="%"', v_detail;
    IF v_detail !~ '[0-9a-f]{40}' THEN
      RAISE EXCEPTION
        '0122 proof 3a: line 4 detail must contain sha, got [%]', v_detail;
    END IF;
    RAISE NOTICE 'proof_3a  has_sha=true  pass=true';

    SELECT detail INTO v_detail
      FROM guardops.page_lines(v_cust, v_job)
     WHERE line_no = 6;
    RAISE NOTICE 'proof_3b  line=6  detail="%"', v_detail;
    IF v_detail NOT LIKE '%pic %' THEN
      RAISE EXCEPTION
        '0122 proof 3b: line 6 detail must contain pic ref, got [%]', v_detail;
    END IF;
    RAISE NOTICE 'proof_3b  has_pic=true  pass=true';

    -- ----------------------------------------------------------------
    -- Proof 4: proof column across all 7 lines — no 40-char sha,
    --          no "pic ", no bare row id.
    -- ----------------------------------------------------------------
    FOR r IN
      SELECT line_no, proof
        FROM guardops.page_lines(v_cust, v_job)
       ORDER BY line_no
    LOOP
      RAISE NOTICE
        'proof_4  line=%  no_sha=%  no_pic=%  no_bare_num=%',
        r.line_no,
        (r.proof !~ '[0-9a-f]{40}'),
        (r.proof NOT LIKE '%pic %'),
        (r.proof !~ '(^|[^0-9a-zA-Z_])[0-9]+([^0-9a-zA-Z_]|$)');

      IF r.proof ~ '[0-9a-f]{40}'
         OR r.proof LIKE '%pic %'
         OR r.proof ~ '(^|[^0-9a-zA-Z_])[0-9]+([^0-9a-zA-Z_]|$)' THEN
        RAISE EXCEPTION
          '0122 proof 4: line % proof contains forbidden content: [%]',
          r.line_no, r.proof;
      END IF;
    END LOOP;
    RAISE NOTICE 'proof_4  all 7 lines clean  pass=true';

    -- ----------------------------------------------------------------
    -- Proof 5: test suites do not regress.
    -- ----------------------------------------------------------------
    SELECT count(*) FILTER (WHERE pass IS NOT TRUE), count(*)
      INTO v_one_fail,   v_one_total   FROM guardops.one_run_test();
    SELECT count(*) FILTER (WHERE pass IS NOT TRUE), count(*)
      INTO v_whole_fail, v_whole_total FROM guardops.whole_run_test();
    SELECT count(*) FILTER (WHERE pass IS NOT TRUE), count(*)
      INTO v_wall_fail,  v_wall_total  FROM guardops.wall_test();

    RAISE NOTICE 'proof_5a one_run_test   total=%  fail=%  want=8/0   pass=%',
      v_one_total,   v_one_fail,   (v_one_total = 8   AND v_one_fail   = 0);
    RAISE NOTICE 'proof_5b whole_run_test total=%  fail=%  want=12/0  pass=%',
      v_whole_total, v_whole_fail, (v_whole_total = 12 AND v_whole_fail = 0);
    RAISE NOTICE 'proof_5c wall_test      total=%  fail=%  want=18/0  pass=%',
      v_wall_total,  v_wall_fail,  (v_wall_total = 18  AND v_wall_fail  = 0);

    IF v_one_total   <> 8  OR v_one_fail   <> 0
    OR v_whole_total <> 12 OR v_whole_fail <> 0
    OR v_wall_total  <> 18 OR v_wall_fail  <> 0 THEN
      RAISE EXCEPTION '0122 regression: one=%/% whole=%/% wall=%/%',
        v_one_total, v_one_fail, v_whole_total, v_whole_fail,
        v_wall_total, v_wall_fail;
    END IF;

    RAISE NOTICE '0122 all proofs passed — fixture rolled back, function replacements stand';
    RAISE EXCEPTION '0122_proof_rollback';

  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> '0122_proof_rollback' THEN RAISE; END IF;
  END;
END;
$$;
