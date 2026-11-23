-- board 11862, lift 8 of 9 part one
-- search_path changed from 'guardops','pg_temp' to '' — all names already fully qualified
CREATE OR REPLACE FUNCTION guardops.pull_abort(p_pull_id bigint, p_reason text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_pull guardops.repo_pull%rowtype;
begin
  select * into v_pull from guardops.repo_pull where id = p_pull_id and account_id = guardops.current_account() for update;
  if not found then
    raise exception '[PULL DOOR] there is no pull %', p_pull_id;
  end if;
  if v_pull.proof_status <> 'OPEN' then
    raise exception '[PULL DOOR] pull % is % - only an OPEN pull can be aborted', p_pull_id, v_pull.proof_status;
  end if;
  update guardops.repo_pull
     set proof_status = 'ABORTED', abort_reason = btrim(coalesce(p_reason, '')), closed_at = now()
   where id = p_pull_id and account_id = guardops.current_account();
  return 'ABORTED';
end $function$;
