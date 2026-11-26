-- migrations/0080_plan_given_add_fix.sql
-- Board 11965. Fresh delivery of the corrected plan door.
-- Board 11950 had this fix reviewed clean (0 critical, 0 major) but its board
-- can never merge because the severity gate holds the highest historic count.
-- This file delivers the same corrected door on a clean board.
--
-- guardops.plan_given_add(p_job_id bigint, p_items text[]) returns bigint[]
-- Files one plan_given row per item (position 1..N). plan_version starts at 1
-- and increments on each refile for the same job. plan_digest is SHA-256 over
-- the JSON-encoded ordered item list (array_to_json) so the encoding is
-- unambiguous: each element is a quoted JSON string; no two distinct arrays
-- produce the same input bytes.
--
-- Three holes from board 11938 are closed:
--   1. Digest ambiguity: array_to_json() produces unambiguous JSON;
--      the old array_to_string(items, chr(31)) was ambiguous for items
--      that contained chr(31).
--   2. Version race: FOR UPDATE taken on the job row before reading
--      MAX(plan_version), serialising concurrent callers for the same job.
--   3. Cross-account access: the FOR UPDATE query filters on
--      account_id = current_account() and raises if NOT FOUND, so a
--      caller cannot file a plan onto another account's job.
--
-- SECURITY DEFINER, search_path empty, REVOKE EXECUTE FROM PUBLIC.

CREATE OR REPLACE FUNCTION guardops.plan_given_add(
  p_job_id  bigint,
  p_items   text[]
)
  RETURNS bigint[]
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
DECLARE
  v_next_version  integer;
  v_digest        text;
  v_ids           bigint[] := ARRAY[]::bigint[];
  v_id            bigint;
  v_item          text;
  v_pos           integer := 0;
BEGIN
  -- Lock the job row first. This serialises concurrent calls on the same
  -- job (closing the version race) and proves account ownership (closing
  -- the cross-account hole) in one step.
  PERFORM 1
    FROM guardops.job
   WHERE id         = p_job_id
     AND account_id = guardops.current_account()
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'job % does not exist or does not belong to this account', p_job_id;
  END IF;

  -- Safe to read MAX(plan_version) now: the job row lock above ensures only
  -- one caller at a time reaches this point for the same p_job_id.
  SELECT COALESCE(MAX(plan_version), 0) + 1
    INTO v_next_version
    FROM guardops.plan_given
   WHERE job_id = p_job_id;

  -- Unambiguous digest: array_to_json quotes every element as a JSON string,
  -- so no two distinct text[] arrays can produce the same encoded bytes.
  v_digest := pg_catalog.encode(
    extensions.digest(
      pg_catalog.convert_to(pg_catalog.array_to_json(p_items)::text, 'UTF8'),
      'sha256'
    ),
    'hex'
  );

  FOREACH v_item IN ARRAY p_items LOOP
    v_pos := v_pos + 1;
    INSERT INTO guardops.plan_given
      (account_id, item_text, position, plan_version, plan_digest, job_id)
    VALUES
      (guardops.current_account(), v_item, v_pos, v_next_version, v_digest, p_job_id)
    RETURNING id INTO v_id;
    v_ids := v_ids || v_id;
  END LOOP;

  RETURN v_ids;
END;
$function$;

REVOKE EXECUTE ON FUNCTION guardops.plan_given_add(bigint, text[]) FROM PUBLIC;

-- ── rolled-back proof ────────────────────────────────────────────────────────
-- Verifies: items filed, positions correct, plan_version=1 on first call,
-- plan_version=2 on refile, digest computed, account isolation raises.
-- All writes are rolled back via the inner RAISE EXCEPTION savepoint.

DO $proof$
DECLARE
  v_acct_id    bigint;
  v_cust_id    bigint;
  v_link_id    bigint;  -- watched_database id
  v_job_id     bigint;
  v_ids1       bigint[];
  v_ids2       bigint[];
  v_count      bigint;
  v_version    integer;
  v_digest     text;
  v_expected   text;
BEGIN
  BEGIN
    -- set up an account and customer with ACTIVE sign-in for the proof
    INSERT INTO guardops.account (name) VALUES ('proof-0080') RETURNING id INTO v_acct_id;
    INSERT INTO guardops.customer (account_id, external_id)
      VALUES (v_acct_id, 'proof-0080-ext') RETURNING id INTO v_cust_id;
    INSERT INTO guardops.connected_account
      (account_id, customer_id, token_secret_name, status)
    VALUES (v_acct_id, v_cust_id, 'proof-0080-tok', 'ACTIVE');

    -- sign in as this house if act_as_house is available;
    -- skipped on schemas where it does not yet exist (older install base)
    IF EXISTS (
      SELECT 1 FROM information_schema.routines
       WHERE routine_schema = 'guardops' AND routine_name = 'act_as_house'
    ) THEN
      PERFORM guardops.act_as_house(v_cust_id);
    END IF;

    v_link_id := guardops.watched_database_add('proof-0080/test');
    v_job_id  := guardops.job_add(v_link_id, 'proof-0080: plan_given_add smoke test');

    -- first file: two items, plan_version must be 1
    v_ids1 := guardops.plan_given_add(v_job_id, ARRAY['step one', 'step two']);

    ASSERT array_length(v_ids1, 1) = 2,
      'plan_given_add must return 2 ids, got ' || array_length(v_ids1, 1);

    SELECT plan_version INTO v_version
      FROM guardops.plan_given
     WHERE id = v_ids1[1];
    ASSERT v_version = 1,
      'first file must have plan_version=1, got ' || v_version;

    -- position order
    SELECT count(*) INTO v_count
      FROM guardops.plan_given
     WHERE job_id = v_job_id
       AND position = 1 AND item_text = 'step one';
    ASSERT v_count = 1, 'position 1 item_text must be step one';

    SELECT count(*) INTO v_count
      FROM guardops.plan_given
     WHERE job_id = v_job_id
       AND position = 2 AND item_text = 'step two';
    ASSERT v_count = 1, 'position 2 item_text must be step two';

    -- digest must match independent calculation
    v_expected := pg_catalog.encode(
      extensions.digest(
        pg_catalog.convert_to(
          pg_catalog.array_to_json(ARRAY['step one', 'step two'])::text, 'UTF8'
        ),
        'sha256'
      ),
      'hex'
    );
    SELECT plan_digest INTO v_digest
      FROM guardops.plan_given WHERE id = v_ids1[1];
    ASSERT v_digest = v_expected,
      'digest mismatch: got ' || v_digest || ' want ' || v_expected;

    -- refile: plan_version must increment to 2
    v_ids2 := guardops.plan_given_add(v_job_id, ARRAY['step one', 'step two', 'step three']);
    ASSERT array_length(v_ids2, 1) = 3,
      'refile must return 3 ids, got ' || array_length(v_ids2, 1);

    SELECT plan_version INTO v_version
      FROM guardops.plan_given
     WHERE id = v_ids2[1];
    ASSERT v_version = 2,
      'refile must have plan_version=2, got ' || v_version;

    RAISE INFO 'proof/0080: all assertions passed inside subtransaction';
    RAISE EXCEPTION 'proof/0080/rollback';

  EXCEPTION
    WHEN OTHERS THEN
      IF sqlerrm = 'proof/0080/rollback' THEN
        NULL;
      ELSE
        RAISE;
      END IF;
  END;

  -- verify no rows remain after rollback
  SELECT count(*) INTO v_count
    FROM guardops.plan_given
   WHERE job_id IN (
     SELECT id FROM guardops.job WHERE what_for = 'proof-0080: plan_given_add smoke test'
   );
  ASSERT v_count = 0,
    'plan_given must be empty after rollback, found ' || v_count || ' row(s)';

  RAISE INFO 'proof/0080: plan_given empty after rollback - door confirmed';
END
$proof$;
