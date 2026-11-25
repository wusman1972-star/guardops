revoke execute on all functions in schema guardops from public, anon, authenticated;
revoke execute on all procedures in schema guardops from public, anon, authenticated;
grant execute on all functions in schema guardops to service_role;
grant execute on all procedures in schema guardops to service_role;

create or replace function guardops.lock_new_doors() returns event_trigger language plpgsql as $x$
declare r record;
begin
  for r in select objid from pg_event_trigger_ddl_commands()
           where command_tag in ('CREATE FUNCTION','CREATE PROCEDURE')
             and schema_name = 'guardops'
  loop
    execute format('revoke execute on routine %s from public, anon, authenticated', r.objid::regprocedure);
    execute format('grant execute on routine %s to service_role', r.objid::regprocedure);
  end loop;
end $x$;

drop event trigger if exists guardops_lock_new_doors;
create event trigger guardops_lock_new_doors on ddl_command_end
  when tag in ('CREATE FUNCTION','CREATE PROCEDURE')
  execute function guardops.lock_new_doors();
