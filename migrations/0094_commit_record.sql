-- migrations/0094_commit_record.sql
-- Split out of 0089 on 26 Nov 2026, byte for byte. Holds one function only.

-- ==========================================================================
-- 7. commit_record: call commit_object_build inline after each commit lands.
--
--    The commit_seen_autobuild_objects trigger was dropped above.  This one
--    added line in commit_record replaces it: every commit that lands now
--    immediately builds its commit_object rows, so job_verdict finds real
--    proof rather than "no commit record".
-- ==========================================================================
CREATE OR REPLACE FUNCTION guardops.commit_record(
    p_repo         text,
    p_branch       text,
    p_sha          text,
    p_author       text,
    p_committed_at timestamptz,
    p_message      text,
    p_files        jsonb,
    p_pull_id      bigint
)
  RETURNS bigint
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

  if p_files is not null and jsonb_typeof(p_files) <> 'object' then
    raise exception '[GIT DOOR] files must be a JSON object, got % - a double-encoded string or array is refused (board 200 A3)', jsonb_typeof(p_files);
  end if;
  if p_files is not null and jsonb_path_exists(p_files, 'strict $.* ? (@.type() != "string")') then
    raise exception '[GIT DOOR] every files value must be a string (a patch or the placeholder) - got a % value (ORDER 94 hole 128)',
      (select jsonb_typeof(e.value) from jsonb_each(p_files) e where jsonb_typeof(e.value) <> 'string' limit 1);
  end if;

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

  -- Build commit_object rows inline, replacing the removed trigger.
  PERFORM guardops.commit_object_build(v_id);

  return v_id;
end $function$;
