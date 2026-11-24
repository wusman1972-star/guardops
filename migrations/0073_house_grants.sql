-- migrations/0073_house_grants.sql
-- Board 11911. Companion to 0071_who_is_calling.sql (applied together by OPUS).
--
-- 0071 revokes EXECUTE on act_as_house from PUBLIC.  The two roles that actually
-- call act_as_house to sign a house in are service_role (server-side workers) and
-- authenticated (edge functions acting on behalf of a logged-in user).
--
-- current_account() does NOT need a grant here: every door that calls it is
-- SECURITY DEFINER and runs as the function owner, not as the caller's role.
-- Do not add a PUBLIC grant to current_account() or act_as_house; PUBLIC access
-- to act_as_house is what 0071 was written to close.

GRANT EXECUTE ON FUNCTION guardops.act_as_house(bigint) TO service_role;
GRANT EXECUTE ON FUNCTION guardops.act_as_house(bigint) TO authenticated;
