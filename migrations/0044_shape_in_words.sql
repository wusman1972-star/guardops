CREATE OR REPLACE FUNCTION guardops.shape_in_words(p_picture_id bigint)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'guardops', 'pg_temp'
AS $function$
declare
  v_label text; v_db bigint; v_taken timestamptz;
  v_prev bigint;
  v_tables int; v_views int; v_schemas int; v_cols bigint; v_bytes bigint; v_empty int;
  v_big text; v_added text; v_gone text; v_changed text;
  v_out text;
begin
  select w.label, p.database_id, p.taken_at into v_label, v_db, v_taken
    from guardops.shape_picture p join guardops.watched_database w on w.id = p.database_id
   where p.id = p_picture_id;
  if v_label is null then
    return 'There is no picture with that number.';
  end if;

  select count(*) filter (where object_kind='table'),
         count(*) filter (where object_kind='view'),
         count(distinct schema_name),
         sum(jsonb_array_length(column_shape)),
         sum(bytes),
         count(*) filter (where object_kind='table' and coalesce(row_estimate,0) <= 0)
    into v_tables, v_views, v_schemas, v_cols, v_bytes, v_empty
    from guardops.shape_object where picture_id = p_picture_id;

  select string_agg(line, E'\n') into v_big from (
    select '   - ' || schema_name || '.' || object_name || ' - about ' ||
           to_char(greatest(coalesce(row_estimate,0),0),'FM999,999,999') || ' rows, ' ||
           pg_size_pretty(coalesce(bytes,0)) as line
      from guardops.shape_object
     where picture_id = p_picture_id and object_kind = 'table'
     order by coalesce(bytes,0) desc limit 5) t;

  select max(id) into v_prev from guardops.shape_picture
   where database_id = v_db and id < p_picture_id;

  if v_prev is not null then
    select string_agg(schema_name||'.'||object_name, ', ') into v_added from (
      select schema_name, object_name from guardops.shape_object where picture_id = p_picture_id
      except select schema_name, object_name from guardops.shape_object where picture_id = v_prev
      order by 1,2 limit 10) a;
    select string_agg(schema_name||'.'||object_name, ', ') into v_gone from (
      select schema_name, object_name from guardops.shape_object where picture_id = v_prev
      except select schema_name, object_name from guardops.shape_object where picture_id = p_picture_id
      order by 1,2 limit 10) g;
    select string_agg(n.schema_name||'.'||n.object_name, ', ') into v_changed from (
      select o.schema_name, o.object_name from guardops.shape_object o
        join guardops.shape_object q on q.picture_id = v_prev
         and q.schema_name = o.schema_name and q.object_name = o.object_name
       where o.picture_id = p_picture_id and o.column_shape is distinct from q.column_shape
       order by 1,2 limit 10) n;
  end if;

  v_out := 'Picture ' || p_picture_id || ' of ' || v_label || ', taken ' ||
           to_char(v_taken at time zone 'Asia/Karachi', 'FMDay FMDD FMMonth, FMHH12:MI AM') || E'.\n\n' ||
           'It holds ' || v_tables || ' tables and ' || v_views || ' views across ' || v_schemas ||
           ' areas, with ' || to_char(v_cols,'FM999,999') || ' columns in all, taking up ' ||
           pg_size_pretty(coalesce(v_bytes,0)) || E'.\n' ||
           v_empty || ' of those tables look empty.' || E'\n\n' ||
           'The biggest tables:' || E'\n' || coalesce(v_big,'   - none') || E'\n';

  if v_prev is null then
    v_out := v_out || E'\nThis is the first picture of this database, so there is nothing to compare it against yet.';
  else
    v_out := v_out || E'\nSince picture ' || v_prev || ':' || E'\n' ||
      '   - new: ' || coalesce(v_added,'nothing') || E'\n' ||
      '   - gone: ' || coalesce(v_gone,'nothing') || E'\n' ||
      '   - changed columns: ' || coalesce(v_changed,'nothing');
  end if;

  return v_out;
end
$function$
