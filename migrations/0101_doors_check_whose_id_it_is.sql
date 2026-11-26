-- migrations/0101_doors_check_whose_id_it_is.sql
-- Hole 870: twenty doors take an id and never ask whose it is. This closes the
-- ones that can actually be reached with someone else's id, and records why the
-- rest are not urgent.
--
-- WHAT THE SWEEP FOUND, and what it means door by door.
--
-- ALREADY CLOSED by 0100: act_as_house refuses a browser caller acting as
-- another customer. verdict_for_customer's only job is to call act_as_house and
-- then read the verdict, so a browser caller handing it someone else's customer
-- id is already refused inside act_as_house. It is hardened here anyway, so it
-- does not depend on a door two levels down staying correct.
--
-- CLOSED HERE: connected_account_add and is_theirs. Both take a customer id
-- outright and both are plausibly callable directly.
--
-- NOT CLOSED HERE, and why: live_signin, live_signin_behind,
-- live_signin_of_customer, signin_group_lock, signin_retire_others,
-- signin_dead, commit_object_build, shape_take_signed, shape_sweep,
-- shape_ask_signed, signed_call, shape_judge, house_make and
-- house_from_signin. These are internal plumbing - each is called by another
-- door that has already established the account, several run only on Supabase
-- because they need net._http_response, and house_make and house_from_signin
-- are the sign-up path and cannot require an account that does not exist yet.
-- None of them is granted to a browser role and job 5 opens only three doors,
-- so none is reachable with a stranger's id. Bolting a uniform check onto the
-- picture pipeline and the sign-in chain tonight would risk breaking both for
-- no gain. They are named in floor/OPEN.md as one sweep, to be done before any
-- further door is ever opened to a browser.

-- ── verdict_for_customer: take the customer from whoever is signed in ───────
CREATE OR REPLACE FUNCTION guardops.verdict_for_customer(
    p_customer bigint,
    p_job_id   bigint
)
  RETURNS TABLE(kind text, what text, proof text)
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
DECLARE
  v_account bigint;
BEGIN
  -- act_as_house already refuses a browser caller asking to be someone else
  -- (0100). This does not lean on that: it checks here too, so the door is not
  -- one change away from being open again.
  PERFORM guardops.act_as_house(p_customer);

  SELECT c.account_id INTO v_account
    FROM guardops.customer c
   WHERE c.id = p_customer;

  IF v_account IS DISTINCT FROM guardops.current_account() THEN
    RAISE EXCEPTION
      '[NOT YOURS] customer % does not belong to the signed-in account', p_customer;
  END IF;

  RETURN QUERY SELECT * FROM guardops.job_verdict(p_job_id);
END;
$function$;

REVOKE EXECUTE ON FUNCTION guardops.verdict_for_customer(bigint, bigint) FROM PUBLIC;

-- ── connected_account_add: the customer must be the caller's own ────────────
CREATE OR REPLACE FUNCTION guardops.connected_account_add(
    p_customer_id      bigint,
    p_provider         text,
    p_org_slug         text,
    p_token_secret_name text
)
  RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
DECLARE
  v_account_id bigint;
  v_id         bigint;
BEGIN
  SELECT account_id INTO v_account_id
    FROM guardops.customer WHERE id = p_customer_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'connected_account_add: customer % does not exist', p_customer_id;
  END IF;

  -- hole 870: it used to attach a connection to ANY customer it was handed.
  -- Only when somebody is signed in is there an account to compare against;
  -- the sign-up path runs before that and is left alone.
  IF guardops.current_account_or_null() IS NOT NULL
     AND v_account_id IS DISTINCT FROM guardops.current_account_or_null() THEN
    RAISE EXCEPTION
      '[NOT YOURS] customer % does not belong to the signed-in account', p_customer_id;
  END IF;

  INSERT INTO guardops.connected_account
    (account_id, customer_id, provider, org_slug, token_secret_name, status, approved_at)
  VALUES
    (v_account_id, p_customer_id, p_provider, p_org_slug, p_token_secret_name, 'ACTIVE', pg_catalog.now())
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$function$;

REVOKE EXECUTE ON FUNCTION guardops.connected_account_add(bigint, text, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION guardops.connected_account_add(bigint, text, text, text) FROM anon;
REVOKE EXECUTE ON FUNCTION guardops.connected_account_add(bigint, text, text, text) FROM authenticated;
GRANT  EXECUTE ON FUNCTION guardops.connected_account_add(bigint, text, text, text) TO service_role;

-- ── is_theirs: answer only about the caller's own account ──────────────────
CREATE OR REPLACE FUNCTION guardops.is_theirs(
    p_customer    bigint,
    p_database_id bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
  -- hole 870: it used to answer about any customer. It now answers only within
  -- the signed-in account, and false when nobody is signed in.
  SELECT EXISTS (
    SELECT 1
      FROM guardops.watched_database d
      JOIN guardops.connected_account a ON a.id = d.connected_account_id
     WHERE d.id = p_database_id
       AND d.status = 'ACTIVE'
       AND a.customer_id = p_customer
       AND a.account_id = d.account_id
       AND d.account_id = guardops.current_account_or_null()
  );
$function$;

REVOKE EXECUTE ON FUNCTION guardops.is_theirs(bigint, bigint) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION guardops.is_theirs(bigint, bigint) FROM anon;
REVOKE EXECUTE ON FUNCTION guardops.is_theirs(bigint, bigint) FROM authenticated;
GRANT  EXECUTE ON FUNCTION guardops.is_theirs(bigint, bigint) TO service_role;

-- ── rolled-back proof ──────────────────────────────────────────────────────
DO $proof$
DECLARE
  v_a_acct bigint; v_a_cust bigint; v_a_db bigint;
  v_b_acct bigint; v_b_cust bigint;
  v_refused boolean;
  v_n bigint;
  v_ok boolean;
BEGIN
  BEGIN
    INSERT INTO guardops.account (name) VALUES ('proof-0101-A') RETURNING id INTO v_a_acct;
    INSERT INTO guardops.customer (account_id, external_id)
      VALUES (v_a_acct, 'proof-0101-A-sub') RETURNING id INTO v_a_cust;
    INSERT INTO guardops.connected_account
      (account_id, customer_id, token_secret_name, status)
      VALUES (v_a_acct, v_a_cust, 'proof-0101-A-tok', 'ACTIVE');

    INSERT INTO guardops.account (name) VALUES ('proof-0101-B') RETURNING id INTO v_b_acct;
    INSERT INTO guardops.customer (account_id, external_id)
      VALUES (v_b_acct, 'proof-0101-B-sub') RETURNING id INTO v_b_cust;
    INSERT INTO guardops.connected_account
      (account_id, customer_id, token_secret_name, status)
      VALUES (v_b_acct, v_b_cust, 'proof-0101-B-tok', 'ACTIVE');

    PERFORM guardops.act_as_house(v_a_cust);
    v_a_db := guardops.watched_database_add('proof-0101-A-db');
    -- watched_database_add does not pin the row to a connection, and is_theirs
    -- answers through that pin, so the proof sets it the way a real register does.
    UPDATE guardops.watched_database d
       SET connected_account_id = (SELECT ca.id FROM guardops.connected_account ca
                                    WHERE ca.customer_id = v_a_cust
                                    ORDER BY ca.id LIMIT 1)
     WHERE d.id = v_a_db;

    -- (1) A asking about A's own database: true
    v_ok := guardops.is_theirs(v_a_cust, v_a_db);
    ASSERT v_ok, 'A must see its own database as theirs';

    -- (2) A asking about B's customer against A's database: false
    v_ok := guardops.is_theirs(v_b_cust, v_a_db);
    ASSERT NOT v_ok, 'is_theirs must not answer true for another account''s customer';

    -- (3) signed in as A, attaching a connection to B's customer: refused
    v_refused := false;
    BEGIN
      PERFORM guardops.connected_account_add(v_b_cust, 'supabase', NULL, 'proof-0101-steal-tok');
    EXCEPTION WHEN OTHERS THEN
      v_refused := true;
    END;
    ASSERT v_refused,
      'connected_account_add must refuse a customer outside the signed-in account';

    -- (4) signed in as A, attaching to A's own customer: allowed
    SELECT guardops.connected_account_add(v_a_cust, 'supabase', NULL, 'proof-0101-ok-tok') INTO v_n;
    ASSERT v_n IS NOT NULL, 'connected_account_add must still work for your own customer';

    -- (5) signed in as A, asking for B's verdict: refused
    v_refused := false;
    BEGIN
      PERFORM * FROM guardops.verdict_for_customer(v_b_cust, 1);
    EXCEPTION WHEN OTHERS THEN
      v_refused := true;
    END;
    ASSERT v_refused,
      'verdict_for_customer must refuse a customer outside the signed-in account';

    RAISE INFO 'proof/0101: is_theirs scoped, connected_account_add refuses another account''s customer, verdict_for_customer refuses another account''s customer';
    RAISE EXCEPTION 'proof/0101/rollback';

  EXCEPTION WHEN OTHERS THEN
    IF sqlerrm = 'proof/0101/rollback' THEN
      NULL;
    ELSE
      RAISE;
    END IF;
  END;

  SELECT count(*) INTO v_n FROM guardops.account WHERE name LIKE 'proof-0101%';
  ASSERT v_n = 0, 'nothing may be left after rollback, found ' || v_n;
  RAISE INFO 'proof/0101: nothing left behind';
END
$proof$;
