-- Board 12169. Close the sign-in door.
-- public.gops_customer_for_signin had a bare =X entry in its ACL (world-callable).
-- Remove EXECUTE from PUBLIC, anon, and authenticated.
-- Grant EXECUTE only to service_role.
-- The sole internal caller is guardops.house_make (SECURITY DEFINER, owner postgres),
-- which runs as the owner and requires no grant.

REVOKE EXECUTE ON FUNCTION public.gops_customer_for_signin(text, text, text) FROM PUBLIC;
DO $do$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    EXECUTE 'REVOKE EXECUTE ON FUNCTION public.gops_customer_for_signin(text, text, text) FROM anon';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    EXECUTE 'REVOKE EXECUTE ON FUNCTION public.gops_customer_for_signin(text, text, text) FROM authenticated';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.gops_customer_for_signin(text, text, text) TO service_role';
  END IF;
END
$do$;
