CREATE OR REPLACE FUNCTION guardops.signin_dead(p_picture_id bigint, p_status integer, p_answer text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'guardops', 'pg_temp'
AS $function$
declare
  v_pic      record;
  v_signin   bigint;
  v_row      record;
  v_label    text;
  v_run      integer;
  v_spare    bigint;
  v_killed   boolean := false;
begin
  select id, database_id into v_pic from guardops.shape_picture where id = p_picture_id;
  if not found then return false; end if;

  v_signin := guardops.live_signin(v_pic.database_id);
  select coalesce(nullif(btrim(label), ''), 'your database') into v_label
    from guardops.watched_database where id = v_pic.database_id;

  update guardops.shape_picture
     set state = 'FAILED',
         failed_why = left('the database would not accept the permission GuardOps holds ('
                        || coalesce(p_status::text, 'no answer') || ')'
                        || case when v_signin is null then ' and no live sign-in is on file'
                                else ' - sign-in ' || v_signin end, 300)
   where id = p_picture_id;

  if v_signin is null then return false; end if;

  -- guardops.signin_refusal_note cut per board 11830 (rule machinery not carried across)

  select id, account_id, provider, customer_id
    into v_row from guardops.connected_account where id = v_signin;

  -- S4: take the SAME lock the retirement takes before asking "is there a spare".
  -- Without it, a retirement committing between this read and the DEAD update
  -- could leave the customer with zero ACTIVE rows - the race this order exists
  -- to close, re-opened at the last step.
  perform guardops.signin_group_lock(v_row.account_id, v_row.customer_id, v_row.provider);

  -- L2: is there anything to fall back to? Only then may this row be called dead.
  select a.id into v_spare
    from guardops.connected_account a
   where a.account_id  = v_row.account_id
     and a.customer_id is not distinct from v_row.customer_id
     and a.provider    = v_row.provider
     and a.status      = 'ACTIVE'
     and a.id         <> v_row.id
   order by a.approved_at desc, a.id desc
   limit 1;

  if v_spare is not null then
    update guardops.connected_account set status = 'DEAD'
     where id = v_signin and status <> 'DEAD';
    v_killed := true;
  end if;

  if v_row.customer_id is null then return v_killed; end if;

  -- Told once, with the fix in it. 'CHANGED' is the kind the live constraint
  -- already allows; about = -1 is this notice's own reserved slot, so it cannot
  -- be blocked by the sign-in-again notice (-2) or by a real picture id from
  -- tell_make, which is always positive. See the header (T1).
  insert into guardops.customer_notice (customer_id, database_id, kind, about, headline, body)
  values (v_row.customer_id, v_pic.database_id, 'CHANGED', -1,
          'GuardOps cannot reach ' || v_label || ' any more',
          'GuardOps tried to look at ' || v_label || ' and was turned away three times in a row.'
          || E'\n\n' || 'The permission you gave it is no longer being accepted, so nothing is being watched on that database right now.'
          || E'\n\n' || 'Signing in again puts it back exactly as it was. Nothing you set up is lost.'
          || E'\n\n' || 'Nobody read any of your data. GuardOps only ever looks at the shape of your database.'
          || E'\n\n' || 'Sign in again here: https://guardops.flowops-hq.workers.dev'
          || E'\n\n' || '- GuardOps')
  on conflict do nothing;

  return v_killed;
end
$function$
