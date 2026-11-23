-- Board 11869 part 3. Straight lift of pull_close from the old floor
-- (lauttgnmksnxohigaqee guardops). One change from pg_get_functiondef: the
-- declared search_path goes from 'guardops, pg_temp' to '' - every name in the
-- body is already qualified (guardops.repo_pull, guardops.repo_link,
-- guardops.current_account, guardops.checker_verify) and the rest is
-- pg_catalog. Same rule as lifts 8 and 9. Nothing cut, nothing added.

CREATE OR REPLACE FUNCTION guardops.pull_close(p_pull_id bigint, p_kind text, p_head_sha text, p_oldest_sha text, p_commits_new integer, p_signature text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_pull    guardops.repo_pull%rowtype;
  v_repo    text;
  v_branch  text;
  v_payload text;
  v_status  text;
begin
  -- R7: the verdict never bounces, but a structurally illegal call RAISES -
  -- unknown pull, a pull that is not OPEN, kind LEGACY, kind outside the walk
  -- outcomes. Nothing about a raise on these paths writes a row.
  select * into v_pull from guardops.repo_pull where id = p_pull_id and account_id = guardops.current_account() for update;
  if not found then
    raise exception '[PULL DOOR] there is no pull %', p_pull_id;
  end if;
  if v_pull.proof_status <> 'OPEN' then
    raise exception '[PULL DOOR] pull % is % - a closed pull is frozen whole (R6)', p_pull_id, v_pull.proof_status;
  end if;
  if p_kind is null or p_kind not in ('FIRST','FORWARD','FORCE_PUSH') then
    raise exception '[PULL DOOR] kind must be FIRST, FORWARD or FORCE_PUSH - LEGACY is the migration''s alone (R2v7)';
  end if;

  select rl.repo, rl.branch into v_repo, v_branch
    from guardops.repo_link rl where rl.id = v_pull.repo_link_id and rl.account_id = guardops.current_account();

  -- R4 (as replaced by R2v8): authority for kind is singular - the tool passes
  -- it, this door stores it, the signature covers it. No derivation, no
  -- substitution, no prev-head cross-check here; that residue is NOT COVERED 1
  -- and the demoted patrol bell.
  update guardops.repo_pull
     set kind = p_kind, head_sha = p_head_sha, oldest_sha = p_oldest_sha,
         commits_new = p_commits_new, signature = p_signature, closed_at = now()
   where id = p_pull_id and account_id = guardops.current_account();

  -- R1 + board 158: the canonical payload is built from the row AS STORED,
  -- never from the caller: pull_id|repo|branch|kind|head_sha|oldest_sha|commits_new
  select rp.id::text || '|' || v_repo || '|' || v_branch || '|' || rp.kind
         || '|' || coalesce(rp.head_sha, '') || '|' || coalesce(rp.oldest_sha, '')
         || '|' || coalesce(rp.commits_new::text, '')
    into v_payload
    from guardops.repo_pull rp where rp.id = p_pull_id and rp.account_id = guardops.current_account();

  v_status := case when guardops.checker_verify(v_payload, p_signature)
                   then 'PROVEN' else 'UNPROVEN' end;
  update guardops.repo_pull set proof_status = v_status where id = p_pull_id and account_id = guardops.current_account();
  return v_status;
end
$function$;
