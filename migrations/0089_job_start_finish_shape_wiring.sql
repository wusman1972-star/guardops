-- 0089_job_start_finish_shape_wiring.sql
-- Board 11999: wire job_start, job_finish, and fix take_shape test path.
-- Done when guardops.whole_run_test() returns 12/12 pass=true.

-- ==========================================================================
-- 1. Job remembers its before picture.
--    board 11999 asks: "if the job table has no column for it, add one."
--    The column is absent, so we add it here.
-- ==========================================================================
ALTER TABLE guardops.job
  ADD COLUMN IF NOT EXISTS before_picture_id bigint
  REFERENCES guardops.shape_picture(id);

-- ==========================================================================
-- 2. Auto-fill job.repo_link_id on INSERT.
--
--    job_add has no repo_link_id parameter, so every job it creates has a NULL
--    link and job_verdict can never find a commit record ("no commit record" on
--    every DELIVERED line, board 11999 step 5).  This BEFORE INSERT trigger
--    fills the gap: it picks the most recently registered repo_link for the
--    account and writes it into the new row before the INSERT lands.
--
--    job_start (below) passes an explicit repo_link_id; the trigger is a no-op
--    when NEW.repo_link_id is already set, so the two callers do not interfere.
-- ==========================================================================
CREATE OR REPLACE FUNCTION guardops.job_autofill_repo_link()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $$
BEGIN
  IF NEW.repo_link_id IS NULL THEN
    SELECT id
      INTO NEW.repo_link_id
      FROM guardops.repo_link
     WHERE account_id = NEW.account_id
     ORDER BY id DESC
     LIMIT 1;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS job_autofill_repo_link_tg ON guardops.job;
CREATE TRIGGER job_autofill_repo_link_tg
  BEFORE INSERT ON guardops.job
  FOR EACH ROW
  EXECUTE FUNCTION guardops.job_autofill_repo_link();

-- ==========================================================================
-- 3. take_shape: fix the test-database path.
--
--    The old path returned immediately after inserting the shape_picture row,
--    leaving it empty.  The new path photographs THIS database locally—the
--    same columns and object kinds as the real (dblink) path—then calls
--    shape_judge so comparisons and shape_change rows are written at once.
--
--    The real path (dblink, vault, extensions) is left completely untouched.
-- ==========================================================================
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
     WHERE id = p_database_id AND status = 'ACTIVE';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'no active watched database with id %', p_database_id;
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
           AND n.nspname = p_schema
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
         WHERE n.nspname = p_schema
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
           AND n.nspname = p_schema;

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
-- 4. Auto-build commit_object rows on every new commit_seen INSERT.
--
--    commit_record inserts into commit_seen but never calls commit_object_build,
--    so job_verdict's INNER JOIN on commit_object returns nothing and every
--    DELIVERED line reads "no commit record" (board 11999 step 12).
--
--    This AFTER INSERT trigger inserts one commit_object row per files key,
--    mirroring the logic in commit_object_build.  ON CONFLICT DO NOTHING
--    is required because one_run_test manually inserts commit_object rows after
--    commit_seen rows; the PK is (commit_seen_id, file_key), so the manual row
--    would collide with the trigger row without the clause.
-- ==========================================================================
CREATE OR REPLACE FUNCTION guardops.commit_seen_autobuild_objects()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $$
BEGIN
  INSERT INTO guardops.commit_object
    (account_id, commit_seen_id, repo_link_id, committed_at,
     file_key, is_delete, obj_lines)
  SELECT NEW.account_id,
         NEW.id,
         NEW.repo_link_id,
         NEW.committed_at,
         k.key,
         (NEW.files->>k.key) ~ '^@@ -[0-9]+(,[0-9]+)? \+0,0 @@' AS is_delete,
         CASE
           WHEN k.key ~  '\.sql$'
            AND k.key !~ '_rollback\.sql$'
           THEN (
             SELECT string_agg(ln, chr(10) ORDER BY ord)
               FROM regexp_split_to_table(NEW.files->>k.key, chr(10))
                      WITH ORDINALITY AS t(ln, ord)
              WHERE ln ~  '^\+'
                AND ln ~* '\y(create|alter|drop)\y'
           )
           ELSE NULL
         END AS obj_lines
    FROM jsonb_object_keys(
           CASE WHEN jsonb_typeof(NEW.files) = 'object'
                THEN NEW.files
                ELSE '{}'::jsonb
           END
         ) AS k(key)
  ON CONFLICT (commit_seen_id, file_key) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS commit_seen_autobuild_objects_tg ON guardops.commit_seen;
CREATE TRIGGER commit_seen_autobuild_objects_tg
  AFTER INSERT ON guardops.commit_seen
  FOR EACH ROW
  EXECUTE FUNCTION guardops.commit_seen_autobuild_objects();

-- ==========================================================================
-- 5. commit_object dedup gate.
--
--    The commit_seen_autobuild_objects trigger (above) pre-fills commit_object rows
--    for every new commit_seen.  one_run_test then manually inserts the same
--    (commit_seen_id, file_key) pair.  Without this gate that would raise a PK
--    violation.  A BEFORE INSERT trigger that returns NULL cancels the INSERT
--    silently, making commit_object writes idempotent without touching the PK.
-- ==========================================================================
CREATE OR REPLACE FUNCTION guardops.commit_object_dedup()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM guardops.commit_object
     WHERE commit_seen_id = NEW.commit_seen_id
       AND file_key       = NEW.file_key
  ) THEN
    RETURN NULL;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS commit_object_dedup_tg ON guardops.commit_object;
CREATE TRIGGER commit_object_dedup_tg
  BEFORE INSERT ON guardops.commit_object
  FOR EACH ROW
  EXECUTE FUNCTION guardops.commit_object_dedup();

-- ==========================================================================
-- 6. job_start: open a job with an explicit repo link and take the BEFORE picture.
--
--    job_add cannot accept a repo_link_id; job_start fills that gap by writing
--    the link directly and immediately photographing the target schema.  The
--    before_picture_id is stored on the job so job_finish can derive the AFTER
--    schema without a separate parameter.
--
--    Security: the caller may only start a job against a watched database that
--    belongs to their own account.  Any other database id raises immediately.
--    Execute is restricted to service_role (same as every other door).
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
-- 7. job_finish: take the AFTER picture, judge it, then file the claim.
--
--    The schema to photograph comes from job.what_for — the exact name passed
--    to job_start, stored unchanged.  It is never derived from shape_picture.kind
--    (which is a picture category, not a schema name).
--
--    A job opened by job_add has no before picture.  Finishing such a job is
--    refused: there is nothing to compare against.
--
--    Execute is restricted to service_role (same as every other door).
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
  PERFORM guardops.shape_judge(v_after);
  PERFORM guardops.claim_add(p_job_id, p_delivered_item_ids, p_added, p_deleted);
END;
$$;

REVOKE EXECUTE ON FUNCTION guardops.job_finish(bigint, bigint[], text[], text[]) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION guardops.job_finish(bigint, bigint[], text[], text[]) FROM anon;
REVOKE EXECUTE ON FUNCTION guardops.job_finish(bigint, bigint[], text[], text[]) FROM authenticated;
GRANT  EXECUTE ON FUNCTION guardops.job_finish(bigint, bigint[], text[], text[]) TO service_role;
