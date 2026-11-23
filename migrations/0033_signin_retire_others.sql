CREATE OR REPLACE FUNCTION guardops.signin_retire_others(p_connected_id bigint)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'guardops', 'pg_catalog', 'pg_temp'
AS $function$
declare v_new record; v_n integer := 0;
begin
  select id, account_id, provider, customer_id
    into v_new
    from guardops.connected_account
   where id = p_connected_id;
  if not found then return 0; end if;
  if v_new.customer_id is null then return 0; end if;

  -- One retirement at a time per customer+provider (released at commit), through
  -- the shared key so the two spare-checks serialise on exactly the same thing.
  perform guardops.signin_group_lock(v_new.account_id, v_new.customer_id, v_new.provider);

  perform 1 from guardops.connected_account a
   where a.account_id  = v_new.account_id
     and a.customer_id = v_new.customer_id
     and a.provider    = v_new.provider
     and a.status      = 'ACTIVE'
   order by a.id
     for update;

  update guardops.connected_account a
     set status = 'SUPERSEDED'
   where a.account_id  = v_new.account_id
     and a.customer_id = v_new.customer_id
     and a.provider    = v_new.provider
     and a.id         <> v_new.id
     and a.status      = 'ACTIVE';

  get diagnostics v_n = row_count;
  return v_n;
end
$function$
