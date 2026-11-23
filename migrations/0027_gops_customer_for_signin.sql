CREATE OR REPLACE FUNCTION public.gops_customer_for_signin(p_secret_name text, p_external_id text, p_email text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'guardops', 'public', 'pg_temp'
AS $function$
declare v_customer bigint; v_new bigint;
begin
  if p_external_id is null or p_external_id = '' then
    raise exception 'a customer needs an id from the provider';
  end if;

  insert into guardops.customer(provider, external_id, email, last_seen)
       values ('supabase', p_external_id, p_email, now())
  on conflict (provider, external_id)
    do update set last_seen = now(),
                  email = coalesce(excluded.email, guardops.customer.email)
    returning id into v_customer;

  with stamped as (
    update guardops.connected_account
       set customer_id = v_customer
     where token_secret_name = p_secret_name
    returning id, status, approved_at)
  select s.id into v_new
    from stamped s
   where s.status = 'ACTIVE'
   order by s.approved_at desc, s.id desc
   limit 1;

  -- ORDER 0140 F1: a finished sign-in retires the ones before it, by id.
  if v_new is not null then
    begin
      perform guardops.signin_retire_others(v_new);
    exception when others then
      raise warning '[ONE SIGN-IN] could not retire the earlier sign-ins behind %: %', v_new, left(sqlerrm, 200);
    end;
  end if;

  return v_customer;
end
$function$;
