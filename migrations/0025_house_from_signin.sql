CREATE OR REPLACE FUNCTION guardops.house_from_signin(p_name text, p_external_id text, p_email text DEFAULT NULL::text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'guardops', 'pg_temp'
AS $function$
DECLARE
  v_ext      text := btrim(coalesce(p_external_id, ''));
  v_customer bigint;
  v_account  bigint;
BEGIN
  IF v_ext = '' THEN
    RAISE EXCEPTION '[SIGN-IN HOUSE] a house needs the provider id its customer is filed under';
  END IF;

  SELECT id INTO v_customer
    FROM guardops.customer
   WHERE provider = 'supabase' AND external_id = v_ext;
  IF found THEN
    UPDATE guardops.customer
       SET last_seen = now(),
           email = coalesce(email, nullif(btrim(p_email), ''))
     WHERE id = v_customer;
    RETURN v_customer;
  END IF;

  IF v_ext ~ 'OAUTH_TOKEN_' OR v_ext ~ '_[0-9]{13}$' THEN
    RAISE EXCEPTION '[SIGN-IN GUARD] external_id looks like a generated token or timestamp, not a stable identifier: %', left(v_ext, 60);
  END IF;

  INSERT INTO guardops.account (name)
       VALUES (coalesce(nullif(btrim(p_name), ''), v_ext))
    RETURNING id INTO v_account;

  INSERT INTO guardops.customer (account_id, provider, external_id, email, last_seen)
       VALUES (v_account, 'supabase', v_ext, nullif(btrim(p_email), ''), now())
    RETURNING id INTO v_customer;

  RETURN v_customer;
END;
$function$;
