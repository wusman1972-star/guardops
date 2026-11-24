-- LIFT: guardops.tell_settle()
-- SOURCE md5 (pg_get_functiondef, old floor lauttgnmksnxohigaqee): 52ed1a69b5cc61e4b31b70508d029860
-- CHANGE 1 search_path - all names are schema-qualified (guardops.customer_notice,
--   net._http_response); safe to empty:
--   BEFORE: SET search_path TO 'guardops', 'net', 'pg_catalog', 'pg_temp'
--   AFTER:  SET search_path TO ''
-- CHANGE 2 none - no change_seen reference.

CREATE OR REPLACE FUNCTION guardops.tell_settle()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare r record; v_done int := 0;
begin
  for r in select n.id, n.request_id, p.status_code, p.content, p.error_msg
             from guardops.customer_notice n
             join net._http_response p on p.id = n.request_id
            where n.state = 'SENT' and n.delivered is null
            order by n.id
  loop
    if r.status_code between 200 and 299 then
      update guardops.customer_notice
         set delivered = true, reply_status = r.status_code, send_error = null
       where id = r.id;
    else
      update guardops.customer_notice
         set state = 'FAILED', delivered = false, reply_status = r.status_code,
             send_error = left(coalesce(r.error_msg, r.content, 'no reply'), 500)
       where id = r.id;
    end if;
    v_done := v_done + 1;
  end loop;
  return v_done;
end $function$;
