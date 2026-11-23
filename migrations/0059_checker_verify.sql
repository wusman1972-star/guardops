-- Board 11869 part 2. Straight lift of checker_verify from the old floor
-- (lauttgnmksnxohigaqee guardops). One change from pg_get_functiondef: the
-- declared search_path goes from 'guardops, extensions, pg_temp' to '' because
-- every name in the body is already qualified - guardops.checker_key and
-- extensions.hmac - and everything else is pg_catalog. Same rule as lifts 8
-- and 9. Nothing cut, nothing added. EXECUTE taken off PUBLIC: this is an
-- internal helper that answers yes/no about a signature, and only pull_close
-- needs it, which reaches it as the owner.

CREATE OR REPLACE FUNCTION guardops.checker_verify(p_payload text, p_offered_sig text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_secret   bytea;
  v_digest   text;
  v_expected bytea;
  v_offered  bytea;
  v_acc      integer := 0;
BEGIN
  -- rule C2: total boolean -- NULL/empty/malformed inputs read false; never NULL, never raise
  IF p_payload IS NULL OR p_payload = '' THEN
    RETURN false;
  END IF;
  -- rule C4 (Opus correction): exactly 64 lowercase hex characters -- today's contract
  IF p_offered_sig IS NULL OR p_offered_sig !~ '^[0-9a-f]{64}$' THEN
    RETURN false;
  END IF;
  SELECT secret, digest INTO v_secret, v_digest
    FROM guardops.checker_key WHERE key_id = 'active';
  IF v_secret IS NULL THEN
    RETURN false;                      -- no key installed yet: nothing can be PROVEN
  END IF;
  -- rule C3: expected value stays raw bytes; offered sig decodes to 32 bytes (shape-checked above)
  v_expected := extensions.hmac(convert_to(p_payload, 'UTF8'), v_secret, v_digest);
  v_offered  := decode(p_offered_sig, 'hex');
  IF v_expected IS NULL OR octet_length(v_expected) <> 32 OR octet_length(v_offered) <> 32 THEN
    RETURN false;
  END IF;
  -- rule C4: constant-time 32-byte compare -- one accumulator, no early exit
  FOR i IN 0..31 LOOP
    v_acc := v_acc | (get_byte(v_expected, i) # get_byte(v_offered, i));
  END LOOP;
  RETURN v_acc = 0;                    -- boolean only; key and expected hash never leave
END
$function$;

REVOKE ALL ON FUNCTION guardops.checker_verify(text, text) FROM PUBLIC;
