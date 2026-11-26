-- migrations/0092_job_start.sql
-- Split out of 0089 on 26 Nov 2026, byte for byte. Holds one function only.

-- ==========================================================================
-- 4. job_start: open a job with an explicit schema to watch and take the BEFORE picture.
--
--    p_schema names the schema to photograph — it is distinct from p_what_for
--    (a human description) so a description that is not a real schema name can
--    never silently produce an empty picture.
--
--    Refuses a schema that does not exist (pg_namespace check for test databases;
--    empty-picture guard for real databases via dblink).  Refuses a database the
--    caller does not own.  Refuses when the picture comes back empty.
-- ==========================================================================
-- Drop the old 3-argument overload so there is no ambiguity.
DROP FUNCTION IF EXISTS guardops.job_start(bigint, bigint, text);

CREATE OR REPLACE FUNCTION guardops.job_start(
    p_watched_database_id bigint,
    p_repo_link_id        bigint,
    p_what_for            text,
    p_schema              text
)
  RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $$
DECLARE
  v_id      bigint;
  v_pic     bigint;
  v_is_test boolean;
  v_count   bigint;
BEGIN
  SELECT is_test INTO v_is_test
    FROM guardops.watched_database
   WHERE id = p_watched_database_id
     AND account_id = guardops.current_account();
  IF NOT FOUND THEN
    RAISE EXCEPTION 'watched database % does not belong to this account', p_watched_database_id;
  END IF;

  IF p_schema IS NULL OR btrim(p_schema) = '' THEN
    RAISE EXCEPTION 'job_start: p_schema must name a schema to watch';
  END IF;

  -- For test databases validate the schema exists locally.
  IF COALESCE(v_is_test, false) THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_catalog.pg_namespace WHERE nspname = p_schema
    ) THEN
      RAISE EXCEPTION 'job_start: schema % does not exist', p_schema;
    END IF;
  END IF;

  INSERT INTO guardops.job
    (account_id, watched_database_id, repo_link_id, what_for, watched_schema)
  VALUES
    (guardops.current_account(), p_watched_database_id, p_repo_link_id, p_what_for, p_schema)
  RETURNING id INTO v_id;

  v_pic := guardops.take_shape(p_watched_database_id, p_schema);

  -- Refuse an empty picture — a job that photographed nothing watched nothing.
  SELECT object_count INTO v_count FROM guardops.shape_picture WHERE id = v_pic;
  IF COALESCE(v_count, 0) = 0 THEN
    RAISE EXCEPTION 'job_start: schema % returned no objects — refusing empty picture', p_schema;
  END IF;

  UPDATE guardops.job SET before_picture_id = v_pic WHERE id = v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION guardops.job_start(bigint, bigint, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION guardops.job_start(bigint, bigint, text, text) FROM anon;
REVOKE EXECUTE ON FUNCTION guardops.job_start(bigint, bigint, text, text) FROM authenticated;
GRANT  EXECUTE ON FUNCTION guardops.job_start(bigint, bigint, text, text) TO service_role;
