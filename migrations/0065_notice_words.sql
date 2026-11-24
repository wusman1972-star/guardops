-- LIFT: guardops.notice_words(p_kind text, p_label text, p_facts jsonb)
-- SOURCE md5 (pg_get_functiondef, old floor lauttgnmksnxohigaqee): 2c23e627df8ca7f0069e5a4bbdaaa63d
-- CHANGE 1 search_path - no guardops names in body; safe to empty:
--   BEFORE: SET search_path TO 'pg_temp'
--   AFTER:  SET search_path TO ''
-- CHANGE 2 none - this function names no guardops object.

CREATE OR REPLACE FUNCTION guardops.notice_words(p_kind text, p_label text, p_facts jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
declare
  v_site  text := 'https://guardops.flowops-hq.workers.dev';
  v_lines text[] := '{}';
  v_n int; v_head text; v_body text;
begin
  if p_kind = 'CHANGED' then
    if coalesce(jsonb_array_length(p_facts->'added_names'), 0) > 0 then
      v_lines := v_lines || ('New: ' || (select string_agg(value #>> '{}', ', ')
                                           from jsonb_array_elements(p_facts->'added_names')));
    end if;
    if coalesce(jsonb_array_length(p_facts->'gone_names'), 0) > 0 then
      v_lines := v_lines || ('Gone: ' || (select string_agg(value #>> '{}', ', ')
                                            from jsonb_array_elements(p_facts->'gone_names')));
    end if;
    if coalesce(jsonb_array_length(p_facts->'changed_names'), 0) > 0 then
      v_lines := v_lines || ('Different columns: ' || (select string_agg(value #>> '{}', ', ')
                                            from jsonb_array_elements(p_facts->'changed_names')));
    end if;

    v_head := 'Something changed in ' || p_label;
    v_body := 'Something changed in ' || p_label || '.'
           || E'\n\n' || array_to_string(v_lines, E'\n')
           || E'\n\nIf that was you or your team, nothing to do.'
           || E'\n\nNobody read any of your data to find this. GuardOps only looks at the shape of your database: the names of your tables and columns.'
           || E'\n\nSee it here: ' || v_site
           || E'\n\n- GuardOps';

  elsif p_kind = 'WRITE' then
    v_n := coalesce((p_facts->>'n')::int, 0);
    v_head := 'Someone changed data in ' || p_label;
    v_body := case when v_n = 1 then 'One change was made' else v_n || ' changes were made' end
           || ' to the tables you asked GuardOps to watch in ' || p_label || '.'
           || E'\n\nThe newest: ' || lower(coalesce(p_facts->>'operation', 'a change'))
           || ' on ' || coalesce(p_facts->>'table', 'a watched table')
           || ', ' || coalesce(p_facts->>'rows', '0') || ' rows.'
           || E'\n\nGuardOps recorded that the change happened. It did not read what was written.'
           || E'\n\nSee the record: ' || v_site
           || E'\n\n- GuardOps';
  else
    v_head := 'GuardOps';
    v_body := 'Something happened on ' || p_label || '.' || E'\n\n- GuardOps';
  end if;

  return jsonb_build_object('headline', v_head, 'body', v_body);
end $function$;
