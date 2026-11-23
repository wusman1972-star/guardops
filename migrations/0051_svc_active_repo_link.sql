CREATE OR REPLACE FUNCTION guardops.svc_active_repo_link()
 RETURNS TABLE(id bigint, repo text, branch text)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select rl.id, rl.repo, rl.branch
    from guardops.repo_link rl
   where rl.active
     and rl.account_id = guardops.current_account()
   order by rl.id
   limit 1;
$function$
