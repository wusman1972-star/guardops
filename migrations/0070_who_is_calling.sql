-- migrations/0070_who_is_calling.sql
-- Board 11878. Fixes Hole 845: current_account() was the constant 1, giving
-- every call the same house and destroying row-level separation between customers.
--
-- Two new objects land here:
--   guardops.act_as_house(p_customer bigint) returns bigint
--     Verifies the customer exists and holds an ACTIVE connected_account, then
--     stamps the matching account_id into a transaction-local GUC.
--     set_config true = the setting dies at END of transaction, never leaks.
--     Raises unconditionally on any failure. No fallback, no default.
--   guardops.current_account() replaced
--     Reads the GUC. Returns the bigint if set and all-digits.
--     Raises with [NO HOUSE] if the GUC is absent or empty.
--     The old stub returned 1; this never will.
--
-- NO SIGNATURE ON THE SETTING (deliberate, recorded here):
--   The old floor HMAC-signed this GUC so a raw set_config could not forge it.
--   Not carried across. The only roles that can execute SQL here are ours;
--   anything that can run set_config as the owner can already read every row
--   directly, so a signature defends against nothing while adding a key, a
--   secret, and a failure mode. Fewest moving parts. If customers are ever
--   granted direct SQL access this decision must be reopened.

CREATE OR REPLACE FUNCTION guardops.act_as_house(p_customer bigint)
  RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
declare
  v_account_id bigint;
  v_active     boolean;
begin
  select c.account_id
    into v_account_id
    from guardops.customer c
   where c.id = p_customer;

  if not found then
    raise exception '[NO HOUSE] customer % does not exist', p_customer;
  end if;

  select true
    into v_active
    from guardops.connected_account ca
   where ca.customer_id = p_customer
     and ca.status      = 'ACTIVE'
   limit 1;

  if not found then
    raise exception '[NO HOUSE] customer % has no ACTIVE sign-in', p_customer;
  end if;

  perform set_config('guardops.house', v_account_id::text, true);
  return v_account_id;
end
$function$;

CREATE OR REPLACE FUNCTION guardops.current_account()
  RETURNS bigint
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
declare
  v_raw text;
begin
  v_raw := btrim(current_setting('guardops.house', true));
  if v_raw is null or v_raw = '' then
    raise exception '[NO HOUSE] nobody is signed in for this call, so GuardOps will not guess';
  end if;
  if v_raw !~ '^\d+$' then
    raise exception '[NO HOUSE] guardops.house is corrupt: %', v_raw;
  end if;
  return v_raw::bigint;
end
$function$;
