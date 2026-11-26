-- migrations/0100_act_as_house_binds_the_caller.sql
-- Job 4 of the wall: the door must stop believing whoever calls it.
--
-- THE HOLE. act_as_house(p_customer) signs in as whatever customer id it is
-- handed. It checks the customer exists and has an ACTIVE sign-in, and nothing
-- else. verdict_for_customer(p_customer, p_job_id) calls it with its own
-- argument. Both are SECURITY DEFINER, so the wall from 0098 does not touch
-- them. The moment a browser role can execute either, any signed-in person
-- could pass any customer id and read that customer's jobs. Found by the cold
-- read of the plan (board 12114) before job 5 opened the way in.
--
-- THE FIX. When the caller is a browser-side role, act_as_house must prove the
-- signed-in person IS that customer, by matching the JWT subject against the
-- customer's external_id. When the caller is not browser-side - the install,
-- the doors, both self-tests, every migration proof - nothing changes.
--
-- Two review corrections are built in:
--   * It does NOT read auth.uid(). That is a Supabase function and does not
--     exist on plain PostgreSQL, which is where every job here is proved, so
--     the proof could never have run. It reads the session setting Supabase
--     itself populates, request.jwt.claim.sub, with missing_ok true.
--   * The trusted path is kept whole. The check fires only when there IS a JWT
--     subject present, which is exactly the browser case. No JWT, no new check.

CREATE OR REPLACE FUNCTION guardops.act_as_house(p_customer bigint)
  RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
DECLARE
  v_account_id bigint;
  v_external   text;
  v_subject    text;
  v_secret     bytea;
  v_digest     text;
  v_payload    text;
  v_sig        bytea;
  v_hex_sig    text;
BEGIN
  SELECT c.account_id, c.external_id INTO v_account_id, v_external
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

  -- The caller is browser-side exactly when a JWT subject is present. Supabase
  -- sets request.jwt.claim.sub on every call made with a user's token. The
  -- install, the doors and the tests carry none, and are unaffected.
  v_subject := pg_catalog.current_setting('request.jwt.claim.sub', true);
  IF v_subject IS NOT NULL AND v_subject <> '' THEN
    IF v_external IS NULL OR v_external <> v_subject THEN
      RAISE EXCEPTION
        '[NO HOUSE] the signed-in person is not customer % - a caller may only act as themselves',
        p_customer;
    END IF;
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

-- ── rolled-back proof ────────────────────────────────────────────────────────
DO $proof$
DECLARE
  v_a_acct bigint; v_a_cust bigint;
  v_b_acct bigint; v_b_cust bigint;
  v_got     bigint;
  v_refused boolean;
  v_msg     text;
BEGIN
  BEGIN
    INSERT INTO guardops.account (name) VALUES ('proof-0100-A') RETURNING id INTO v_a_acct;
    INSERT INTO guardops.customer (account_id, external_id)
      VALUES (v_a_acct, 'proof-0100-A-sub') RETURNING id INTO v_a_cust;
    INSERT INTO guardops.connected_account
      (account_id, customer_id, token_secret_name, status)
      VALUES (v_a_acct, v_a_cust, 'proof-0100-A-tok', 'ACTIVE');

    INSERT INTO guardops.account (name) VALUES ('proof-0100-B') RETURNING id INTO v_b_acct;
    INSERT INTO guardops.customer (account_id, external_id)
      VALUES (v_b_acct, 'proof-0100-B-sub') RETURNING id INTO v_b_cust;
    INSERT INTO guardops.connected_account
      (account_id, customer_id, token_secret_name, status)
      VALUES (v_b_acct, v_b_cust, 'proof-0100-B-tok', 'ACTIVE');

    -- (1) the trusted path: no JWT at all, nothing changes
    PERFORM pg_catalog.set_config('request.jwt.claim.sub', '', true);
    v_got := guardops.act_as_house(v_a_cust);
    ASSERT v_got = v_a_acct,
      'with no JWT the door must still work, wanted ' || v_a_acct || ' got ' || COALESCE(v_got::text,'<null>');

    -- (2) a browser caller acting as themselves: allowed
    PERFORM pg_catalog.set_config('request.jwt.claim.sub', 'proof-0100-A-sub', true);
    v_got := guardops.act_as_house(v_a_cust);
    ASSERT v_got = v_a_acct,
      'a caller acting as themselves must be allowed, got ' || COALESCE(v_got::text,'<null>');

    -- (3) THE HOLE: a browser caller asking to be someone else: refused
    PERFORM pg_catalog.set_config('request.jwt.claim.sub', 'proof-0100-A-sub', true);
    v_refused := false;
    BEGIN
      PERFORM guardops.act_as_house(v_b_cust);
    EXCEPTION WHEN OTHERS THEN
      v_refused := true; v_msg := SQLERRM;
    END;
    ASSERT v_refused,
      'a caller asking to act as another customer MUST be refused';
    ASSERT v_msg LIKE '%may only act as themselves%',
      'the refusal must say why, got: ' || COALESCE(v_msg,'<null>');

    -- (4) a browser caller with a subject that matches nobody: refused
    PERFORM pg_catalog.set_config('request.jwt.claim.sub', 'proof-0100-nobody', true);
    v_refused := false;
    BEGIN
      PERFORM guardops.act_as_house(v_a_cust);
    EXCEPTION WHEN OTHERS THEN
      v_refused := true;
    END;
    ASSERT v_refused, 'an unknown JWT subject must be refused';

    PERFORM pg_catalog.set_config('request.jwt.claim.sub', '', true);
    RAISE INFO 'proof/0100: no JWT still works, self allowed, acting as another customer refused, unknown subject refused';
    RAISE EXCEPTION 'proof/0100/rollback';

  EXCEPTION WHEN OTHERS THEN
    IF sqlerrm = 'proof/0100/rollback' THEN
      NULL;
    ELSE
      RAISE;
    END IF;
  END;

  SELECT count(*) INTO v_got FROM guardops.account WHERE name LIKE 'proof-0100%';
  ASSERT v_got = 0, 'nothing may be left after rollback, found ' || v_got;
  RAISE INFO 'proof/0100: nothing left behind';
END
$proof$;
