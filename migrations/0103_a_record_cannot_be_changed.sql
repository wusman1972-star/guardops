-- migrations/0103_a_record_cannot_be_changed.sql

-- Generic append-only guard for fact tables.
-- Uses TG_TABLE_NAME so one function covers all five tables.

CREATE FUNCTION guardops.a_record_cannot_be_changed()
    RETURNS trigger LANGUAGE plpgsql AS
$$
BEGIN
    RAISE EXCEPTION '% rows are append-only; UPDATE and DELETE are not permitted', TG_TABLE_NAME;
END;
$$;

CREATE FUNCTION guardops.a_record_cannot_be_wiped()
    RETURNS trigger LANGUAGE plpgsql AS
$$
BEGIN
    RAISE EXCEPTION '%: the recorded fact cannot be wiped; TRUNCATE is not permitted', TG_TABLE_NAME;
END;
$$;

-- claim

CREATE TRIGGER claim_cannot_be_changed
    BEFORE UPDATE OR DELETE ON guardops.claim
    FOR EACH ROW EXECUTE FUNCTION guardops.a_record_cannot_be_changed();

CREATE TRIGGER claim_cannot_be_wiped
    BEFORE TRUNCATE ON guardops.claim
    FOR EACH STATEMENT EXECUTE FUNCTION guardops.a_record_cannot_be_wiped();

-- commit_drift

CREATE TRIGGER commit_drift_cannot_be_changed
    BEFORE UPDATE OR DELETE ON guardops.commit_drift
    FOR EACH ROW EXECUTE FUNCTION guardops.a_record_cannot_be_changed();

CREATE TRIGGER commit_drift_cannot_be_wiped
    BEFORE TRUNCATE ON guardops.commit_drift
    FOR EACH STATEMENT EXECUTE FUNCTION guardops.a_record_cannot_be_wiped();

-- pull_commit

CREATE TRIGGER pull_commit_cannot_be_changed
    BEFORE UPDATE OR DELETE ON guardops.pull_commit
    FOR EACH ROW EXECUTE FUNCTION guardops.a_record_cannot_be_changed();

CREATE TRIGGER pull_commit_cannot_be_wiped
    BEFORE TRUNCATE ON guardops.pull_commit
    FOR EACH STATEMENT EXECUTE FUNCTION guardops.a_record_cannot_be_wiped();

-- shape_object

CREATE TRIGGER shape_object_cannot_be_changed
    BEFORE UPDATE OR DELETE ON guardops.shape_object
    FOR EACH ROW EXECUTE FUNCTION guardops.a_record_cannot_be_changed();

CREATE TRIGGER shape_object_cannot_be_wiped
    BEFORE TRUNCATE ON guardops.shape_object
    FOR EACH STATEMENT EXECUTE FUNCTION guardops.a_record_cannot_be_wiped();

-- write_record

CREATE TRIGGER write_record_cannot_be_changed
    BEFORE UPDATE OR DELETE ON guardops.write_record
    FOR EACH ROW EXECUTE FUNCTION guardops.a_record_cannot_be_changed();

CREATE TRIGGER write_record_cannot_be_wiped
    BEFORE TRUNCATE ON guardops.write_record
    FOR EACH STATEMENT EXECUTE FUNCTION guardops.a_record_cannot_be_wiped();
