CREATE OR REPLACE FUNCTION guardops.shape_sweep()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'guardops', 'extensions', 'pg_temp'
AS $function$
declare
  v_pic   record;
  v_count integer;
  v_done  integer := 0;
  v_why   text;
begin
  for v_pic in
    select p.id
      from guardops.shape_picture p
      join net._http_response r on r.id = p.request_id
     where p.state = 'PENDING'
     order by p.id
  loop
    begin
      v_count := guardops.shape_take_signed(v_pic.id);
      if v_count is not null then
        v_done := v_done + 1;
      end if;
    exception when others then
      v_why := left(sqlerrm, 300);
      begin
        update guardops.shape_picture
           set state = 'FAILED', failed_why = 'collecting this picture failed: ' || v_why
         where id = v_pic.id and state = 'PENDING';
      exception when others then
        null;
      end;
      raise warning '[SHAPE SWEEP] picture % could not be collected: %', v_pic.id, v_why;
    end;
  end loop;

  update guardops.shape_picture
     set state = 'FAILED', failed_why = 'the database never answered'
   where state = 'PENDING'
     and taken_at < now() - interval '5 minutes';

  return v_done;
end
$function$
