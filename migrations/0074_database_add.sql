-- migrations/0074_database_add.sql
-- Board 11912. Door to register a database to watch.
-- Naming follows the floor pattern: table watched_database → door watched_database_add.
--
-- The table constraint watched_database_one_way_in requires:
--   CONNECTION mode → secret_name IS NOT NULL
--   SIGNED mode     → project_ref IS NOT NULL AND connected_account_id IS NOT NULL
-- When p_secret_name is omitted and mode is CONNECTION (the default), the door
-- generates a 'pending:<label>' placeholder so test-mode callers that omit it
-- still satisfy the constraint. A production caller supplies the real Vault name.

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
END
$function$;

REVOKE EXECUTE ON FUNCTION guardops.watched_database_add(text, text, text, boolean, text) FROM PUBLIC;

-- Drop any prior 4-param overload left by an earlier draft of this migration.
DROP FUNCTION IF EXISTS guardops.watched_database_add(text, text, text, boolean);
