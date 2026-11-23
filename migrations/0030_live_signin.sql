CREATE OR REPLACE FUNCTION guardops.live_signin(p_database_id bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'guardops', 'pg_temp'
AS $function$
declare v_pin bigint;
begin
  select d.connected_account_id into v_pin
    from guardops.watched_database d where d.id = p_database_id;
  if v_pin is null then return null; end if;
  return guardops.live_signin_behind(v_pin);
end
$function$
