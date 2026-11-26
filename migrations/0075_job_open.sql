-- migrations/0075_job_open.sql
-- Board 11913. STEP 3 of the plan (board 11902).
--
-- guardops.job_add(p_repo_link_id bigint, p_what_for text) returns bigint
-- Stamps account_id with guardops.current_account(). Follows the shape
-- guardops.job already has (migration 0063). SECURITY DEFINER, search_path empty.
-- one_run_test step 2 checks for this door by name 'job_add'.

CREATE OR REPLACE FUNCTION guardops.job_add(p_repo_link_id bigint, p_what_for text)
  RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
DECLARE
  v_id bigint;
BEGIN
  INSERT INTO guardops.job (account_id, repo_link_id, what_for)
  VALUES (guardops.current_account(), p_repo_link_id, p_what_for)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$function$;

REVOKE EXECUTE ON FUNCTION guardops.job_add(bigint, text) FROM PUBLIC;

-- ── rolled-back proof ────────────────────────────────────────────────────────
-- One inner BEGIN..EXCEPTION block: PL/pgSQL places an implicit savepoint at
-- the opening BEGIN, so the RAISE EXCEPTION at the end rolls back all DB writes.
-- RETURN rows buffered before the raise survive and are returned to the caller.
-- job must have 0 rows after this block exits.

DO $proof$
DECLARE
  v_acct_id  bigint;
  v_cust_id  bigint;
  v_link_id  bigint;
  v_job_id   bigint;
  v_count    bigint;
BEGIN
  BEGIN
    -- set up an account and customer with ACTIVE sign-in for the proof
    INSERT INTO guardops.account (name) VALUES ('proof-0075') RETURNING id INTO v_acct_id;
    INSERT INTO guardops.customer (account_id, external_id)
      VALUES (v_acct_id, 'proof-0075-ext') RETURNING id INTO v_cust_id;
    INSERT INTO guardops.connected_account
      (account_id, customer_id, token_secret_name, status)
    VALUES (v_acct_id, v_cust_id, 'proof-0075-tok', 'ACTIVE');

    -- sign in as this house if act_as_house is available;
    -- skipped on schemas where it does not yet exist (older install base)
    IF EXISTS (
      SELECT 1 FROM information_schema.routines
       WHERE routine_schema = 'guardops' AND routine_name = 'act_as_house'
    ) THEN
      PERFORM guardops.act_as_house(v_cust_id);
    END IF;

    v_link_id := guardops.repo_link_add('proof-0075/test', 'main');

    -- open a job against that repo link
    v_job_id := guardops.job_add(v_link_id, 'proof-0075: door smoke test');

    ASSERT v_job_id IS NOT NULL,
      'job_add must return a non-null id';

    SELECT count(*) INTO v_count
      FROM guardops.job
     WHERE id = v_job_id;
    ASSERT v_count = 1,
      'job row must exist inside the subtransaction, found ' || v_count;

    RAISE INFO 'proof/0075: job_add returned id %; row confirmed inside subtransaction', v_job_id;
    RAISE EXCEPTION 'proof/0075/rollback';

  EXCEPTION
    WHEN OTHERS THEN
      IF sqlerrm = 'proof/0075/rollback' THEN
        NULL; -- expected; test data rolled back by savepoint
      ELSE
        RAISE;
      END IF;
  END;

  -- verify job is unchanged after rollback
  SELECT count(*) INTO v_count
    FROM guardops.job
   WHERE what_for = 'proof-0075: door smoke test';
  ASSERT v_count = 0,
    'job must be empty after rollback, found ' || v_count || ' row(s)';

  RAISE INFO 'proof/0075: job unchanged after rollback - door confirmed';
END
$proof$;
