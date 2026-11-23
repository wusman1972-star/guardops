-- board 11862, lift 8 of 9 part one
-- search_path changed from 'guardops','pg_temp' to '' — all names already fully qualified
CREATE OR REPLACE FUNCTION guardops.pull_begin(p_repo_link_id bigint)
 RETURNS TABLE(pull_id bigint, prev_head_sha text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_prev text;
  v_id   bigint;
begin
  perform 1 from guardops.repo_link where id = p_repo_link_id and account_id = guardops.current_account();
  if not found then
    raise exception '[PULL DOOR] there is no repo link %', p_repo_link_id;
  end if;
  if exists (select 1 from guardops.repo_pull rp
             where rp.repo_link_id = p_repo_link_id and rp.proof_status = 'OPEN' and rp.account_id = guardops.current_account()) then
    raise exception '[PULL DOOR] link % already has an OPEN pull - close it before opening another (R1)', p_repo_link_id;
  end if;
  -- R2v8: prev_head_sha derives from the latest PROVEN pull, never the latest
  -- closed one - an UNPROVEN close's head is an unverified claim (R5). The TOOL
  -- reads this value and treats NULL as FIRST (board 162 C2); the door never
  -- derives kind. Returned alongside the id because the tool's seat holds no
  -- SELECT on repo_pull (DEVIATION D1, flagged in the header).
  select rp.head_sha into v_prev
    from guardops.repo_pull rp
   where rp.repo_link_id = p_repo_link_id and rp.proof_status = 'PROVEN' and rp.account_id = guardops.current_account()
   order by rp.closed_at desc nulls last, rp.id desc
   limit 1;
  insert into guardops.repo_pull (account_id, repo_link_id, prev_head_sha)
  values (guardops.current_account(), p_repo_link_id, v_prev)
  returning id into v_id;
  return query select v_id, v_prev;
end $function$;
