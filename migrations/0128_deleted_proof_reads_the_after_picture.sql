-- Migration 0128: deleted proof reads the after picture
-- Hole 887. Line 7 printed "After: gone" for every object in claim.deleted without
-- ever reading the after picture to check.  An object still present in the after
-- picture could be reported gone to the customer, which is false.
--
-- Fix: replace the v_deleted_proof block in page_lines(bigint,bigint) with a
-- version that checks the after picture for each claimed-deleted object before
-- saying "gone".  Uses the same identity match as MISSING in job_verdict (0127):
-- lowercase, bracketed tail stripped, schema and base_name compared separately.
--
-- Behaviour after the fix:
--   - Object absent from after picture  → proof names the object and both pictures.
--   - Object still present in after picture → not reported gone (NULL, filtered out).
--   - No after picture → proof says so plainly for every entry.
--
-- CREATE OR REPLACE is safe to re-run; works on an empty database too.

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

  -- Proof for DELIVERED: per-statement filtered — split obj_lines line by line,
  -- keep only lines whose object identity exactly matches the delivered set,
  -- rejoin kept lines per file, aggregate across files.
  -- A line whose object cannot be parsed is dropped, never guessed.
  SELECT string_agg(
    coalesce(
      (SELECT string_agg(per_file.kept_lines, E'\n'
                ORDER BY per_file.committed_at, per_file.file_key)
         FROM (
           SELECT cs.committed_at,
                  co.file_key,
                  string_agg(ln.line, E'\n' ORDER BY ln.ord) AS kept_lines
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
             CROSS JOIN LATERAL regexp_split_to_table(co.obj_lines, E'\n')
                  WITH ORDINALITY AS ln(line, ord)
            WHERE pc.plan_given_id = pg.id
              AND pc.account_id    = v_account
              AND lower(replace(
                    COALESCE(
                      (regexp_match(
                        ln.line,
                        '(?i)^[+\- ]*(?:create(?:\s+or\s+replace)?(?:\s+(?:temp(?:orary)?))?(?:\s+unlogged)?\s+(?:(?:materialized\s+)?view|table|function|type|sequence|trigger)|alter\s+(?:table|view|type))\s+(?:if\s+not\s+exists\s+)?((?:"[^"]*"|[A-Za-z_]\w*)\.(?:"[^"]*"|[A-Za-z_]\w*))'
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

  -- Proof for DELETED: verify each claimed-deleted object is genuinely absent from
  -- the after picture before reporting it gone.  Same identity match as MISSING in
  -- job_verdict: lowercase, bracketed tail stripped, schema and base_name split
  -- separately (reuse, not rewrite).
  -- Objects still present in the after picture yield NULL and are excluded by the
  -- WHERE clause — they are not reported gone.
  -- When there is no after picture the proof says so plainly for every entry.
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
    SELECT trim(
             CASE WHEN strpos(trim(obj.name), '(') > 0
                  THEN left(trim(obj.name), strpos(trim(obj.name), '(') - 1)
                  ELSE trim(obj.name) END
           ) AS stripped
  ) AS s
  CROSS JOIN LATERAL (
    SELECT
      CASE WHEN strpos(s.stripped, '.') > 0
           THEN lower(trim(split_part(s.stripped, '.', 1)))
           ELSE '' END AS schema_part,
      lower(trim(split_part(s.stripped, '.', -1))) AS base_name
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
             AND lower(split_part(sa.object_name, '(', 1)) = p.base_name
             AND (p.schema_part = '' OR lower(sa.schema_name) = p.schema_part)
        ) THEN NULL
        ELSE
          obj.name || E'\n' ||
          'Before (picture ' || v_before_pic || '):' || E'\n' ||
          coalesce(b_cols.cols, 'no column record') || E'\n' ||
          'After (picture ' || v_after_pic || '): gone'
      END AS proof_text
    FROM
      (SELECT string_agg(e.name || ' ' || e.type, E'\n') AS cols
         FROM (SELECT so.column_shape
                 FROM guardops.shape_object so
                WHERE so.picture_id  = v_before_pic
                  AND so.account_id  = v_account
                  AND lower(split_part(so.object_name, '(', 1)) = p.base_name
                  AND (p.schema_part = '' OR lower(so.schema_name) = p.schema_part)
                LIMIT 1) one_row,
              LATERAL jsonb_to_recordset(one_row.column_shape) AS e(name text, type text)
      ) b_cols
  ) combined
  WHERE combined.proof_text IS NOT NULL;

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

REVOKE ALL ON FUNCTION guardops.page_lines(bigint, bigint) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION guardops.page_lines(bigint, bigint) TO postgres, service_role;
REVOKE ALL ON FUNCTION guardops.page_lines(bigint) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION guardops.page_lines(bigint) TO postgres, service_role;
