ALTER TABLE guardops.customer_notice
  DROP CONSTRAINT customer_notice_kind_check;
ALTER TABLE guardops.customer_notice
  ADD CONSTRAINT customer_notice_kind_check
    CHECK (kind = ANY (ARRAY['CHANGED'::text, 'WRITE'::text, 'JOB'::text]));

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

  elsif p_kind = 'JOB' then
    v_head := 'GuardOps checked the work on ' || p_label;

    if coalesce(jsonb_array_length(p_facts->'delivered'), 0) > 0 then
      v_lines := v_lines || ('Delivered: ' || (select string_agg(value #>> '{}', ', ')
                                                from jsonb_array_elements(p_facts->'delivered')));
    end if;
    if coalesce(jsonb_array_length(p_facts->'missing'), 0) > 0 then
      v_lines := v_lines || ('Still outstanding: ' || (select string_agg(value #>> '{}', ', ')
                                                         from jsonb_array_elements(p_facts->'missing')));
    end if;
    if coalesce(jsonb_array_length(p_facts->'added'), 0) > 0 then
      v_lines := v_lines || ('Added but not in the plan: ' || (select string_agg(value #>> '{}', ', ')
                                                                 from jsonb_array_elements(p_facts->'added')));
    end if;
    if coalesce(jsonb_array_length(p_facts->'deleted'), 0) > 0 then
      v_lines := v_lines || ('Deleted: ' || (select string_agg(value #>> '{}', ', ')
                                              from jsonb_array_elements(p_facts->'deleted')));
    end if;

    if array_length(v_lines, 1) is null then
      v_body := 'GuardOps checked the work on ' || p_label || '.'
             || E'\n\nNothing in the plan changed.'
             || E'\n\nSee it here: ' || v_site
             || E'\n\n- GuardOps';
    else
      v_body := 'GuardOps checked the work on ' || p_label || '.'
             || E'\n\n' || array_to_string(v_lines, E'\n')
             || E'\n\nSee it here: ' || v_site
             || E'\n\n- GuardOps';
    end if;

  else
    v_head := 'GuardOps';
    v_body := 'Something happened on ' || p_label || '.' || E'\n\n- GuardOps';
  end if;

  return jsonb_build_object('headline', v_head, 'body', v_body);
end $function$;


CREATE OR REPLACE FUNCTION guardops.job_finish(p_job_id bigint, p_delivered_item_ids bigint[], p_added text[], p_deleted text[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_db_id          bigint;
  v_schema         text;
  v_before_pic     bigint;
  v_after_existing bigint;
  v_after          bigint;
  v_count          bigint;
  v_jlabel         text;
  v_jcust_id       bigint;
  v_jfacts         jsonb;
  v_jwords         jsonb;
BEGIN
  SELECT j.watched_database_id, j.watched_schema, j.before_picture_id, j.after_picture_id
    INTO v_db_id, v_schema, v_before_pic, v_after_existing
    FROM guardops.job j
   WHERE j.id = p_job_id
     AND j.account_id = guardops.current_account()
   FOR UPDATE;

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

  SELECT object_count INTO v_count FROM guardops.shape_picture WHERE id = v_after;
  IF COALESCE(v_count, 0) = 0 THEN
    RAISE EXCEPTION 'job_finish: after picture for schema % returned no objects', v_schema;
  END IF;

  PERFORM guardops.shape_judge(v_after, v_before_pic);
  UPDATE guardops.job SET after_picture_id = v_after WHERE id = p_job_id;
  PERFORM guardops.claim_add(p_job_id, p_delivered_item_ids, p_added, p_deleted);

  BEGIN
    SELECT
      jsonb_build_object(
        'delivered', to_jsonb(coalesce(array_agg(what ORDER BY what) FILTER (WHERE kind = 'DELIVERED'), '{}'::text[])),
        'missing',   to_jsonb(coalesce(array_agg(what ORDER BY what) FILTER (WHERE kind = 'MISSING'),   '{}'::text[])),
        'added',     to_jsonb(coalesce(array_agg(what ORDER BY what) FILTER (WHERE kind = 'ADDED'),     '{}'::text[])),
        'deleted',   to_jsonb(coalesce(array_agg(what ORDER BY what) FILTER (WHERE kind = 'DELETED'),   '{}'::text[]))
      )
    INTO v_jfacts
    FROM guardops.job_verdict(p_job_id)
    WHERE kind IN ('DELIVERED', 'MISSING', 'ADDED', 'DELETED');

    SELECT coalesce(nullif(btrim(d.label), ''), 'your database'), c.id
      INTO v_jlabel, v_jcust_id
      FROM guardops.watched_database d
      JOIN guardops.connected_account a ON a.id = d.connected_account_id
      JOIN guardops.customer c ON c.id = a.customer_id
     WHERE d.id = v_db_id;

    v_jwords := guardops.notice_words('JOB', v_jlabel, v_jfacts);

    INSERT INTO guardops.customer_notice (customer_id, database_id, kind, about, headline, body)
    VALUES (v_jcust_id, v_db_id, 'JOB', p_job_id, v_jwords->>'headline', v_jwords->>'body');

    PERFORM guardops.tell_send();
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING '[JOB FINISH] telling the customer failed for job %: %', p_job_id, left(sqlerrm, 300);
  END;
END;
$function$;
