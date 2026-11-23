CREATE OR REPLACE FUNCTION guardops.signin_group_lock(p_account bigint, p_customer bigint, p_provider text)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'guardops', 'pg_catalog', 'pg_temp'
AS $function$
  select pg_catalog.pg_advisory_xact_lock(
           pg_catalog.hashtextextended(
             'guardops.signin_group:' || coalesce(p_account::text, '-')
             || ':' || coalesce(p_customer::text, '-')
             || ':' || coalesce(p_provider, '-'), 0));
$function$
