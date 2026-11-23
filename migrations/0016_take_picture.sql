-- migrations/0016_take_picture.sql

-- 16. take_picture
-- One function: takes (database_id, schema_name), reads that schema live from
-- the catalog, writes one shape_picture row and one shape_object row per object
-- (tables, functions, triggers). Returns the new picture id.

CREATE FUNCTION guardops.take_picture(
    p_database_id bigint,
    p_schema      text
) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_picture_id bigint;
    v_obj_count  integer := 0;
    v_col_shape  jsonb;
    v_tbl        record;
    v_fn         record;
    v_trg        record;
BEGIN
    INSERT INTO guardops.shape_picture (database_id, kind, source)
    VALUES (p_database_id, p_schema, 'CONNECTION')
    RETURNING id INTO v_picture_id;

    -- One row per table; columns packed into column_shape as ordered jsonb array
    FOR v_tbl IN
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = p_schema
          AND table_type   = 'BASE TABLE'
        ORDER BY table_name
    LOOP
        SELECT jsonb_agg(
            jsonb_build_object(
                'name',     column_name,
                'type',     udt_name,
                'position', ordinal_position::int,
                'nullable', is_nullable
            ) ORDER BY ordinal_position
        )
        INTO v_col_shape
        FROM information_schema.columns
        WHERE table_schema = p_schema
          AND table_name   = v_tbl.table_name;

        INSERT INTO guardops.shape_object (
            picture_id, schema_name, object_name, object_kind,
            column_shape, row_estimate, bytes
        )
        SELECT
            v_picture_id,
            p_schema,
            v_tbl.table_name,
            'TABLE',
            COALESCE(v_col_shape, '[]'::jsonb),
            greatest(0, c.reltuples::bigint),
            c.relpages::bigint * 8192
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = p_schema
          AND c.relname = v_tbl.table_name;

        IF FOUND THEN
            v_obj_count := v_obj_count + 1;
        END IF;
    END LOOP;

    -- One row per function (overloads each get their own row via specific_name)
    FOR v_fn IN
        SELECT r.routine_name,
               r.specific_name,
               r.data_type AS return_type
        FROM information_schema.routines r
        WHERE r.specific_schema = p_schema
          AND r.routine_type    = 'FUNCTION'
        ORDER BY r.routine_name, r.specific_name
    LOOP
        SELECT jsonb_build_object(
            'specific_name', v_fn.specific_name,
            'return_type',   v_fn.return_type,
            'args', COALESCE(
                (SELECT jsonb_agg(
                    jsonb_build_object(
                        'name', COALESCE(p.parameter_name, '$' || p.ordinal_position::text),
                        'type', p.udt_name,
                        'mode', p.parameter_mode
                    ) ORDER BY p.ordinal_position
                )
                FROM information_schema.parameters p
                WHERE p.specific_schema = p_schema
                  AND p.specific_name   = v_fn.specific_name
                  AND p.parameter_mode <> 'OUT'
                ),
                '[]'::jsonb
            )
        )
        INTO v_col_shape;

        INSERT INTO guardops.shape_object (
            picture_id, schema_name, object_name, object_kind, column_shape
        )
        VALUES (
            v_picture_id, p_schema, v_fn.routine_name, 'FUNCTION', v_col_shape
        );

        v_obj_count := v_obj_count + 1;
    END LOOP;

    -- One row per trigger; events decoded from pg_trigger.tgtype bitmask so that
    -- TRUNCATE triggers (absent from information_schema.triggers) are included.
    FOR v_trg IN
        SELECT
            t.tgname AS trigger_name,
            c.relname AS event_object_table,
            CASE
                WHEN t.tgtype & 2 > 0  THEN 'BEFORE'
                WHEN t.tgtype & 64 > 0 THEN 'INSTEAD OF'
                ELSE 'AFTER'
            END AS action_timing,
            (SELECT string_agg(e, ' OR ' ORDER BY e)
               FROM unnest(ARRAY[
                   CASE WHEN t.tgtype &  4 > 0 THEN 'INSERT'   END,
                   CASE WHEN t.tgtype &  8 > 0 THEN 'DELETE'   END,
                   CASE WHEN t.tgtype & 16 > 0 THEN 'UPDATE'   END,
                   CASE WHEN t.tgtype & 32 > 0 THEN 'TRUNCATE' END
               ]) AS e(e)
               WHERE e IS NOT NULL) AS events,
            pg_get_triggerdef(t.oid) AS action_statement
        FROM pg_catalog.pg_trigger t
        JOIN pg_catalog.pg_class c ON c.oid = t.tgrelid
        JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
        WHERE NOT t.tgisinternal
          AND n.nspname = p_schema
        ORDER BY t.tgname, c.relname
    LOOP
        INSERT INTO guardops.shape_object (
            picture_id, schema_name, object_name, object_kind, column_shape
        )
        VALUES (
            v_picture_id,
            p_schema,
            v_trg.trigger_name,
            'TRIGGER',
            jsonb_build_object(
                'table',     v_trg.event_object_table,
                'timing',    v_trg.action_timing,
                'events',    v_trg.events,
                'statement', v_trg.action_statement
            )
        );

        v_obj_count := v_obj_count + 1;
    END LOOP;

    UPDATE guardops.shape_picture
       SET object_count = v_obj_count
     WHERE id = v_picture_id;

    RETURN v_picture_id;
END;
$$;
