CREATE OR REPLACE FUNCTION guardops.house_make(p_name text, p_login text, p_external_id text, p_email text DEFAULT NULL::text, p_org_slug text DEFAULT NULL::text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'guardops', 'pg_catalog', 'pg_temp'
AS $function$
declare
  v_name     text := btrim(coalesce(p_name, ''));
  v_ext      text := btrim(coalesce(p_external_id, ''));
  v_account  bigint;
  v_customer bigint;
begin
  if v_name = '' then
    raise exception '[HOUSE DOOR] a house needs a name';
  end if;
  if v_ext = '' then
    raise exception '[HOUSE DOOR] a house needs the provider id its customer is filed under';
  end if;

  -- 1. mint the house row itself (nothing else makes an account row; account 1 was
  --    seeded, never born through a door).
  insert into guardops.account (name) values (v_name) returning id into v_account;

  -- 3. its customer, through the door that already exists (now reachable - board 1695
  --    fault 1 grant above). gops_customer_for_signin runs as its postgres owner, makes
  --    the customer row and returns its id, which the sign-in row links below.
  v_customer := public.gops_customer_for_signin('customer_signin_' || v_account::text, v_ext, nullif(btrim(coalesce(p_email, '')), ''));

  -- 4. its sign-in row, written directly (board 1698 fault 4 - OPUS overruled the board
  --    1695 deferral). connected_account is in this order's scope now (amendment 1005) and
  --    guard_owner is granted exactly the reach this insert needs just below. The row is
  --    stamped to THIS house (account_id = v_account), not the account 1 the sign-in door
  --    still hardcodes. No real provider token is sealed at house-make time, so
  --    token_secret_name is a deterministic placeholder the seat seals when the house first
  --    connects (the same deferred-reach posture as customer_door's password); the row is
  --    the house's ACTIVE sign-in, linked to the customer made in step 3 and carrying its
  --    org_slug when one was given.
  insert into guardops.connected_account
    (account_id, provider, approved_at, token_secret_name, status, org_slug, customer_id)
  values
    (v_account, 'supabase', now(), 'house_signin_pending_' || v_account::text, 'ACTIVE',
     nullif(btrim(coalesce(p_org_slug, '')), ''), v_customer);

  return v_account;
end
$function$;
