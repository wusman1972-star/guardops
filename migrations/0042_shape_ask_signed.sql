CREATE OR REPLACE FUNCTION guardops.shape_ask_signed(p_database_id bigint, p_kind text DEFAULT 'WATCH'::text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'guardops', 'public', 'pg_temp'
AS $function$
declare
  v_req     bigint;
  v_picture bigint;
  v_signin  bigint;
begin
  insert into guardops.shape_picture(database_id, source, state, kind)
       values (p_database_id, 'SIGNED', 'PENDING', upper(coalesce(nullif(btrim(p_kind),''),'WATCH')))
    returning id into v_picture;

  -- ORDER 0140: say it, do not pretend it.
  v_signin := guardops.live_signin(p_database_id);
  if v_signin is null then
    update guardops.shape_picture
       set state = 'FAILED',
           failed_why = 'nobody is signed in for this database right now, so GuardOps could not look. Signing in again puts it back exactly as it was.'
     where id = v_picture;
    return v_picture;
  end if;

  v_req := guardops.signed_call(p_database_id, 'look', $q$
      select n.nspname::text as schema_name,
             c.relname::text as object_name,
             (case c.relkind
                when 'r' then 'table' when 'p' then 'table'
                when 'v' then 'view'  when 'm' then 'view' end)::text as object_kind,
             coalesce((select jsonb_agg(jsonb_build_object(
                                 'name', a.attname,
                                 'type', pg_catalog.format_type(a.atttypid, a.atttypmod))
                               order by a.attnum)
                         from pg_catalog.pg_attribute a
                        where a.attrelid = c.oid
                          and a.attnum > 0
                          and not a.attisdropped), '[]'::jsonb) as column_shape,
             c.reltuples::bigint as row_estimate,
             pg_catalog.pg_total_relation_size(c.oid) as bytes
        from pg_catalog.pg_class c
        join pg_catalog.pg_namespace n on n.oid = c.relnamespace
       where c.relkind in ('r','p','v','m')
         and n.nspname not in ('pg_catalog','information_schema','pg_toast',
                               'cron','net','extensions','vault','pgsodium',
                               'auth','storage','realtime','graphql',
                               'graphql_public','supabase_migrations')
      union all
      -- HOLE 277: the camera sees triggers. Our guards are triggers on the
      -- customer's own tables, outside schema guardops_watch. object_name is
      -- table-qualified so it is unique; column_shape says which table it sits on
      -- and whether it is OURS (its function lives in schema guardops_watch).
      select n.nspname::text as schema_name,
             (c.relname || '.' || t.tgname)::text as object_name,
             'trigger'::text as object_kind,
             jsonb_build_object(
               'on_table', c.relname,
               'trigger',  t.tgname,
               'ours',     exists(select 1 from pg_catalog.pg_proc pr
                                     join pg_catalog.pg_namespace pn on pn.oid = pr.pronamespace
                                    where pr.oid = t.tgfoid and pn.nspname = 'guardops_watch')
             ) as column_shape,
             0::bigint as row_estimate,
             0::bigint as bytes
        from pg_catalog.pg_trigger t
        join pg_catalog.pg_class c on c.oid = t.tgrelid
        join pg_catalog.pg_namespace n on n.oid = c.relnamespace
       where not t.tgisinternal
         and n.nspname not in ('pg_catalog','information_schema','pg_toast',
                               'cron','net','extensions','vault','pgsodium',
                               'auth','storage','realtime','graphql',
                               'graphql_public','supabase_migrations')
    $q$);

  -- board 11845: stamp the dispatching sign-in so signin_dead targets the right one.
  update guardops.shape_picture set request_id = v_req, dispatched_signin_id = v_signin where id = v_picture;
  return v_picture;
end
$function$
