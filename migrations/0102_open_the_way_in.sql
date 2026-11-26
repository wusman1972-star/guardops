-- migrations/0102_open_the_way_in.sql
-- Job 5, the last of the wall: let a browser reach exactly three doors.
--
-- Until now nothing outside this database could reach anything at all: anon and
-- authenticated held no USAGE on the schema and EXECUTE on none of the doors,
-- which is why the sign-up screens had nothing to talk to.
--
-- USAGE ON SCHEMA IS NOT OPTIONAL. Measured on 26 Nov: service_role holds
-- EXECUTE on all 50 doors by ACL and still cannot call one, because it has no
-- USAGE on guardops and the call fails at the schema gate before the function
-- ACL is ever consulted. Granting EXECUTE alone would have looked like opening
-- the way in and changed nothing.
--
-- THREE DOORS, AND NO TABLE, EVER. A browser reaches a door or nothing. No
-- table grant is made here and none should ever be: the wall in 0098 is the
-- second line, not the first.
--
-- This is safe to do only because of what landed before it:
--   0097 the rules can ask who is signed in without raising
--   0098 every tenant table is walled by account
--   0099 a second customer provably reads zero of the first's rows
--   0100 act_as_house refuses a browser caller acting as someone else
--   0101 verdict_for_customer checks the customer is the caller's own

GRANT USAGE ON SCHEMA guardops TO authenticated;

GRANT EXECUTE ON FUNCTION guardops.house_from_signin(text, text, text)   TO authenticated;
GRANT EXECUTE ON FUNCTION guardops.job_verdict(bigint)                   TO authenticated;
GRANT EXECUTE ON FUNCTION guardops.verdict_for_customer(bigint, bigint)  TO authenticated;

-- anon stays shut out entirely: no USAGE, no EXECUTE, nothing.
REVOKE USAGE ON SCHEMA guardops FROM anon;

-- ── rolled-back proof ──────────────────────────────────────────────────────
DO $proof$
DECLARE
  v_acct bigint; v_cust bigint;
  v_n bigint; v_refused boolean; v_why text;
BEGIN
  BEGIN
    INSERT INTO guardops.account (name) VALUES ('proof-0102') RETURNING id INTO v_acct;
    INSERT INTO guardops.customer (account_id, external_id)
      VALUES (v_acct, 'proof-0102-sub') RETURNING id INTO v_cust;
    INSERT INTO guardops.connected_account
      (account_id, customer_id, token_secret_name, status)
      VALUES (v_acct, v_cust, 'proof-0102-tok', 'ACTIVE');

    PERFORM pg_catalog.set_config('request.jwt.claims',
      '{"sub":"proof-0102-sub","role":"authenticated"}', true);

    -- (1) the browser role can now reach the schema at all
    SET LOCAL ROLE authenticated;
    v_refused := false;
    BEGIN
      PERFORM guardops.current_account_or_null();
    EXCEPTION WHEN OTHERS THEN
      v_refused := true;
    END;
    RESET ROLE;
    ASSERT v_refused,
      'current_account_or_null is NOT one of the three doors and must still be refused';

    -- (2) a browser caller can sign themselves in through the way-in door
    SET LOCAL ROLE authenticated;
    v_refused := false;
    BEGIN
      PERFORM guardops.house_from_signin('proof-0102', 'proof-0102-sub', NULL);
    EXCEPTION WHEN OTHERS THEN
      v_refused := true; v_why := SQLERRM;
    END;
    RESET ROLE;
    ASSERT NOT v_refused,
      'the way-in door must be reachable by a browser caller, got: ' || COALESCE(v_why,'');

    -- (3) a door that was NOT opened is still refused
    SET LOCAL ROLE authenticated;
    v_refused := false;
    BEGIN
      PERFORM guardops.watched_database_add('proof-0102-db');
    EXCEPTION WHEN OTHERS THEN
      v_refused := true;
    END;
    RESET ROLE;
    ASSERT v_refused,
      'watched_database_add was not opened and must still be refused to a browser';

    -- (4) a table is still refused outright - USAGE is not permission to read
    SET LOCAL ROLE authenticated;
    v_refused := false;
    BEGIN
      PERFORM 1 FROM guardops.job LIMIT 1;
    EXCEPTION WHEN OTHERS THEN
      v_refused := true;
    END;
    RESET ROLE;
    ASSERT v_refused,
      'no table may be reachable by a browser; USAGE on the schema is not a read';

    -- (5) anon reaches nothing at all
    SET LOCAL ROLE anon;
    v_refused := false;
    BEGIN
      PERFORM guardops.house_from_signin('proof-0102', 'proof-0102-sub', NULL);
    EXCEPTION WHEN OTHERS THEN
      v_refused := true;
    END;
    RESET ROLE;
    ASSERT v_refused, 'anon must reach nothing at all';

    PERFORM pg_catalog.set_config('request.jwt.claims', '', true);
    RAISE INFO 'proof/0102: the three doors are open to a browser, everything else is shut, and anon reaches nothing';
    RAISE EXCEPTION 'proof/0102/rollback';

  EXCEPTION WHEN OTHERS THEN
    IF sqlerrm = 'proof/0102/rollback' THEN
      NULL;
    ELSE
      RAISE;
    END IF;
  END;

  SELECT count(*) INTO v_n FROM guardops.account WHERE name = 'proof-0102';
  ASSERT v_n = 0, 'nothing may be left after rollback, found ' || v_n;
  RAISE INFO 'proof/0102: nothing left behind';
END
$proof$;
