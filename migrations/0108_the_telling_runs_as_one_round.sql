create or replace function guardops.tell_round()
  returns table(settled int, made int, sent int)
  language plpgsql
  security definer
  set search_path to ''
as $function$
declare
  v_settled int := 0;
  v_made    int := 0;
  v_sent    int := 0;
begin
  begin
    v_settled := guardops.tell_settle();
  exception when others then
    raise warning '[TELL] tell_settle failed in tell_round: %', left(sqlerrm, 300);
  end;

  begin
    v_made := guardops.tell_make();
  exception when others then
    raise warning '[TELL] tell_make failed in tell_round: %', left(sqlerrm, 300);
  end;

  begin
    v_sent := guardops.tell_send();
  exception when others then
    raise warning '[TELL] tell_send failed in tell_round: %', left(sqlerrm, 300);
  end;

  return query select v_settled, v_made, v_sent;
end;
$function$;

grant execute on function guardops.tell_round() to postgres, service_role;
