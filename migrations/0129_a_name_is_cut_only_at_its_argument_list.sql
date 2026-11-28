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
                        '(?i)^[+\\- ]*(?:create(?:\\s+or\\s+replace)?(?:\\s+(?:temp(?:orary)?))?(?:\\s+unlogged)?\\s+(?:(?:materialized\\s+)?view|table|function|type|sequence|trigger)|alter\\s+(?:table|view|type))\\s+(?:if\\s+not\\s+exists\\s+)?((?:\"[^\"]*\"|[A-Za-z_]\\w*)\\.(?:\"[^\"]*\"|[A-Za-z_]\\w*))'
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
  CROSS JOIN LATERAL (
    SELECT
      CASE
        WHEN strpos(s.stripped, '.') > 0
        THEN CASE
               WHEN trim(split_part(s.stripped, '.', 1)) ~ '^".*"$'
               THEN trim(both '"' from trim(split_part(s.stripped, '.', 1)))
               ELSE lower(trim(split_part(s.stripped, '.', 1)))
             END
        ELSE ''
      END AS schema_part,
      CASE
        WHEN trim(split_part(s.stripped, '.', -1)) ~ '^".*"$'
        THEN trim(both '"' from trim(split_part(s.stripped, '.', -1)))
        ELSE lower(trim(split_part(s.stripped, '.', -1)))
      END AS base_name
  ) AS p
  CROSS JOIN LATERAL (
    SELECT
      CASE
        WHEN v_after_pic IS NULL THEN
          obj.name || ': no after picture taken for this job'
        WHEN EXISTS (
          SELECT 1 FROM guardops.shape_object sa
           WHERE sa.picture_id = v_after_pic
             AND sa.account_id = v_account
             AND guardops.name_without_arguments(sa.object_name) = p.base_name
             AND (p.schema_part = '' OR sa.schema_name = p.schema_part)
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
                  AND guardops.name_without_arguments(so.object_name) = p.base_name
                  AND (p.schema_part = '' OR so.schema_name = p.schema_part)
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
  v_delivered_ids bigint[];
  v_added_objs    text[];
  v_deleted_objs  text[];
BEGIN
  SELECT j.account_id, j.watched_database_id, j.repo_link_id, j.opened_at
    INTO v_account_id, v_db_id, v_repo_link_id, v_opened_at
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
        WHERE sc.database_id  = v_db_id
          AND sc.change_kind  = 'APPEARED'
          AND sc.schema_name || '.' || sc.object_name = obj.name
        ORDER BY sc.noticed_at DESC
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
        WHERE sc.database_id  = v_db_id
          AND sc.change_kind  = 'GONE'
          AND sc.schema_name || '.' || sc.object_name = obj.name
        ORDER BY sc.noticed_at DESC
        LIMIT 1),
      'no shape record'
    )
  FROM unnest(COALESCE(v_deleted_objs, ARRAY[]::text[])) AS obj(name);

END;
$function$;
