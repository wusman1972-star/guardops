CREATE OR REPLACE FUNCTION guardops.live_signin_behind(p_connected_id bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'guardops', 'pg_temp'
AS $function$
declare v_row record;
begin
  select id, account_id, provider, customer_id, status
    into v_row
    from guardops.connected_account
   where id = p_connected_id;
  if not found then return null; end if;

  if v_row.customer_id is null then
    return case when v_row.status = 'ACTIVE' then v_row.id else null end;
  end if;

  return guardops.live_signin_of_customer(v_row.account_id, v_row.customer_id, v_row.provider);
end
$function$
