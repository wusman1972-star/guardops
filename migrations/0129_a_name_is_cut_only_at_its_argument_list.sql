-- hole 886: object names were cut at the first '(' regardless of context.
-- One shared function does the cutting; both page_lines and job_verdict call it.

CREATE OR REPLACE FUNCTION guardops.name_without_arguments(p_name text)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path TO ''
AS $$
  SELECT
    CASE
      WHEN p_name IS NULL THEN NULL
      WHEN right(btrim(p_name), 1) = ')'
           AND strpos(btrim(p_name), '(') > 0
      THEN btrim(
             left(
               btrim(p_name),
               length(btrim(p_name)) - strpos(reverse(btrim(p_name)), '(')
             )
           )
      ELSE btrim(p_name)
    END
$$;

CREATE OR REPLACE FUNCTION guardops.schema_and_object_name(p_qualified_name text)
RETURNS TABLE(schema_name text, object_name text)
LANGUAGE sql
IMMUTABLE
SET search_path TO ''
AS $fn$
  WITH parts AS (
    SELECT regexp_match(
             btrim(p_qualified_name),
             $rx$^("(?:[^"]|"")*"|[^.]+)\.("(?:[^"]|"")*"|.+)$$rx$
           ) AS m
  )
  SELECT
    CASE
      WHEN p_qualified_name IS NULL THEN NULL
      WHEN m IS NULL THEN ''
      WHEN left(m[1], 1) = '"'
        THEN replace(substr(m[1], 2, length(m[1]) - 2), '""', '"')
      ELSE lower(m[1])
    END,
    CASE
      WHEN p_qualified_name IS NULL THEN NULL
      WHEN m IS NULL THEN
        CASE
          WHEN left(btrim(p_qualified_name), 1) = '"'
          THEN replace(substr(btrim(p_qualified_name), 2, length(btrim(p_qualified_name)) - 2), '""', '"')
          ELSE lower(btrim(p_qualified_name))
        END
      WHEN left(m[2], 1) = '"'
        THEN replace(substr(m[2], 2, length(m[2]) - 2), '""', '"')
      ELSE lower(m[2])
    END
  FROM parts
$fn$;

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

  SELECT string_agg(pg.item_text, E'\\n' ORDER BY pg.position, pg.id)
    INTO v_plan_body
    FROM guardops.plan_given pg
   WHERE pg.job_id     = p_job_id
     AND pg.account_id = guardops.current_account();

  SELECT
    string_agg(jv.what,  E'\\n' ORDER BY jv.what) FILTER (WHERE jv.kind = 'DELIVERED'),
    string_agg(jv.proof, E'\\n' ORDER BY jv.what) FILTER (WHERE jv.kind = 'DELIVERED'),
    string_agg(jv.what,  E'\\n' ORDER BY jv.what) FILTER (WHERE jv.kind = 'MISSING'),
    string_agg(jv.proof, E'\\n' ORDER BY jv.what) FILTER (WHERE jv.kind = 'MISSING'),
    string_agg(jv.what,  E'\\n' ORDER BY jv.what) FILTER (WHERE jv.kind = 'ADDED'),
    string_agg(jv.proof, E'\\n' ORDER BY jv.what) FILTER (WHERE jv.kind = 'ADDED')
  INTO
    v_built_body,   v_built_detail,
    v_unbuilt_body, v_unbuilt_proof,
    v_added_body,   v_added_detail
  FROM guardops.job_verdict(p_job_id) AS jv;

  SELECT array_agg(DISTINCT so.schema_name || '.' || guardops.name_without_arguments(so.object_name))
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
     AND so.schema_name || '.' || guardops.name_without_arguments(so.object_name) NOT IN (
       SELECT a
         FROM guardops.claim c
        CROSS JOIN LATERAL unnest(COALESCE(c.added, ARRAY[]::text[])) AS a
        WHERE c.job_id     = p_job_id
          AND c.account_id = v_account
     );

  SELECT string_agg(
    coalesce(
      (SELECT string_agg(per_file.kept_lines, E'\\n'
                ORDER BY per_file.committed_at, per_file.file_key)
         FROM (
           SELECT cs.committed_at,
                  co.file_key,
                  string_agg(ln.line, E'\\n' ORDER BY ln.ord) AS kept_lines
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
             CROSS JOIN LATERAL regexp_split_to_table(co.obj_lines, E'\\n')
                  WITH ORDINALITY AS ln(line, ord)
            WHERE pc.plan_given_id = pg.id
              AND pc.account_id    = v_account
              AND lower(replace(
                    COALESCE(
                      (regexp_match(
                        ln.line,
                        $$(?i)^[+ -]*(?:create(?:\s+or\s+replace)?(?:\s+(?:temp(?:orary)?))?(?:\s+unlogged)?\s+(?:(?:materialized\s+)?view|table|function|type|sequence|trigger)|alter\s+(?:table|view|type))\s+(?:if\s+not\s+exists\s+)?((?:"[^"]*"|[A-Za-z_]\w*)\.(?:"[^"]*"|[A-Za-z_]\w*))$$
                      ))[1],
                      ''
                    ),
                    '"', ''
                  )) = ANY(
                    SELECT lower(dn.name)
                      FROM unnest(COALESCE(v_delivered_names, ARRAY[]::text[])) AS dn(name)
                  )
            GROUP BY cs.committed_at, co.file_key
         ) per_file
      ),
      'nothing to prove'
    ),
    E'\\n' ORDER BY pg.item_text
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

  SELECT string_agg(
    combined.proof_text,
    E'\\n' ORDER BY obj.name
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
          THEN 'Before:' || E'\\n' || b_cols.cols
        ELSE 'Before: did not exist'
      END || E'\\n' || 'After:' || E'\\n' || coalesce(a_cols.cols, 'no column record')
    AS proof_text
    FROM
      (SELECT string_agg(e.name || ' ' || e.type, E'\\n') AS cols
         FROM (SELECT so.column_shape
                 FROM guardops.shape_object so
                WHERE so.picture_id  = v_before_pic
                  AND so.account_id  = v_account
                  AND so.schema_name || '.' || guardops.name_without_arguments(so.object_name) = obj.name
                LIMIT 1) one_row,
              LATERAL jsonb_to_recordset(one_row.column_shape) AS e(name text, type text)
      ) b_cols,
      (SELECT string_agg(e.name || ' ' || e.type, E'\\n') AS cols
         FROM (SELECT so.column_shape
                 FROM guardops.shape_object so
                WHERE so.picture_id  = v_after_pic
                  AND so.account_id  = v_account
                  AND so.schema_name || '.' || guardops.name_without_arguments(so.object_name) = obj.name
                LIMIT 1) one_row,
              LATERAL jsonb_to_recordset(one_row.column_shape) AS e(name text, type text)
      ) a_cols
  ) combined;

  SELECT
    string_agg(obj.name, E'\\n' ORDER BY obj.name)
      FILTER (WHERE combined.proof_text IS NOT NULL),
    string_agg(combined.proof_text, E'\\n' ORDER BY obj.name)
      FILTER (WHERE combined.proof_text IS NOT NULL)
  INTO v_deleted_body, v_deleted_proof
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
    SELECT guardops.name_without_arguments(obj.name) AS stripped
  ) AS s
  CROSS JOIN LATERAL guardops.schema_and_object_name(s.stripped) AS p
  CROSS JOIN LATERAL (
    SELECT
      CASE
        WHEN v_after_pic IS NULL THEN
          obj.name || ': no after picture taken for this job'
        WHEN EXISTS (
          SELECT 1 FROM guardops.shape_object sa
           WHERE sa.picture_id = v_after_pic
             AND sa.account_id = v_account
             AND guardops.name_without_arguments(sa.object_name) = p.object_name
             AND (p.schema_name = '' OR sa.schema_name = p.schema_name)
        ) THEN NULL
        ELSE
          obj.name || E'\\n' ||
          'Before (picture ' || v_before_pic || '):' || E'\\n' ||
          coalesce(b_cols.cols, 'no column record') || E'\\n' ||
          'After (picture ' || v_after_pic || '): gone'
      END AS proof_text
    FROM
      (SELECT string_agg(e.name || ' ' || e.type, E'\\n') AS cols
         FROM (SELECT so.column_shape
                 FROM guardops.shape_object so
                WHERE so.picture_id  = v_before_pic
                  AND so.account_id  = v_account
                  AND guardops.name_without_arguments(so.object_name) = p.object_name
                  AND (p.schema_name = '' OR so.schema_name = p.schema_name)
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
  v_before_pic    bigint;
  v_after_pic     bigint;
  v_delivered_ids bigint[];
  v_added_objs    text[];
  v_deleted_objs  text[];
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
    COALESCE(
      (SELECT string_agg(cs.sha || ' -> ' || co.file_key, '; '
                         ORDER BY cs.committed_at, co.file_key)
         FROM guardops.commit_seen cs
         JOIN guardops.commit_object co
              ON  co.commit_seen_id = cs.id
              AND co.account_id     = v_account_id
        WHERE cs.repo_link_id  = v_repo_link_id
          AND cs.account_id    = v_account_id
          AND v_repo_link_id  IS NOT NULL
          AND cs.committed_at >= v_opened_at
          AND cs.committed_at <= COALESCE(
                (SELECT MAX(c2.claimed_at)
                   FROM guardops.claim c2
                  WHERE c2.job_id     = p_job_id
                    AND c2.account_id = v_account_id),
                now()
              )),
      'no commit record'
    )
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
        WHERE sc.prev_picture_id = v_before_pic
          AND sc.picture_id      = v_after_pic
          AND sc.change_kind     = 'APPEARED'
          AND sc.schema_name || '.' ||
              CASE WHEN lower(sc.object_kind) = 'function'
                   THEN guardops.name_without_arguments(sc.object_name)
                   ELSE sc.object_name END = obj.name
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
        WHERE sc.prev_picture_id = v_before_pic
          AND sc.picture_id      = v_after_pic
          AND sc.change_kind     = 'GONE'
          AND sc.schema_name || '.' ||
              CASE WHEN lower(sc.object_kind) = 'function'
                   THEN guardops.name_without_arguments(sc.object_name)
                   ELSE sc.object_name END = obj.name
        LIMIT 1),
      'no shape record'
    )
  FROM unnest(COALESCE(v_deleted_objs, ARRAY[]::text[])) AS obj(name);

END;
$function$;

-- job_finish: wire after_picture_id onto the job after shape_judge so that
-- job_verdict's picture-based proof lookup finds the right shape_change rows.
CREATE OR REPLACE FUNCTION guardops.job_finish(p_job_id bigint, p_delivered_item_ids bigint[], p_added text[], p_deleted text[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_db_id          bigint;
  v_schema         text;
  v_before_pic     bigint;
  v_after_existing bigint;
  v_after          bigint;
  v_count          bigint;
  v_jlabel         text;
  v_jcust_id       bigint;
  v_jfacts         jsonb;
  v_jwords         jsonb;
BEGIN
  SELECT j.watched_database_id, j.watched_schema, j.before_picture_id, j.after_picture_id
    INTO v_db_id, v_schema, v_before_pic, v_after_existing
    FROM guardops.job j
   WHERE j.id = p_job_id
     AND j.account_id = guardops.current_account()
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'job % not found or does not belong to this account', p_job_id;
  END IF;

  IF v_before_pic IS NULL THEN
    RAISE EXCEPTION 'job % has no before picture — was not opened with job_start', p_job_id;
  END IF;

  IF v_after_existing IS NOT NULL THEN
    RAISE EXCEPTION 'job % already finished with after picture % - job_finish may not be called twice', p_job_id, v_after_existing;
  END IF;

  v_after := guardops.take_shape(v_db_id, v_schema);

  SELECT object_count INTO v_count FROM guardops.shape_picture WHERE id = v_after;
  IF COALESCE(v_count, 0) = 0 THEN
    RAISE EXCEPTION 'job_finish: after picture for schema % returned no objects', v_schema;
  END IF;

  PERFORM guardops.shape_judge(v_after, v_before_pic);
  UPDATE guardops.job SET after_picture_id = v_after WHERE id = p_job_id;
  PERFORM guardops.claim_add(p_job_id, p_delivered_item_ids, p_added, p_deleted);

  BEGIN
    SELECT
      jsonb_build_object(
        'delivered', to_jsonb(coalesce(array_agg(what ORDER BY what) FILTER (WHERE kind = 'DELIVERED'), '{}'::text[])),
        'missing',   to_jsonb(coalesce(array_agg(what ORDER BY what) FILTER (WHERE kind = 'MISSING'),   '{}'::text[])),
        'added',     to_jsonb(coalesce(array_agg(what ORDER BY what) FILTER (WHERE kind = 'ADDED'),     '{}'::text[])),
        'deleted',   to_jsonb(coalesce(array_agg(what ORDER BY what) FILTER (WHERE kind = 'DELETED'),   '{}'::text[]))
      )
    INTO v_jfacts
    FROM guardops.job_verdict(p_job_id)
    WHERE kind IN ('DELIVERED', 'MISSING', 'ADDED', 'DELETED');

    SELECT coalesce(nullif(btrim(d.label), ''), 'your database'), c.id
      INTO v_jlabel, v_jcust_id
      FROM guardops.watched_database d
      JOIN guardops.connected_account a ON a.id = d.connected_account_id
      JOIN guardops.customer c ON c.id = a.customer_id
     WHERE d.id = v_db_id;

    v_jwords := guardops.notice_words('JOB', v_jlabel, v_jfacts);

    INSERT INTO guardops.customer_notice (customer_id, database_id, kind, about, headline, body, state)
    VALUES (v_jcust_id, v_db_id, 'JOB', p_job_id, v_jwords->>'headline', v_jwords->>'body',
            CASE
              WHEN jsonb_array_length(v_jfacts->'missing')  > 0
                OR jsonb_array_length(v_jfacts->'added')    > 0
                OR jsonb_array_length(v_jfacts->'deleted')  > 0
              THEN 'NEW'
              ELSE 'ON_RECORD'
            END);
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING '[JOB FINISH] building/storing notice failed for job %: %', p_job_id, left(sqlerrm, 300);
  END;

  BEGIN
    PERFORM guardops.tell_send();
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING '[JOB FINISH] tell_send failed for job %: %', p_job_id, left(sqlerrm, 300);
  END;
END;
$job_finish$;

-- whole_run_test: steps 6 and 8 wire before/after picture IDs onto the job
-- so job_verdict's picture-pair filter finds the right shape_change rows.
-- Step 13 verifies page_lines returns 7 lines.
CREATE OR REPLACE FUNCTION guardops.whole_run_test()
 RETURNS TABLE(step integer, what text, got text, want text, pass boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'guardops', 'pg_catalog', 'pg_temp'
AS $whole_run$
DECLARE
  v_acct_id     bigint;
  v_cust_id     bigint;
  v_db_id       bigint;
  v_link_id     bigint;
  v_job_id      bigint;
  v_link_on_job bigint;
  v_before_pic  bigint;
  v_after_pic   bigint;
  v_pull_id     bigint;
  v_commit_id   bigint;
  v_plan_items  bigint[];
  v_claim_id    bigint;
  v_sc_count    bigint;
  v_bad_proof   bigint;
  v_line_count  bigint;
  v_secrets     text[];
  v_payload     text;
  v_sig         text;
BEGIN
  BEGIN

    INSERT INTO guardops.account (name, repos_allowed)
      VALUES ('whole_run_test', 1) RETURNING id INTO v_acct_id;
    INSERT INTO guardops.customer (account_id, external_id)
      VALUES (v_acct_id, 'whole_run_test') RETURNING id INTO v_cust_id;
    INSERT INTO guardops.connected_account
      (account_id, customer_id, token_secret_name, status)
      VALUES (v_acct_id, v_cust_id, 'whole_run_test-tok', 'ACTIVE');
    v_secrets := guardops.txn_hmac_secrets();
    v_payload := v_acct_id::text || ':' || session_user || ':' || pg_catalog.pg_current_xact_id()::text;
    v_sig     := pg_catalog.encode(extensions.hmac(v_payload::bytea, v_secrets[1]::bytea, 'sha256'), 'hex');
    PERFORM pg_catalog.set_config('guardops.txn_account', v_acct_id::text || '.' || v_sig, true);
    step := 1; what := 'sign in';
    got  := 'signed in as account ' || v_acct_id::text;
    want := 'signed in as an account';
    pass := (v_acct_id IS NOT NULL AND guardops.current_account() = v_acct_id);
    RETURN NEXT;

    v_db_id := guardops.watched_database_add('whole_run_test');
    step := 2; what := 'register watched database';
    got  := 'database id ' || v_db_id::text;
    want := 'a watched database id';
    pass := (v_db_id IS NOT NULL);
    RETURN NEXT;

    v_link_id := guardops.repo_link_add('whole-run-test/repo', 'main');
    step := 3; what := 'repo_link_add';
    got  := 'repo link id ' || v_link_id::text;
    want := 'a repo link id';
    pass := (v_link_id IS NOT NULL);
    RETURN NEXT;

    v_job_id := guardops.job_add(v_link_id, 'whole_run_test');
    UPDATE guardops.job SET watched_database_id = v_db_id WHERE id = v_job_id;
    step := 4; what := 'open a job';
    got  := 'job id ' || v_job_id::text;
    want := 'a job id';
    pass := (v_job_id IS NOT NULL);
    RETURN NEXT;

    SELECT j.repo_link_id INTO v_link_on_job
      FROM guardops.job j WHERE j.id = v_job_id;
    step := 5; what := 'job carries a code link';
    got  := CASE WHEN v_link_on_job IS NULL
                 THEN 'job.repo_link_id is null'
                 ELSE 'job.repo_link_id is ' || v_link_on_job::text END;
    want := 'a code link on the job';
    pass := (v_link_on_job IS NOT NULL);
    RETURN NEXT;

    EXECUTE 'CREATE SCHEMA whole_run_test_work';

    v_before_pic := guardops.take_shape(v_db_id, 'whole_run_test_work');
    UPDATE guardops.job SET before_picture_id = v_before_pic WHERE id = v_job_id;
    step := 6; what := 'take before picture';
    got  := 'picture id ' || v_before_pic::text;
    want := 'a before picture id';
    pass := (v_before_pic IS NOT NULL);
    RETURN NEXT;

    EXECUTE 'CREATE TABLE whole_run_test_work.new_table (id bigint)';
    step := 7; what := 'build new object in watched schema';
    got  := 'created whole_run_test_work.new_table';
    want := 'a new object in the watched schema';
    pass := true;
    RETURN NEXT;

    v_after_pic := guardops.take_shape(v_db_id, 'whole_run_test_work');
    UPDATE guardops.job SET after_picture_id = v_after_pic WHERE id = v_job_id;
    step := 8; what := 'take after picture';
    got  := 'picture id ' || v_after_pic::text;
    want := 'an after picture id';
    pass := (v_after_pic IS NOT NULL);
    RETURN NEXT;

    SELECT count(*) INTO v_sc_count
      FROM guardops.shape_change WHERE database_id = v_db_id;
    step := 9; what := 'shape change detected';
    got  := v_sc_count::text || ' changes detected';
    want := 'at least 1 change detected';
    pass := (v_sc_count >= 1);
    RETURN NEXT;

    SELECT pull_id INTO v_pull_id FROM guardops.pull_begin(v_link_id);
    v_commit_id := guardops.commit_record(
      'whole-run-test/repo', 'main',
      'aaabbbccc111222333444555666777888999000a',
      'whole-run-tester', now(),
      'whole_run_test: build new_table',
      '{"new_table.sql": "-- new table"}'::jsonb,
      v_pull_id
    );
    step := 10; what := 'record commit';
    got  := 'commit id ' || v_commit_id::text;
    want := 'a commit id';
    pass := (v_commit_id IS NOT NULL AND v_commit_id > 0);
    RETURN NEXT;

    v_plan_items := guardops.plan_given_add(
      v_job_id,
      ARRAY['build whole_run_test_work.new_table']
    );
    v_claim_id := guardops.claim_add(
      v_job_id,
      v_plan_items,
      ARRAY['whole_run_test_work.new_table'],
      ARRAY[]::text[]
    );
    step := 11; what := 'file plan and claim';
    got  := 'claim id ' || v_claim_id::text;
    want := 'a claim id';
    pass := (v_claim_id IS NOT NULL);
    RETURN NEXT;

    SELECT count(*) INTO v_bad_proof
      FROM guardops.job_verdict(v_job_id)
     WHERE proof IN ('no commit record', 'no shape record');
    step := 12; what := 'four lines carry real proof';
    got  := v_bad_proof::text || ' lines missing proof';
    want := '0 lines missing proof';
    pass := (v_bad_proof = 0);
    RETURN NEXT;

    SELECT count(*) INTO v_line_count
      FROM guardops.page_lines(v_cust_id, v_job_id);
    step := 13; what := 'page_lines returns 7 lines';
    got  := v_line_count::text || ' lines';
    want := '7 lines';
    pass := (v_line_count = 7);
    RETURN NEXT;

    RAISE EXCEPTION 'whole_run_rollback';

  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'whole_run_rollback' THEN
      RAISE;
    END IF;
  END;
END;
$whole_run$;
