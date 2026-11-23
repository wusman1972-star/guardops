-- board 11862, lift 8 of 9 part one
-- straight lift, no changes
CREATE OR REPLACE FUNCTION guardops.svc_open_pull(p_repo_link_id bigint)
 RETURNS TABLE(pull_id bigint, prev_head_sha text)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select rp.id, rp.prev_head_sha
    from guardops.repo_pull rp
   where rp.repo_link_id = p_repo_link_id and rp.proof_status = 'OPEN'
     and rp.account_id = guardops.current_account()
   order by rp.id
   limit 1;
$function$;
