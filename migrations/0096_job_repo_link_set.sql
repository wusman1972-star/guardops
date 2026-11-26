-- migrations/0096_job_repo_link_set.sql
-- Reviewer finding three of three, 26 Nov 2026: 0089 relaxed job.repo_link_id to
-- nullable so a job can be opened before the first code link is registered, but
-- nothing could ever fill it in afterwards. Without a link, every DELIVERED line
-- in that job's verdict reads 'no commit record' forever.
--
-- guardops.job_repo_link_set(p_job_id, p_repo_link_id): attach a code link to a
-- job that has none. Set once, never changed, never on a closed job, and only
-- within the caller's own account.

CREATE OR REPLACE FUNCTION guardops.job_repo_link_set(
    p_job_id       bigint,
    p_repo_link_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
DECLARE
  v_existing bigint;
  v_closed   timestamptz;
BEGIN
  SELECT j.repo_link_id, j.closed_at
    INTO v_existing, v_closed
    FROM guardops.job j
   WHERE j.id = p_job_id
     AND j.account_id = guardops.current_account()
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'job % not found or does not belong to this account', p_job_id;
  END IF;

  IF v_closed IS NOT NULL THEN
    RAISE EXCEPTION 'job % is closed; its code link may not be changed', p_job_id;
  END IF;

  IF v_existing IS NOT NULL THEN
    RAISE EXCEPTION 'job % already carries code link %; a code link is set once', p_job_id, v_existing;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM guardops.repo_link rl
     WHERE rl.id = p_repo_link_id
       AND rl.account_id = guardops.current_account()
  ) THEN
    RAISE EXCEPTION 'code link % does not exist in this account', p_repo_link_id;
  END IF;

  UPDATE guardops.job SET repo_link_id = p_repo_link_id WHERE id = p_job_id;
END;
$function$;

REVOKE EXECUTE ON FUNCTION guardops.job_repo_link_set(bigint, bigint) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION guardops.job_repo_link_set(bigint, bigint) FROM anon;
REVOKE EXECUTE ON FUNCTION guardops.job_repo_link_set(bigint, bigint) FROM authenticated;
GRANT  EXECUTE ON FUNCTION guardops.job_repo_link_set(bigint, bigint) TO service_role;

-- ── rolled-back proof ────────────────────────────────────────────────────────
DO $proof$
DECLARE
  v_acct_id bigint;
  v_cust_id bigint;
  v_repo_a  bigint;
  v_job_id  bigint;
  v_got     bigint;
  v_refused boolean;
BEGIN
  BEGIN
    INSERT INTO guardops.account (name) VALUES ('proof-0096') RETURNING id INTO v_acct_id;
    INSERT INTO guardops.customer (account_id, external_id)
      VALUES (v_acct_id, 'proof-0096-ext') RETURNING id INTO v_cust_id;
    INSERT INTO guardops.connected_account
      (account_id, customer_id, token_secret_name, status)
    VALUES (v_acct_id, v_cust_id, 'proof-0096-tok', 'ACTIVE');

    IF EXISTS (
      SELECT 1 FROM information_schema.routines
       WHERE routine_schema = 'guardops' AND routine_name = 'act_as_house'
    ) THEN
      PERFORM guardops.act_as_house(v_cust_id);
    END IF;

    -- one link only: the free tier allows one repo per account, and that gate
    -- is doing its job - the proof must not fight it.
    v_repo_a := guardops.repo_link_add('proof-0096/a', 'main');

    -- a job with no code link at all
    INSERT INTO guardops.job (account_id, what_for, opened_by)
    VALUES (guardops.current_account(), 'proof-0096: linkless job', 'PROOF')
    RETURNING id INTO v_job_id;

    -- (a) the link can be attached
    PERFORM guardops.job_repo_link_set(v_job_id, v_repo_a);
    SELECT repo_link_id INTO v_got FROM guardops.job WHERE id = v_job_id;
    ASSERT v_got = v_repo_a,
      'job_repo_link_set must attach the link, got ' || COALESCE(v_got::text,'null');

    -- (b) a second attempt must be refused, even with the same link
    v_refused := false;
    BEGIN
      PERFORM guardops.job_repo_link_set(v_job_id, v_repo_a);
    EXCEPTION WHEN OTHERS THEN
      v_refused := true;
    END;
    ASSERT v_refused,
      'job_repo_link_set must refuse to change a link that is already set';

    SELECT repo_link_id INTO v_got FROM guardops.job WHERE id = v_job_id;
    ASSERT v_got = v_repo_a,
      'the original link must survive the refused change, got ' || COALESCE(v_got::text,'null');

    RAISE INFO 'proof/0096: link attached once and the second attempt refused';
    RAISE EXCEPTION 'proof/0096/rollback';

  EXCEPTION
    WHEN OTHERS THEN
      IF sqlerrm = 'proof/0096/rollback' THEN
        NULL;
      ELSE
        RAISE;
      END IF;
  END;

  SELECT count(*) INTO v_got FROM guardops.job WHERE what_for = 'proof-0096: linkless job';
  ASSERT v_got = 0,
    'job must be empty after rollback, found ' || v_got || ' row(s)';

  RAISE INFO 'proof/0096: job unchanged after rollback - door confirmed';
END
$proof$;
