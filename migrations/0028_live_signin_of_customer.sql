CREATE OR REPLACE FUNCTION guardops.live_signin_of_customer(p_account bigint, p_customer bigint, p_provider text)
 RETURNS bigint
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'guardops', 'pg_temp'
AS $function$
  select a.id
    from guardops.connected_account a
   where a.account_id  = p_account
     and a.customer_id = p_customer
     and a.provider    = p_provider
     and a.status      = 'ACTIVE'
   order by a.approved_at desc, a.id desc
   limit 1;
$function$
