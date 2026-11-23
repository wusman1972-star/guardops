-- board 11862, lift 8 of 9 part one
-- floor_account() swapped to current_account() on both predicates (hole 838 rule — no unfiltered rows)
CREATE OR REPLACE FUNCTION guardops.svc_pull_sighted_shas(p_pull_id bigint)
 RETURNS SETOF text
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select cs.sha
    from guardops.pull_commit pc
    join guardops.commit_seen cs on cs.id = pc.commit_seen_id
   where pc.pull_id = p_pull_id
     and pc.account_id = guardops.current_account()
     and cs.account_id = guardops.current_account();
$function$;
