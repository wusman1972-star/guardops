-- migrations/0015_plan_given_truncate_guard.sql

-- 15. plan_given truncate guard
-- Hole 795: TRUNCATE bypasses the row-level append-only triggers and fires nothing.
-- This statement-level BEFORE TRUNCATE trigger closes that gap.

CREATE FUNCTION guardops.plan_given_no_truncate()
    RETURNS trigger LANGUAGE plpgsql AS
$$
BEGIN
    RAISE EXCEPTION 'plan_given: the recorded plan cannot be wiped; TRUNCATE is not permitted';
END;
$$;

CREATE TRIGGER plan_given_no_truncate
    BEFORE TRUNCATE ON guardops.plan_given
    FOR EACH STATEMENT EXECUTE FUNCTION guardops.plan_given_no_truncate();
