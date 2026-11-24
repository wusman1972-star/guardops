-- migrations/0079_connected_account_add.sql
-- Board 11948. The sign-in door.
--
-- guardops.connected_account_add(p_customer_id bigint, p_provider text,
--   p_org_slug text, p_token_secret_name text) returns bigint
-- Writes a new ACTIVE connected_account row for the given customer without
-- calling current_account(). SECURITY DEFINER, search_path empty.
-- REVOKE EXECUTE FROM PUBLIC. GRANT EXECUTE to service_role only.

CREATE OR REPLACE FUNCTION guardops.connected_account_add(
  p_customer_id       bigint,
  p_provider          text,
  p_org_slug          text,
  p_token_secret_name text
) RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
DECLARE
  v_account_id bigint;
  v_id         bigint;
BEGIN
  SELECT account_id
    INTO v_account_id
    FROM guardops.customer
   WHERE id = p_customer_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'connected_account_add: customer % does not exist', p_customer_id;
  END IF;

  INSERT INTO guardops.connected_account
    (account_id, customer_id, provider, org_slug, token_secret_name, status, approved_at)
  VALUES
    (v_account_id, p_customer_id, p_provider, p_org_slug, p_token_secret_name, 'ACTIVE', now())
  RETURNING id INTO v_id;

  PERFORM guardops.signin_retire_others(v_id);

  RETURN v_id;
END;
$function$;

REVOKE EXECUTE ON FUNCTION guardops.connected_account_add(bigint, text, text, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION guardops.connected_account_add(bigint, text, text, text) TO service_role;

-- ── rolled-back proof ────────────────────────────────────────────────────────
-- Proof does not call current_account() or house_make; inserts account and
-- customer directly so the proof is safe whether or not 0071 is applied.
-- The inner BEGIN block places an implicit savepoint; RAISE EXCEPTION at the
-- end rolls back all test data. connected_account must have the same row count
-- before and after.

DO $proof$
DECLARE
  v_account_id  bigint;
  v_customer_id bigint;
  v_conn_id_1   bigint;
  v_conn_id_2   bigint;
  v_count       bigint;
  v_before      bigint;
BEGIN
  SELECT count(*) INTO v_before FROM guardops.connected_account;

  BEGIN
    INSERT INTO guardops.account (name)
    VALUES ('proof-0079')
    RETURNING id INTO v_account_id;

    INSERT INTO guardops.customer (account_id, provider, external_id, email)
    VALUES (v_account_id, 'supabase', 'proof-ext-0079', 'proof@0079.test')
    RETURNING id INTO v_customer_id;

    -- first call: must produce one ACTIVE row
    v_conn_id_1 := guardops.connected_account_add(
      v_customer_id, 'supabase', 'proof-org', 'proof-secret-0079a'
    );

    ASSERT v_conn_id_1 IS NOT NULL,
      'connected_account_add must return a non-null id';

    SELECT count(*) INTO v_count
      FROM guardops.connected_account
     WHERE customer_id = v_customer_id AND status = 'ACTIVE';
    ASSERT v_count = 1,
      'must have exactly 1 ACTIVE row after first call, found ' || v_count;

    RAISE INFO 'proof/0079: first call returned %; 1 ACTIVE row confirmed', v_conn_id_1;

    -- second call for same customer+provider: old row must become SUPERSEDED
    v_conn_id_2 := guardops.connected_account_add(
      v_customer_id, 'supabase', 'proof-org', 'proof-secret-0079b'
    );

    SELECT count(*) INTO v_count
      FROM guardops.connected_account
     WHERE customer_id = v_customer_id AND status = 'ACTIVE';
    ASSERT v_count = 1,
      'must have exactly 1 ACTIVE row after second call, found ' || v_count;

    SELECT count(*) INTO v_count
      FROM guardops.connected_account
     WHERE id = v_conn_id_1 AND status = 'SUPERSEDED';
    ASSERT v_count = 1,
      'first row must be SUPERSEDED after second call, found ' || v_count;

    RAISE INFO 'proof/0079: second call returned %; first row % superseded; 1 ACTIVE confirmed',
      v_conn_id_2, v_conn_id_1;

    RAISE EXCEPTION 'proof/0079/rollback';

  EXCEPTION
    WHEN OTHERS THEN
      IF sqlerrm = 'proof/0079/rollback' THEN
        NULL; -- expected; test data rolled back by savepoint
      ELSE
        RAISE;
      END IF;
  END;

  SELECT count(*) INTO v_count FROM guardops.connected_account;
  ASSERT v_count = v_before,
    'connected_account must be unchanged after rollback, found ' || v_count || ' row(s)';

  RAISE INFO 'proof/0079: connected_account unchanged after rollback - door confirmed';
END
$proof$;
