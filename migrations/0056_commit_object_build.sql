-- Lift 9 of 9 (board 11865). Straight lift of commit_object_build from old floor
-- (lauttgnmksnxohigaqee guardops) to clean floor (mfysxqhediepzohzhufp guardops).
-- One change from the pg_get_functiondef body: search_path set to '' (empty)
-- because every name in the body is already fully qualified (guardops. prefix
-- throughout). Same rule applied on lift 8. No rule call found; none removed.

CREATE OR REPLACE FUNCTION guardops.commit_object_build(p_commit_seen_id bigint)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_n integer;
begin
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
  return v_n;
end
$function$;
