-- migrations/0090_shape_judge.sql
-- Split out of 0089 on 26 Nov 2026, byte for byte. Holds one function only.

-- ==========================================================================
-- 6. shape_judge: optional baseline + object-kind matching.
--
--    Fix A: accept an optional p_baseline_id.  When supplied it is validated
--    (must exist, be earlier, be DONE, not be a SURVEY, belong to the same
--    database and account) and used as the comparison base instead of the
--    auto-selected newest judged picture.
--
--    Fix B: match routines by name AND input argument types AND object kind,
--    so overloads and same-name objects of different kinds are never paired.
-- ==========================================================================
CREATE OR REPLACE FUNCTION guardops.shape_judge(
    p_picture_id  bigint,
    p_baseline_id bigint DEFAULT NULL
)
  RETURNS text
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'guardops', 'public', 'pg_temp'
AS $function$
declare
  v_pic   record;
  v_base  record;
  v_prev  bigint;
  v_label text;
  v_added text; v_gone text; v_changed text;
  v_msg   text;
begin
  select * into v_pic from guardops.shape_picture where id = p_picture_id for update;
  if not found then raise exception 'no picture with id %', p_picture_id; end if;
  if v_pic.state <> 'DONE' then
    return 'picture ' || p_picture_id || ' is ' || v_pic.state || ', nothing to judge';
  end if;
  -- Allow re-judging when an explicit baseline is supplied; guard only the auto path.
  if v_pic.judged_at is not null and p_baseline_id is null then
    return 'picture ' || p_picture_id || ' was already judged';
  end if;

  select label into v_label from guardops.watched_database where id = v_pic.database_id;

  if upper(coalesce(v_pic.kind, 'WATCH')) = 'SURVEY' then
    update guardops.shape_picture set judged_at = now() where id = p_picture_id;
    return 'Survey picture ' || p_picture_id || ' of ' || coalesce(v_label,'this database')
        || ' recorded; a survey sits outside the compare chain (hole 276).';
  end if;

  -- When re-judging with an explicit baseline, discard the prior comparison first.
  if p_baseline_id is not null and v_pic.judged_at is not null then
    delete from guardops.shape_change where picture_id = p_picture_id;
    update guardops.shape_picture set judged_at = null where id = p_picture_id;
  end if;

  -- Fix A: validate and use the explicit baseline when supplied.
  if p_baseline_id is not null then
    select * into v_base from guardops.shape_picture where id = p_baseline_id;
    if not found then
      raise exception 'baseline picture % does not exist', p_baseline_id;
    end if;
    if v_base.id >= p_picture_id then
      raise exception 'baseline picture % is not earlier than picture %', p_baseline_id, p_picture_id;
    end if;
    if v_base.state <> 'DONE' then
      raise exception 'baseline picture % is not DONE (state: %)', p_baseline_id, v_base.state;
    end if;
    if upper(coalesce(v_base.kind, 'WATCH')) = 'SURVEY' then
      raise exception 'baseline picture % is a survey; surveys may not be a comparison base', p_baseline_id;
    end if;
    if v_base.database_id <> v_pic.database_id then
      raise exception 'baseline picture % belongs to a different database than picture %', p_baseline_id, p_picture_id;
    end if;
    if v_base.account_id <> v_pic.account_id then
      raise exception 'baseline picture % belongs to a different account than picture %', p_baseline_id, p_picture_id;
    end if;
    if v_base.watched_schema is distinct from v_pic.watched_schema then
      raise exception 'baseline picture % watches schema % but picture % watches schema %',
        p_baseline_id, coalesce(v_base.watched_schema,'(unknown)'), p_picture_id, coalesce(v_pic.watched_schema,'(unknown)');
    end if;
    v_prev := p_baseline_id;
  else
    select max(id) into v_prev from guardops.shape_picture
     where database_id = v_pic.database_id and id < p_picture_id
       and state = 'DONE' and judged_at is not null
       and kind is distinct from 'SURVEY'
       and watched_schema = v_pic.watched_schema;
  end if;

  if v_prev is null then
    update guardops.shape_picture set judged_at = now() where id = p_picture_id;
    return 'First picture of ' || coalesce(v_label,'this database') || ' judged. Nothing to compare yet.';
  end if;

  -- Fix B: match by name AND input argument types AND object kind.
  insert into guardops.shape_change
        (account_id, database_id, picture_id, prev_picture_id, change_kind, schema_name, object_name, object_kind)
  select v_pic.account_id, v_pic.database_id, p_picture_id, v_prev, 'APPEARED', n.schema_name,
         case when n.object_kind = 'function'
              then n.object_name || '(' || coalesce(n.column_shape->>'args', '') || ')'
              else n.object_name end,
         n.object_kind
    from guardops.shape_object n
   where n.picture_id = p_picture_id and n.object_kind is distinct from 'trigger'
     and not exists (select 1 from guardops.shape_object o
                      where o.picture_id = v_prev and o.object_kind is distinct from 'trigger'
                        and o.schema_name = n.schema_name and o.object_name = n.object_name
                        and o.object_kind = n.object_kind
                        and (n.object_kind <> 'function' or
                             case when o.column_shape ? 'idargs' and n.column_shape ? 'idargs'
                                  then o.column_shape->>'idargs' = n.column_shape->>'idargs'
                                  else o.column_shape->>'args'   = n.column_shape->>'args'
                             end))
  on conflict (picture_id, change_kind, schema_name, object_name) do nothing;

  insert into guardops.shape_change
        (account_id, database_id, picture_id, prev_picture_id, change_kind, schema_name, object_name, object_kind)
  select v_pic.account_id, v_pic.database_id, p_picture_id, v_prev, 'GONE', o.schema_name,
         case when o.object_kind = 'function'
              then o.object_name || '(' || coalesce(o.column_shape->>'args', '') || ')'
              else o.object_name end,
         o.object_kind
    from guardops.shape_object o
   where o.picture_id = v_prev and o.object_kind is distinct from 'trigger'
     and not exists (select 1 from guardops.shape_object n
                      where n.picture_id = p_picture_id and n.object_kind is distinct from 'trigger'
                        and n.schema_name = o.schema_name and n.object_name = o.object_name
                        and n.object_kind = o.object_kind
                        and (o.object_kind <> 'function' or
                             case when o.column_shape ? 'idargs' and n.column_shape ? 'idargs'
                                  then o.column_shape->>'idargs' = n.column_shape->>'idargs'
                                  else o.column_shape->>'args'   = n.column_shape->>'args'
                             end))
  on conflict (picture_id, change_kind, schema_name, object_name) do nothing;

  insert into guardops.shape_change
        (account_id, database_id, picture_id, prev_picture_id, change_kind, schema_name, object_name, object_kind)
  select v_pic.account_id, v_pic.database_id, p_picture_id, v_prev, 'COLUMNS', n.schema_name,
         case when n.object_kind = 'function'
              then n.object_name || '(' || coalesce(n.column_shape->>'args', '') || ')'
              else n.object_name end,
         n.object_kind
    from guardops.shape_object n
    join guardops.shape_object q on q.picture_id = v_prev
         and q.schema_name = n.schema_name and q.object_name = n.object_name
         and q.object_kind = n.object_kind
         and q.object_kind is distinct from 'trigger'
         and (n.object_kind <> 'function' or
              case when q.column_shape ? 'idargs' and n.column_shape ? 'idargs'
                   then q.column_shape->>'idargs' = n.column_shape->>'idargs'
                   else q.column_shape->>'args'   = n.column_shape->>'args'
              end)
   where n.picture_id = p_picture_id and n.object_kind is distinct from 'trigger'
     and (n.column_shape - 'idargs') is distinct from (q.column_shape - 'idargs')
  on conflict (picture_id, change_kind, schema_name, object_name) do nothing;

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

  return 'Picture ' || p_picture_id || ' judged, change found.';
end
$function$;

REVOKE EXECUTE ON FUNCTION guardops.shape_judge(bigint, bigint) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION guardops.shape_judge(bigint, bigint) FROM anon;
REVOKE EXECUTE ON FUNCTION guardops.shape_judge(bigint, bigint) FROM authenticated;
GRANT  EXECUTE ON FUNCTION guardops.shape_judge(bigint, bigint) TO service_role;
