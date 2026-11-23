CREATE OR REPLACE FUNCTION guardops.detach_verdict(p_after bigint)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
declare
  v_db     bigint;
  v_before bigint;
begin
  select database_id into v_db from guardops.shape_picture where id = p_after;
  if v_db is null then raise exception 'no picture with id %', p_after; end if;

  select max(id) into v_before from guardops.shape_picture
   where database_id = v_db and id < p_after
     and state = 'DONE' and kind is distinct from 'SURVEY';

  if v_before is null then
    return 'Cannot prove a clean detach yet: there is no earlier picture of this '
        || 'database to compare against. Take a picture before detaching.';
  end if;

  return guardops.detach_verdict(v_before, p_after);
end
$function$
