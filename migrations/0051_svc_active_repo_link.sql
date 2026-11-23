CREATE OR REPLACE FUNCTION guardops.svc_active_repo_link()
 RETURNS TABLE(id bigint, repo text, branch text)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select rl.id, rl.repo, rl.branch
    from guardops.repo_link rl
   where rl.active
     -- floor_account() cut: not present in the clean install database; the floor-account
     -- concept belongs to the GuardOps floor and is not shipped to customers (THE CUSTOMER INSTALL).
   order by rl.id
   limit 1;
$function$
