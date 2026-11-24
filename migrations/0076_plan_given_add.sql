-- migrations/0076_plan_given_add.sql
-- Board 11950. Fixes three findings from the review of board 11938.
--
-- guardops.plan_given_add(p_job_id bigint, p_items text[]) returns bigint[]
--
-- Fix 1 (digest ambiguity): chr(31) separator allowed two distinct arrays to
--   serialise to the same string (e.g. ['a\x1f','b'] == ['a','\x1fb']).
--   Replaced with to_json(p_items)::text, which JSON-quotes every item and
--   escapes control characters - no two distinct arrays can collide.
--
-- Fix 2 (version race): plan_version was read and then written without any
--   serialisation gate, so two concurrent callers could both read the same
--   MAX and write duplicate version numbers.  FOR UPDATE on the job row now
--   serialises all concurrent filings for the same job.
--
-- Fix 3 (account isolation): the door never verified that p_job_id belongs
--   to the calling account.  The FOR UPDATE SELECT now also filters on
--   account_id, so a caller can only file plans onto their own jobs.

CREATE OR REPLACE FUNCTION guardops.plan_given_add(p_job_id bigint, p_items text[])
  RETURNS bigint[]
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
DECLARE
  v_next_version integer;
  v_digest       text;
  v_ids          bigint[] := ARRAY[]::bigint[];
  v_id           bigint;
  v_i            integer;
BEGIN
  -- Verify ownership and serialise concurrent filings for the same job.
  -- FOR UPDATE: two callers for the same job queue here; the second reads
  -- MAX(plan_version) only after the first has committed its rows.
  PERFORM 1 FROM guardops.job
    WHERE id = p_job_id AND account_id = guardops.current_account()
    FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'job % does not exist or does not belong to this account', p_job_id;
  END IF;

  -- plan_version: 1 on first filing, +1 on each refile.
  SELECT COALESCE(MAX(plan_version), 0) + 1
    INTO v_next_version
    FROM guardops.plan_given
   WHERE job_id = p_job_id;

  -- JSON encoding is unambiguous: each item is quoted and control characters
  -- are escaped, so no two distinct arrays can produce the same string.
  v_digest := encode(
    extensions.digest(
      to_json(p_items)::text,
      'sha256'
    ),
    'hex'
  );

  FOR v_i IN 1 .. array_length(p_items, 1) LOOP
    INSERT INTO guardops.plan_given
      (account_id, item_text, position, plan_version, plan_digest, job_id)
    VALUES
      (guardops.current_account(), p_items[v_i], v_i, v_next_version, v_digest, p_job_id)
    RETURNING id INTO v_id;
    v_ids := v_ids || v_id;
  END LOOP;

  RETURN v_ids;
END;
$function$;

REVOKE EXECUTE ON FUNCTION guardops.plan_given_add(bigint, text[]) FROM PUBLIC;

-- ── rolled-back proof ────────────────────────────────────────────────────────
-- Inner BEGIN..EXCEPTION: PL/pgSQL savepoint rolls back all writes on the
-- RAISE EXCEPTION at the end. The post-block ASSERTs verify no rows survive.

DO $proof$
DECLARE
  v_link_id bigint;
  v_job_id  bigint;
  v_ids     bigint[];
  v_count   bigint;
  v_digest1 text;
  v_digest2 text;
BEGIN
  BEGIN
    v_link_id := guardops.repo_link_add('proof-0076/test', 'main');
    v_job_id  := guardops.job_add(v_link_id, 'proof-0076: plan_given_add smoke test');

    -- file a 3-item plan; expect 3 ids back at version 1
    v_ids := guardops.plan_given_add(
      v_job_id,
      ARRAY['step one', 'step two', 'step three']
    );

    ASSERT array_length(v_ids, 1) = 3,
      'plan_given_add must return 3 ids, got ' || array_length(v_ids, 1);

    SELECT count(*) INTO v_count
      FROM guardops.plan_given
     WHERE job_id = v_job_id AND plan_version = 1;
    ASSERT v_count = 3,
      'must have 3 rows at version 1, found ' || v_count;

    SELECT plan_digest INTO v_digest1
      FROM guardops.plan_given WHERE id = v_ids[1];

    -- refile with different items; version must increment to 2
    v_ids := guardops.plan_given_add(
      v_job_id,
      ARRAY['step one', 'step two revised']
    );

    ASSERT array_length(v_ids, 1) = 2,
      'refile must return 2 ids, got ' || array_length(v_ids, 1);

    SELECT count(*) INTO v_count
      FROM guardops.plan_given
     WHERE job_id = v_job_id AND plan_version = 2;
    ASSERT v_count = 2,
      'refile must produce 2 rows at version 2, found ' || v_count;

    SELECT plan_digest INTO v_digest2
      FROM guardops.plan_given WHERE id = v_ids[1];

    ASSERT v_digest1 <> v_digest2,
      'distinct plans must produce distinct digests';

    -- isolation gate: a job id that does not exist must be rejected
    BEGIN
      PERFORM guardops.plan_given_add(99999999, ARRAY['hijack attempt']);
      RAISE EXCEPTION 'proof/0076: isolation gate did not fire for unknown job';
    EXCEPTION
      WHEN OTHERS THEN
        IF sqlerrm LIKE '%does not exist or does not belong to this account%' THEN
          RAISE INFO 'proof/0076: isolation gate correctly rejected unknown job id';
        ELSE
          RAISE;
        END IF;
    END;

    RAISE INFO 'proof/0076: 3 ids at v1, 2 ids at v2, digests differ, isolation gate fires';
    RAISE EXCEPTION 'proof/0076/rollback';

  EXCEPTION
    WHEN OTHERS THEN
      IF sqlerrm = 'proof/0076/rollback' THEN
        NULL;
      ELSE
        RAISE;
      END IF;
  END;

  -- verify no plan_given rows survive the rollback
  SELECT count(*) INTO v_count
    FROM guardops.plan_given
   WHERE item_text IN ('step one', 'step two', 'step three', 'step two revised');
  ASSERT v_count = 0,
    'plan_given must be empty after rollback, found ' || v_count || ' row(s)';

  RAISE INFO 'proof/0076: no rows survive rollback - confirmed';
END
$proof$;
