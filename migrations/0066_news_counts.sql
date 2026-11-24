-- LIFT: guardops.news_counts(p_database_id bigint)
-- SOURCE md5 (pg_get_functiondef, old floor lauttgnmksnxohigaqee): f034b93c9834f44dc2d5b592c55a01af
-- CHANGE 1 search_path - all guardops names are schema-qualified; safe to empty:
--   BEFORE: SET search_path TO 'guardops', 'pg_temp'
--   AFTER:  SET search_path TO ''
-- CHANGE 2 change_seen → shape_change (change_seen does not exist on either floor):
--   BEFORE: v_seen := exists (select 1 from guardops.change_seen
--   BEFORE:                    where database_id = p_database_id and picture_id = v_pic);
--   AFTER:  v_seen := exists (select 1 from guardops.shape_change
--   AFTER:                     where database_id = p_database_id and picture_id = v_pic);

CREATE OR REPLACE FUNCTION guardops.news_counts(p_database_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_pic bigint; v_prev bigint; v_seen boolean; v_when timestamptz;
  v_added text[]; v_gone text[]; v_changed text[];
begin
  select id, taken_at into v_pic, v_when from guardops.shape_picture
   where database_id = p_database_id and state = 'DONE' order by id desc limit 1;
  if v_pic is null then return jsonb_build_object('picture', null); end if;

  v_seen := exists (select 1 from guardops.shape_change
                     where database_id = p_database_id and picture_id = v_pic);

  select id into v_prev from guardops.shape_picture
   where database_id = p_database_id and state = 'DONE' and id < v_pic order by id desc limit 1;
  if v_prev is null then
    return jsonb_build_object('picture', v_pic, 'previous', null, 'seen', v_seen,
                              'when', v_when, 'added', 0, 'gone', 0, 'changed', 0);
  end if;

  select array_agg(n.schema_name || '.' || n.object_name order by n.object_name) into v_added
    from guardops.shape_object n
   where n.picture_id = v_pic and n.schema_name <> 'guardops_watch'
     and not exists (select 1 from guardops.shape_object o
                      where o.picture_id = v_prev and o.schema_name = n.schema_name
                        and o.object_name = n.object_name);

  select array_agg(o.schema_name || '.' || o.object_name order by o.object_name) into v_gone
    from guardops.shape_object o
   where o.picture_id = v_prev and o.schema_name <> 'guardops_watch'
     and not exists (select 1 from guardops.shape_object n
                      where n.picture_id = v_pic and n.schema_name = o.schema_name
                        and n.object_name = o.object_name);

  select array_agg(n.schema_name || '.' || n.object_name order by n.object_name) into v_changed
    from guardops.shape_object n
    join guardops.shape_object o on o.picture_id = v_prev
     and o.schema_name = n.schema_name and o.object_name = n.object_name
   where n.picture_id = v_pic and n.schema_name <> 'guardops_watch'
     and n.column_shape <> o.column_shape;

  return jsonb_build_object(
    'picture', v_pic, 'previous', v_prev, 'seen', v_seen, 'when', v_when,
    'added',   coalesce(array_length(v_added, 1), 0),
    'gone',    coalesce(array_length(v_gone, 1), 0),
    'changed', coalesce(array_length(v_changed, 1), 0),
    'added_names',   to_jsonb(coalesce(v_added,   '{}'::text[])),
    'gone_names',    to_jsonb(coalesce(v_gone,    '{}'::text[])),
    'changed_names', to_jsonb(coalesce(v_changed, '{}'::text[])));
end $function$;
