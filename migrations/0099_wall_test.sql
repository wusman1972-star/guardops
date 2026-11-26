-- migrations/0099_wall_test.sql
-- Job 3 of the wall: the test that makes the wall believable.
--
-- The wall is only worth anything if a second customer actually cannot read the
-- first one's rows. This runs that, as a numbered pass sheet in the same shape
-- as one_run_test, and rolls everything back.
--
-- Four corrections from review are built into this, and each one is here because
-- without it the test would come out green for the wrong reason:
--   * A row is written into EVERY table under test, as customer A, and asserted
--     visible to A FIRST. A zero count against an empty table proves nothing.
--   * The reading is done by a throwaway role with no BYPASSRLS, not by postgres
--     and not by authenticated, whose grants are whatever Supabase gave it.
--   * That role is granted USAGE on the schema and EXECUTE on
--     current_account_or_null before the reads, because a policy expression is
--     evaluated as the querying role - without them the query fails on the
--     policy itself, which is a permission error dressed up as a pass.
--   * The owner check at the end is run as that same no-bypass role too. Run as
--     postgres it bypasses the wall and proves nothing.
--
-- The sign-in is transaction-local and its signature binds session_user, not
-- current_user, so a sign-in survives SET LOCAL ROLE. That is what lets the same
-- role read as A at the end and as B in the middle.

CREATE OR REPLACE FUNCTION guardops.wall_test()
  RETURNS TABLE(step integer, what text, got text, want text, pass boolean)
  LANGUAGE plpgsql
  -- SECURITY INVOKER on purpose: Postgres refuses SET LOCAL ROLE inside a
  -- security-definer function, and this test has to become another role to
  -- prove the wall bites. It is granted to service_role only.
  SET search_path TO ''
AS $function$
DECLARE
  v_a_acct  bigint;
  v_a_cust  bigint;
  v_b_acct  bigint;
  v_b_cust  bigint;
  v_db      bigint;
  v_repo    bigint;
  v_job     bigint;
  v_seen    bigint;
  v_refused boolean;
BEGIN
  BEGIN
    -- ── customer A, with a row in every table this test reads ───────────────
    INSERT INTO guardops.account (name) VALUES ('wall_test_A') RETURNING id INTO v_a_acct;
    INSERT INTO guardops.customer (account_id, external_id)
      VALUES (v_a_acct, 'wall_test_A_ext') RETURNING id INTO v_a_cust;
    INSERT INTO guardops.connected_account
      (account_id, customer_id, token_secret_name, status)
      VALUES (v_a_acct, v_a_cust, 'wall_test_A_tok', 'ACTIVE');
    PERFORM guardops.act_as_house(v_a_cust);

    v_db   := guardops.watched_database_add('wall_test_A_db');
    v_repo := guardops.repo_link_add('walltest-a/repo', 'main');
    v_job  := guardops.job_add(v_repo, 'wall_test_A job');
    PERFORM guardops.plan_given_add(v_job, ARRAY['wall_test_A plan item']);

    -- step 1: A can see its own rows. If this fails nothing below means anything.
    SELECT count(*) INTO v_seen FROM guardops.job         WHERE account_id = v_a_acct;
    step := 1; what := 'A sees its own job';
    got := v_seen::text || ' rows'; want := '1 rows'; pass := (v_seen = 1); RETURN NEXT;

    SELECT count(*) INTO v_seen FROM guardops.plan_given  WHERE account_id = v_a_acct;
    step := 1; what := 'A sees its own plan';
    got := v_seen::text || ' rows'; want := '1 rows'; pass := (v_seen = 1); RETURN NEXT;

    SELECT count(*) INTO v_seen FROM guardops.watched_database WHERE account_id = v_a_acct;
    step := 1; what := 'A sees its own database';
    got := v_seen::text || ' rows'; want := '1 rows'; pass := (v_seen = 1); RETURN NEXT;

    SELECT count(*) INTO v_seen FROM guardops.repo_link   WHERE account_id = v_a_acct;
    step := 1; what := 'A sees its own code link';
    got := v_seen::text || ' rows'; want := '1 rows'; pass := (v_seen = 1); RETURN NEXT;

    -- ── a reader with no bypass of its own ──────────────────────────────────
    CREATE ROLE guardops_wall_probe NOLOGIN;
    GRANT USAGE ON SCHEMA guardops TO guardops_wall_probe;
    GRANT EXECUTE ON FUNCTION guardops.current_account_or_null(boolean) TO guardops_wall_probe;
    GRANT SELECT ON guardops.job, guardops.plan_given, guardops.watched_database,
                    guardops.repo_link, guardops.account, guardops.customer
      TO guardops_wall_probe;

    step := 2; what := 'the probe role has no bypass';
    SELECT rolbypassrls INTO v_refused FROM pg_catalog.pg_roles WHERE rolname = 'guardops_wall_probe';
    got := CASE WHEN v_refused THEN 'it can bypass' ELSE 'it cannot bypass' END;
    want := 'it cannot bypass'; pass := (v_refused = false); RETURN NEXT;

    -- ── customer B signs in, and reads as that role ─────────────────────────
    INSERT INTO guardops.account (name) VALUES ('wall_test_B') RETURNING id INTO v_b_acct;
    INSERT INTO guardops.customer (account_id, external_id)
      VALUES (v_b_acct, 'wall_test_B_ext') RETURNING id INTO v_b_cust;
    INSERT INTO guardops.connected_account
      (account_id, customer_id, token_secret_name, status)
      VALUES (v_b_acct, v_b_cust, 'wall_test_B_tok', 'ACTIVE');
    PERFORM guardops.act_as_house(v_b_cust);

    SET LOCAL ROLE guardops_wall_probe;

    SELECT count(*) INTO v_seen FROM guardops.job         WHERE account_id = v_a_acct;
    step := 3; what := 'B reads A''s job';
    got := v_seen::text || ' rows'; want := '0 rows'; pass := (v_seen = 0); RETURN NEXT;

    SELECT count(*) INTO v_seen FROM guardops.plan_given  WHERE account_id = v_a_acct;
    step := 3; what := 'B reads A''s plan';
    got := v_seen::text || ' rows'; want := '0 rows'; pass := (v_seen = 0); RETURN NEXT;

    SELECT count(*) INTO v_seen FROM guardops.watched_database WHERE account_id = v_a_acct;
    step := 3; what := 'B reads A''s database';
    got := v_seen::text || ' rows'; want := '0 rows'; pass := (v_seen = 0); RETURN NEXT;

    SELECT count(*) INTO v_seen FROM guardops.repo_link   WHERE account_id = v_a_acct;
    step := 3; what := 'B reads A''s code link';
    got := v_seen::text || ' rows'; want := '0 rows'; pass := (v_seen = 0); RETURN NEXT;

    SELECT count(*) INTO v_seen FROM guardops.account     WHERE id = v_a_acct;
    step := 3; what := 'B reads A''s account row';
    got := v_seen::text || ' rows'; want := '0 rows'; pass := (v_seen = 0); RETURN NEXT;

    SELECT count(*) INTO v_seen FROM guardops.customer    WHERE account_id = v_a_acct;
    step := 3; what := 'B reads A''s customer row';
    got := v_seen::text || ' rows'; want := '0 rows'; pass := (v_seen = 0); RETURN NEXT;

    -- ── the owner is not locked out, read by the same no-bypass role ────────
    RESET ROLE;
    PERFORM guardops.act_as_house(v_a_cust);
    SET LOCAL ROLE guardops_wall_probe;

    SELECT count(*) INTO v_seen FROM guardops.job WHERE account_id = v_a_acct;
    step := 4; what := 'A still sees its own job';
    got := v_seen::text || ' rows'; want := '1 rows'; pass := (v_seen = 1); RETURN NEXT;

    SELECT count(*) INTO v_seen FROM guardops.plan_given WHERE account_id = v_a_acct;
    step := 4; what := 'A still sees its own plan';
    got := v_seen::text || ' rows'; want := '1 rows'; pass := (v_seen = 1); RETURN NEXT;

    SELECT count(*) INTO v_seen FROM guardops.watched_database WHERE account_id = v_a_acct;
    step := 4; what := 'A still sees its own database';
    got := v_seen::text || ' rows'; want := '1 rows'; pass := (v_seen = 1); RETURN NEXT;

    SELECT count(*) INTO v_seen FROM guardops.repo_link WHERE account_id = v_a_acct;
    step := 4; what := 'A still sees its own code link';
    got := v_seen::text || ' rows'; want := '1 rows'; pass := (v_seen = 1); RETURN NEXT;

    SELECT count(*) INTO v_seen FROM guardops.account WHERE id = v_a_acct;
    step := 4; what := 'A still sees its own account row';
    got := v_seen::text || ' rows'; want := '1 rows'; pass := (v_seen = 1); RETURN NEXT;

    SELECT count(*) INTO v_seen FROM guardops.customer WHERE account_id = v_a_acct;
    step := 4; what := 'A still sees its own customer row';
    got := v_seen::text || ' rows'; want := '1 rows'; pass := (v_seen = 1); RETURN NEXT;

    -- ── and with no grant at all it is refused outright ─────────────────────
    RESET ROLE;
    REVOKE SELECT ON guardops.job, guardops.plan_given, guardops.watched_database,
                     guardops.repo_link, guardops.account, guardops.customer
      FROM guardops_wall_probe;
    REVOKE EXECUTE ON FUNCTION guardops.current_account_or_null(boolean) FROM guardops_wall_probe;
    REVOKE USAGE ON SCHEMA guardops FROM guardops_wall_probe;

    SET LOCAL ROLE guardops_wall_probe;
    v_refused := false;
    BEGIN
      PERFORM 1 FROM guardops.job LIMIT 1;
    EXCEPTION WHEN OTHERS THEN
      v_refused := true;
    END;
    RESET ROLE;

    step := 5; what := 'with no grant the table is refused outright';
    got := CASE WHEN v_refused THEN 'refused' ELSE 'it could still read' END;
    want := 'refused'; pass := v_refused; RETURN NEXT;

    RAISE EXCEPTION 'wall_test_rollback';

  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'wall_test_rollback' THEN
      RAISE;
    END IF;
  END;
END;
$function$;

-- 26 Nov, review finding: this is NOT granted to service_role. It is SECURITY
-- INVOKER, and it has to CREATE ROLE and GRANT on tables to prove anything, so
-- it needs owner-level rights the service key does not have and should not be
-- given. Granting it to service_role would hand out a function the service key
-- can never finish. It is an install-time and audit-time proof, run by the
-- database owner - which is exactly who runs the install.
REVOKE EXECUTE ON FUNCTION guardops.wall_test() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION guardops.wall_test() FROM anon;
REVOKE EXECUTE ON FUNCTION guardops.wall_test() FROM authenticated;
