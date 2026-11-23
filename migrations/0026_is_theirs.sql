CREATE OR REPLACE FUNCTION guardops.is_theirs(p_customer bigint, p_database_id bigint)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'guardops', 'pg_temp'
AS $function$
  select exists (
    select 1 from guardops.watched_database d
      join guardops.connected_account a on a.id = d.connected_account_id
     where d.id = p_database_id and d.status = 'ACTIVE' and a.customer_id = p_customer
       and a.account_id = d.account_id);
$function$;
