-- migrations/0097_current_account_or_null.sql
-- Job 1 of the wall. Cold-read and approved: board 12126.
--
-- The rules that keep customers apart have to ask "whose row is this". The only
-- thing that can answer is current_account(), and it RAISES when nobody is
-- signed in. A rule that raises turns every query by a signed-out caller into an
-- error instead of quietly returning nothing, and an error leaks the shape of
-- what is behind it. The rules need an answer of "nobody".
--
-- The whole body moves into ONE function that can either raise or return NULL.
-- current_account() becomes a one-line wrapper. Two copies of a security check
-- drift apart; one gets fixed and the other does not, and the stale one is the
-- one guarding the wall. So there is one copy.
--
-- Nothing else changes: same name, same return type, same raise wording, same
-- constant-time compare. The 14 tables whose account_id defaults to
-- current_account() call the name, not the body, so they are untouched.

CREATE OR REPLACE FUNCTION guardops.current_account_or_null(
    p_raise boolean DEFAULT false
)
  RETURNS bigint
  LANGUAGE plpgsql
  VOLATILE
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
DECLARE
  v_raw         text;
  v_hex_sig     text;
  v_account_txt text;
  v_payload     text;
  v_secret      bytea;
  v_digest      text;
  v_expected    bytea;
  v_offered     bytea;
  v_acc         integer := 0;
  i             integer;
BEGIN
  v_raw := pg_catalog.current_setting('guardops.house', true);
  IF v_raw IS NULL OR v_raw = '' THEN
    IF p_raise THEN RAISE EXCEPTION '[NO HOUSE] nobody is signed in for this call'; END IF;
    RETURN NULL;
  END IF;

  -- expected shape: {digits}.{64 lowercase hex chars}
  IF pg_catalog.length(v_raw) <= 65 THEN
    IF p_raise THEN RAISE EXCEPTION '[NO HOUSE] guardops.house is malformed'; END IF;
    RETURN NULL;
  END IF;
  v_hex_sig     := pg_catalog.right(v_raw, 64);
  v_account_txt := pg_catalog.left(v_raw, pg_catalog.length(v_raw) - 65);
  IF pg_catalog.substr(v_raw, pg_catalog.length(v_raw) - 64, 1) <> '.' THEN
    IF p_raise THEN RAISE EXCEPTION '[NO HOUSE] guardops.house is malformed'; END IF;
    RETURN NULL;
  END IF;
  IF v_hex_sig !~ '^[0-9a-f]{64}$' THEN
    IF p_raise THEN RAISE EXCEPTION '[NO HOUSE] guardops.house is malformed'; END IF;
    RETURN NULL;
  END IF;
  IF v_account_txt !~ '^\d+$' THEN
    IF p_raise THEN RAISE EXCEPTION '[NO HOUSE] guardops.house is malformed'; END IF;
    RETURN NULL;
  END IF;

  SELECT ck.secret, ck.digest INTO v_secret, v_digest
    FROM guardops.checker_key ck WHERE ck.key_id = 'active';
  IF v_secret IS NULL THEN
    IF p_raise THEN RAISE EXCEPTION '[NO HOUSE] no signing key installed'; END IF;
    RETURN NULL;
  END IF;

  -- rebuild the same payload act_as_house signed; a different session user or
  -- transaction id means the compare fails
  v_payload := v_account_txt
            || ':' || session_user
            || ':' || pg_catalog.pg_current_xact_id()::text;

  -- constant-time compare (same loop as checker_verify - no early exit)
  v_expected := extensions.hmac(pg_catalog.convert_to(v_payload, 'UTF8'), v_secret, v_digest);
  v_offered  := pg_catalog.decode(v_hex_sig, 'hex');
  IF v_expected IS NULL
     OR pg_catalog.octet_length(v_expected) <> 32
     OR pg_catalog.octet_length(v_offered)  <> 32
  THEN
    IF p_raise THEN RAISE EXCEPTION '[NO HOUSE] guardops.house signature could not be verified'; END IF;
    RETURN NULL;
  END IF;
  FOR i IN 0..31 LOOP
    v_acc := v_acc | (pg_catalog.get_byte(v_expected, i) # pg_catalog.get_byte(v_offered, i));
  END LOOP;
  IF v_acc <> 0 THEN
    IF p_raise THEN RAISE EXCEPTION '[NO HOUSE] guardops.house is forged or replayed'; END IF;
    RETURN NULL;
  END IF;

  RETURN v_account_txt::bigint;
END
$function$;

REVOKE EXECUTE ON FUNCTION guardops.current_account_or_null(boolean) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION guardops.current_account_or_null(boolean) FROM anon;
REVOKE EXECUTE ON FUNCTION guardops.current_account_or_null(boolean) FROM authenticated;
GRANT  EXECUTE ON FUNCTION guardops.current_account_or_null(boolean) TO service_role;

-- current_account() is now a wrapper over the single copy of the checking.
CREATE OR REPLACE FUNCTION guardops.current_account()
  RETURNS bigint
  LANGUAGE plpgsql
  VOLATILE
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
BEGIN
  RETURN guardops.current_account_or_null(true);
END
$function$;

REVOKE EXECUTE ON FUNCTION guardops.current_account() FROM PUBLIC;

-- ── rolled-back proof ────────────────────────────────────────────────────────
DO $proof$
DECLARE
  v_acct_id bigint;
  v_cust_id bigint;
  v_got     bigint;
  v_raised  boolean;
  v_msg     text;
BEGIN
  BEGIN
    -- (1) signed out: NULL, and no raise
    PERFORM pg_catalog.set_config('guardops.house', '', true);
    v_got := guardops.current_account_or_null();
    ASSERT v_got IS NULL, 'signed out must return NULL, got ' || COALESCE(v_got::text,'<null>');

    -- (2) malformed setting: NULL, and no raise
    PERFORM pg_catalog.set_config('guardops.house', 'not-a-house', true);
    v_got := guardops.current_account_or_null();
    ASSERT v_got IS NULL, 'a malformed setting must return NULL, got ' || COALESCE(v_got::text,'<null>');

    -- (3) forged signature of the right shape: NULL, and no raise
    PERFORM pg_catalog.set_config('guardops.house',
      '1.' || repeat('a', 64), true);
    v_got := guardops.current_account_or_null();
    ASSERT v_got IS NULL, 'a forged signature must return NULL, got ' || COALESCE(v_got::text,'<null>');

    -- (4) current_account() still raises when signed out, same wording
    PERFORM pg_catalog.set_config('guardops.house', '', true);
    v_raised := false;
    BEGIN
      PERFORM guardops.current_account();
    EXCEPTION WHEN OTHERS THEN
      v_raised := true;
      v_msg := SQLERRM;
    END;
    ASSERT v_raised, 'current_account() must still raise when nobody is signed in';
    ASSERT v_msg = '[NO HOUSE] nobody is signed in for this call',
      'the raise wording must be unchanged, got: ' || COALESCE(v_msg,'<null>');

    -- (5) a real sign-in, in this same transaction, returns that account
    INSERT INTO guardops.account (name) VALUES ('proof-0097') RETURNING id INTO v_acct_id;
    INSERT INTO guardops.customer (account_id, external_id)
      VALUES (v_acct_id, 'proof-0097-ext') RETURNING id INTO v_cust_id;
    INSERT INTO guardops.connected_account
      (account_id, customer_id, token_secret_name, status)
    VALUES (v_acct_id, v_cust_id, 'proof-0097-tok', 'ACTIVE');
    PERFORM guardops.act_as_house(v_cust_id);

    v_got := guardops.current_account_or_null();
    ASSERT v_got = v_acct_id,
      'after a real sign-in it must return that account, wanted ' || v_acct_id || ' got ' || COALESCE(v_got::text,'<null>');
    ASSERT guardops.current_account() = v_acct_id,
      'the wrapper must return the same account';

    RAISE INFO 'proof/0097: NULL when signed out, malformed and forged; the account after a real sign-in; wrapper still raises with the same wording';
    RAISE EXCEPTION 'proof/0097/rollback';

  EXCEPTION
    WHEN OTHERS THEN
      IF sqlerrm = 'proof/0097/rollback' THEN
        NULL;
      ELSE
        RAISE;
      END IF;
  END;

  SELECT count(*) INTO v_got FROM guardops.account WHERE name = 'proof-0097';
  ASSERT v_got = 0, 'account must be empty after rollback, found ' || v_got;

  RAISE INFO 'proof/0097: nothing left behind after rollback';
END
$proof$;
