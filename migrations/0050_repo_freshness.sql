CREATE OR REPLACE FUNCTION guardops.repo_freshness(p_repo_link_id bigint DEFAULT NULL::bigint)
 RETURNS TABLE(repo_link_id bigint, closed_at timestamp with time zone, age interval, head_sha text, kind text, proof_status text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'guardops', 'pg_temp'
AS $function$
declare v_link bigint;
begin
  -- DEVIATION D2: NULL means "the active link" (order 51: at most one is active),
  -- so receipt-page can ask without holding a link id.
  v_link := coalesce(p_repo_link_id, (select rl.id from guardops.repo_link rl where rl.active and rl.account_id = guardops.current_account()));
  if v_link is null then
    return;
  end if;
  return query
    select rp.repo_link_id, rp.closed_at, now() - rp.closed_at,
           rp.head_sha, rp.kind, rp.proof_status
      from guardops.repo_pull rp
     where rp.repo_link_id = v_link and rp.closed_at is not null
       and rp.account_id = guardops.current_account()
     order by rp.closed_at desc, rp.id desc
     limit 1;
end $function$
