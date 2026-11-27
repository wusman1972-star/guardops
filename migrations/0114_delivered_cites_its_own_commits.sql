-- hole 838: DELIVERED proof cites this item's commits, not the job-wide list.
-- Only the proof expression on the DELIVERED block changes. Everything else is identical.

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
    COALESCE(
      'this item''s commits: ' || (
        SELECT string_agg(cs2.sha || ' -> ' || co2.file_key, '; '
                          ORDER BY cs2.committed_at, co2.file_key)
          FROM guardops.plan_commit pc
          JOIN guardops.commit_seen cs2
               ON  cs2.id         = pc.commit_seen_id
               AND cs2.account_id = v_account_id
          JOIN guardops.commit_object co2
               ON  co2.commit_seen_id = cs2.id
               AND co2.account_id     = v_account_id
         WHERE pc.plan_given_id = pg.id
           AND pc.account_id    = v_account_id
      ),
      'job-window commits: ' || (SELECT string_agg(cs.sha || ' -> ' || co.file_key, '; '
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
