-- Hole 858: revoke EXECUTE from public/anon/authenticated on all guardops
-- functions and procedures; grant to service_role only; close the default
-- so every function created after today is born locked.

revoke execute on all functions  in schema guardops from public, anon, authenticated;
revoke execute on all procedures in schema guardops from public, anon, authenticated;

grant execute on all functions  in schema guardops to service_role;
grant execute on all procedures in schema guardops to service_role;

alter default privileges in schema guardops
    revoke execute on functions from public;

alter default privileges for role postgres in schema guardops
    revoke execute on functions from public;
