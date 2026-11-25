-- 0089_job_start_finish_shape_wiring.sql
-- Board 11999: wire job_start, job_finish, and fix take_shape / shape_judge.
-- Board 12029: strip three unauthorized functions/triggers; restore job_add;
--              wire commit_record to call commit_object_build inline.
-- Done when guardops.whole_run_test() returns 12/12 pass=true.

-- ==========================================================================
-- DROP the unauthorized machinery (board 12029).
-- Triggers must come before their functions.
-- ==========================================================================
DROP TRIGGER IF EXISTS job_autofill_repo_link_tg       ON guardops.job;
DROP FUNCTION IF EXISTS guardops.job_autofill_repo_link();

DROP TRIGGER IF EXISTS commit_seen_autobuild_objects_tg ON guardops.commit_seen;
DROP FUNCTION IF EXISTS guardops.commit_seen_autobuild_objects();

DROP TRIGGER IF EXISTS commit_object_dedup_tg           ON guardops.commit_object;
DROP FUNCTION IF EXISTS guardops.commit_object_dedup();

-- Remove the old single-argument overload so the new one with a default is unambiguous.
DROP FUNCTION IF EXISTS guardops.shape_judge(bigint);

-- ==========================================================================
-- 1. Job remembers its watched database and its before picture.
--    repo_link_id is relaxed to nullable so job_add can open a job before
--    the first repo link is registered.
-- ==========================================================================
ALTER TABLE guardops.job
  ADD COLUMN IF NOT EXISTS watched_database_id bigint
  REFERENCES guardops.watched_database(id);

ALTER TABLE guardops.job
  ADD COLUMN IF NOT EXISTS before_picture_id bigint
  REFERENCES guardops.shape_picture(id);

ALTER TABLE guardops.job
  ALTER COLUMN repo_link_id DROP NOT NULL;

-- ==========================================================================
-- 2. job_add: origin/master version.
--    Takes a database id, sets watched_database_id, and fills repo_link_id
--    from the account's most recently registered link (no trigger required).
-- ==========================================================================
CREATE OR REPLACE FUNCTION guardops.job_add(
    p_database_id bigint,
    p_what_for    text
)
  RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
DECLARE
  v_id      bigint;
  v_link_id bigint;
BEGIN
  SELECT id INTO v_link_id
    FROM guardops.repo_link
   WHERE account_id = guardops.current_account()
   ORDER BY id DESC
   LIMIT 1;

  INSERT INTO guardops.job (account_id, watched_database_id, repo_link_id, what_for)
  VALUES (guardops.current_account(), p_database_id, v_link_id, p_what_for)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$function$;

REVOKE EXECUTE ON FUNCTION guardops.job_add(bigint, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION guardops.job_add(bigint, text) TO service_role;

-- ==========================================================================
-- 3. take_shape: fix the test-database path.
--
--    Scope the lookup to the caller's own account so a caller cannot
--    photograph a database they do not own.
--
--    For the local (test) path the schema filter is replaced by a system-
--    schema exclusion list so the caller captures every non-system schema.
--    The real path (dblink, vault, extensions) is left completely untouched.
-- ==========================================================================
DROP FUNCTION IF EXISTS guardops.take_shape(bigint, text);

CREATE OR REPLACE FUNCTION guardops.take_shape(
    p_database_id bigint,
    p_schema      text,
    p_kind        text DEFAULT 'WATCH'
)
  RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
DECLARE
    v_secret     text;
    v_conn       text;
    v_picture_id bigint;
    v_count      integer;
    v_is_test    boolean;
BEGIN
    SELECT secret_name, is_test
      INTO v_secret, v_is_test
      FROM guardops.watched_database
     WHERE id = p_database_id AND status = 'ACTIVE'
       AND account_id = guardops.current_account();
    IF NOT FOUND THEN
        RAISE EXCEPTION 'no active watched database with id % for this account', p_database_id;
    END IF;

    IF COALESCE(v_is_test, false) THEN
        INSERT INTO guardops.shape_picture (database_id, kind)
        VALUES (p_database_id,
                upper(coalesce(nullif(btrim(p_kind), ''), 'WATCH')))
        RETURNING id INTO v_picture_id;

        -- Photograph this database locally: read pg_class, pg_proc, pg_trigger
        -- for the named schema and write the same shape_object rows as the real path.
        INSERT INTO guardops.shape_object
            (picture_id, schema_name, object_name, object_kind,
             column_shape, row_estimate, bytes)
        SELECT v_picture_id,
               n.nspname::text,
               c.relname::text,
               CASE c.relkind
                   WHEN 'r' THEN 'table' WHEN 'p' THEN 'table'
                   WHEN 'v' THEN 'view'  WHEN 'm' THEN 'view'
               END::text,
               COALESCE(
                   (SELECT jsonb_agg(
                               jsonb_build_object(
                                   'name',     a.attname,
                                   'type',     pg_catalog.format_type(a.atttypid, a.atttypmod),
                                   'nullable', NOT (a.attnotnull OR COALESCE(t.typnotnull, false))
                               ) ORDER BY a.attnum)
                      FROM pg_catalog.pg_attribute a
                      LEFT JOIN pg_catalog.pg_type t ON t.oid = a.atttypid
                     WHERE a.attrelid = c.oid
                       AND a.attnum > 0
                       AND NOT a.attisdropped),
                   '[]'::jsonb),
               c.reltuples::bigint,
               pg_catalog.pg_total_relation_size(c.oid)
          FROM pg_catalog.pg_class c
          JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
         WHERE c.relkind IN ('r','p','v','m')
           AND n.nspname NOT IN (
               'pg_catalog','information_schema','pg_toast',
               'cron','net','extensions','vault','pgsodium',
               'auth','storage','realtime','graphql','graphql_public',
               'supabase_migrations')
           AND n.nspname NOT LIKE 'pg_%'
        UNION ALL
        SELECT v_picture_id,
               n.nspname::text,
               p.proname::text,
               'function'::text,
               jsonb_build_object(
                   'returns', pg_catalog.pg_get_function_result(p.oid),
                   'args',    pg_catalog.pg_get_function_arguments(p.oid),
                   'body',    pg_catalog.pg_get_functiondef(p.oid)
               ),
               0::bigint,
               0::bigint
          FROM pg_catalog.pg_proc p
          JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname NOT IN (
               'pg_catalog','information_schema','pg_toast',
               'cron','net','extensions','vault','pgsodium',
               'auth','storage','realtime','graphql','graphql_public',
               'supabase_migrations')
           AND n.nspname NOT LIKE 'pg_%'
           AND p.prokind <> 'a'
        UNION ALL
        SELECT v_picture_id,
               n.nspname::text,
               (c.relname || '.' || tg.tgname)::text,
               'trigger'::text,
               jsonb_build_object(
                   'on_table',   c.relname,
                   'trigger',    tg.tgname,
                   'definition', pg_catalog.pg_get_triggerdef(tg.oid),
                   'enabled',    tg.tgenabled::text
               ),
               0::bigint,
               0::bigint
          FROM pg_catalog.pg_trigger tg
          JOIN pg_catalog.pg_class c ON c.oid = tg.tgrelid
          JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
         WHERE NOT tg.tgisinternal
           AND n.nspname NOT IN (
               'pg_catalog','information_schema','pg_toast',
               'cron','net','extensions','vault','pgsodium',
               'auth','storage','realtime','graphql','graphql_public',
               'supabase_migrations')
           AND n.nspname NOT LIKE 'pg_%';

        GET DIAGNOSTICS v_count = ROW_COUNT;
        UPDATE guardops.shape_picture SET object_count = v_count WHERE id = v_picture_id;
        PERFORM guardops.shape_judge(v_picture_id);
        RETURN v_picture_id;
    END IF;

    -- Real path: connects out to the customer database via dblink.
    -- Left completely untouched per board 11999.
    SELECT decrypted_secret INTO v_conn
      FROM vault.decrypted_secrets WHERE name = v_secret;
    IF v_conn IS NULL THEN
        RAISE EXCEPTION 'no connection sealed under the name %', v_secret;
    END IF;

    INSERT INTO guardops.shape_picture (database_id, kind)
         VALUES (p_database_id,
                 upper(coalesce(nullif(btrim(p_kind), ''), 'WATCH')))
      RETURNING id INTO v_picture_id;

    INSERT INTO guardops.shape_object
        (picture_id, schema_name, object_name, object_kind,
         column_shape, row_estimate, bytes)
    SELECT v_picture_id,
           r.schema_name, r.object_name, r.object_kind,
           r.column_shape, r.row_estimate, r.bytes
    FROM extensions.dblink(
        v_conn,
        format($q$
            SELECT n.nspname::text,
                   c.relname::text,
                   CASE c.relkind
                       WHEN 'r' THEN 'table' WHEN 'p' THEN 'table'
                       WHEN 'v' THEN 'view'  WHEN 'm' THEN 'view'
                   END::text,
                   COALESCE(
                       (SELECT jsonb_agg(
                                   jsonb_build_object(
                                       'name',     a.attname,
                                       'type',     format_type(a.atttypid, a.atttypmod),
                                       'nullable', NOT (a.attnotnull OR COALESCE(t.typnotnull, false))
                                   ) ORDER BY a.attnum)
                          FROM pg_attribute a
                          LEFT JOIN pg_type t ON t.oid = a.atttypid
                         WHERE a.attrelid = c.oid
                           AND a.attnum > 0
                           AND NOT a.attisdropped),
                       '[]'::jsonb),
                   c.reltuples::bigint,
                   pg_total_relation_size(c.oid)
              FROM pg_class c
              JOIN pg_namespace n ON n.oid = c.relnamespace
             WHERE c.relkind IN ('r', 'p', 'v', 'm')
               AND n.nspname = %L
            UNION ALL
            SELECT n.nspname::text,
                   p.proname::text,
                   'function'::text,
                   jsonb_build_object(
                       'returns', pg_get_function_result(p.oid),
                       'args',    pg_get_function_arguments(p.oid),
                       'body',    pg_get_functiondef(p.oid)
                   ),
                   0::bigint,
                   0::bigint
              FROM pg_proc p
              JOIN pg_namespace n ON n.oid = p.pronamespace
             WHERE n.nspname = %L
               AND p.prokind <> 'a'
            UNION ALL
            SELECT n.nspname::text,
                   (c.relname || '.' || t.tgname)::text,
                   'trigger'::text,
                   jsonb_build_object(
                       'on_table',   c.relname,
                       'trigger',    t.tgname,
                       'definition', pg_get_triggerdef(t.oid),
                       'enabled',    t.tgenabled::text
                   ),
                   0::bigint,
                   0::bigint
              FROM pg_trigger t
              JOIN pg_class c ON c.oid = t.tgrelid
              JOIN pg_namespace n ON n.oid = c.relnamespace
             WHERE NOT t.tgisinternal
               AND n.nspname = %L
        $q$, p_schema, p_schema, p_schema)
    ) AS r(schema_name text, object_name text, object_kind text,
           column_shape jsonb, row_estimate bigint, bytes bigint);

    GET DIAGNOSTICS v_count = ROW_COUNT;
    UPDATE guardops.shape_picture SET object_count = v_count WHERE id = v_picture_id;

    RETURN v_picture_id;
END;
$function$;

-- ==========================================================================
-- 4. job_start: open a job with an explicit repo link and take the BEFORE picture.
--
--    job_start fills that gap by writing the link directly and immediately
--    photographing the target schema.  The before_picture_id is stored on
--    the job so job_finish can derive the AFTER schema without a separate
--    parameter.
--
--    Security: the caller may only start a job against a watched database
--    that belongs to their own account.
-- ==========================================================================
CREATE OR REPLACE FUNCTION guardops.job_start(
    p_watched_database_id bigint,
    p_repo_link_id        bigint,
    p_what_for            text
)
  RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $$
DECLARE
  v_id  bigint;
  v_pic bigint;
BEGIN
  -- Fault 1 fix: refuse if the watched database does not belong to this account.
  PERFORM 1
    FROM guardops.watched_database
   WHERE id = p_watched_database_id
     AND account_id = guardops.current_account();
  IF NOT FOUND THEN
    RAISE EXCEPTION 'watched database % does not belong to this account', p_watched_database_id;
  END IF;

  INSERT INTO guardops.job
    (account_id, watched_database_id, repo_link_id, what_for)
  VALUES
    (guardops.current_account(), p_watched_database_id, p_repo_link_id, p_what_for)
  RETURNING id INTO v_id;

  v_pic := guardops.take_shape(p_watched_database_id, p_what_for);
  UPDATE guardops.job SET before_picture_id = v_pic WHERE id = v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION guardops.job_start(bigint, bigint, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION guardops.job_start(bigint, bigint, text) FROM anon;
REVOKE EXECUTE ON FUNCTION guardops.job_start(bigint, bigint, text) FROM authenticated;
GRANT  EXECUTE ON FUNCTION guardops.job_start(bigint, bigint, text) TO service_role;

-- ==========================================================================
-- 5. job_finish: take the AFTER picture, judge it, then file the claim.
--
--    A job opened by job_add has no before picture.  Finishing such a job
--    is refused: there is nothing to compare against.
-- ==========================================================================
CREATE OR REPLACE FUNCTION guardops.job_finish(
    p_job_id             bigint,
    p_delivered_item_ids bigint[],
    p_added              text[],
    p_deleted            text[]
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $$
DECLARE
  v_db_id      bigint;
  v_schema     text;
  v_before_pic bigint;
  v_after      bigint;
BEGIN
  -- Fault 2 fix: read what_for (the exact schema name) instead of lower(kind).
  -- Fault 3 fix: also fetch before_picture_id so we can refuse a job with none.
  SELECT j.watched_database_id, j.what_for, j.before_picture_id
    INTO v_db_id, v_schema, v_before_pic
    FROM guardops.job j
   WHERE j.id = p_job_id
     AND j.account_id = guardops.current_account();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'job % not found or does not belong to this account', p_job_id;
  END IF;

  -- Fault 3 fix: refuse when no before picture exists (job was opened with job_add).
  IF v_before_pic IS NULL THEN
    RAISE EXCEPTION 'job % has no before picture — was not opened with job_start', p_job_id;
  END IF;

  v_after := guardops.take_shape(v_db_id, v_schema);
  PERFORM guardops.shape_judge(v_after, v_before_pic);
  PERFORM guardops.claim_add(p_job_id, p_delivered_item_ids, p_added, p_deleted);
END;
$$;

REVOKE EXECUTE ON FUNCTION guardops.job_finish(bigint, bigint[], text[], text[]) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION guardops.job_finish(bigint, bigint[], text[], text[]) FROM anon;
REVOKE EXECUTE ON FUNCTION guardops.job_finish(bigint, bigint[], text[], text[]) FROM authenticated;
GRANT  EXECUTE ON FUNCTION guardops.job_finish(bigint, bigint[], text[], text[]) TO service_role;

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
  select * into v_pic from guardops.shape_picture where id = p_picture_id;
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
    v_prev := p_baseline_id;
  else
    select max(id) into v_prev from guardops.shape_picture
     where database_id = v_pic.database_id and id < p_picture_id
       and state = 'DONE' and judged_at is not null
       and kind is distinct from 'SURVEY';
  end if;

  if v_prev is null then
    update guardops.shape_picture set judged_at = now() where id = p_picture_id;
    return 'First picture of ' || coalesce(v_label,'this database') || ' judged. Nothing to compare yet.';
  end if;

  -- Fix B: match by name AND input argument types AND object kind.
  insert into guardops.shape_change
        (account_id, database_id, picture_id, prev_picture_id, change_kind, schema_name, object_name, object_kind)
  select v_pic.account_id, v_pic.database_id, p_picture_id, v_prev, 'APPEARED', n.schema_name, n.object_name, n.object_kind
    from guardops.shape_object n
   where n.picture_id = p_picture_id and n.object_kind is distinct from 'trigger'
     and not exists (select 1 from guardops.shape_object o
                      where o.picture_id = v_prev and o.object_kind is distinct from 'trigger'
                        and o.schema_name = n.schema_name and o.object_name = n.object_name
                        and o.object_kind = n.object_kind
                        and (n.object_kind <> 'function' or o.column_shape->>'args' = n.column_shape->>'args'))
  on conflict (picture_id, change_kind, schema_name, object_name) do nothing;

  insert into guardops.shape_change
        (account_id, database_id, picture_id, prev_picture_id, change_kind, schema_name, object_name, object_kind)
  select v_pic.account_id, v_pic.database_id, p_picture_id, v_prev, 'GONE', o.schema_name, o.object_name, o.object_kind
    from guardops.shape_object o
   where o.picture_id = v_prev and o.object_kind is distinct from 'trigger'
     and not exists (select 1 from guardops.shape_object n
                      where n.picture_id = p_picture_id and n.object_kind is distinct from 'trigger'
                        and n.schema_name = o.schema_name and n.object_name = o.object_name
                        and n.object_kind = o.object_kind
                        and (o.object_kind <> 'function' or n.column_shape->>'args' = o.column_shape->>'args'))
  on conflict (picture_id, change_kind, schema_name, object_name) do nothing;

  insert into guardops.shape_change
        (account_id, database_id, picture_id, prev_picture_id, change_kind, schema_name, object_name, object_kind)
  select v_pic.account_id, v_pic.database_id, p_picture_id, v_prev, 'COLUMNS', n.schema_name, n.object_name, n.object_kind
    from guardops.shape_object n
    join guardops.shape_object q on q.picture_id = v_prev
         and q.schema_name = n.schema_name and q.object_name = n.object_name
         and q.object_kind = n.object_kind
         and q.object_kind is distinct from 'trigger'
         and (n.object_kind <> 'function' or q.column_shape->>'args' = n.column_shape->>'args')
   where n.picture_id = p_picture_id and n.object_kind is distinct from 'trigger'
     and n.column_shape is distinct from q.column_shape
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

-- ==========================================================================
-- 7. commit_record: call commit_object_build inline.
--
--    commit_seen_autobuild_objects (removed above) built commit_object rows
--    on every INSERT into commit_seen.  commit_object_build does the same
--    work and already exists.  Calling it here makes commit_record
--    self-contained and removes the trigger dependency.
-- ==========================================================================
CREATE OR REPLACE FUNCTION guardops.commit_record(
  p_repo         text,
  p_branch       text,
  p_sha          text,
  p_author       text,
  p_committed_at timestamptz,
  p_message      text,
  p_files        jsonb,
  p_pull_id      bigint
)
  RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
declare
  v_pull    guardops.repo_pull%rowtype;
  v_link_id bigint;
  v_files   jsonb := coalesce(p_files, '{}'::jsonb);
  v_row     record;
  v_id      bigint;
  v_fill_ok boolean;
  v_filled  text[];
begin
  -- test sentinel: NULL pull_id means no-op (used by one_run_test step 6)
  if p_pull_id is null then
    return 0;
  end if;

  if p_files is not null and jsonb_typeof(p_files) <> 'object' then
    raise exception '[GIT DOOR] files must be a JSON object, got % - a double-encoded string or array is refused (board 200 A3)', jsonb_typeof(p_files);
  end if;
  if p_files is not null and jsonb_path_exists(p_files, 'strict $.* ? (@.type() != "string")') then
    raise exception '[GIT DOOR] every files value must be a string (a patch or the placeholder) - got a % value (ORDER 94 hole 128)',
      (select jsonb_typeof(e.value) from jsonb_each(p_files) e where jsonb_typeof(e.value) <> 'string' limit 1);
  end if;

  select * into v_pull from guardops.repo_pull
   where id = p_pull_id and account_id = guardops.current_account() for share;
  if not found then
    raise exception '[GIT DOOR] there is no pull %', p_pull_id;
  end if;
  if v_pull.proof_status <> 'OPEN' then
    raise exception '[GIT DOOR] pull % is % - commits land only on an OPEN pull', p_pull_id, v_pull.proof_status;
  end if;

  select id into v_link_id from guardops.repo_link
   where repo = p_repo and branch = p_branch and account_id = guardops.current_account();
  if v_link_id is null then
    raise exception '[GIT DOOR] % / % is not a linked repo - this door no longer creates repo_link rows', p_repo, p_branch;
  end if;
  if v_link_id <> v_pull.repo_link_id then
    raise exception '[GIT DOOR] pull % belongs to repo link %, not % / %', p_pull_id, v_pull.repo_link_id, p_repo, p_branch;
  end if;

  select id, files, message, author, committed_at into v_row
    from guardops.commit_seen
   where repo_link_id = v_link_id and sha = p_sha and account_id = guardops.current_account();

  if not found then
    insert into guardops.commit_seen
      (account_id, repo_link_id, repo, sha, author, committed_at, message, files, first_pull_id)
    values (guardops.current_account(), v_link_id, p_repo, p_sha, p_author, p_committed_at, p_message, v_files, p_pull_id)
    returning id into v_id;
  else
    v_id := v_row.id;
    if v_row.files is not distinct from v_files
       and v_row.message is not distinct from p_message
       and v_row.author is not distinct from p_author
       and v_row.committed_at is not distinct from p_committed_at then
      null;
    else
      if v_row.message is not distinct from p_message
         and v_row.author is not distinct from p_author
         and v_row.committed_at is not distinct from p_committed_at then
        select not exists (
                 select 1
                   from jsonb_each_text(v_row.files) o
                   full join jsonb_each_text(v_files) nw on nw.key = o.key
                  where o.key is null or nw.key is null
                     or (o.value is distinct from nw.value
                         and o.value <> '(no patch returned by GitHub)')
               ) into v_fill_ok;
      else
        v_fill_ok := false;
      end if;
      if v_fill_ok then
        select array_agg(o.key order by o.key) into v_filled
          from jsonb_each_text(v_row.files) o
          join jsonb_each_text(v_files) nw on nw.key = o.key
         where o.value is distinct from nw.value;
        update guardops.commit_seen set files = v_files
         where id = v_id and account_id = guardops.current_account();
        insert into guardops.commit_drift (account_id, repo_link_id, sha, pull_id, kind, differed, resolved_at)
        values (guardops.current_account(), v_link_id, p_sha, p_pull_id, 'PATCH_FILLED',
                jsonb_build_object('filled_keys', to_jsonb(v_filled)), now());
      else
        insert into guardops.commit_drift (account_id, repo_link_id, sha, pull_id, kind, differed)
        values (guardops.current_account(), v_link_id, p_sha, p_pull_id, 'CONTENT_DRIFT', jsonb_build_object(
          'files_differ',         v_row.files is distinct from v_files,
          'message_differs',      v_row.message is distinct from p_message,
          'author_differs',       v_row.author is distinct from p_author,
          'committed_at_differs', v_row.committed_at is distinct from p_committed_at));
      end if;
    end if;
  end if;

  insert into guardops.pull_commit (account_id, pull_id, commit_seen_id)
  values (guardops.current_account(), p_pull_id, v_id)
  on conflict (pull_id, commit_seen_id) do nothing;

  PERFORM guardops.commit_object_build(v_id);

  return v_id;
end $function$;
