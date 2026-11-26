-- migrations/0093_job_finish.sql
-- Split out of 0089 on 26 Nov 2026, byte for byte. Holds one function only.

-- ==========================================================================
-- 5. job_finish: take the AFTER picture, judge it, then file the claim.
--
--    Reads watched_schema (stored by job_start) so it photographs the same
--    schema as the before picture.  Refuses if no before picture exists or
--    if the after picture comes back empty.
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
  v_db_id         bigint;
  v_schema        text;
  v_before_pic    bigint;
  v_after_existing bigint;
  v_after         bigint;
  v_count         bigint;
BEGIN
  SELECT j.watched_database_id, j.watched_schema, j.before_picture_id, j.after_picture_id
    INTO v_db_id, v_schema, v_before_pic, v_after_existing
    FROM guardops.job j
   WHERE j.id = p_job_id
     AND j.account_id = guardops.current_account();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'job % not found or does not belong to this account', p_job_id;
  END IF;

  IF v_before_pic IS NULL THEN
    RAISE EXCEPTION 'job % has no before picture — was not opened with job_start', p_job_id;
  END IF;

  IF v_after_existing IS NOT NULL THEN
    RAISE EXCEPTION 'job % already finished with after picture % - job_finish may not be called twice', p_job_id, v_after_existing;
  END IF;

  v_after := guardops.take_shape(v_db_id, v_schema);

  -- Refuse an empty after picture — a job that photographed nothing proved nothing.
  SELECT object_count INTO v_count FROM guardops.shape_picture WHERE id = v_after;
  IF COALESCE(v_count, 0) = 0 THEN
    RAISE EXCEPTION 'job_finish: after picture for schema % returned no objects', v_schema;
  END IF;

  PERFORM guardops.shape_judge(v_after, v_before_pic);
  UPDATE guardops.job SET after_picture_id = v_after WHERE id = p_job_id;
  PERFORM guardops.claim_add(p_job_id, p_delivered_item_ids, p_added, p_deleted);
END;
$$;

REVOKE EXECUTE ON FUNCTION guardops.job_finish(bigint, bigint[], text[], text[]) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION guardops.job_finish(bigint, bigint[], text[], text[]) FROM anon;
REVOKE EXECUTE ON FUNCTION guardops.job_finish(bigint, bigint[], text[], text[]) FROM authenticated;
GRANT  EXECUTE ON FUNCTION guardops.job_finish(bigint, bigint[], text[], text[]) TO service_role;
