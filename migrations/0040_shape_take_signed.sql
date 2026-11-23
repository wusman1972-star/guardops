CREATE OR REPLACE FUNCTION guardops.shape_take_signed(p_picture_id bigint)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'guardops', 'extensions', 'pg_temp'
AS $function$
declare
  v_pic   record;
  v_reply record;
  v_body  jsonb;
  v_count integer;
  v_seen  text;
begin
  select * into v_pic from guardops.shape_picture where id = p_picture_id for update;
  if not found then raise exception 'no picture with id %', p_picture_id; end if;
  if v_pic.state <> 'PENDING' then raise exception 'picture % is already %', p_picture_id, v_pic.state; end if;

  select r.status_code, r.content into v_reply
    from net._http_response r where r.id = v_pic.request_id;
  if not found then return null; end if;
  if v_reply.status_code is null then return null; end if;

  begin
    v_body := v_reply.content::jsonb;
  exception when others then
    v_body := null;
  end;

  if v_reply.status_code <> 200 or not coalesce((v_body ->> 'ok')::boolean, false) then
    -- ORDER 0140: a refused key is named, counted and told about - not filed as "no".
    v_seen := lower(coalesce(v_body ->> 'why', coalesce(v_reply.content, '')));
    if v_reply.status_code in (401, 403)
       or v_seen like '%invalid access token%'
       or v_seen like '%invalid_token%'
       or v_seen like '%invalid_grant%'
       or v_seen like '%token expired%'
       or v_seen like '%unauthorized%' then
      perform guardops.signin_dead(p_picture_id, v_reply.status_code,
                                   coalesce(v_body ->> 'why', v_reply.content));
      return 0;
    end if;

    update guardops.shape_picture
       set state = 'FAILED',
           failed_why = left(coalesce(v_body ->> 'why', coalesce(v_reply.content,'')), 300)
     where id = p_picture_id;
    return 0;
  end if;

  insert into guardops.shape_object
    (picture_id, schema_name, object_name, object_kind, column_shape, row_estimate, bytes)
  select p_picture_id, r.schema_name, r.object_name, r.object_kind,
         r.column_shape, r.row_estimate, r.bytes
    from jsonb_to_recordset((v_body ->> 'rows')::jsonb)
         as r(schema_name text, object_name text, object_kind text,
              column_shape jsonb, row_estimate bigint, bytes bigint);

  get diagnostics v_count = row_count;
  update guardops.shape_picture set object_count = v_count, state = 'DONE' where id = p_picture_id;

  -- guardops.signin_refusal_clear cut per board 11834 (rule machinery not carried across)

  return v_count;
end
$function$
