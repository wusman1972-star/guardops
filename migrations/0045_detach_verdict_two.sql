CREATE OR REPLACE FUNCTION guardops.detach_verdict(p_before bigint, p_after bigint)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
declare
  v_left int;
  v_ours text;
begin
  -- A verdict is only honest about a picture that was actually TAKEN. An empty,
  -- PENDING or FAILED after-picture has no objects, which would read as v_left=0 and
  -- hand back a false CLEAN that nobody looked at. Refuse to judge it.
  if not exists (select 1 from guardops.shape_picture where id = p_after and state = 'DONE') then
    return 'NOT PROVEN. Picture ' || p_after || ' is not a finished look, so nothing was seen yet.';
  end if;
  if not exists (select 1 from guardops.shape_object where picture_id = p_after) then
    return 'NOT PROVEN. Picture ' || p_after || ' holds no objects; the look did not return.';
  end if;

  -- ours, and only ours: anything still in schema guardops_watch, or any trigger of
  -- ours still sitting on one of the customer's tables (hole 277 made these visible).
  select count(*), string_agg(schema_name || '.' || object_name, ', ')
    into v_left, v_ours
    from guardops.shape_object
   where picture_id = p_after
     and ( schema_name = 'guardops_watch'
           or (object_kind = 'trigger' and coalesce((column_shape ->> 'ours')::boolean, false)) );

  if v_left = 0 then
    return 'CLEAN. Nothing of ours is left in your database - no guardops_watch schema, '
        || 'table or function, and none of our triggers on your tables. '
        || 'We did not look at anything of yours to say so, only the shape.';
  end if;

  return 'NOT CLEAN. ' || v_left || ' thing(s) of ours still here' || coalesce(' (' || v_ours || ')', '') || '.';
end
$function$
