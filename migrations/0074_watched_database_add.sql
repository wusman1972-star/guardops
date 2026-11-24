-- migrations/0074_watched_database_add.sql
-- Board 11937. STEP 5 of the plan.
--
-- guardops.watched_database_add(p_label text, ...) returns bigint
-- One required argument; optional: p_project_ref, p_connect_mode, p_is_test, p_secret_name.
-- Stamps account_id with guardops.current_account(). SECURITY DEFINER, search_path empty.
-- one_run_test step 1 checks for this door by name 'watched_database_add'.

CREATE OR REPLACE FUNCTION guardops.watched_database_add(
  p_label        text,
  p_project_ref  text    DEFAULT NULL,
  p_connect_mode text    DEFAULT 'CONNECTION',
  p_is_test      boolean DEFAULT false,
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

DO $proof$
DECLARE
  v_db_id  bigint;
  v_count  bigint;
BEGIN
  BEGIN
    v_db_id := guardops.watched_database_add('proof-0074/test'::text);

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
        NULL;
      ELSE
        RAISE;
      END IF;
  END;

  SELECT count(*) INTO v_count
    FROM guardops.watched_database
   WHERE label = 'proof-0074/test';
  ASSERT v_count = 0,
    'watched_database must be empty after rollback, found ' || v_count || ' row(s)';

  RAISE INFO 'proof/0074: watched_database unchanged after rollback - door confirmed';
END
$proof$;
