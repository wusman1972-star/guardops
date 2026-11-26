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
  ADD COLUMN IF NOT EXISTS after_picture_id bigint
  REFERENCES guardops.shape_picture(id);

ALTER TABLE guardops.job
  ADD COLUMN IF NOT EXISTS watched_schema text;

ALTER TABLE guardops.job
  ALTER COLUMN repo_link_id DROP NOT NULL;

-- ==========================================================================
-- 2. shape_picture records which schema was photographed (board 12052).
-- ==========================================================================
ALTER TABLE guardops.shape_picture
  ADD COLUMN IF NOT EXISTS watched_schema text;


-- 26 Nov 2026: the six function rewrites that used to live here were split into
-- 0090 shape_judge, 0091 take_shape, 0092 job_start, 0093 job_finish,
-- 0094 commit_record and 0095 job_verdict. This file now holds only the drops
-- and the table columns they all depend on.
