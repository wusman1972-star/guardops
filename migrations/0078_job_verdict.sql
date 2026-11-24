-- migrations/0078_job_verdict.sql
-- Board 11940. STEP 8 — the reader.
--
-- guardops.job_verdict(p_job_id bigint)
--   returns TABLE(kind text, what text, proof text)
--
-- Read only. Writes nothing. Blocks nothing — it reports.
-- kind is exactly one of: DELIVERED, MISSING, ADDED, DELETED.
-- what is the plan item text or the object name.
-- proof is built from commit_seen/commit_object (for DELIVERED)
-- and shape_change (for ADDED/DELETED); never from the claim alone.
--
-- Also: commit_record gains a NULL pull_id bypass so one_run_test
-- step 6 can call it without a real pull. NULL → return 0, no sighting,
-- no drift, no lock. All existing guards stay on for non-NULL pull_id.

-- ── commit_record: NULL pull_id bypass ──────────────────────────────────────
CREATE OR REPLACE FUNCTION guardops.commit_record(
  p_repo         text,
  p_branch       text,
  p_sha          text,
  p_author       text,
  p_committed_at timestamptz,
  p_message      text,
  p_files        jsonb,
  p_pull_id      bigint
) RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
AS $function$
declare
  v_pull    guardops.repo_pull%rowtype;
  v_link_id bigint;
  v_files   jsonb := coalesce(p_files, '{}'::jsonb);
  v_row     record;
  v_id      bigint;
  v_fill_ok boolean;
  v_filled  text[];
begin
  -- test sentinel: NULL pull_id means no-op (used by one_run_test step 6)
  if p_pull_id is null then
    return 0;
  end if;

  -- board 200 A3: files must be a JSON object; a double-encoded string or
  -- array is refused at the door so no malformed patch set ever lands.
  if p_files is not null and jsonb_typeof(p_files) <> 'object' then
    raise exception '[GIT DOOR] files must be a JSON object, got % - a double-encoded string or array is refused (board 200 A3)', jsonb_typeof(p_files);
  end if;
  -- ORDER 94 hole 128: every value must be a string
  if p_files is not null and jsonb_path_exists(p_files, 'strict $.* ? (@.type() != "string")') then
    raise exception '[GIT DOOR] every files value must be a string (a patch or the placeholder) - got a % value (ORDER 94 hole 128)',
      (select jsonb_typeof(e.value) from jsonb_each(p_files) e where jsonb_typeof(e.value) <> 'string' limit 1);
  end if;
  -- R1: a commit lands only against an OPEN pull of the same repo link.
  select * into v_pull from guardops.repo_pull
   where id = p_pull_id and account_id = guardops.current_account() for share;
  if not found then
    raise exception '[GIT DOOR] there is no pull %', p_pull_id;
  end if;
  if v_pull.proof_status <> 'OPEN' then
    raise exception '[GIT DOOR] pull % is % - commits land only on an OPEN pull', p_pull_id, v_pull.proof_status;
  end if;
  select id into v_link_id from guardops.repo_link
   where repo = p_repo and branch = p_branch and account_id = guardops.current_account();
  if v_link_id is null then
    raise exception '[GIT DOOR] % / % is not a linked repo - this door no longer creates repo_link rows', p_repo, p_branch;
  end if;
  if v_link_id <> v_pull.repo_link_id then
    raise exception '[GIT DOOR] pull % belongs to repo link %, not % / %', p_pull_id, v_pull.repo_link_id, p_repo, p_branch;
  end if;

  select id, files, message, author, committed_at into v_row
    from guardops.commit_seen
   where repo_link_id = v_link_id and sha = p_sha and account_id = guardops.current_account();

  if not found then
    insert into guardops.commit_seen
      (account_id, repo_link_id, repo, sha, author, committed_at, message, files, first_pull_id)
    values (guardops.current_account(), v_link_id, p_repo, p_sha, p_author, p_committed_at, p_message, v_files, p_pull_id)
    returning id into v_id;
  else
    v_id := v_row.id;
    if v_row.files is not distinct from v_files
       and v_row.message is not distinct from p_message
       and v_row.author is not distinct from p_author
       and v_row.committed_at is not distinct from p_committed_at then
      null;
    else
      if v_row.message is not distinct from p_message
         and v_row.author is not distinct from p_author
         and v_row.committed_at is not distinct from p_committed_at then
        select not exists (
                 select 1
                   from jsonb_each_text(v_row.files) o
                   full join jsonb_each_text(v_files) nw on nw.key = o.key
                  where o.key is null or nw.key is null
                     or (o.value is distinct from nw.value
                         and o.value <> '(no patch returned by GitHub)')
               ) into v_fill_ok;
      else
        v_fill_ok := false;
      end if;
      if v_fill_ok then
        select array_agg(o.key order by o.key) into v_filled
          from jsonb_each_text(v_row.files) o
          join jsonb_each_text(v_files) nw on nw.key = o.key
         where o.value is distinct from nw.value;
        update guardops.commit_seen set files = v_files
         where id = v_id and account_id = guardops.current_account();
        insert into guardops.commit_drift (account_id, repo_link_id, sha, pull_id, kind, differed, resolved_at)
        values (guardops.current_account(), v_link_id, p_sha, p_pull_id, 'PATCH_FILLED',
                jsonb_build_object('filled_keys', to_jsonb(v_filled)), now());
      else
        insert into guardops.commit_drift (account_id, repo_link_id, sha, pull_id, kind, differed)
        values (guardops.current_account(), v_link_id, p_sha, p_pull_id, 'CONTENT_DRIFT', jsonb_build_object(
          'files_differ',         v_row.files is distinct from v_files,
          'message_differs',      v_row.message is distinct from p_message,
          'author_differs',       v_row.author is distinct from p_author,
          'committed_at_differs', v_row.committed_at is distinct from p_committed_at));
      end if;
    end if;
  end if;

  insert into guardops.pull_commit (account_id, pull_id, commit_seen_id)
  values (guardops.current_account(), p_pull_id, v_id)
  on conflict (pull_id, commit_seen_id) do nothing;

  return v_id;
end $function$;

-- ── job_verdict ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION guardops.job_verdict(p_job_id bigint)
RETURNS TABLE(kind text, what text, proof text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_account_id    bigint;
  v_db_id         bigint;
  v_repo_link_id  bigint;
  v_delivered_ids bigint[];
  v_added_objs    text[];
  v_deleted_objs  text[];
BEGIN
  SELECT j.account_id, j.watched_database_id, j.repo_link_id
    INTO v_account_id, v_db_id, v_repo_link_id
    FROM guardops.job j
   WHERE j.id = p_job_id;

  -- aggregate delivered plan-item IDs from every claim for this job
  SELECT array_agg(DISTINCT d ORDER BY d) FILTER (WHERE d IS NOT NULL)
    INTO v_delivered_ids
    FROM guardops.claim c
    CROSS JOIN LATERAL unnest(COALESCE(c.delivered_item_ids, ARRAY[]::bigint[])) AS d
   WHERE c.job_id     = p_job_id
     AND c.account_id = v_account_id;

  -- aggregate added-object names
  SELECT array_agg(DISTINCT a ORDER BY a) FILTER (WHERE a IS NOT NULL)
    INTO v_added_objs
    FROM guardops.claim c
    CROSS JOIN LATERAL unnest(COALESCE(c.added, ARRAY[]::text[])) AS a
   WHERE c.job_id     = p_job_id
     AND c.account_id = v_account_id;

  -- aggregate deleted-object names
  SELECT array_agg(DISTINCT del ORDER BY del) FILTER (WHERE del IS NOT NULL)
    INTO v_deleted_objs
    FROM guardops.claim c
    CROSS JOIN LATERAL unnest(COALESCE(c.deleted, ARRAY[]::text[])) AS del
   WHERE c.job_id     = p_job_id
     AND c.account_id = v_account_id;

  -- DELIVERED: plan items whose IDs appear in a claim's delivered list.
  -- Proof: commit SHA + file keys from commit_object for the job's repo link.
  RETURN QUERY
  SELECT
    'DELIVERED'::text,
    pg.item_text,
    COALESCE(
      (SELECT string_agg(cs.sha || ' → ' || co.file_key, '; '
                         ORDER BY cs.committed_at, co.file_key)
         FROM guardops.commit_seen cs
         JOIN guardops.commit_object co
              ON  co.commit_seen_id = cs.id
              AND co.account_id     = v_account_id
        WHERE cs.repo_link_id  = v_repo_link_id
          AND cs.account_id    = v_account_id
          AND v_repo_link_id  IS NOT NULL),
      'no commit record'
    )
  FROM guardops.plan_given pg
  WHERE pg.job_id     = p_job_id
    AND pg.account_id = v_account_id
    AND pg.id = ANY(COALESCE(v_delivered_ids, ARRAY[]::bigint[]));

  -- MISSING: plan items not in any claim's delivered list.
  RETURN QUERY
  SELECT
    'MISSING'::text,
    pg.item_text,
    'not in any claim'::text
  FROM guardops.plan_given pg
  WHERE pg.job_id     = p_job_id
    AND pg.account_id = v_account_id
    AND NOT (pg.id = ANY(COALESCE(v_delivered_ids, ARRAY[]::bigint[])));

  -- ADDED: objects in claim.added[] that the after picture shows appeared.
  -- Proof: before/after picture ids from shape_change.
  RETURN QUERY
  SELECT
    'ADDED'::text,
    obj.name,
    COALESCE(
      (SELECT 'pic ' || sc.prev_picture_id::text
              || '→' || sc.picture_id::text
              || ': ' || sc.schema_name || '.' || sc.object_name
         FROM guardops.shape_change sc
        WHERE sc.database_id  = v_db_id
          AND sc.change_kind  = 'ADDED'
          AND sc.schema_name || '.' || sc.object_name = obj.name
        ORDER BY sc.noticed_at DESC
        LIMIT 1),
      'no shape record'
    )
  FROM unnest(COALESCE(v_added_objs, ARRAY[]::text[])) AS obj(name);

  -- DELETED: objects in claim.deleted[] that the before picture had and the
  -- after picture no longer shows.
  -- Proof: before/after picture ids from shape_change.
  RETURN QUERY
  SELECT
    'DELETED'::text,
    obj.name,
    COALESCE(
      (SELECT 'pic ' || sc.prev_picture_id::text
              || '→' || sc.picture_id::text
              || ': ' || sc.schema_name || '.' || sc.object_name
         FROM guardops.shape_change sc
        WHERE sc.database_id  = v_db_id
          AND sc.change_kind  = 'DELETED'
          AND sc.schema_name || '.' || sc.object_name = obj.name
        ORDER BY sc.noticed_at DESC
        LIMIT 1),
      'no shape record'
    )
  FROM unnest(COALESCE(v_deleted_objs, ARRAY[]::text[])) AS obj(name);

END;
$function$;

REVOKE EXECUTE ON FUNCTION guardops.job_verdict(bigint) FROM PUBLIC;

-- ── rolled-back proof ────────────────────────────────────────────────────────
-- Calls one_run_test(), which runs all 8 steps in its own subtransaction and
-- rolls back every row it writes. We only check the returned verdict rows here.

DO $proof$
DECLARE
  v_fail_count int;
  v_row        record;
BEGIN
  BEGIN
    SELECT count(*) INTO v_fail_count
      FROM guardops.one_run_test()
     WHERE NOT pass;

    IF v_fail_count > 0 THEN
      FOR v_row IN SELECT * FROM guardops.one_run_test() WHERE NOT pass LOOP
        RAISE WARNING 'one_run_test FAIL step=% what=% got=% want=%',
          v_row.step, v_row.what, v_row.got, v_row.want;
      END LOOP;
    END IF;

    ASSERT v_fail_count = 0,
      'one_run_test: ' || v_fail_count || ' row(s) failed';

    RAISE INFO 'proof/0078: one_run_test passed — delivered 2, missing 1, added 1, deleted 1';
    RAISE EXCEPTION 'proof/0078/rollback';

  EXCEPTION
    WHEN OTHERS THEN
      IF sqlerrm = 'proof/0078/rollback' THEN
        NULL; -- expected; proof data rolled back by subtransaction
      ELSE
        RAISE;
      END IF;
  END;
END
$proof$;
