-- migrations/0125_the_picture_pointers_are_set_once.sql

-- ========================================================================
-- PREFLIGHT — refuse if 0125 already fired.
-- ========================================================================
DO $preflight$
BEGIN
  IF EXISTS (
    SELECT 1
      FROM pg_catalog.pg_trigger t
      JOIN pg_catalog.pg_class c ON c.oid = t.tgrelid
      JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'guardops'
       AND c.relname = 'job'
       AND t.tgname  = 'job_pointers_are_set_once'
  ) THEN
    RAISE EXCEPTION '0125 REFUSED: trigger job_pointers_are_set_once already exists on guardops.job (already applied).';
  END IF;
END $preflight$;

-- ========================================================================
-- TRIGGER FUNCTION
-- ========================================================================
CREATE FUNCTION guardops.a_picture_pointer_is_set_once()
    RETURNS trigger LANGUAGE plpgsql AS
$$
BEGIN
    IF OLD.before_picture_id IS NOT NULL
       AND NEW.before_picture_id IS DISTINCT FROM OLD.before_picture_id THEN
        RAISE EXCEPTION 'job %: before_picture_id cannot be repointed once set', OLD.id;
    END IF;

    IF OLD.after_picture_id IS NOT NULL
       AND NEW.after_picture_id IS DISTINCT FROM OLD.after_picture_id THEN
        RAISE EXCEPTION 'job %: after_picture_id cannot be repointed once set', OLD.id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER job_pointers_are_set_once
    BEFORE UPDATE ON guardops.job
    FOR EACH ROW EXECUTE FUNCTION guardops.a_picture_pointer_is_set_once();
