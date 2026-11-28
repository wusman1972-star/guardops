-- Migration 0127: missing proof reads the after picture
-- Fixes guardops.job_verdict so MISSING rows prove absence from the after
-- picture, not from the absence of a worker claim.
-- CREATE OR REPLACE is safe to re-run on a database where this is already applied.

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

  -- MISSING: match by object identity, not raw item text.
  -- s: strip arg list (everything from first '(' onwards).
  -- p: split on '.' → schema_part (first segment, if dot present), base_name (last segment).
  --    base_name must look like a valid Postgres identifier (letters/digits/underscores/$);
  --    free-text items that contain spaces or other non-identifier characters return '' and
  --    are reported with an explains-so proof rather than a false absence claim.
  -- Postgres-style case: compare lowercased (unquoted names fold to lowercase).
  RETURN QUERY
  SELECT
    'MISSING'::text,
    pg.item_text,
    CASE
      WHEN p.base_name = '' THEN
        'plan item cannot be resolved to an object identity; absence cannot be proved'
      WHEN v_after_pic IS NULL THEN
        'no after picture taken for this job'
      ELSE
        'looked in after picture ' || v_after_pic::text
          || '; no object '
          || CASE WHEN p.schema_part <> '' THEN p.schema_part || '.' ELSE '' END
          || p.base_name
          || ' found'
    END
  FROM guardops.plan_given pg
  CROSS JOIN LATERAL (
    SELECT trim(
             CASE WHEN strpos(trim(pg.item_text), '(') > 0
                  THEN left(trim(pg.item_text), strpos(trim(pg.item_text), '(') - 1)
                  ELSE trim(pg.item_text)
             END
           ) AS stripped
  ) AS s
  CROSS JOIN LATERAL (
    SELECT
      CASE WHEN lower(trim(split_part(s.stripped, '.', -1))) ~ '^[a-z_][a-z0-9_$]*$'
           THEN lower(trim(split_part(s.stripped, '.', -1)))
           ELSE ''
      END AS base_name,
      CASE WHEN strpos(s.stripped, '.') > 0
           THEN lower(trim(split_part(s.stripped, '.', 1)))
           ELSE ''
      END AS schema_part
  ) AS p
  WHERE pg.job_id     = p_job_id
    AND pg.account_id = v_account_id
    AND NOT (pg.id = ANY(COALESCE(v_delivered_ids, ARRAY[]::bigint[])))
    AND (
      p.base_name = ''
      OR v_after_pic IS NULL
      OR NOT EXISTS (
        SELECT 1
          FROM guardops.shape_object so
         WHERE so.picture_id = v_after_pic
           AND so.account_id = v_account_id
           AND lower(split_part(so.object_name, '(', 1)) = p.base_name
           AND (p.schema_part = '' OR lower(so.schema_name) = p.schema_part)
      )
    );

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
