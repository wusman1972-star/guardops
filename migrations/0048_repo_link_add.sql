CREATE OR REPLACE FUNCTION guardops.repo_link_add(p_repo text, p_branch text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'guardops', 'pg_temp'
AS $function$
declare
  -- ORDER 122 S6: the caller's own house, never the literal 1. A paid customer is capped
  -- by its own number and locks its own account row; a house with no allowance is refused,
  -- never let through on our number (board 1746). The wider product debt is closed here.
  v_account  bigint  := guardops.current_account();
  v_repo     text    := btrim(coalesce(p_repo, ''));
  v_branch   text    := btrim(coalesce(p_branch, ''));
  v_allowed  integer;
  v_have     integer;
  v_existing bigint;
  v_id       bigint;
begin
  -- is_strong_seat() cut: not present in the clean install database; the seat-wall
  -- is a GuardOps-floor rule and is not shipped to customers (THE CUSTOMER INSTALL).

  -- R2a: repo blank, or not owner/name shape. The shape admits digits, hyphens,
  -- dots and underscores in the name and hyphens in the owner. F1: the example
  -- is generic, never a real account. F2: the name segment refuses "." and ".."
  -- on their own (GitHub rejects both).
  if v_repo = '' then
    raise exception '[REPO GATE] the repo is blank - write it as owner/name, e.g. acme/shop-api';
  end if;
  if v_repo !~ '^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?/[A-Za-z0-9._-]+$'
     or split_part(v_repo, '/', 2) in ('.', '..') then
    raise exception '[REPO GATE] "%" is not an owner/name repo - write it as owner/name, e.g. acme/shop-api', v_repo;
  end if;

  -- R2b: branch blank, or holding whitespace (btrim removes only the edges, so
  -- this catches whitespace INSIDE the name).
  if v_branch = '' then
    raise exception '[REPO GATE] the branch is blank - write the branch exactly as it reads on GitHub';
  end if;
  if v_branch ~ '[[:space:]]' then
    raise exception '[REPO GATE] the branch holds whitespace - write the branch exactly as it reads on GitHub';
  end if;

  -- R2d + F3: lock the account row FOR UPDATE before counting, so two concurrent
  -- calls cannot both pass the allowance count. R2d: a missing account REFUSES -
  -- a gate over nothing fails; zero is never read as room. ORDER 122 S6: the CALLER's row.
  select repos_allowed into v_allowed
    from guardops.account where id = v_account for update;
  if not found then
    raise exception '[REPO GATE] account % is not on the floor - restore account % before linking any repo', v_account, v_account;
  end if;

  -- R2c: already linked. O2: GitHub owner/name is case-insensitive, so compare
  -- lower(repo); the branch stays exact (git branches are case-sensitive). The
  -- door is the only writer and holds this line - the UNIQUE(repo,branch)
  -- constraint itself stays case-sensitive (GAPS row 68). The account row lock
  -- above serializes this read with the insert below.
  select id into v_existing
    from guardops.repo_link where lower(repo) = lower(v_repo) and branch = v_branch and account_id = guardops.current_account();
  if found then
    raise exception '[REPO GATE] already linked as repo link % - pick it with repo_pick(%)', v_existing, v_existing;
  end if;

  -- R2e + R4: count every repo_link row for the account (rows are never deleted)
  -- and refuse at the allowance. No door raises the allowance yet (GAPS row 68).
  select count(*) into v_have
    from guardops.repo_link where account_id = guardops.current_account();
  if v_have >= v_allowed then
    raise exception '[REPO GATE] account % may link % repos and has % - no door raises the allowance yet (GAPS row 68)', v_account, v_allowed, v_have;
  end if;

  -- R3: one insert. linked_by is set by the door (never an argument; no trigger
  -- fills it), active false, account_id the caller's own house. Never picks.
  insert into guardops.repo_link (account_id, repo, branch, linked_by, active)
  values (guardops.current_account(), v_repo, v_branch, 'WAQAR', false)
  returning id into v_id;

  return v_id;
end $function$
