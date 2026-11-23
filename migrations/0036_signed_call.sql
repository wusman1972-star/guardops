CREATE OR REPLACE FUNCTION guardops.signed_call(p_database_id bigint, p_kind text, p_sql text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'guardops', 'extensions', 'pg_temp'
AS $function$
declare
  v_db  record;
  v_ca  record;
  v_key text;
  v_jwt text;
  v_req bigint;
begin
  if p_kind not in ('look','place') then
    raise exception 'kind must be look or place, not %', p_kind;
  end if;

  select * into v_db from guardops.watched_database
   where id = p_database_id and status = 'ACTIVE';
  if not found then raise exception 'no active watched database with id %', p_database_id; end if;
  if v_db.connect_mode <> 'SIGNED' then
    raise exception 'watched database % is not a signed-in connection', p_database_id;
  end if;

  -- ORDER 0140: resolve forward. connected_account_id records which sign-in first
  -- connected this database; the call travels on the customer's current one.
  select * into v_ca from guardops.connected_account
   where id = guardops.live_signin(p_database_id);
  if not found then raise exception 'no live sign-in behind watched database %', p_database_id; end if;

  select decrypted_secret into v_key from vault.decrypted_secrets where name = 'GUARDOPS_REFRESH_KEY';
  select decrypted_secret into v_jwt from vault.decrypted_secrets where name = 'FACTORY_PULL_GATEWAY_JWT';
  if v_key is null or v_jwt is null then raise exception 'the floor key or the gateway key is not sealed'; end if;

  -- Only the NAME of the sealed key travels here. The key itself never enters
  -- net.http_request_queue, which every login role on this floor can read.
  select net.http_post(
    url := 'https://lauttgnmksnxohigaqee.supabase.co/functions/v1/database-call',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || v_jwt,
      'x-guardops-refresh-key', v_key,
      'Content-Type', 'application/json'),
    body := jsonb_build_object(
      'secret_name', v_ca.token_secret_name,
      'project_ref', v_db.project_ref,
      'kind', p_kind,
      'sql', p_sql),
    timeout_milliseconds := 60000
  ) into v_req;

  return v_req;
end
$function$
