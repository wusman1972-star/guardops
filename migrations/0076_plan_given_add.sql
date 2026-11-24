-- migrations/0076_plan_given_add.sql
-- Board 11938. STEP 6 of the plan (board 11902).
--
-- guardops.plan_given_add(p_job_id bigint, p_items text[]) returns bigint[]
-- Files one plan_given row per item in position order.
-- plan_version rises from 1 on each refile for the same job.
-- plan_digest is SHA-256 over the whole ordered item list, so an altered
-- plan cannot pass as the original.
-- account_id stamped with guardops.current_account().
-- SECURITY DEFINER, search_path empty, REVOKE EXECUTE FROM PUBLIC.

CREATE OR REPLACE FUNCTION guardops.plan_given_add(
  p_job_id bigint,
  p_items  text[]
)
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
  -- plan_version: 1 on first file for this job, +1 on each refile
  SELECT COALESCE(MAX(plan_version), 0) + 1
    INTO v_next_version
    FROM guardops.plan_given
   WHERE job_id = p_job_id;

  -- digest covers the full ordered item list; chr(31) = ASCII unit separator,
  -- chosen to avoid collision with plausible item text
  v_digest := encode(
    extensions.digest(
      array_to_string(p_items, chr(31)),
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
-- Part A: one_run_test must not stop at step 3 (plan_given_add exists and runs).
-- Part B: UPDATE on a filed plan row must be refused by plan_given_no_mutation.
-- All test data is rolled back; nothing persists after this block.

DO $proof$
DECLARE
  v_row        record;
  v_link_id    bigint;
  v_job_id     bigint;
  v_items      bigint[];
  v_blocked    boolean := false;
BEGIN
  BEGIN

    -- Part A ------------------------------------------------------------------
    FOR v_row IN SELECT * FROM guardops.one_run_test() LOOP
      IF v_row.step = 3 AND NOT v_row.pass THEN
        RAISE EXCEPTION 'proof/0076: one_run_test stopped at step 3: got=%, want=%',
          v_row.got, v_row.want;
      END IF;
    END LOOP;
    RAISE INFO 'proof/0076: one_run_test passed step 3';

    -- Part B ------------------------------------------------------------------
    -- Write a row, attempt an UPDATE, expect the append-only trigger to refuse.
    -- The inner BEGIN..EXCEPTION catches the trigger error and rolls back
    -- the DML inside; v_blocked survives as a PL/pgSQL variable.
    BEGIN
      v_link_id := guardops.repo_link_add('proof-0076/update-block', 'main');
      v_job_id  := guardops.job_add(v_link_id, 'proof-0076: update-block test');
      v_items   := guardops.plan_given_add(v_job_id, ARRAY['proof item one']);

      UPDATE guardops.plan_given
         SET item_text = 'mutated'
       WHERE id = v_items[1];

      -- trigger must have fired before this line
      RAISE EXCEPTION 'proof/0076/update_allowed_unexpectedly';
    EXCEPTION
      WHEN OTHERS THEN
        IF sqlerrm LIKE '%append-only%' THEN
          v_blocked := true;
        ELSE
          RAISE;
        END IF;
    END;

    ASSERT v_blocked,
      'proof/0076: UPDATE on plan_given must be blocked by plan_given_no_mutation';
    RAISE INFO 'proof/0076: UPDATE correctly blocked by append-only trigger';

    -- Roll back all proof DML
    RAISE EXCEPTION 'proof/0076/rollback';

  EXCEPTION
    WHEN OTHERS THEN
      IF sqlerrm = 'proof/0076/rollback' THEN
        RAISE INFO 'proof/0076: data rolled back - door confirmed';
      ELSE
        RAISE;
      END IF;
  END;
END
$proof$;
