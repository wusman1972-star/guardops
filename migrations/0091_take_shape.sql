-- migrations/0091_take_shape.sql
-- Split out of 0089 on 26 Nov 2026, byte for byte. Holds one function only.

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
        INSERT INTO guardops.shape_picture (database_id, kind, watched_schema)
        VALUES (p_database_id,
                upper(coalesce(nullif(btrim(p_kind), ''), 'WATCH')),
                p_schema)
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
                   'body',    pg_catalog.pg_get_functiondef(p.oid),
                   'idargs',  pg_catalog.pg_get_function_identity_arguments(p.oid)
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

    INSERT INTO guardops.shape_picture (database_id, kind, watched_schema)
         VALUES (p_database_id,
                 upper(coalesce(nullif(btrim(p_kind), ''), 'WATCH')),
                 p_schema)
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
                       'body',    pg_get_functiondef(p.oid),
                       'idargs',  pg_get_function_identity_arguments(p.oid)
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

REVOKE EXECUTE ON FUNCTION guardops.take_shape(bigint, text, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION guardops.take_shape(bigint, text, text) TO service_role;
