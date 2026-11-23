CREATE OR REPLACE FUNCTION guardops.shape_watch(p_database_id bigint)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
declare
  v_pic bigint; v_prev bigint; v_label text;
  v_added text; v_gone text; v_changed text;
  v_msg text;
begin
  select label into v_label from guardops.watched_database where id = p_database_id;
  v_pic := guardops.take_shape(p_database_id);
  select max(id) into v_prev from guardops.shape_picture
   where database_id = p_database_id and id < v_pic
     and kind is distinct from 'SURVEY';
  if v_prev is null then
    return 'First picture of ' || coalesce(v_label,'this database') || ' taken. Nothing to compare yet.';
  end if;

  select string_agg(schema_name||'.'||object_name, ', ') into v_added from (
    select schema_name, object_name from guardops.shape_object where picture_id = v_pic and object_kind is distinct from 'trigger'
    except select schema_name, object_name from guardops.shape_object where picture_id = v_prev and object_kind is distinct from 'trigger'
    order by 1,2 limit 10) a;
  select string_agg(schema_name||'.'||object_name, ', ') into v_gone from (
    select schema_name, object_name from guardops.shape_object where picture_id = v_prev and object_kind is distinct from 'trigger'
    except select schema_name, object_name from guardops.shape_object where picture_id = v_pic and object_kind is distinct from 'trigger'
    order by 1,2 limit 10) g;
  select string_agg(o.schema_name||'.'||o.object_name, ', ') into v_changed from (
    select o.schema_name, o.object_name from guardops.shape_object o
      join guardops.shape_object q on q.picture_id = v_prev
       and q.schema_name = o.schema_name and q.object_name = o.object_name
     where o.picture_id = v_pic and o.object_kind is distinct from 'trigger'
       and o.column_shape is distinct from q.column_shape
     order by 1,2 limit 10) o;

  if v_added is null and v_gone is null and v_changed is null then
    return 'Picture ' || v_pic || ' taken. Nothing changed in ' || coalesce(v_label,'this database') || '.';
  end if;

  v_msg := 'Something changed in ' || coalesce(v_label,'your database') || E'\n';
  if v_added   is not null then v_msg := v_msg || E'\nNew: ' || v_added; end if;
  if v_gone    is not null then v_msg := v_msg || E'\nGone: ' || v_gone; end if;
  if v_changed is not null then v_msg := v_msg || E'\nColumns changed: ' || v_changed; end if;
  v_msg := v_msg || E'\n\nNobody read any of your data to find this - only the shape.';

  return 'Picture ' || v_pic || ' taken, change found.';
end
$function$
