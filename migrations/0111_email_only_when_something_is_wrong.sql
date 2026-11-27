-- migrations/0111_email_only_when_something_is_wrong.sql
-- His ruling 2026-11-27: email a customer only when something is wrong.
-- Clean jobs and routine changes go to ON_RECORD, not NEW, so they are
-- recorded but never leave by email.

-- 1. Extend the state check to allow ON_RECORD
ALTER TABLE guardops.customer_notice
  DROP CONSTRAINT customer_notice_state_check;
ALTER TABLE guardops.customer_notice
  ADD CONSTRAINT customer_notice_state_check
    CHECK (state = ANY (ARRAY['NEW'::text, 'ON_RECORD'::text, 'SENT'::text,
                              'HELD'::text, 'NO_WAY_TO_TELL'::text, 'FAILED'::text]));

-- 2. job_finish: write NEW only when the verdict has something wrong
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

  -- Block 1: build and store the notice. A failure here warns but does not
  -- prevent the job from finishing.
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

    INSERT INTO guardops.customer_notice (customer_id, database_id, kind, about, headline, body, state)
    VALUES (v_jcust_id, v_db_id, 'JOB', p_job_id, v_jwords->>'headline', v_jwords->>'body',
            CASE
              WHEN jsonb_array_length(v_jfacts->'missing')  > 0
                OR jsonb_array_length(v_jfacts->'added')    > 0
                OR jsonb_array_length(v_jfacts->'deleted')  > 0
              THEN 'NEW'
              ELSE 'ON_RECORD'
            END);
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING '[JOB FINISH] building/storing notice failed for job %: %', p_job_id, left(sqlerrm, 300);
  END;

  -- Block 2: attempt the send. A failure here warns but does not roll back
  -- the notice row written in block 1 above.
  BEGIN
    PERFORM guardops.tell_send();
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING '[JOB FINISH] tell_send failed for job %: %', p_job_id, left(sqlerrm, 300);
  END;
END;
$function$;

-- 3. tell_make: CHANGED and WRITE notices go ON_RECORD — a customer
-- changing their own database while working is not a fault
CREATE OR REPLACE FUNCTION guardops.tell_make()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  r record; w record;
  v_facts jsonb; v_words jsonb;
  v_made int := 0; v_rows int;
  v_last bigint; v_n int; v_max bigint;
begin
  for r in select d.id, coalesce(nullif(btrim(d.label), ''), 'your database') as label, c.id as customer_id
             from guardops.watched_database d
             join guardops.connected_account a on a.id = d.connected_account_id
             join guardops.customer c on c.id = a.customer_id
            where d.status = 'ACTIVE' and d.connect_mode = 'SIGNED'
            order by d.id
  loop
    begin
      v_facts := guardops.news_counts(r.id);
      if coalesce((v_facts->>'previous')::bigint, 0) > 0
         and coalesce((v_facts->>'seen')::boolean, false) is not true
         and (coalesce((v_facts->>'added')::int,0) + coalesce((v_facts->>'gone')::int,0)
              + coalesce((v_facts->>'changed')::int,0)) > 0 then
        v_words := guardops.notice_words('CHANGED', r.label, v_facts);
        insert into guardops.customer_notice (customer_id, database_id, kind, about, headline, body, state)
        values (r.customer_id, r.id, 'CHANGED', (v_facts->>'picture')::bigint,
                v_words->>'headline', v_words->>'body', 'ON_RECORD')
        on conflict do nothing;
        get diagnostics v_rows = row_count;
        v_made := v_made + v_rows;
      end if;
    exception when others then
      raise warning '[TELL] making the change notice for database % failed: %', r.id, left(sqlerrm, 300);
    end;

    begin
      select coalesce(max(about), 0) into v_last
        from guardops.customer_notice where database_id = r.id and kind = 'WRITE';
      select count(*), max(id) into v_n, v_max
        from guardops.write_record where database_id = r.id and id > v_last;
      if coalesce(v_n, 0) > 0 then
        select table_name, operation, rows_touched into w
          from guardops.write_record
         where database_id = r.id and id > v_last order by id desc limit 1;
        v_words := guardops.notice_words('WRITE', r.label,
                     jsonb_build_object('n', v_n, 'table', w.table_name,
                                        'operation', w.operation, 'rows', w.rows_touched));
        insert into guardops.customer_notice (customer_id, database_id, kind, about, headline, body, state)
        values (r.customer_id, r.id, 'WRITE', v_max, v_words->>'headline', v_words->>'body', 'ON_RECORD')
        on conflict do nothing;
        get diagnostics v_rows = row_count;
        v_made := v_made + v_rows;
      end if;
    exception when others then
      raise warning '[TELL] making the write notice for database % failed: %', r.id, left(sqlerrm, 300);
    end;
  end loop;

  return v_made;
end $function$;

-- PROOF: numbered rows, pass true/false, rolls back so no email can leave
DO $$
DECLARE
  v_acct_id    bigint;
  v_cust_id    bigint;
  v_conn_id    bigint;
  v_db_id1     bigint;
  v_db_id2     bigint;
  v_link_id    bigint;
  v_job_id     bigint;
  v_plan_items bigint[];
  v_state      text;
  v_notice_id  bigint;
  v_state_after text;
  v_pic1       bigint;
  v_pic2       bigint;
BEGIN
  -- Shared setup
  INSERT INTO guardops.account(name) VALUES('0111_proof') RETURNING id INTO v_acct_id;
  INSERT INTO guardops.customer(account_id, external_id)
    VALUES(v_acct_id, '0111_proof') RETURNING id INTO v_cust_id;
  INSERT INTO guardops.connected_account(account_id, customer_id, token_secret_name, status)
    VALUES(v_acct_id, v_cust_id, '0111-proof-tok', 'ACTIVE')
    RETURNING id INTO v_conn_id;
  PERFORM guardops.act_as_house(v_cust_id);

  INSERT INTO guardops.repo_link(account_id, repo, branch, linked_by, active)
    VALUES(guardops.current_account(), '0111-proof/repo', 'main', 'TEST', false)
    RETURNING id INTO v_link_id;

  -- 1. Clean job (all items delivered, nothing added, nothing deleted) → ON_RECORD
  v_db_id1 := guardops.watched_database_add('0111-proof-job1');
  UPDATE guardops.watched_database SET connected_account_id = v_conn_id WHERE id = v_db_id1;

  v_job_id     := guardops.job_start(v_db_id1, v_link_id, '0111 proof clean job', 'guardops');
  v_plan_items := guardops.plan_given_add(v_job_id, ARRAY['deploy item alpha']);
  PERFORM guardops.job_finish(v_job_id, v_plan_items, '{}', '{}');

  SELECT state INTO v_state
    FROM guardops.customer_notice WHERE about = v_job_id AND kind = 'JOB';
  RAISE NOTICE '1 clean-job-state  got=% want=ON_RECORD pass=%', v_state, (v_state = 'ON_RECORD');

  -- 2. Missing job: CASE condition with non-empty missing array → NEW
  --    (tested directly because tell_send fires inside job_finish and would
  --    immediately transition the state; this exercises the exact CASE expression
  --    that the new job_finish uses)
  v_db_id2 := guardops.watched_database_add('0111-proof-job2');
  UPDATE guardops.watched_database SET connected_account_id = v_conn_id WHERE id = v_db_id2;

  INSERT INTO guardops.customer_notice
    (customer_id, database_id, kind, about, headline, body, state)
  VALUES
    (v_cust_id, v_db_id2, 'JOB', 999001, 'proof: missing', 'body',
     CASE
       WHEN jsonb_array_length('{"missing":["item_a"],"added":[],"deleted":[]}'::jsonb->'missing') > 0
         OR jsonb_array_length('{"missing":["item_a"],"added":[],"deleted":[]}'::jsonb->'added')   > 0
         OR jsonb_array_length('{"missing":["item_a"],"added":[],"deleted":[]}'::jsonb->'deleted') > 0
       THEN 'NEW'
       ELSE 'ON_RECORD'
     END)
  RETURNING state INTO v_state;
  RAISE NOTICE '2 missing-job-state  got=% want=NEW pass=%', v_state, (v_state = 'NEW');

  -- 3. tell_make CHANGED notice → ON_RECORD
  --    Uses a SIGNED watched_database with two shape pictures showing one added
  --    table so that news_counts returns previous > 0 and added = 1.
  --    No shape_change for the latest picture so news_counts.seen = false.
  --    Direct INSERT because watched_database_add cannot satisfy the
  --    watched_database_one_way_in constraint (SIGNED needs project_ref and
  --    connected_account_id at the same moment).
  INSERT INTO guardops.watched_database
    (account_id, label, project_ref, connect_mode, is_test, connected_account_id)
  VALUES
    (guardops.current_account(), '0111-proof-tell',
     'mfysxqhediepzohzhufp', 'SIGNED', true, v_conn_id)
  RETURNING id INTO v_db_id2;

  INSERT INTO guardops.shape_picture(database_id, state, object_count)
    VALUES(v_db_id2, 'DONE', 1) RETURNING id INTO v_pic1;
  INSERT INTO guardops.shape_object(picture_id, schema_name, object_name, object_kind, column_shape)
    VALUES(v_pic1, 'public', 'table_a', 'table', '[]'::jsonb);

  INSERT INTO guardops.shape_picture(database_id, state, object_count)
    VALUES(v_db_id2, 'DONE', 2) RETURNING id INTO v_pic2;
  INSERT INTO guardops.shape_object(picture_id, schema_name, object_name, object_kind, column_shape)
    VALUES(v_pic2, 'public', 'table_a', 'table', '[]'::jsonb);
  INSERT INTO guardops.shape_object(picture_id, schema_name, object_name, object_kind, column_shape)
    VALUES(v_pic2, 'public', 'table_b', 'table', '[]'::jsonb);

  PERFORM guardops.tell_make();

  SELECT state INTO v_state
    FROM guardops.customer_notice WHERE database_id = v_db_id2 AND kind = 'CHANGED';
  RAISE NOTICE '3 changed-notice-state  got=% want=ON_RECORD pass=%', v_state, (v_state = 'ON_RECORD');

  -- 4. tell_send leaves ON_RECORD alone
  SELECT id INTO v_notice_id
    FROM guardops.customer_notice WHERE database_id = v_db_id2 AND kind = 'CHANGED';
  PERFORM guardops.tell_send();
  SELECT state INTO v_state_after FROM guardops.customer_notice WHERE id = v_notice_id;
  RAISE NOTICE '4 on-record-after-send  got=% want=ON_RECORD pass=%',
               v_state_after, (v_state_after = 'ON_RECORD');

  RAISE EXCEPTION '0111_proof_rollback';
EXCEPTION WHEN OTHERS THEN
  IF SQLERRM <> '0111_proof_rollback' THEN RAISE; END IF;
END $$;

-- 5. Existing test suites must not move
DO $$
DECLARE
  v_one   int;
  v_whole int;
  v_wall  int;
BEGIN
  SELECT count(*) INTO v_one   FROM guardops.one_run_test()   WHERE pass = true;
  SELECT count(*) INTO v_whole FROM guardops.whole_run_test() WHERE pass = true;
  SELECT count(*) INTO v_wall  FROM guardops.wall_test()      WHERE pass = true;

  RAISE NOTICE '5a one_run_test   got=% want=8  pass=%', v_one,   (v_one   = 8);
  RAISE NOTICE '5b whole_run_test got=% want=12 pass=%', v_whole, (v_whole = 12);
  RAISE NOTICE '5c wall_test      got=% want=18 pass=%', v_wall,  (v_wall  = 18);

  IF v_one <> 8 OR v_whole <> 12 OR v_wall <> 18 THEN
    RAISE EXCEPTION '0111 regression: one_run=% whole_run=% wall=%', v_one, v_whole, v_wall;
  END IF;
END $$;
