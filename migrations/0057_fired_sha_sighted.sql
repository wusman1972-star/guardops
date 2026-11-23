-- Lift 9 of 9 (board 11865). Straight lift of fired_sha_sighted from old floor
-- (lauttgnmksnxohigaqee guardops) to clean floor (mfysxqhediepzohzhufp guardops).
-- One change from the pg_get_functiondef body: search_path set to '' (empty)
-- because every name in the body is already fully qualified (guardops. prefix
-- throughout, including guardops.current_account()). Same rule applied on lift 8.
-- No rule call found; none removed.

CREATE OR REPLACE FUNCTION guardops.fired_sha_sighted(p_sha text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  -- ORDER 104 (ruling 1087 item 2c): the one test that a fired head is on master.
  -- A merge commit brings the fired branch head onto master as a reachable commit
  -- the signed pull walks; squash or rebase rewrites the sha and it is never
  -- sighted. submit_job and strong_seat_waiting both ask this, so the rule lives
  -- in one place.
  select coalesce(btrim(p_sha), '') <> '' and exists (
    select 1
    from guardops.commit_seen cs
    join guardops.repo_link rl on rl.id = cs.repo_link_id and rl.active and rl.branch = 'master'
    join guardops.pull_commit pc on pc.commit_seen_id = cs.id
    join guardops.repo_pull rp on rp.id = pc.pull_id and rp.proof_status = 'PROVEN'
    where cs.sha = btrim(p_sha)
      and cs.account_id = guardops.current_account() and rl.account_id = guardops.current_account()
      and pc.account_id = guardops.current_account() and rp.account_id = guardops.current_account()
  );
$function$;
