-- migrations/0098_the_wall.sql
-- Job 2 of the wall. Plan cold-read on board 12114: FOR ALL with matching USING
-- and WITH CHECK is right, no table needs a SELECT/write split, and every door
-- is SECURITY DEFINER owned by postgres, which carries BYPASSRLS, so the doors
-- are untouched by this.
--
-- Until now the database itself enforced nothing: every "is this row yours"
-- check lived inside the doors, and row security was on for exactly one table
-- (checker_key, with no policy, which denies every non-bypass role). This puts
-- the check in the database.
--
-- The rule never raises: it calls current_account_or_null() from 0097, which
-- answers NULL when nobody is signed in. NULL means no rows - the safe default.
-- A rule that raised would turn every query by a signed-out caller into an
-- error, and an error leaks the shape of what is behind it.
--
-- NO TABLE GRANT IS ADDED HERE. A browser must never reach a table, only a
-- door. Today only postgres holds a table grant and that stays true.

-- ── the 17 tables keyed by account_id ────────────────────────────────────────
DO $wall$
DECLARE
  t text;
  tables text[] := ARRAY[
    'claim','commit_drift','commit_object','commit_seen','connected_account',
    'customer','customer_notice','job','plan_given','pull_commit','repo_link',
    'repo_pull','shape_change','shape_object','shape_picture',
    'watched_database','write_record'
  ];
BEGIN
  FOREACH t IN ARRAY tables LOOP
    EXECUTE format('ALTER TABLE guardops.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS own_account_only ON guardops.%I', t);
    EXECUTE format(
      'CREATE POLICY own_account_only ON guardops.%I FOR ALL'
      || ' USING (account_id = guardops.current_account_or_null())'
      || ' WITH CHECK (account_id = guardops.current_account_or_null())', t);
  END LOOP;
END
$wall$;

-- ── account: its own id IS the tenant key, there is no account_id column ─────
ALTER TABLE guardops.account ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS own_account_only ON guardops.account;
CREATE POLICY own_account_only ON guardops.account
  FOR ALL
  USING (id = guardops.current_account_or_null())
  WITH CHECK (id = guardops.current_account_or_null());

-- checker_key is deliberately left exactly as it is: row security already on,
-- zero policies, which denies every role that cannot bypass. It holds the
-- install signing secret and has no tenant at all.

-- ── rolled-back proof ────────────────────────────────────────────────────────
DO $proof$
DECLARE
  v_on      int;
  v_pol     int;
  v_missing text;
BEGIN
  -- every one of the 18 has row security on
  SELECT count(*) INTO v_on
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'guardops' AND c.relkind = 'r' AND c.relrowsecurity;
  ASSERT v_on = 19,
    'all 19 tables must have row security on (18 new plus checker_key), got ' || v_on;

  -- exactly one policy on each of the 18, and none on checker_key
  SELECT count(*) INTO v_pol FROM pg_policy p
    JOIN pg_class c ON c.oid = p.polrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'guardops';
  ASSERT v_pol = 18,
    'there must be exactly 18 policies, one per tenant table, got ' || v_pol;

  SELECT count(*) INTO v_pol FROM pg_policy p
    JOIN pg_class c ON c.oid = p.polrelid
   WHERE c.relname = 'checker_key';
  ASSERT v_pol = 0, 'checker_key must still carry no policy, got ' || v_pol;

  -- no table in guardops has been granted to anyone but postgres
  SELECT string_agg(DISTINCT grantee, ', ') INTO v_missing
    FROM information_schema.role_table_grants
   WHERE table_schema = 'guardops' AND grantee <> 'postgres';
  ASSERT v_missing IS NULL,
    'no role but postgres may hold a table grant, found: ' || COALESCE(v_missing,'');

  RAISE INFO 'proof/0098: 18 tenant tables walled, one policy each, checker_key still closed, no table granted to anyone but postgres';
END
$proof$;
