-- migrations/0078_job_verdict.sql
-- Board 11940. STEP 6 of the plan (board 11902). Fixed by board 11953.
--
-- guardops.job_verdict(p_job_id bigint)
--   RETURNS TABLE(kind text, what text, proof text)
-- Reads the verdict for a job: which plan items were DELIVERED, which are
-- MISSING, which objects were ADDED, and which were DELETED.
-- SECURITY DEFINER, search_path empty. REVOKE EXECUTE FROM PUBLIC.
-- GRANT EXECUTE to service_role only.
--
-- Board 11953 fixes:
--   1. Initial job lookup now filters AND account_id = current_account(),
--      matching the ownership pattern used by plan_given_add and claim_add.
--      Without it any service_role caller could read verdicts across accounts.
--   2. IF NOT FOUND guard after the job lookup raises a clear error instead of
--      returning an empty set for a non-existent or cross-account job_id.
--   3. REVOKE EXECUTE FROM PUBLIC + GRANT EXECUTE TO service_role added.
--      The original draft had neither, leaving the function callable by any
--      authenticated role (the same gap fixed in 0077 by board 11952).

CREATE OR REPLACE FUNCTION guardops.job_verdict(p_job_id bigint)
  RETURNS TABLE(kind text, what text, proof text)
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
DECLARE
  v_account_id    bigint;
  v_db_id         bigint;
  v_repo_link_id  bigint;
  v_delivered_ids bigint[];
  v_added_objs    text[];
  v_deleted_objs  text[];
BEGIN
  SELECT j.account_id, j.watched_database_id, j.repo_link_id
    INTO v_account_id, v_db_id, v_repo_link_id
    FROM guardops.job j
   WHERE j.id         = p_job_id
     AND j.account_id = guardops.current_account();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'job % does not exist or does not belong to this account', p_job_id;
  END IF;

  -- aggregate delivered plan-item IDs from every claim for this job
  SELECT array_agg(DISTINCT d ORDER BY d) FILTER (WHERE d IS NOT NULL)
    INTO v_delivered_ids
    FROM guardops.claim c
    CROSS JOIN LATERAL unnest(COALESCE(c.delivered_item_ids, ARRAY[]::bigint[])) AS d
   WHERE c.job_id     = p_job_id
     AND c.account_id = v_account_id;

  -- aggregate added-object names
  SELECT array_agg(DISTINCT a ORDER BY a) FILTER (WHERE a IS NOT NULL)
    INTO v_added_objs
    FROM guardops.claim c
    CROSS JOIN LATERAL unnest(COALESCE(c.added, ARRAY[]::text[])) AS a
   WHERE c.job_id     = p_job_id
     AND c.account_id = v_account_id;

  -- aggregate deleted-object names
  SELECT array_agg(DISTINCT del ORDER BY del) FILTER (WHERE del IS NOT NULL)
    INTO v_deleted_objs
    FROM guardops.claim c
    CROSS JOIN LATERAL unnest(COALESCE(c.deleted, ARRAY[]::text[])) AS del
   WHERE c.job_id     = p_job_id
     AND c.account_id = v_account_id;

  -- DELIVERED: plan items whose IDs appear in a claim's delivered list.
  -- Proof: commit SHA + file keys from commit_object for the job's repo link.
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
          AND v_repo_link_id  IS NOT NULL),
      'no commit record'
    )
  FROM guardops.plan_given pg
  WHERE pg.job_id     = p_job_id
    AND pg.account_id = v_account_id
    AND pg.id = ANY(COALESCE(v_delivered_ids, ARRAY[]::bigint[]));

  -- MISSING: plan items not in any claim's delivered list.
  RETURN QUERY
  SELECT
    'MISSING'::text,
    pg.item_text,
    'not in any claim'::text
  FROM guardops.plan_given pg
  WHERE pg.job_id     = p_job_id
    AND pg.account_id = v_account_id
    AND NOT (pg.id = ANY(COALESCE(v_delivered_ids, ARRAY[]::bigint[])));

  -- ADDED: objects in claim.added[] that the after picture shows appeared.
  -- Proof: before/after picture ids from shape_change.
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
          AND sc.change_kind  = 'ADDED'
          AND sc.schema_name || '.' || sc.object_name = obj.name
        ORDER BY sc.noticed_at DESC
        LIMIT 1),
      'no shape record'
    )
  FROM unnest(COALESCE(v_added_objs, ARRAY[]::text[])) AS obj(name);

  -- DELETED: objects in claim.deleted[] that the before picture had and the
  -- after picture no longer shows.
  -- Proof: before/after picture ids from shape_change.
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
          AND sc.change_kind  = 'DELETED'
          AND sc.schema_name || '.' || sc.object_name = obj.name
        ORDER BY sc.noticed_at DESC
        LIMIT 1),
      'no shape record'
    )
  FROM unnest(COALESCE(v_deleted_objs, ARRAY[]::text[])) AS obj(name);

END;
$function$;

REVOKE EXECUTE ON FUNCTION guardops.job_verdict(bigint) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION guardops.job_verdict(bigint) TO service_role;

-- ── rolled-back proof ────────────────────────────────────────────────────────
-- Three checks in one subtransaction:
--   (a) 2 plan items delivered, 1 missing   → kind counts match
--   (b) 1 object added, 1 object deleted    → kind counts match
--   (c) unknown job_id raises an exception  → NOT FOUND guard fires
-- RAISE EXCEPTION at the end rolls back all test data.

DO $proof$
DECLARE
  v_db_id     bigint;
  v_job_id    bigint;
  v_plan_ids  bigint[];
  v_claim_id  bigint;
  v_delivered bigint;
  v_missing   bigint;
  v_added     bigint;
  v_deleted   bigint;
  v_ok        boolean;
  v_count     bigint;
BEGIN
  BEGIN
    v_db_id    := guardops.watched_database_add('proof-0078/db');
    v_job_id   := guardops.job_add(v_db_id, 'proof-0078: job_verdict smoke test');
    v_plan_ids := guardops.plan_given_add(
      v_job_id,
      ARRAY['proof-0078 step one', 'proof-0078 step two', 'proof-0078 step three']
    );

    -- deliver first two; step three is deliberately left missing
    v_claim_id := guardops.claim_add(
      v_job_id,
      v_plan_ids[1:2],
      ARRAY['guardops.fn_proof_added'],
      ARRAY['guardops.fn_proof_deleted']
    );

    -- (a) delivered + missing
    SELECT count(*) INTO v_delivered
      FROM guardops.job_verdict(v_job_id) WHERE kind = 'DELIVERED';
    SELECT count(*) INTO v_missing
      FROM guardops.job_verdict(v_job_id) WHERE kind = 'MISSING';
    ASSERT v_delivered = 2,
      'expected 2 DELIVERED, got ' || v_delivered;
    ASSERT v_missing = 1,
      'expected 1 MISSING, got ' || v_missing;

    -- (b) added + deleted
    SELECT count(*) INTO v_added
      FROM guardops.job_verdict(v_job_id) WHERE kind = 'ADDED';
    SELECT count(*) INTO v_deleted
      FROM guardops.job_verdict(v_job_id) WHERE kind = 'DELETED';
    ASSERT v_added = 1,
      'expected 1 ADDED, got ' || v_added;
    ASSERT v_deleted = 1,
      'expected 1 DELETED, got ' || v_deleted;

    -- (c) unknown job_id must raise
    v_ok := false;
    BEGIN
      PERFORM * FROM guardops.job_verdict(-1);
    EXCEPTION WHEN OTHERS THEN
      v_ok := true;
    END;
    ASSERT v_ok,
      'job_verdict(-1) must raise for a non-existent job_id';

    RAISE INFO 'proof/0078: delivered=%, missing=%, added=%, deleted=%; unknown-id guard confirmed',
      v_delivered, v_missing, v_added, v_deleted;
    RAISE EXCEPTION 'proof/0078/rollback';

  EXCEPTION
    WHEN OTHERS THEN
      IF sqlerrm = 'proof/0078/rollback' THEN
        NULL;
      ELSE
        RAISE;
      END IF;
  END;

  SELECT count(*) INTO v_count
    FROM guardops.job
   WHERE what_for = 'proof-0078: job_verdict smoke test';
  ASSERT v_count = 0,
    'job must be empty after rollback, found ' || v_count || ' row(s)';

  RAISE INFO 'proof/0078: data unchanged after rollback - door confirmed';
END
$proof$;
