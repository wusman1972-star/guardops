create or replace function guardops.house_make(p_name text, p_login text, p_external_id text, p_email text default null::text, p_org_slug text default null::text)
returns bigint
language plpgsql
security definer
set search_path to 'guardops', 'pg_catalog', 'pg_temp'
as $function$
declare
  v_name     text := btrim(coalesce(p_name, ''));
  v_login    text := btrim(coalesce(p_login, ''));
  v_ext      text := btrim(coalesce(p_external_id, ''));
  v_account  bigint;
  v_customer bigint;
begin
  if v_name = '' then
    raise exception '[HOUSE DOOR] a house needs a name';
  end if;
  if v_login = '' then
    raise exception '[HOUSE DOOR] a house needs a login role';
  end if;
  if v_ext = '' then
    raise exception '[HOUSE DOOR] a house needs the provider id its customer is filed under';
  end if;
  if not exists (select 1 from pg_catalog.pg_roles r where r.rolname = v_login and r.rolcanlogin) then
    raise exception '[HOUSE DOOR] % is not a login role on this floor - make its sealed login first (ORDER 117 S3)', v_login;
  end if;

  insert into guardops.account (name) values (v_name) returning id into v_account;
  -- No seat is written here. Whose house a call is in comes from the signed
  -- guardops.house setting that act_as_house issues and current_account_or_null verifies.

  v_customer := public.gops_customer_for_signin('customer_signin_' || v_account::text, v_ext, nullif(btrim(coalesce(p_email, '')), ''));

  insert into guardops.connected_account
    (account_id, provider, approved_at, token_secret_name, status, org_slug, customer_id)
  values
    (v_account, 'supabase', now(), 'house_signin_pending_' || v_account::text, 'ACTIVE',
     nullif(btrim(coalesce(p_org_slug, '')), ''), v_customer);

  return v_account;
end
$function$;
