-- migrations/0077_claim_add.sql
-- Board 11939. STEP 5 of the plan (board 11902). Fixed by board 11952.
--
-- guardops.claim_add(p_job_id bigint, p_delivered_item_ids bigint[],
--   p_added text[], p_deleted text[]) returns bigint
-- Records what the AI claimed to have done on a job.
-- Stamps account_id with guardops.current_account(). SECURITY DEFINER, search_path empty.
-- REVOKE EXECUTE FROM PUBLIC. GRANT EXECUTE to service_role only.
--
-- Hole 845: an EMPTY claim (null or empty p_delivered_item_ids) is recorded
-- and flagged is_empty = true. It is never accepted as agreement.
--
-- Board 11952 fix: GRANT EXECUTE to service_role was missing from the original
-- draft; added here. Without it, any role other than the owner received
-- permission denied after the PUBLIC revoke.

ALTER TABLE guardops.claim
  ADD COLUMN IF NOT EXISTS delivered_item_ids bigint[],
  ADD COLUMN IF NOT EXISTS added              text[],
  ADD COLUMN IF NOT EXISTS deleted            text[],
  ADD COLUMN IF NOT EXISTS is_empty           boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION guardops.claim_add(
  p_job_id              bigint,
  p_delivered_item_ids  bigint[],
  p_added               text[],
  p_deleted             text[]
) RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
DECLARE
  v_id    bigint;
  v_empty boolean;
BEGIN
  v_empty := (p_delivered_item_ids IS NULL
              OR array_length(p_delivered_item_ids, 1) IS NULL);

  INSERT INTO guardops.claim
    (account_id, job_id, delivered_item_ids, added, deleted, is_empty)
  VALUES
    (guardops.current_account(), p_job_id,
     p_delivered_item_ids, p_added, p_deleted, v_empty)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$function$;

REVOKE EXECUTE ON FUNCTION guardops.claim_add(bigint, bigint[], text[], text[]) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION guardops.claim_add(bigint, bigint[], text[], text[]) TO service_role;

-- ── rolled-back proof ────────────────────────────────────────────────────────
-- Two checks in one subtransaction:
--   (a) a normal claim is recorded with is_empty = false
--   (b) an empty claim (null delivered ids) is recorded and is_empty = true,
--       never accepted as agreement (hole 845)
-- RAISE EXCEPTION at the end rolls back all test data.

DO $proof$
DECLARE
  v_acct_id    bigint;
  v_cust_id    bigint;
  v_link_id    bigint;
  v_job_id     bigint;
  v_plan_ids   bigint[];
  v_claim_id   bigint;
  v_empty_id   bigint;
  v_is_empty   boolean;
  v_count      bigint;
BEGIN
  BEGIN
    -- set up an account and customer with ACTIVE sign-in for the proof
    INSERT INTO guardops.account (name) VALUES ('proof-0077') RETURNING id INTO v_acct_id;
    INSERT INTO guardops.customer (account_id, external_id)
      VALUES (v_acct_id, 'proof-0077-ext') RETURNING id INTO v_cust_id;
    INSERT INTO guardops.connected_account
      (account_id, customer_id, token_secret_name, status)
    VALUES (v_acct_id, v_cust_id, 'proof-0077-tok', 'ACTIVE');

    -- sign in as this house if act_as_house is available;
    -- skipped on schemas where it does not yet exist (older install base)
    IF EXISTS (
      SELECT 1 FROM information_schema.routines
       WHERE routine_schema = 'guardops' AND routine_name = 'act_as_house'
    ) THEN
      PERFORM guardops.act_as_house(v_cust_id);
    END IF;

    v_link_id  := guardops.repo_link_add('proof-0077/test', 'main');
    v_job_id   := guardops.job_add(v_link_id, 'proof-0077: claim_add smoke test');
    v_plan_ids := guardops.plan_given_add(
      v_job_id,
      ARRAY['proof-0077 step one', 'proof-0077 step two']
    );

    -- (a) normal claim
    v_claim_id := guardops.claim_add(
      v_job_id,
      ARRAY[v_plan_ids[1]],
      ARRAY['guardops.fn_added'],
      ARRAY['guardops.fn_removed']
    );

    ASSERT v_claim_id IS NOT NULL,
      'claim_add must return a non-null id';

    SELECT is_empty INTO v_is_empty
      FROM guardops.claim WHERE id = v_claim_id;
    ASSERT v_is_empty = false,
      'a non-empty claim must have is_empty = false, got ' || v_is_empty;

    -- (b) empty claim: null delivered list
    v_empty_id := guardops.claim_add(
      v_job_id,
      NULL,
      NULL,
      NULL
    );

    ASSERT v_empty_id IS NOT NULL,
      'claim_add must record an empty claim (hole 845)';

    SELECT is_empty INTO v_is_empty
      FROM guardops.claim WHERE id = v_empty_id;
    ASSERT v_is_empty = true,
      'an empty claim must have is_empty = true, got ' || v_is_empty;

    RAISE INFO 'proof/0077: normal claim id=%, empty claim id=% (is_empty=true) confirmed inside subtransaction',
      v_claim_id, v_empty_id;
    RAISE EXCEPTION 'proof/0077/rollback';

  EXCEPTION
    WHEN OTHERS THEN
      IF sqlerrm = 'proof/0077/rollback' THEN
        NULL;
      ELSE
        RAISE;
      END IF;
  END;

  SELECT count(*) INTO v_count
    FROM guardops.claim
   WHERE job_id IN (SELECT id FROM guardops.job WHERE what_for = 'proof-0077: claim_add smoke test');
  ASSERT v_count = 0,
    'claim must be empty after rollback, found ' || v_count || ' row(s)';

  RAISE INFO 'proof/0077: claim unchanged after rollback - door confirmed';
END
$proof$;
