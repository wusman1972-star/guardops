-- LIFT: guardops.tell_make()
-- SOURCE md5 (pg_get_functiondef, old floor lauttgnmksnxohigaqee): 78fb1a37c68c228e4c32844e0031276d
-- CHANGE 1 search_path - all guardops names are schema-qualified; safe to empty:
--   BEFORE: SET search_path TO 'guardops', 'pg_temp'
--   AFTER:  SET search_path TO ''
-- CHANGE 2 none - no change_seen reference.

CREATE OR REPLACE FUNCTION guardops.tell_make()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  r record; w record;
  v_facts jsonb; v_words jsonb;
  v_made int := 0; v_rows int;
  v_last bigint; v_n int; v_max bigint;
begin
  for r in select d.id, coalesce(nullif(btrim(d.label), ''), 'your database') as label, c.id as customer_id
             from guardops.watched_database d
             join guardops.connected_account a on a.id = d.connected_account_id
             join guardops.customer c on c.id = a.customer_id
            where d.status = 'ACTIVE' and d.connect_mode = 'SIGNED'
            order by d.id
  loop
    -- the shape changed and they have not seen it on the website
    begin
      v_facts := guardops.news_counts(r.id);
      if coalesce((v_facts->>'previous')::bigint, 0) > 0
         and coalesce((v_facts->>'seen')::boolean, false) is not true
         and (coalesce((v_facts->>'added')::int,0) + coalesce((v_facts->>'gone')::int,0)
              + coalesce((v_facts->>'changed')::int,0)) > 0 then
        v_words := guardops.notice_words('CHANGED', r.label, v_facts);
        insert into guardops.customer_notice (customer_id, database_id, kind, about, headline, body)
        values (r.customer_id, r.id, 'CHANGED', (v_facts->>'picture')::bigint,
                v_words->>'headline', v_words->>'body')
        on conflict do nothing;
        get diagnostics v_rows = row_count;
        v_made := v_made + v_rows;
      end if;
    exception when others then
      raise warning '[TELL] making the change notice for database % failed: %', r.id, left(sqlerrm, 300);
    end;

    -- the alarms caught writes we have not told them about yet
    begin
      select coalesce(max(about), 0) into v_last
        from guardops.customer_notice where database_id = r.id and kind = 'WRITE';
      select count(*), max(id) into v_n, v_max
        from guardops.write_record where database_id = r.id and id > v_last;
      if coalesce(v_n, 0) > 0 then
        select table_name, operation, rows_touched into w
          from guardops.write_record
         where database_id = r.id and id > v_last order by id desc limit 1;
        v_words := guardops.notice_words('WRITE', r.label,
                     jsonb_build_object('n', v_n, 'table', w.table_name,
                                        'operation', w.operation, 'rows', w.rows_touched));
        insert into guardops.customer_notice (customer_id, database_id, kind, about, headline, body)
        values (r.customer_id, r.id, 'WRITE', v_max, v_words->>'headline', v_words->>'body')
        on conflict do nothing;
        get diagnostics v_rows = row_count;
        v_made := v_made + v_rows;
      end if;
    exception when others then
      raise warning '[TELL] making the write notice for database % failed: %', r.id, left(sqlerrm, 300);
    end;
  end loop;

  return v_made;
end $function$;
