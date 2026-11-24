-- migrations/0071_who_is_calling.sql
-- Board 11885. Replaces 0070_who_is_calling.sql (never applied, deleted in this job).
--
-- Two findings from CodeRabbit on 0070:
--   1. act_as_house was SECURITY DEFINER with EXECUTE left on PUBLIC - any role
--      that can run SQL could call it and become any customer with an ACTIVE sign-in.
--   2. The GUC was unsigned - any role that can run SQL could call
--      set_config('guardops.house', ..., true) and skip the door entirely.
--
-- Fix: sign the GUC with the install HMAC key (guardops.checker_key / extensions.hmac,
-- same as checker_verify). The payload binds the account id, the session user, and the
-- current transaction id. current_account() rebuilds the payload and verifies with a
-- constant-time compare. A copied or hand-written value is refused: the transaction id
-- in the stored signature will not match the current transaction.

-- ── act_as_house ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION guardops.act_as_house(p_customer bigint)
  RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
DECLARE
  v_account_id bigint;
  v_secret     bytea;
  v_digest     text;
  v_payload    text;
  v_sig        bytea;
  v_hex_sig    text;
BEGIN
  SELECT c.account_id INTO v_account_id
    FROM guardops.customer c
   WHERE c.id = p_customer;
  IF NOT FOUND THEN
    RAISE EXCEPTION '[NO HOUSE] customer % does not exist', p_customer;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM guardops.connected_account ca
     WHERE ca.customer_id = p_customer
       AND ca.status = 'ACTIVE'
  ) THEN
    RAISE EXCEPTION '[NO HOUSE] customer % has no ACTIVE sign-in', p_customer;
  END IF;

  SELECT ck.secret, ck.digest INTO v_secret, v_digest
    FROM guardops.checker_key ck WHERE ck.key_id = 'active';
  IF v_secret IS NULL THEN
    RAISE EXCEPTION '[NO HOUSE] no signing key installed';
  END IF;

  -- payload: account_id:session_user:transaction_id
  -- binding the transaction id means a copy from another transaction will not verify
  v_payload := v_account_id::text
            || ':' || session_user
            || ':' || pg_catalog.pg_current_xact_id()::text;

  v_sig     := extensions.hmac(pg_catalog.convert_to(v_payload, 'UTF8'), v_secret, v_digest);
  v_hex_sig := pg_catalog.encode(v_sig, 'hex');

  PERFORM pg_catalog.set_config('guardops.house',
                                v_account_id::text || '.' || v_hex_sig,
                                true);
  RETURN v_account_id;
END
$function$;

REVOKE EXECUTE ON FUNCTION guardops.act_as_house(bigint) FROM PUBLIC;
-- Deployment role needs an explicit GRANT EXECUTE ON FUNCTION
-- guardops.act_as_house(bigint) TO <role>; that target comes from deployment
-- config, not from this file.

-- ── current_account ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION guardops.current_account()
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
    RAISE EXCEPTION '[NO HOUSE] nobody is signed in for this call';
  END IF;

  -- expected shape: {digits}.{64 lowercase hex chars}
  IF pg_catalog.length(v_raw) <= 65 THEN
    RAISE EXCEPTION '[NO HOUSE] guardops.house is malformed';
  END IF;
  v_hex_sig     := pg_catalog.right(v_raw, 64);
  v_account_txt := pg_catalog.left(v_raw, pg_catalog.length(v_raw) - 65);
  IF pg_catalog.substr(v_raw, pg_catalog.length(v_raw) - 64, 1) <> '.' THEN
    RAISE EXCEPTION '[NO HOUSE] guardops.house is malformed';
  END IF;
  IF v_hex_sig !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION '[NO HOUSE] guardops.house is malformed';
  END IF;
  IF v_account_txt !~ '^\d+$' THEN
    RAISE EXCEPTION '[NO HOUSE] guardops.house is malformed';
  END IF;

  SELECT ck.secret, ck.digest INTO v_secret, v_digest
    FROM guardops.checker_key ck WHERE ck.key_id = 'active';
  IF v_secret IS NULL THEN
    RAISE EXCEPTION '[NO HOUSE] no signing key installed';
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
    RAISE EXCEPTION '[NO HOUSE] guardops.house signature could not be verified';
  END IF;
  FOR i IN 0..31 LOOP
    v_acc := v_acc | (pg_catalog.get_byte(v_expected, i) # pg_catalog.get_byte(v_offered, i));
  END LOOP;
  IF v_acc <> 0 THEN
    RAISE EXCEPTION '[NO HOUSE] guardops.house is forged or replayed';
  END IF;

  RETURN v_account_txt::bigint;
END
$function$;

REVOKE EXECUTE ON FUNCTION guardops.current_account() FROM PUBLIC;
-- Deployment role needs an explicit GRANT EXECUTE ON FUNCTION
-- guardops.current_account() TO <role>; that target comes from deployment
-- config, not from this file.

-- ── rolled-back proof ───────────────────────────────────────────────────────
-- One inner BEGIN..EXCEPTION block: PL/pgSQL places an implicit savepoint at
-- the opening BEGIN, so the RAISE EXCEPTION at the end rolls back all test data
-- while the outer DO exits normally and the migration commits.

DO $proof$
DECLARE
  v_acct1_id   bigint;
  v_acct2_id   bigint;
  v_cust1_id   bigint;
  v_cust2_id   bigint;
  v_cust_no_id bigint;
  v_got        bigint;
  v_ok         boolean;
  v_key_secret bytea;
  v_key_digest text;
  v_fake_payload text;
  v_fake_sig   text;
  v_xid_plus1  text;
BEGIN
  BEGIN
    -- two accounts, two customers with ACTIVE sign-ins, one customer with none
    INSERT INTO guardops.account (name) VALUES ('proof-0071-a') RETURNING id INTO v_acct1_id;
    INSERT INTO guardops.account (name) VALUES ('proof-0071-b') RETURNING id INTO v_acct2_id;

    INSERT INTO guardops.customer (account_id, external_id)
      VALUES (v_acct1_id, 'proof-0071-ext-1') RETURNING id INTO v_cust1_id;
    INSERT INTO guardops.customer (account_id, external_id)
      VALUES (v_acct2_id, 'proof-0071-ext-2') RETURNING id INTO v_cust2_id;
    INSERT INTO guardops.customer (account_id, external_id)
      VALUES (v_acct1_id, 'proof-0071-ext-3') RETURNING id INTO v_cust_no_id;

    INSERT INTO guardops.connected_account
      (account_id, customer_id, token_secret_name, status)
    VALUES (v_acct1_id, v_cust1_id, 'proof-0071-tok-1', 'ACTIVE');
    INSERT INTO guardops.connected_account
      (account_id, customer_id, token_secret_name, status)
    VALUES (v_acct2_id, v_cust2_id, 'proof-0071-tok-2', 'ACTIVE');
    INSERT INTO guardops.connected_account
      (account_id, customer_id, token_secret_name, status)
    VALUES (v_acct1_id, v_cust_no_id, 'proof-0071-tok-3', 'INACTIVE');

    -- check 1: house 1 signs in and reads back its own account
    v_got := guardops.act_as_house(v_cust1_id);
    ASSERT v_got = v_acct1_id,
      'check 1a: act_as_house returned ' || v_got || ' want ' || v_acct1_id;
    v_got := guardops.current_account();
    ASSERT v_got = v_acct1_id,
      'check 1b: current_account returned ' || v_got || ' want ' || v_acct1_id;

    -- check 2: house 2 signs in and reads back its own account
    v_got := guardops.act_as_house(v_cust2_id);
    ASSERT v_got = v_acct2_id,
      'check 2a: act_as_house returned ' || v_got || ' want ' || v_acct2_id;
    v_got := guardops.current_account();
    ASSERT v_got = v_acct2_id,
      'check 2b: current_account returned ' || v_got || ' want ' || v_acct2_id;

    -- check 3: customer with no ACTIVE sign-in raises
    v_ok := false;
    BEGIN
      PERFORM guardops.act_as_house(v_cust_no_id);
    EXCEPTION WHEN OTHERS THEN
      ASSERT sqlerrm LIKE '%NO HOUSE%',
        'check 3: wrong error "' || sqlerrm || '"';
      v_ok := true;
    END;
    ASSERT v_ok, 'check 3: act_as_house(no-active) should have raised';

    -- check 4: non-existent customer raises
    v_ok := false;
    BEGIN
      PERFORM guardops.act_as_house(-99999);
    EXCEPTION WHEN OTHERS THEN
      ASSERT sqlerrm LIKE '%NO HOUSE%',
        'check 4: wrong error "' || sqlerrm || '"';
      v_ok := true;
    END;
    ASSERT v_ok, 'check 4: act_as_house(-99999) should have raised';

    -- check 5: current_account() with nothing set raises with readable message
    PERFORM pg_catalog.set_config('guardops.house', '', true);
    v_ok := false;
    BEGIN
      PERFORM guardops.current_account();
    EXCEPTION WHEN OTHERS THEN
      ASSERT sqlerrm LIKE '%NO HOUSE%',
        'check 5: wrong error "' || sqlerrm || '"';
      v_ok := true;
    END;
    ASSERT v_ok, 'check 5: current_account() on empty GUC should have raised';

    -- check 6: hand-written set_config is refused
    -- uses a real-looking account id and 64 valid hex chars; hmac will not match
    PERFORM pg_catalog.set_config(
      'guardops.house',
      '2.' || pg_catalog.repeat('de', 32),
      true
    );
    v_ok := false;
    BEGIN
      PERFORM guardops.current_account();
    EXCEPTION WHEN OTHERS THEN
      ASSERT sqlerrm LIKE '%NO HOUSE%',
        'check 6: wrong error "' || sqlerrm || '"';
      v_ok := true;
    END;
    ASSERT v_ok, 'check 6: hand-forged set_config should be refused';

    -- check 7: a token signed for a different transaction is refused
    -- simulated by signing the payload with xact_id+1; current_account() rebuilds
    -- with the real xact_id, so the compare fails
    SELECT ck.secret, ck.digest INTO v_key_secret, v_key_digest
      FROM guardops.checker_key ck WHERE ck.key_id = 'active';
    v_xid_plus1    := (pg_catalog.pg_current_xact_id()::text::bigint + 1)::text;
    v_fake_payload := v_acct1_id::text || ':' || session_user || ':' || v_xid_plus1;
    v_fake_sig     := pg_catalog.encode(
                        extensions.hmac(pg_catalog.convert_to(v_fake_payload, 'UTF8'),
                                        v_key_secret, v_key_digest),
                        'hex');
    PERFORM pg_catalog.set_config(
      'guardops.house',
      v_acct1_id::text || '.' || v_fake_sig,
      true
    );
    v_ok := false;
    BEGIN
      PERFORM guardops.current_account();
    EXCEPTION WHEN OTHERS THEN
      ASSERT sqlerrm LIKE '%NO HOUSE%',
        'check 7: wrong error "' || sqlerrm || '"';
      v_ok := true;
    END;
    ASSERT v_ok, 'check 7: replay from different transaction should be refused';

    RAISE INFO 'proof/0071: all 7 checks passed';
    RAISE EXCEPTION 'proof/0071/rollback';

  EXCEPTION
    WHEN OTHERS THEN
      IF sqlerrm = 'proof/0071/rollback' THEN
        NULL; -- expected; test data rolled back by savepoint
      ELSE
        RAISE; -- assertion failure or unexpected error: propagate
      END IF;
  END;
END
$proof$;
