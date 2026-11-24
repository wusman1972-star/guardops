-- migrations/0073_house_grants.sql
-- Board 11924. Replaces the authenticated grant filed by board 11911 in error.
--
-- act_as_house(p_customer) trusts its argument alone: it checks the customer
-- exists and has an ACTIVE sign-in, then signs that house account_id in. It
-- never compares p_customer against the calling user. Granting EXECUTE to
-- authenticated would let any logged-in customer supply another house's
-- customer id and have current_account() return that house's identity.
-- authenticated is therefore deliberately NOT granted.
--
-- The 12 doors that call current_account() are SECURITY DEFINER and reach it
-- as the function owner, so they do not need this grant themselves.
-- service_role is trusted to sign a house in on behalf of a verified caller.

GRANT EXECUTE ON FUNCTION guardops.act_as_house(bigint) TO service_role;
-- authenticated is not granted: a caller-facing sign-in door that verifies the
-- caller owns the customer id before invoking act_as_house does not exist yet.
-- When it does, it must carry its own authorization check - never take
-- p_customer as a trusted argument from an unverified caller.
