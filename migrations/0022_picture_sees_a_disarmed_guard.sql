-- migrations/0022_picture_sees_a_disarmed_guard.sql
-- Closes two disarm holes found by the reviewer on board 11709 (Majors):
--   1. Function bodies are now stored via pg_get_functiondef.
--      A rewrite of a guard body changes column_shape; the pictures differ.
--   2. Trigger firing state (tgenabled) is now stored alongside the definition.
--      ALTER TABLE ... DISABLE TRIGGER changes tgenabled from O to D;
--      the pictures differ.
-- Nothing else about the door changes.

CREATE OR REPLACE FUNCTION guardops.take_shape(
    p_database_id bigint,
    p_schema      text,
    p_kind        text DEFAULT 'WATCH'
) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_secret     text;
    v_conn       text;
    v_picture_id bigint;
    v_count      integer;
BEGIN
    SELECT secret_name INTO v_secret
      FROM guardops.watched_database
     WHERE id = p_database_id AND status = 'ACTIVE';
    IF v_secret IS NULL THEN
        RAISE EXCEPTION 'no active watched database with id %', p_database_id;
    END IF;

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
                                       'nullable', NOT a.attnotnull
                                   ) ORDER BY a.attnum)
                          FROM pg_attribute a
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
    UPDATE guardops.shape_picture
       SET object_count = v_count
     WHERE id = v_picture_id;

    RETURN v_picture_id;
END;
$$;
