-- 1. plan_commit: append-only lock, same pattern as shape_object
DROP TRIGGER IF EXISTS plan_commit_cannot_be_changed ON guardops.plan_commit;
CREATE TRIGGER plan_commit_cannot_be_changed
  BEFORE DELETE OR UPDATE ON guardops.plan_commit
  FOR EACH ROW EXECUTE FUNCTION guardops.a_record_cannot_be_changed();

DROP TRIGGER IF EXISTS plan_commit_cannot_be_wiped ON guardops.plan_commit;
CREATE TRIGGER plan_commit_cannot_be_wiped
  BEFORE TRUNCATE ON guardops.plan_commit
  FOR EACH STATEMENT EXECUTE FUNCTION guardops.a_record_cannot_be_wiped();

-- 2. commit_seen: only the files column may be updated, and only to fill placeholders
CREATE OR REPLACE FUNCTION guardops.a_patch_can_only_be_filled()
  RETURNS trigger LANGUAGE plpgsql AS $function$
DECLARE
  v_fill_ok boolean;
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'commit_seen rows are permanent; DELETE is not permitted';
  END IF;
  -- UPDATE: raise if any column other than files differs from OLD
  IF (to_jsonb(OLD) - 'files') IS DISTINCT FROM (to_jsonb(NEW) - 'files') THEN
    RAISE EXCEPTION 'commit_seen: only the files column may be updated';
  END IF;
  -- UPDATE of files: validate the fill
  IF OLD.files IS DISTINCT FROM NEW.files THEN
    SELECT NOT EXISTS (
      SELECT 1
      FROM jsonb_each_text(COALESCE(OLD.files, '{}'::jsonb)) o
      FULL JOIN jsonb_each_text(COALESCE(NEW.files, '{}'::jsonb)) nw ON nw.key = o.key
      WHERE o.key IS NULL
         OR nw.key IS NULL
         OR (o.value IS DISTINCT FROM nw.value
             AND o.value <> '(no patch returned by GitHub)')
    ) INTO v_fill_ok;
    IF NOT v_fill_ok THEN
      RAISE EXCEPTION 'commit_seen.files: only placeholder values may be replaced; keys may not be added or removed';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS commit_seen_patch_can_only_be_filled ON guardops.commit_seen;
CREATE TRIGGER commit_seen_patch_can_only_be_filled
  BEFORE UPDATE OR DELETE ON guardops.commit_seen
  FOR EACH ROW EXECUTE FUNCTION guardops.a_patch_can_only_be_filled();

DROP TRIGGER IF EXISTS commit_seen_cannot_be_wiped ON guardops.commit_seen;
CREATE TRIGGER commit_seen_cannot_be_wiped
  BEFORE TRUNCATE ON guardops.commit_seen
  FOR EACH STATEMENT EXECUTE FUNCTION guardops.a_record_cannot_be_wiped();

-- 3. commit_object: derived rows rebuilt only by their door
CREATE OR REPLACE FUNCTION guardops.a_derived_row_is_rebuilt_only_by_its_door()
  RETURNS trigger LANGUAGE plpgsql AS $function$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION 'commit_object rows are derived; UPDATE is not permitted';
  END IF;
  -- DELETE: allow only when commit_object_build has set the flag
  IF coalesce(current_setting('guardops.rebuilding_commit_object', true), '') <> '1' THEN
    RAISE EXCEPTION 'commit_object rows may only be deleted by commit_object_build';
  END IF;
  RETURN OLD;
END;
$function$;

DROP TRIGGER IF EXISTS commit_object_rebuilt_only_by_its_door ON guardops.commit_object;
CREATE TRIGGER commit_object_rebuilt_only_by_its_door
  BEFORE UPDATE OR DELETE ON guardops.commit_object
  FOR EACH ROW EXECUTE FUNCTION guardops.a_derived_row_is_rebuilt_only_by_its_door();

DROP TRIGGER IF EXISTS commit_object_cannot_be_wiped ON guardops.commit_object;
CREATE TRIGGER commit_object_cannot_be_wiped
  BEFORE TRUNCATE ON guardops.commit_object
  FOR EACH STATEMENT EXECUTE FUNCTION guardops.a_record_cannot_be_wiped();

-- 4. commit_object_build: add set_config as first statement so DELETE is permitted
CREATE OR REPLACE FUNCTION guardops.commit_object_build(p_commit_seen_id bigint)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_n integer;
begin
  perform set_config('guardops.rebuilding_commit_object', '1', true);
  delete from guardops.commit_object where commit_seen_id = p_commit_seen_id;
  insert into guardops.commit_object (account_id, commit_seen_id, repo_link_id, committed_at, file_key, is_delete, obj_lines)
  select cs.account_id, cs.id, cs.repo_link_id, cs.committed_at, k.key,
         (cs.files->>k.key) ~ '^@@ -[0-9]+(,[0-9]+)? \+0,0 @@' as is_delete,
         case when k.key ~ '\.sql$' and k.key !~ '_rollback\.sql$'
              then (select string_agg(t.ln, chr(10) order by t.ord)
                      from regexp_split_to_table(cs.files->>k.key, chr(10)) with ordinality as t(ln, ord)
                     where t.ln ~ '^\+' and t.ln ~* '\y(create|alter|drop)\y')
              else null end as obj_lines
    from guardops.commit_seen cs
    cross join lateral jsonb_object_keys(case when jsonb_typeof(cs.files) = 'object' then cs.files else '{}'::jsonb end) as k(key)
   where cs.id = p_commit_seen_id;
  get diagnostics v_n = row_count;
  perform set_config('guardops.rebuilding_commit_object', '0', true);
  return v_n;
end
$function$;
