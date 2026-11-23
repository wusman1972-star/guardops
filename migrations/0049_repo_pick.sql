CREATE OR REPLACE FUNCTION guardops.repo_pick(p_repo_link_id bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'guardops', 'pg_temp'
AS $function$
begin
  -- is_strong_seat() cut: not present in the clean install database; the seat-wall
  -- is a GuardOps-floor rule and is not shipped to customers (THE CUSTOMER INSTALL).

  -- the named row must exist before anything moves
  if not exists (select 1 from guardops.repo_link where id = p_repo_link_id and account_id = guardops.current_account()) then
    raise exception '[REPO GATE] there is no repo_link % - link one first with repo_link_add(repo, branch)', p_repo_link_id;
  end if;

  -- clear every active flag, then raise the one named. The partial unique index
  -- makes a second active row impossible; clearing first keeps the pick atomic.
  update guardops.repo_link set active = false where active and account_id = guardops.current_account();
  update guardops.repo_link set active = true  where id = p_repo_link_id and account_id = guardops.current_account();

  return p_repo_link_id;
end $function$
