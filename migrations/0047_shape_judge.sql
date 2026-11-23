CREATE OR REPLACE FUNCTION guardops.shape_judge(p_picture_id bigint)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'guardops', 'public', 'pg_temp'
AS $function$
declare
  v_pic   record;
  v_prev  bigint;
  v_label text;
  v_added text; v_gone text; v_changed text;
  v_msg   text; v_ring bigint;
begin
  select * into v_pic from guardops.shape_picture where id = p_picture_id;
  if not found then raise exception 'no picture with id %', p_picture_id; end if;
  if v_pic.state <> 'DONE' then return 'picture ' || p_picture_id || ' is ' || v_pic.state || ', nothing to judge'; end if;
  if v_pic.judged_at is not null then return 'picture ' || p_picture_id || ' was already judged'; end if;

  select label into v_label from guardops.watched_database where id = v_pic.database_id;

  -- HOLE 276: a SURVEY is stamped judged so the round does not retry it, but it is
  -- never compared and never a comparison base for anything else.
  if upper(coalesce(v_pic.kind, 'WATCH')) = 'SURVEY' then
    update guardops.shape_picture set judged_at = now() where id = p_picture_id;
    return 'Survey picture ' || p_picture_id || ' of ' || coalesce(v_label,'this database')
        || ' recorded; a survey sits outside the compare chain (hole 276).';
  end if;

  select max(id) into v_prev from guardops.shape_picture
   where database_id = v_pic.database_id and id < p_picture_id
     and state = 'DONE' and judged_at is not null
     and kind is distinct from 'SURVEY';

  if v_prev is null then
    update guardops.shape_picture set judged_at = now() where id = p_picture_id;
    return 'First picture of ' || coalesce(v_label,'this database') || ' judged. Nothing to compare yet.';
  end if;

  -- ====================================================================
  -- HOLE 269 PIECE 1 (board 2291): the re-shape RECORDS what changed.
  -- Persist the FULL set of differences against the standing picture v_prev into
  -- guardops.shape_change. This is the SEEING only - nothing is fitted, removed or
  -- told here (that is PIECE 2, forked on Waqar's auto-vs-approve question). The
  -- compare base (v_prev) and the trigger-excluding filter are exactly the ones the
  -- bell below uses, so these rows are the bell's rows without the 10-name cap.
  -- The board named change_seen for this; the floor wins: change_seen means "the
  -- customer has SEEN this on the website" and cannot carry per-table differences.
  -- ====================================================================
  insert into guardops.shape_change
        (account_id, database_id, picture_id, prev_picture_id, change_kind, schema_name, object_name, object_kind)
  select v_pic.account_id, v_pic.database_id, p_picture_id, v_prev, 'APPEARED', n.schema_name, n.object_name, n.object_kind
    from guardops.shape_object n
   where n.picture_id = p_picture_id and n.object_kind is distinct from 'trigger'
     and not exists (select 1 from guardops.shape_object o
                      where o.picture_id = v_prev and o.object_kind is distinct from 'trigger'
                        and o.schema_name = n.schema_name and o.object_name = n.object_name)
  on conflict (picture_id, change_kind, schema_name, object_name) do nothing;

  insert into guardops.shape_change
        (account_id, database_id, picture_id, prev_picture_id, change_kind, schema_name, object_name, object_kind)
  select v_pic.account_id, v_pic.database_id, p_picture_id, v_prev, 'GONE', o.schema_name, o.object_name, o.object_kind
    from guardops.shape_object o
   where o.picture_id = v_prev and o.object_kind is distinct from 'trigger'
     and not exists (select 1 from guardops.shape_object n
                      where n.picture_id = p_picture_id and n.object_kind is distinct from 'trigger'
                        and n.schema_name = o.schema_name and n.object_name = o.object_name)
  on conflict (picture_id, change_kind, schema_name, object_name) do nothing;

  insert into guardops.shape_change
        (account_id, database_id, picture_id, prev_picture_id, change_kind, schema_name, object_name, object_kind)
  select v_pic.account_id, v_pic.database_id, p_picture_id, v_prev, 'COLUMNS', n.schema_name, n.object_name, n.object_kind
    from guardops.shape_object n
    join guardops.shape_object q on q.picture_id = v_prev
         and q.schema_name = n.schema_name and q.object_name = n.object_name
         and q.object_kind is distinct from 'trigger'
   where n.picture_id = p_picture_id and n.object_kind is distinct from 'trigger'
     and n.column_shape is distinct from q.column_shape
  on conflict (picture_id, change_kind, schema_name, object_name) do nothing;
  -- end HOLE 269 PIECE 1 ------------------------------------------------

  select string_agg(schema_name||'.'||object_name, ', ') into v_added from (
    select schema_name, object_name from guardops.shape_object where picture_id = p_picture_id and object_kind is distinct from 'trigger'
    except select schema_name, object_name from guardops.shape_object where picture_id = v_prev and object_kind is distinct from 'trigger'
    order by 1,2 limit 10) a;
  select string_agg(schema_name||'.'||object_name, ', ') into v_gone from (
    select schema_name, object_name from guardops.shape_object where picture_id = v_prev and object_kind is distinct from 'trigger'
    except select schema_name, object_name from guardops.shape_object where picture_id = p_picture_id and object_kind is distinct from 'trigger'
    order by 1,2 limit 10) g;
  select string_agg(o.schema_name||'.'||o.object_name, ', ') into v_changed from (
    select o.schema_name, o.object_name from guardops.shape_object o
      join guardops.shape_object q on q.picture_id = v_prev
       and q.schema_name = o.schema_name and q.object_name = o.object_name
     where o.picture_id = p_picture_id and o.object_kind is distinct from 'trigger'
       and o.column_shape is distinct from q.column_shape
     order by 1,2 limit 10) o;

  update guardops.shape_picture set judged_at = now() where id = p_picture_id;

  if v_added is null and v_gone is null and v_changed is null then
    return 'Picture ' || p_picture_id || ' judged. Nothing changed in ' || coalesce(v_label,'this database') || '.';
  end if;

  v_msg := 'Something changed in ' || coalesce(v_label,'your database') || E'\n';
  if v_added   is not null then v_msg := v_msg || E'\nNew: ' || v_added; end if;
  if v_gone    is not null then v_msg := v_msg || E'\nGone: ' || v_gone; end if;
  if v_changed is not null then v_msg := v_msg || E'\nColumns changed: ' || v_changed; end if;
  v_msg := v_msg || E'\n\nNobody read any of your data to find this - only the shape.';

  -- guardops.ring_alarm cut: ring_alarm is a rule-engine call not present in the clean
  -- install database. The return below is adjusted to drop the ring reference (v_ring
  -- is never set, so the old bell-rung line would read "ring ?").
  return 'Picture ' || p_picture_id || ' judged, change found.';
end
$function$
