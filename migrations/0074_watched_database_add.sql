-- migrations/0074_watched_database_add.sql
-- Board 11937. STEP 5 of the one_run_test plan.
-- Board 11951 fix: proof must call act_as_house before the door;
-- guarded so it is skipped when act_as_house does not yet exist.
--
-- guardops.watched_database_add(p_label text) returns bigint
-- Stamps account_id with guardops.current_account(). is_test=true for all rows
-- created through this door. SECURITY DEFINER, search_path empty, REVOKE from PUBLIC.

CREATE OR REPLACE FUNCTION guardops.watched_database_add(p_label text)
  RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
DECLARE
  v_id bigint;
BEGIN
  INSERT INTO guardops.watched_database (account_id, label, is_test, secret_name)
  VALUES (guardops.current_account(), p_label, true, 'test:' || p_label)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$function$;

REVOKE EXECUTE ON FUNCTION guardops.watched_database_add(text) FROM PUBLIC;

-- ── rolled-back proof ────────────────────────────────────────────────────────
-- One inner BEGIN..EXCEPTION block: PL/pgSQL places an implicit savepoint at
-- the opening BEGIN, so the RAISE EXCEPTION at the end rolls back all test data
-- while the outer DO exits normally and the migration commits.

DO $proof$
DECLARE
  v_acct_id bigint;
  v_cust_id bigint;
  v_db_id   bigint;
  v_count   bigint;
BEGIN
  BEGIN
    -- set up an account and customer with ACTIVE sign-in for the proof
    INSERT INTO guardops.account (name) VALUES ('proof-0074') RETURNING id INTO v_acct_id;
    INSERT INTO guardops.customer (account_id, external_id)
      VALUES (v_acct_id, 'proof-0074-ext') RETURNING id INTO v_cust_id;
    INSERT INTO guardops.connected_account
      (account_id, customer_id, token_secret_name, status)
    VALUES (v_acct_id, v_cust_id, 'proof-0074-tok', 'ACTIVE');

    -- sign in as this house if act_as_house is available;
    -- skipped on schemas where it does not yet exist (older install base)
    IF EXISTS (
      SELECT 1 FROM information_schema.routines
       WHERE routine_schema = 'guardops' AND routine_name = 'act_as_house'
    ) THEN
      PERFORM guardops.act_as_house(v_cust_id);
    END IF;

    v_db_id := guardops.watched_database_add('proof-0074');

    ASSERT v_db_id IS NOT NULL,
      'watched_database_add must return a non-null id';

    SELECT count(*) INTO v_count
      FROM guardops.watched_database
     WHERE id = v_db_id;
    ASSERT v_count = 1,
      'watched_database row must exist inside the subtransaction, found ' || v_count;

    RAISE INFO 'proof/0074: watched_database_add returned id %; row confirmed inside subtransaction', v_db_id;
    RAISE EXCEPTION 'proof/0074/rollback';

  EXCEPTION
    WHEN OTHERS THEN
      IF sqlerrm = 'proof/0074/rollback' THEN
        NULL; -- expected; test data rolled back by savepoint
      ELSE
        RAISE;
      END IF;
  END;

  -- verify watched_database is unchanged after rollback
  SELECT count(*) INTO v_count
    FROM guardops.watched_database
   WHERE label = 'proof-0074';
  ASSERT v_count = 0,
    'watched_database must be empty after rollback, found ' || v_count || ' row(s)';

  RAISE INFO 'proof/0074: watched_database unchanged after rollback - door confirmed';
END
$proof$;
