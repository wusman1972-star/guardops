-- LIFT: guardops.tell_send()
-- SOURCE md5 (pg_get_functiondef, old floor lauttgnmksnxohigaqee): f8c140a5dc3a3138ea372f2c1ac3712e
-- CHANGE 1 search_path - all names are schema-qualified (vault.decrypted_secrets,
--   guardops.customer_notice, guardops.customer, net.http_post); safe to empty:
--   BEFORE: SET search_path TO 'guardops', 'vault', 'net', 'pg_catalog', 'pg_temp'
--   AFTER:  SET search_path TO ''
-- CHANGE 2 none - no change_seen reference.

CREATE OR REPLACE FUNCTION guardops.tell_send()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  r record; v_key text; v_from text; v_req bigint; v_sent int := 0;
begin
  select decrypted_secret into v_key  from vault.decrypted_secrets where name = 'RESEND_KEY';
  select decrypted_secret into v_from from vault.decrypted_secrets where name = 'tell_from_address';
  v_from := coalesce(nullif(btrim(v_from), ''), 'GuardOps <onboarding@resend.dev>');

  for r in select n.id, n.headline, n.body, c.email
             from guardops.customer_notice n
             join guardops.customer c on c.id = n.customer_id
            where n.state in ('NEW', 'HELD', 'NO_WAY_TO_TELL')
            order by n.id limit 20
  loop
    begin
      if coalesce(btrim(r.email), '') = '' then
        update guardops.customer_notice
           set state = 'NO_WAY_TO_TELL',
               held_why = 'no address for this customer yet - it arrives with their next sign-in, and this notice goes out then'
         where id = r.id and state <> 'NO_WAY_TO_TELL';
        continue;
      end if;

      if v_key is null then
        update guardops.customer_notice
           set state = 'HELD', held_why = 'no sending key sealed yet (vault RESEND_KEY)'
         where id = r.id and state <> 'HELD';
        continue;
      end if;

      v_req := net.http_post(
        url     := 'https://api.resend.com/emails',
        body    := jsonb_build_object('from', v_from, 'to', jsonb_build_array(r.email),
                                      'subject', r.headline, 'text', r.body),
        headers := jsonb_build_object('Content-Type', 'application/json',
                                      'Authorization', 'Bearer ' || v_key),
        timeout_milliseconds := 15000);

      update guardops.customer_notice
         set state = 'SENT', sent_at = now(), sent_to = r.email,
             request_id = v_req, send_error = null, held_why = null
       where id = r.id;
      v_sent := v_sent + 1;

    exception when others then
      update guardops.customer_notice
         set state = 'FAILED', send_error = left(sqlerrm, 500) where id = r.id;
    end;
  end loop;

  return v_sent;
end $function$;
