-- migrations/0081_watched_database_add_fix.sql
-- Board 11968. Fresh delivery of the corrected register-a-database door.
-- 0074_watched_database_add.sql sits on branch board-11937 and was held with
-- one Major; that board can never merge. This file delivers the same door on a
-- clean board so a fresh install gets guardops.watched_database_add.
--
-- guardops.watched_database_add(p_label, p_project_ref, p_connect_mode,
--   p_is_test, p_secret_name) returns bigint
-- Inserts one watched_database row for the calling account.
-- connect_mode defaults to 'CONNECTION'; when CONNECTION, secret_name is set
-- to 'pending:<label>' if not supplied, satisfying the watched_database_one_way_in
-- check constraint. is_test defaults to true for all calls through this door.
-- SECURITY DEFINER, search_path empty, REVOKE EXECUTE FROM PUBLIC.
--
-- Proof fix (the finding that held board-11937):
--   The proof must sign in as a house before calling the door so it works once
--   the owner fix is applied. The act_as_house call is guarded: it is skipped
--   when the function does not yet exist, so the proof is safe on any install.

CREATE OR REPLACE FUNCTION guardops.watched_database_add(
  p_label        text,
  p_project_ref  text    DEFAULT NULL,
  p_connect_mode text    DEFAULT 'CONNECTION',
  p_is_test      boolean DEFAULT true,
  p_secret_name  text    DEFAULT NULL
)
  RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
DECLARE
  v_id          bigint;
  v_mode        text := COALESCE(p_connect_mode, 'CONNECTION');
  v_secret_name text := CASE
                          WHEN v_mode = 'CONNECTION'
                          THEN COALESCE(p_secret_name, 'pending:' || p_label)
                          ELSE p_secret_name
                        END;
BEGIN
  INSERT INTO guardops.watched_database
    (account_id, label, project_ref, connect_mode, is_test, secret_name)
  VALUES
    (guardops.current_account(), p_label, p_project_ref, v_mode, p_is_test, v_secret_name)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$function$;

REVOKE EXECUTE ON FUNCTION guardops.watched_database_add(text, text, text, boolean, text) FROM PUBLIC;

-- ── rolled-back proof ────────────────────────────────────────────────────────
-- Sets up account + customer + connected_account, signs in if act_as_house
-- exists (guard so it is safe before the owner fix is applied), then calls
-- the door and asserts the row. The inner RAISE EXCEPTION rolls back all test
-- data via the implicit PL/pgSQL savepoint; the outer check confirms no row
-- survives.

DO $proof$
DECLARE
  v_acct_id bigint;
  v_cust_id bigint;
  v_db_id   bigint;
  v_count   bigint;
BEGIN
  BEGIN
    INSERT INTO guardops.account (name) VALUES ('proof-0081') RETURNING id INTO v_acct_id;

    INSERT INTO guardops.customer (account_id, external_id)
      VALUES (v_acct_id, 'proof-0081-ext') RETURNING id INTO v_cust_id;

    INSERT INTO guardops.connected_account
      (account_id, customer_id, token_secret_name, status)
    VALUES (v_acct_id, v_cust_id, 'proof-0081-tok', 'ACTIVE');

    -- sign in as this house if act_as_house is available;
    -- skipped on schemas where it does not yet exist (before the owner fix)
    IF EXISTS (
      SELECT 1 FROM information_schema.routines
       WHERE routine_schema = 'guardops' AND routine_name = 'act_as_house'
    ) THEN
      PERFORM guardops.act_as_house(v_cust_id);
    END IF;

    v_db_id := guardops.watched_database_add('proof-0081');

    ASSERT v_db_id IS NOT NULL,
      'watched_database_add must return a non-null id';

    SELECT count(*) INTO v_count
      FROM guardops.watched_database
     WHERE id = v_db_id;
    ASSERT v_count = 1,
      'watched_database row must exist inside the subtransaction, found ' || v_count;

    RAISE INFO 'proof/0081: watched_database_add returned id %; row confirmed inside subtransaction', v_db_id;
    RAISE EXCEPTION 'proof/0081/rollback';

  EXCEPTION
    WHEN OTHERS THEN
      IF sqlerrm = 'proof/0081/rollback' THEN
        NULL; -- expected; test data rolled back by savepoint
      ELSE
        RAISE;
      END IF;
  END;

  SELECT count(*) INTO v_count
    FROM guardops.watched_database
   WHERE label = 'proof-0081';
  ASSERT v_count = 0,
    'watched_database must be empty after rollback, found ' || v_count || ' row(s)';

  RAISE INFO 'proof/0081: watched_database unchanged after rollback - door confirmed';
END
$proof$;
